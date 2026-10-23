extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const Traffic = preload("res://scripts/traffic_system.gd")
var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := Simulation.new()
	game.save_path = "user://transit_quality_test.json"
	check(not game.place_stop(Vector2i(18, 0)), "Transit waits for completed scenario")
	check(game.WATER_AFFECTED_HOMES.size() == 3, "Exactly three affected houses")
	for i in range(24):
		if game.buildings[i] == "house":
			check(game.has_water(i) == (i not in game.WATER_AFFECTED_HOMES), "Addressed water supply")
	var isolated := Simulation.new()
	isolated.buildings.fill("empty")
	isolated.buildings[8] = "house"
	isolated.buildings[1] = "house"
	check(isolated.placement_bonus(0, "cafe") == 2, "World geometry excludes two rows away, includes adjacent column")
	isolated.buildings.fill("empty")
	isolated.buildings[4] = "house"
	check(isolated.placement_bonus(0, "cafe") == 2, "Equal visible distances give equal bonus on either axis")
	isolated.buildings.fill("empty")
	isolated.buildings[0] = "house"
	isolated.buildings[16] = "house"
	check(is_equal_approx(isolated.district_quality(), (62.0 * 8 + 19.0 * 4) / 12), "District quality weighted by residents, not by houses")
	check(game.house_quality(16).score <= 19, "No water is critical")
	var before: float = game.district_quality()
	game.leak_fixed = true
	check(game.district_quality() > before and game.house_quality(16).water, "Repair immediately improves quality")
	game.signal_fixed = true
	game.budget = 1000
	game.build(9, "cafe")
	check(game.completed, "Scenario completed before transit")
	before = game.district_quality()
	var house_point: Vector3 = game.building_world(16)
	var cafe_point: Vector3 = game.building_world(9)
	var first: Vector2i = game.territory.nearest_road(house_point)
	var second: Vector2i = game.territory.nearest_road(cafe_point)
	check(game.place_stop(first) and not game.place_stop(first), "Stops require a unique connected road cell")
	check(game.place_stop(second), "Second stop can be placed on another street")
	check(game.stop_orientation(game.transit.stops[0]) in ["horizontal", "vertical"] and game.stop_orientation(game.transit.stops[1]) in ["horizontal", "vertical"], "Every placed stop receives an along-road orientation")
	check(not game.place_stop(Vector2i(0, 29)), "A forest cell is not a stop location")
	check(game.transit.route_for(game.territory, 0, 1).size() > 4, "Route follows a connected multi-cell road path")
	var route := game.transit.route_for(game.territory, 0, 1)
	var has_turn := false
	for index in range(2, route.size()):
		var first_axis := (route[index - 1] - route[index - 2]).normalized()
		var next_axis := (route[index] - route[index - 1]).normalized()
		if absf(first_axis.dot(next_axis)) < 0.1:
			has_turn = true
	check(has_turn, "Bus route has an actual turn at the road intersection")
	check(game.move_stop(0, second) == false, "Moving a stop onto the other endpoint is rejected")
	check(game.start_transit(), "One bus route launches")
	check(not game.start_transit(), "No duplicate buses or charge")
	var current_path: Array[Vector3] = game.transit.route_points.duplicate()
	var current_target: int = game.transit.current_target
	var alternate := Vector2i(12, 6)
	check(game.move_stop(1, alternate), "A stop can move to a connected road on another street")
	check(game.transit.route_dirty and game.transit.current_target == current_target and game.transit.route_points == current_path, "An active bus safely finishes its current leg before retargeting")
	check(game.transit_metrics().covered > 0, "Route endpoints provide walking coverage")
	check(game.district_quality() >= before, "Transit quality is recalculated without reducing prior services")
	check(game.happiness() != roundi(game.district_quality()), "Mayor rating is independent")
	var budget: int = game.budget
	game.income_clock = 11.95
	game.tick(0.1)
	check(game.budget == budget + game.income() - 3, "Route maintenance charged")
	var traffic := Traffic.new()
	root.add_child(traffic)
	traffic.build()
	traffic.set_active_count(3)
	traffic.vehicles[2].managed = true
	traffic.vehicles[0].node.hide()
	traffic.vehicles[1].node.hide()
	traffic.signal_fixed = false
	for i in range(2400):
		traffic.step(0.05)
		game.transit.tick(0.05, traffic, game.territory)
	check(game.transit.trips >= 2 and game.transit.last_delay > 0, "Bus follows its route and waits at the broken traffic signal")
	check(traffic.vehicles[2].node.visible, "Managed route bus remains visible in traffic")
	game.save_game()
	var loaded := Simulation.new()
	loaded.save_path = game.save_path
	check(loaded.load_game(), "Transit save loads")
	check(loaded.transit.stops == game.transit.stops and loaded.transit.active and loaded.transit.trips == game.transit.trips, "Stops and active route persist")
	check(loaded.transit.route_points == game.transit.route_points and loaded.transit.route_index == game.transit.route_index and loaded.transit.bus_position == game.transit.bus_position, "Bus route, position and leg progress persist")
	check(is_equal_approx(loaded.district_quality(), game.district_quality()), "Quality recalculated after load")
	for band in range(5):
		check(Simulation.quality_band(band * 20) == band and Simulation.quality_band(band * 20 + 19) == band, "Band boundaries")
	game.buildings.fill("empty")
	check(game.district_quality() < 0, "No residents means no data")
	game.transit.funded = false
	check(game.transit_metrics().served == 0, "Unfunded route has no service")
	game.buildings.fill("house")
	game.transit.funded = true
	check(game.transit_metrics().covered > 0 and game.transit_metrics().served == 0, "Coverage without destinations gives no utility")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(loaded.save_path))
	data.erase("transit")
	var file := FileAccess.open(loaded.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	check(loaded.load_game() and not loaded.transit.active, "Older saves without a transit section remain compatible")
	traffic.queue_free()
	await process_frame
	for resolution in [Vector2i(360, 800), Vector2i(540, 960), Vector2i(1080, 2400)]:
		var viewport := SubViewport.new()
		viewport.size = resolution
		viewport.size_2d_override = Vector2i(540, roundi(540.0 * resolution.y / resolution.x))
		viewport.size_2d_override_stretch = true
		root.add_child(viewport)
		var scene = load("res://main.tscn").instantiate()
		viewport.add_child(scene)
		scene.set_process(false)
		scene.game = Simulation.new()
		scene.game.save_path = "user://transit_ui_test.json"
		scene.refresh()
		for i in range(24):
			var object = scene.plots.get_node("plot_%d" % i)
			if object.type_id == "house":
				check(object.serviced_value == (i not in scene.game.WATER_AFFECTED_HOMES), "Only three house visuals lose water")
		scene.game.leak_fixed = true
		scene.refresh()
		for i in range(24):
			var object = scene.plots.get_node("plot_%d" % i)
			if object.type_id == "house":
				check(object.serviced_value, "Every home has water after repair")
		scene.game.signal_fixed = true
		scene.game.budget = 1000
		scene.game.build(9, "cafe")
		for language in ["ru", "en"]:
			scene.game.language = language
			for mode in ["house", "condition", "transit", "placement"]:
				scene.placing_stop = false
				scene.quality_mode = mode == "condition"
				if mode in ["house", "condition"]:
					scene.selected = 16
					scene.selection_kind = "plot"
				else:
					scene.selection_kind = "transit"
					scene.selected = -1
					scene.placing_stop = mode == "placement"
				scene.refresh()
				for i in range(15):
					await process_frame
				check(scene.sheet.position.y >= scene.hud.get_global_rect().end.y, "Panel leaves map and HUD accessible: " + mode)
				check(scene.sheet.get_global_rect().end.x <= scene.screen.size.x, "Panel width fits: " + mode)
				check(scene.sheet.get_global_rect().end.y <= scene.navbar.position.y, "Panel above navigation: " + mode)
				check(scene.screen.get_node("MapTools").get_global_rect().end.x <= scene.screen.size.x - 15, "Map buttons inside safe area")
			scene.selected = 16
			scene.selection_kind = "plot"
			scene.refresh()
			check(scene.house_problems(16).size() >= 1, "House explains current problem")
			var labels: Array = scene.sheet_column.get_children().filter(func(n): return n.has_meta("house_problem"))
			check(labels.size() <= 2, "Normal house panel has at most two issues")
		viewport.queue_free()
		await process_frame
	if failures == 0:
		print("TRANSIT + QUALITY CHECKS: PASS")
	quit(0 if failures == 0 else 1)
