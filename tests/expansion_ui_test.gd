extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
var failures: int = 0

func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for resolution in [Vector2i(360, 800), Vector2i(720, 1600), Vector2i(1080, 2400)]:
		var viewport := SubViewport.new()
		viewport.size = resolution
		viewport.size_2d_override = Vector2i(540, 1200)
		viewport.size_2d_override_stretch = true
		root.add_child(viewport)
		var scene = load("res://main.tscn").instantiate()
		scene.game.save_path = "user://test_startup.json"
		viewport.add_child(scene)
		scene.set_process(false)
		scene.game = Simulation.new()
		scene.game.save_path = "user://expansion_ui_test.json"
		scene.game.budget = 5000
		var straight_links: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT]
		var corner_links: Array[Vector2i] = [Vector2i.LEFT, Vector2i.UP]
		var tee_links: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]
		var cross_links: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
		check(scene.road_topology(straight_links) == "straight", "New road has a straight marking layout")
		check(scene.road_topology(corner_links) == "corner", "A 90-degree connection gets a dedicated corner layout")
		check(scene.road_topology(tee_links) == "tee", "A three-way intersection gets a dedicated crossing layout")
		check(scene.road_topology(cross_links) == "cross", "A four-way intersection gets a dedicated crossing layout")
		scene.open_catalog()
		for frame in range(3):
			await process_frame
		var initial_catalog: Control = scene.sheet
		check(initial_catalog.size.y <= 480, "Catalog with a single house stays compact and does not cover most of the map")
		check(initial_catalog.find_child("ModelPreview_house", true, false) != null, "Building catalog uses a live VisualRoot model preview instead of a placeholder image")
		scene.set_catalog_category("services")
		var police_card: Button = scene.sheet.find_child("CatalogItem_police_station", true, false)
		check(police_card != null and police_card.disabled, "Police station remains visible but locked at city level one")
		scene.game.leak_fixed = true
		scene.game.signal_fixed = true
		scene.refresh()
		check(scene.game.city_level() >= 2 and not scene.sheet.find_child("CatalogItem_police_station", true, false).disabled, "City growth unlocks the next service tier")
		var land_cell := Vector2i(14, 21)
		scene.open_land_cell(land_cell)
		check(scene.selection_kind == "land_cell" and scene.sheet.find_child("ClearLandCell", true, false) != null,
			"Tapping a forest tile opens immediate land actions")
		scene.sheet.find_child("ClearLandCell", true, false).pressed.emit()
		await process_frame
		check(scene.selection_kind == "territory" and scene.territory_tool == "clear" and scene.territory_cell == land_cell,
			"Forest action enters placement mode for the exact tapped tile")
		scene.close_sheet()
		check(scene.game.territory.clear_cell(land_cell.x, land_cell.y), "Prepare a free landscaping tile for the interaction regression")
		scene.open_land_cell(land_cell)
		scene.sheet.find_child("LandscapeLandCell", true, false).pressed.emit()
		await process_frame
		check(scene.selection_kind == "catalog" and scene.catalog_category == "landscaping" and scene.catalog_grid_target == land_cell,
			"A tapped free tile opens the landscaping catalog targeted to that tile")
		scene.sheet.find_child("CatalogItem_lawn", true, false).pressed.emit()
		await process_frame
		check(scene.selection_kind == "territory" and scene.territory_cell == land_cell and scene.territory_tool == "lawn",
			"Choosing lawn keeps the original tap location as the placement preview")
		var one_cell_size: Vector2 = scene.territory_building_visual_size({"width": 1, "height": 1})
		check(one_cell_size.is_equal_approx(Vector2(4.6, 4.6)), "Landscaping ground visual stays inside its one-cell footprint")
		scene.close_sheet()
		var budget_before_cancel: int = scene.game.budget
		scene.open_catalog()
		scene.set_catalog_category("services")
		await process_frame
		scene.sheet.find_child("CatalogItem_fire_station", true, false).pressed.emit()
		await process_frame
		check(scene.selection_kind == "territory" and scene.territory_tool == "fire_station", "Selecting a catalog card enters placement mode")
		scene.cancel_catalog_placement()
		check(scene.selection_kind == "catalog" and scene.game.budget == budget_before_cancel and scene.game.construction_job.is_empty(), "Cancel returns to catalog without reserving money or starting work")
		scene.game.clear_grid_cell(9, 19)
		scene.game.build_grid_road(9, 19)
		for dy in range(2):
			for dx in range(2):
				scene.game.clear_grid_cell(10 + dx, 19 + dy)
		for language in ["ru", "en"]:
			scene.game.language = language
			scene.open_territory()
			scene.set_territory_tool("house")
			scene.territory_cell = Vector2i(17, 27)
			scene.refresh()
			check(scene.territory_reason() == "outside" and scene.sheet.find_child("ConfirmTerritory", true, false).disabled, "An invalid footprint is explained and cannot be purchased")
			var budget: int = scene.game.budget
			var tap := InputEventMouseButton.new()
			tap.button_index = MOUSE_BUTTON_LEFT
			tap.position = scene.camera.unproject_position(scene.game.territory.cell_world(10, 19)) * scene.viewport_container.stretch_shrink
			scene.map_input(tap)
			check(scene.territory_cell == Vector2i(10, 19) and scene.game.budget == budget, "Map taps select a footprint without spending money")
			for frame in range(10):
				await process_frame
			check(scene.preview != null and scene.preview.type_id == "house", "The next building is visible as a 3D preview")
			check(scene.sheet.position.y > scene.hud.get_global_rect().end.y and scene.sheet.get_global_rect().end.y <= scene.navbar.position.y, "Expansion controls fit between HUD and navigation")
		# Подтверждение добавляет дом и открывает его собственную карточку.
		scene.sheet.find_child("ConfirmTerritory", true, false).pressed.emit()
		await process_frame
		check(scene.selection_kind == "construction_job" and not scene.game.construction_job.is_empty() and scene.game.territory.building_at(10, 19).is_empty(), "Confirmed construction reserves funds and saves a worksite before the lot is occupied")
		var house_task: Dictionary = scene.game.construction_job.duplicate(true)
		scene.game.tick(6.1)
		scene.handle_construction_finish(house_task)
		scene.refresh()
		check(scene.selection_kind == "grid_house", "Finished construction opens the new home's card")
		for frame in range(3):
			await physics_frame
		var entry: Dictionary = scene.selected_grid_record()
		var tap := InputEventMouseButton.new()
		tap.button_index = MOUSE_BUTTON_LEFT
		tap.position = scene.camera.unproject_position(entry.position + Vector3(0, 4.7, 0)) * scene.viewport_container.stretch_shrink
		scene.close_sheet()
		scene.map_input(tap)
		check(scene.selection_kind == "grid_house" and scene.grid_selected_id == entry.instance_id, "Tapping the new home's roof selects its own state")
		var original = scene.territory_visuals.get_node(NodePath(entry.instance_id))
		var collision = original.interaction_area
		var budget: int = scene.game.budget
		var saved := FileAccess.get_file_as_string(scene.game.save_path)
		scene.sheet.find_child("UpgradeButton", true, false).pressed.emit()
		await process_frame
		check(scene.selection_kind == "grid_upgrade" and scene.preview.level == 2, "New homes use the same swappable upgrade preview")
		check(not original.visual_root.visible and original.interaction_area == collision and scene.game.budget == budget and scene.selected_grid_record().level == 1, "Preview hides only the original model without changing gameplay")
		check(FileAccess.get_file_as_string(scene.game.save_path) == saved, "Preview never rewrites the saved city")
		scene.sheet.find_child("CancelGridUpgrade", true, false).pressed.emit()
		await process_frame
		check(original.visual_root.visible and scene.preview == null, "Cancel restores the original model")
		scene.sheet.find_child("UpgradeButton", true, false).pressed.emit()
		await process_frame
		scene.close_sheet()
		check(original.visual_root.visible and scene.preview == null, "Closing the panel restores the original model")
		scene.select_grid_house(entry.instance_id)
		scene.sheet.find_child("UpgradeButton", true, false).pressed.emit()
		await process_frame
		scene.select_plot(0)
		check(original.visual_root.visible, "Changing selection restores the original model")
		scene.select_grid_house(entry.instance_id)
		scene.sheet.find_child("UpgradeButton", true, false).pressed.emit()
		await process_frame
		scene.sheet.find_child("ConfirmGridUpgrade", true, false).pressed.emit()
		await process_frame
		var grid_upgrade_task: Dictionary = scene.game.construction_job.duplicate(true)
		check(grid_upgrade_task.get("kind", "") == "upgrade_grid" and scene.selected_grid_record().level == 1, "Confirming upgrade starts a saved worksite without changing the level early")
		scene.game.tick(6.1)
		scene.handle_construction_finish(grid_upgrade_task)
		scene.refresh()
		check(scene.selected_grid_record().level == 2, "Completed upgrade changes the expansion level")
		check(scene.preview == null and scene.territory_visuals.get_node(NodePath(entry.instance_id)).visual_root.visible, "After confirmation only the upgraded real model remains")
		scene.game.territory.building_by_id(entry.instance_id).inspected = true
		scene.refresh()
		check(scene.sheet.find_child("InspectGridHouse", true, false) == null, "Completed access check no longer leaves a permanent inactive button")
		# Нижний старый участок расположен в 14.4 м от дома расширения.
		scene.game.buildings[21] = "empty"
		var bonus: int = scene.game.placement_bonus(21, "cafe")
		check(scene.influence_targets(21, "cafe").any(func(item): return item.instance_id == entry.instance_id), "An expansion house appears in the legacy cafe influence preview")
		check(scene.influence_targets(21, "park").any(func(item): return item.instance_id == entry.instance_id), "An expansion house also appears in the legacy park influence preview")
		scene.selected = 21
		scene.selection_kind = "plot"
		scene.preview_kind = "cafe"
		scene.refresh()
		var base_count: int = scene.highlights.get_child_count()
		scene.game.territory.buildings.erase(scene.game.territory.building_by_id(entry.instance_id))
		check(scene.game.placement_bonus(21, "cafe") == bonus - 4, "The level-two expansion house adds the same neighbor bonus")
		scene.refresh()
		check(scene.highlights.get_child_count() == base_count - 4, "The removed expansion house also loses exactly its four outline edges")
		scene.open_territory()
		scene.set_territory_tool("clear")
		for dy in range(2):
			for dx in range(2):
				scene.open_territory()
				scene.set_territory_tool("clear")
				scene.territory_cell = Vector2i(12 + dx, 19 + dy)
				scene.refresh()
				scene.sheet.find_child("ConfirmTerritory", true, false).pressed.emit()
				await process_frame
				var clear_task: Dictionary = scene.game.construction_job.duplicate(true)
				scene.game.tick(6.1)
				scene.handle_construction_finish(clear_task)
				scene.refresh()
		scene.open_territory()
		scene.set_territory_tool("service")
		scene.set_service_type("fire_station")
		scene.territory_cell = Vector2i(12, 19)
		scene.refresh()
		var service_choice_visible: bool = scene.sheet.find_children("*", "Button", true, false).any(func(item): return item.text == scene.t("fire_station"))
		var service_valid: bool = scene.territory_reason() == "" and not scene.sheet.find_child("ConfirmTerritory", true, false).disabled
		scene.sheet.find_child("ConfirmTerritory", true, false).pressed.emit()
		await process_frame
		check(service_valid and not scene.game.construction_job.is_empty() and scene.game.construction_job.type_id == "fire_station" and scene.game.territory.state_at(13, 20) == "free", "Service selection starts a worksite without occupying its lot early")
		var service_task: Dictionary = scene.game.construction_job.duplicate(true)
		scene.game.tick(6.1)
		scene.handle_construction_finish(service_task)
		scene.refresh()
		check(scene.selected_grid_record().get("type_id", "") == "fire_station" and scene.game.territory.state_at(13, 20) == "occupied", "Finished player-placed fire station occupies its full footprint")
		scene.game.buildings[3] = "cafe"
		scene.select_plot(3)
		check(scene.action_height < 430 and scene.sheet.get_global_rect().end.y <= scene.navbar.position.y + 1, "Café card fits its content without a fixed empty footer")
		scene.toggle_quality()
		check(scene.quality_mode and scene.quality_legend.visible, "Condition mode also covers expansion homes")
		scene.audio.shutdown()
		viewport.queue_free()
		await process_frame
	DirAccess.remove_absolute("user://expansion_ui_test.json")
	await create_timer(0.2).timeout
	print("EXPANSION UI: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
