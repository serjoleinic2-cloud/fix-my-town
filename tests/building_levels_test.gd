extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const Catalog = preload("res://scripts/asset_catalog.gd")
var failures: int = 0
func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game := Simulation.new()
	game.save_path = "user://building_levels_test.json"
	game.budget = 5000
	game.leak_fixed = true
	game.signal_fixed = true
	game.build(9, "cafe")
	game.build(14, "park")
	game.buildings[12] = "cafe"
	game.place_stop(0)
	game.place_stop(4)
	game.start_transit()
	var before: Dictionary = game.metrics()
	var money: int = game.budget
	var predicted: Dictionary = game.project_change(16)
	check(game.budget == money and game.building_level(16) == 1, "Preview never mutates or charges")
	var neighbor_before: int = game.placement_bonus(12, "cafe")
	check(game.upgrade(16) and game.building_level(16) == 2 and game.budget == money - 90, "House upgrade price/level")
	check(game.metrics() == predicted, "Preview matches real population, income, neighborhood, demand and quality")
	check(game.population() == before.population + 4 and game.income() > before.income and game.transit_metrics().demand > before.demand, "House density affects economy/transit")
	check(game.placement_bonus(12, "cafe") > neighbor_before, "Upgraded house changes amenity neighborhood bonus")
	check(game.upgrade(16) and game.building_level(16) == 3, "House reaches third level")
	money = game.budget
	check(not game.upgrade(16) and game.budget == money, "Fourth level rejected")
	game.leak_fixed = false
	check(game.house_quality(16).score <= 19 and game.house_residents(16) == 8, "High-level house still suffers from missing water")
	game.leak_fixed = true
	var surroundings: int = game.house_quality(8).environment
	var income: int = game.income()
	check(game.upgrade(9) and game.upgrade(9), "Cafe reaches third level")
	check(game.income() > income and game.house_quality(8).environment > surroundings, "Cafe level changes income and surrounding quality")
	var park_income: int = game.building_income(14)
	check(game.upgrade(14) and game.upgrade(14) and game.building_income(14) < park_income, "Park raises maintenance with level")
	game.save_game()
	var loaded := Simulation.new()
	loaded.save_path = game.save_path
	check(loaded.load_game() and loaded.levels == game.levels and loaded.metrics() == game.metrics(), "All levels and characteristics survive save/load")
	predicted = loaded.project_change(16, true)
	money = loaded.budget
	var refund: int = loaded.demolition_refund(16)
	check(loaded.demolish(16) and loaded.buildings[16] == "empty" and loaded.building_level(16) == 1, "Demolition empties plot and resets level")
	check(loaded.budget == money + refund and refund == 82, "Refund is 25 percent of base plus upgrades")
	check(loaded.metrics() == predicted and loaded.population() < game.population() and loaded.transit_metrics().demand < game.transit_metrics().demand, "Demolition recomputes all metrics")
	check(loaded.build(16, "house") and loaded.building_level(16) == 1, "Rebuild at level one")
	check(not loaded.demolish(2) and not loaded.upgrade(2), "Depot protected")
	loaded.budget = 0
	check(not loaded.upgrade(16) and loaded.building_level(16) == 1, "Unaffordable improvement is safe")
	# Удаление последней полезной точки обнуляет спрос, не закрывает достижение.
	var route := Simulation.new()
	route.save_path = "user://building_route_test.json"
	route.buildings.fill("empty")
	route.levels.fill(1)
	route.buildings[16] = "house"
	route.buildings[0] = "cafe"
	route.completed = true
	route.leak_fixed = true
	route.budget = 1000
	route.place_stop(0)
	route.place_stop(4)
	route.start_transit()
	var demand: int = route.transit_metrics().demand
	check(route.upgrade(0) and route.transit_metrics().demand > demand, "Cafe demand changes with level")
	check(route.demolish(0) and route.transit_metrics().served == 0 and route.transit_metrics().demand == 0, "No destination means no route utility")
	check(route.completed and route.transit.active, "Demolition does not revoke earned transport")
	# Старый файл без уровней мигрирует; повреждённые уровни отвергаются атомарно.
	var data = JSON.parse_string(FileAccess.get_file_as_string(game.save_path))
	data.version = 1
	data.erase("levels")
	data.erase("completed")
	write_data(game.save_path, data)
	check(loaded.load_game() and loaded.levels.all(func(v): return v == 1), "Old save defaults to level one")
	data.version = 2
	data.levels = game.levels.duplicate()
	data.levels[0] = 4
	write_data(game.save_path, data)
	money = loaded.budget
	check(not loaded.load_game() and loaded.budget == money, "Invalid levels do not partially load")
	# Внешний вид, коллизии, отмены и подтверждение в реальной сцене.
	for resolution in [Vector2i(360, 800), Vector2i(540, 960)]:
		var viewport := SubViewport.new()
		viewport.size = resolution
		viewport.size_2d_override = Vector2i(540, roundi(540.0 * resolution.y / resolution.x))
		viewport.size_2d_override_stretch = true
		viewport.gui_embed_subwindows = true
		root.add_child(viewport)
		var scene = load("res://main.tscn").instantiate()
		scene.game.save_path = "user://test_startup.json"
		viewport.add_child(scene)
		scene.set_process(false)
		scene.game = Simulation.new()
		scene.game.save_path = "user://levels_ui_test.json"
		scene.game.budget = 5000
		for language in ["ru", "en"]:
			scene.game.language = language
			for kind in ["house", "cafe", "park"]:
				scene.game.buildings[16] = kind
				scene.game.levels[16] = 1
				scene.selected = 16
				scene.selection_kind = "plot"
				scene.refresh()
				var object = scene.plots.get_node("plot_16")
				var area = object.interaction_area
				var sockets = object.mounts
				var visual = object.visual_root.get_child(0)
				if kind == "park":
					var benches: Array = visual.find_children("ParkBench*", "Node3D", true, false)
					var fountain := visual.find_child("FountainWater0", true, false) as Sprite3D
					check(benches.size() == 2 and benches.all(func(item): return item.scale.x < 0.8 and absf(item.position.x) > 1.1 and absf(item.position.z) > 1.1), "Park benches are smaller and outside both paths")
					check(fountain != null and fountain.billboard == BaseMaterial3D.BILLBOARD_ENABLED, "Fountain water uses camera-facing 2D sprites")
				money = scene.game.budget
				scene.begin_upgrade()
				for i in range(12):
					await process_frame
				check(scene.preview.level == 2 and scene.preview.visual_root.get_child(0).visual_level == 2, "Preview uses level-specific catalog wrapper")
				check(scene.game.building_level(16) == 1 and scene.game.budget == money and not object.visual_root.visible, "Preview does not change real object")
				check(scene.sheet.position.y > scene.hud.get_global_rect().end.y and scene.sheet.get_global_rect().end.x <= scene.screen.size.x, "Upgrade sheet fits compact screen")
				scene.cancel_upgrade()
				check(object.visual_root.visible and object.visual_root.get_child(0) == visual and scene.game.budget == money, "Cancel restores original unchanged visual")
				scene.confirm_upgrade(16, kind, 1)
				check(object.level == 2 and object.visual_root.get_child(0).visual_level == 2 and object.interaction_area == area and object.mounts == sockets, "Upgrade changes only visual, preserves interactions and mounts")
				money = scene.game.budget
				scene.confirm_upgrade(16, kind, 1)
				check(scene.game.budget == money and scene.game.building_level(16) == 2, "Stale confirmation cannot charge twice")
				scene.game.save_game()
				var restored := Simulation.new()
				restored.save_path = scene.game.save_path
				check(restored.load_game(), "UI upgrade save loads")
				scene.game = restored
				scene.refresh()
				check(scene.plots.get_node("plot_16").level == 2, "Load restores visual level")
				scene.request_demolition(16)
				await process_frame
				var dialog = scene.get_node("DemolitionConfirmation")
				check(dialog.visible and dialog.get_cancel_button().custom_minimum_size.y >= 72, "Demolition has usable cancel confirmation")
				dialog.canceled.emit()
				await process_frame
				check(scene.game.buildings[16] == kind and scene.game.budget == money, "Cancel demolition preserves building")
				scene.request_demolition(16)
				await process_frame
				scene.get_node("DemolitionConfirmation").confirmed.emit()
				await process_frame
				check(scene.game.buildings[16] == "empty" and scene.plots.get_node("plot_16").type_id == "empty", "Confirm demolition redraws vacant lot")
		scene.audio.shutdown()
		await create_timer(0.1).timeout
		viewport.queue_free()
		await process_frame
	if failures == 0:
		print("BUILDING LEVEL CHECKS: PASS")
	quit(0 if failures == 0 else 1)

func write_data(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
