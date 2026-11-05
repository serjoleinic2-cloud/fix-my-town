extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const Catalog = preload("res://scripts/asset_catalog.gd")
var failures := 0
var scene: Node

func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func capture(name_value: String) -> void:
	for frame in range(5):
		await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/screenshots/" + name_value + ".png")

func prepare(cell: Vector2i) -> void:
	for dy in range(2):
		for dx in range(2):
			if scene.game.territory.state_at(cell.x + dx, cell.y + dy) == "forest":
				check(scene.game.clear_grid_cell(cell.x + dx, cell.y + dy), "Clear connected footprint")

func test_work(cell: Vector2i, type_id: String) -> void:
	scene.territory_cell = cell
	scene.territory_tool = type_id
	scene.apply_territory_tool()
	check(not scene.game.construction_job.is_empty() and not scene.sheet.visible, "Work starts on the map without a work dialog: " + type_id)
	check(scene.game.territory.building_at(cell.x, cell.y).is_empty(), "Building waits for work completion: " + type_id)
	var visual: Node = scene.construction_objects.site.visual_root.get_child(0)
	for part in ["SquareGround", "Bricks", "Boards", "Pipes", "Barrels", "BuildingFrame"]:
		check(visual.has_node(part), "Visible worksite material: " + part)
	check(not scene.construction_objects.has("truck") and not scene.construction_objects.has("digger") and not scene.construction_objects.has("sign_positions"), "No construction vehicles or road signs are instantiated")
	scene.set_camera_focus(scene.game.territory.cell_world(cell.x, cell.y))
	scene.game.tick(2.0, false)
	scene.refresh()
	await capture("material-" + type_id + "-working")
	scene.game.save_game()
	var resumed := Simulation.new(false)
	resumed.save_path = scene.game.save_path
	check(resumed.load_game() and is_equal_approx(resumed.construction_progress(), scene.game.construction_progress()), "Work progress resumes without offline advancement")
	scene.game = resumed
	var task: Dictionary = scene.game.construction_job.duplicate(true)
	scene.game.tick(4.1, false)
	scene.game.tick(1.3, false)
	scene.handle_construction_finish(task)
	scene.refresh()
	check(scene.game.territory.building_at(cell.x, cell.y).get("type_id", "") == type_id and scene.construction_root.get_child_count() == 0 and not scene.sheet.visible, "Finished building replaces materials and leaves map open: " + type_id)
	await capture("material-" + type_id + "-finished")

func test_upgrade(identifier: String, type_id: String) -> void:
	scene.game.campaign_stage = 2
	check(scene.game.start_grid_upgrade(identifier), "Upgrade starts timed work: " + type_id)
	scene.selection_kind = "construction_job"
	scene.refresh()
	var object: Node = scene.territory_visuals.get_node(NodePath(identifier))
	check(not object.visual_root.visible and object.level == 1 and scene.construction_objects.has("site") and not scene.sheet.visible, "Upgrade shows materials instead of the old model, with no work dialog")
	scene.close_sheet()
	scene.refresh()
	check(not object.visual_root.visible, "Changing UI selection does not reveal the building during upgrade")
	scene.game.tick(2.0, false)
	scene.refresh()
	await capture("material-" + type_id + "-upgrading")
	scene.game.save_game()
	var resumed := Simulation.new(false)
	resumed.save_path = scene.game.save_path
	check(resumed.load_game() and int(resumed.territory.building_by_id(identifier).level) == 1, "Reload keeps original level until upgrade finishes")
	scene.game = resumed
	scene.territory_signature = ""
	scene.refresh()
	object = scene.territory_visuals.get_node(NodePath(identifier))
	check(not object.visual_root.visible and scene.construction_objects.has("site"), "Reload restores the material worksite and hides old model")
	var task: Dictionary = scene.game.construction_job.duplicate(true)
	scene.game.tick(4.1, false)
	scene.game.tick(1.3, false)
	scene.handle_construction_finish(task)
	scene.refresh()
	object = scene.territory_visuals.get_node(NodePath(identifier))
	check(object.visual_root.visible and object.level == 2 and scene.construction_root.get_child_count() == 0, "Finished upgrade replaces worksite with level 2 model")
	scene.close_sheet()
	await capture("material-" + type_id + "-upgraded")

func run() -> void:
	root.size = Vector2i(840, 1870)
	root.content_scale_size = Vector2i(540, 1200)
	scene = load("res://main.tscn").instantiate()
	scene.game.save_path = "user://material_worksite_test.json"
	root.add_child(scene)
	scene.set_process(false)
	scene.game.start_empty_city()
	scene.game.budget = 5000
	scene.game.campaign_finished = true # Keep screenshot fixtures on the map after their build objectives.
	scene.close_subsidy_offer()
	scene.refresh()
	prepare(Vector2i(9, 19))
	await test_work(Vector2i(9, 19), "house")
	await test_upgrade(str(scene.game.territory.building_at(9, 19).instance_id), "house")
	prepare(Vector2i(9, 22))
	scene.catalog_screen_mode = "categories"
	scene.open_land_cell(Vector2i(9, 22))
	scene.sheet.find_child("BuildServiceOnLandCell", true, false).pressed.emit()
	await process_frame
	check(scene.catalog_category == "services" and scene.catalog_screen_mode == "items" and scene.sheet.find_child("CatalogItem_fire_station", true, false) != null, "Free land opens service items directly")
	scene.sheet.find_child("CatalogItem_fire_station", true, false).pressed.emit()
	await process_frame
	check(scene.selection_kind == "catalog_detail" and scene.catalog_target_reason("fire_station") == "" and scene.sheet.find_child("CatalogPlacementStatus", true, false) != null, "Fire station card explains the valid selected footprint")
	for size_value in [Vector2i(360, 640), Vector2i(540, 960), Vector2i(540, 1200)]:
		root.content_scale_size = size_value
		for language in ["ru", "en"]:
			scene.game.language = language
			scene.refresh()
			for frame in range(5):
				await process_frame
			check(scene.sheet.get_global_rect().end.x <= scene.screen.size.x + 1 and scene.sheet_scroll.get_global_rect().end.y <= scene.screen.size.y + 1 and scene.sheet_column.size.x <= scene.screen.size.x, "Fire station card stays within narrow/short screen: %s %s sheet=%s scroll=%s column=%s screen=%s" % [size_value, language, scene.sheet.get_global_rect(), scene.sheet_scroll.get_global_rect(), scene.sheet_column.size, scene.screen.size])
			scene.sheet_scroll.scroll_vertical = 100000
			for frame in range(3):
				await process_frame
			var action: Control = scene.sheet.find_child("PrepareCatalogPlacement", true, false)
			check(scene.sheet_scroll.get_global_rect().encloses(action.get_global_rect()), "Placement action is reachable by scrolling: %s %s" % [size_value, language])
	root.content_scale_size = Vector2i(540, 1200)
	scene.game.language = "ru"
	scene.refresh()
	await capture("material-fire-station-card")
	scene.catalog_grid_target = Vector2i(50, 50)
	scene.refresh()
	check(scene.catalog_target_reason("fire_station") == "outside" and scene.sheet.find_child("CatalogPlacementStatus", true, false).text.contains("не подходит"), "Hidden land gets an explicit invalid-site explanation")
	scene.catalog_grid_target = Vector2i(9, 22)
	scene.refresh()
	scene.sheet.find_child("PrepareCatalogPlacement", true, false).pressed.emit()
	await process_frame
	check(scene.territory_cell == Vector2i(9, 22), "Service placement retains the selected site")
	await test_work(Vector2i(9, 22), "fire_station")
	for item in [{"cell": Vector2i(12, 22), "type_id": "cafe"}, {"cell": Vector2i(15, 19), "type_id": "park"}]:
		prepare(item.cell)
		await test_work(item.cell, item.type_id)
		await test_upgrade(str(scene.game.territory.building_at(item.cell.x, item.cell.y).instance_id), item.type_id)
	for type_id in ["city_hall", "house", "cafe", "depot", "fire_station", "police_station", "hospital", "logistics_center", "warehouse", "bus_stop"]:
		var object: Node = scene.create_object(scene.world, type_id, "label_test_" + type_id, Vector3(0, -100, 0))
		var labels: Array = object.visual_root.find_children("*", "Label3D", true, false)
		var has_no_name: bool = labels.is_empty() or (type_id == "fire_station" and labels.size() == 1 and labels[0].name == "FireStation911" and labels[0].text == "911")
		check(has_no_name, "No text names on model (911 roof emblem is allowed): " + type_id)
		object.queue_free()
	scene.game = Simulation.new(true)
	scene.game.save_path = "user://material_worksite_test.json"
	scene.game.budget = 5000
	check(scene.game.start_legacy_upgrade(16), "Old saved district supports upgrade works")
	scene.refresh()
	check(not scene.plots.get_node("plot_16").visual_root.visible and scene.construction_objects.site.position.is_equal_approx(scene.game.building_world(16)), "Legacy upgrade worksite replaces the model at the actual plot position")
	scene.game.tick(6.1, false)
	scene.game.tick(1.3, false)
	scene.refresh()
	check(scene.plots.get_node("plot_16").visual_root.visible and scene.plots.get_node("plot_16").level == 2 and scene.construction_root.get_child_count() == 0, "Legacy upgrade finishes with level 2 visual")
	scene.audio.shutdown()
	await create_timer(0.2).timeout
	scene.queue_free()
	await process_frame
	await process_frame
	DirAccess.remove_absolute("user://material_worksite_test.json")
	print("MATERIAL WORKSITES: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
