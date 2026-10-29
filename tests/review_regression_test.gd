extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const Traffic = preload("res://scripts/traffic_system.gd")
const TerritoryGrid = preload("res://scripts/territory_grid.gd")
var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var empty := Simulation.new(false)
	empty.save_path = "user://empty_city_test.json"
	empty.start_empty_city()
	var has_roads := false
	for row in empty.territory.cells:
		for state in row:
			if state == "road":
				has_roads = true
	check(empty.district_house_count() == 0 and has_roads and empty.empty_city_mode and empty.has_city_hall() and empty.territory.buildings.size() == 1, "New city starts with only the permanent City Hall and its street ring, without inherited homes")
	check(empty.income() == 0 and empty.budget == 0 and empty.job == "" and empty.fires.is_empty(), "Fresh city has no budget income, service vehicle job, or incidents")
	check(empty.incident_penalty() == 0, "Empty city has no legacy service penalty")
	check(empty.territory.is_revealed(12, 20) and not empty.territory.is_revealed(4, 4), "New city starts with a small visible pocket")
	empty.tick(180.0, true)
	check(empty.incidents.is_empty(), "Empty city does not generate incidents on empty terrain")
	check(empty.can_offer_subsidy() and empty.take_subsidy(500), "The player can select a startup grant before earning income")
	for row in range(19, 24):
		for col in range(9, 11):
			empty.territory.clear_cell(col, row)
	check(empty.build_grid_building(9, 19, "house"), "First cleared house connects to the City Hall street ring")
	check(empty.territory.has_constructed_network(), "The connected road network remains available")
	check(empty.territory.is_revealed(6, 19), "Buildings reveal nearby cells outward from the centre")
	check(empty.build_grid_building(9, 22, "house"), "Second house can extend the network linearly")
	var game := Simulation.new(true)
	game.save_path = "user://review_regression_test.json"
	game.budget = 5000
	check(game.incident_penalty() == 5 and game.net_income() == game.income() - 5, "Unresolved service failures reduce periodic net income")
	game.budget = 0
	game.tick(12.0, false)
	check(game.budget == game.income() - game.incident_penalty(), "A populated legacy city recovers only through earned net income")
	game.budget = 5000
	var neglected := Simulation.new(true)
	neglected.save_path = "user://neglect_test.json"
	neglected.signal_fixed = true
	neglected.tick(72.0, false)
	check(neglected.house_damage("pine_district_legacy_12") > 0, "Long-unresolved water failure damages affected homes")
	game.leak_fixed = true
	game.signal_fixed = true
	# Transit regression uses an explicitly prepared legacy road network.
	game.territory.reset()
	game.territory.initialize_legacy_road_network()
	game.build(9, "cafe")
	game.place_stop(0)
	game.place_stop(4)
	check(game.start_transit(), "Route starts")
	var traffic := Traffic.new()
	root.add_child(traffic)
	traffic.build()
	traffic.intersections.clear()
	traffic.set_active_count(0)
	game.transit.tick(3.1, traffic, game.territory)
	var destination: Vector3 = game.transit.route_points.back()
	check(not game.transit.turning_out, "Initial boarding must not skip the first destination")
	check(destination.distance_to(game.transit.stop_position(game.transit.stops[1], game.territory) + Vector3(0, 0.18, 0)) <= TerritoryGrid.CELL_SIZE, "First target follows the road network to the second stop")
	for step in range(500):
		game.transit.tick(0.05, traffic, game.territory)
		if game.transit.trips > 0:
			break
	check(game.transit.trips == 1 and game.transit.bus_position.distance_to(destination) < 0.1, "First trip stops at the destination before returning on the route")
	# Предпросмотр старого участка учитывает жителей расширенной территории.
	for cell in [Vector2i(12, 19), Vector2i(13, 19), Vector2i(14, 19), Vector2i(14, 20), Vector2i(14, 21), Vector2i(14, 22), Vector2i(15, 21), Vector2i(16, 21), Vector2i(15, 22), Vector2i(16, 22)]:
		check(game.clear_grid_cell(cell.x, cell.y), "Clear expansion")
	for cell in [Vector2i(12, 19), Vector2i(13, 19), Vector2i(14, 19), Vector2i(14, 20), Vector2i(14, 21), Vector2i(14, 22)]:
		check(game.build_grid_road(cell.x, cell.y), "Connect expansion")
	check(game.build_grid_house(15, 21), "Build expansion home")
	var before := game.population()
	var predicted: Dictionary = game.project_change(0)
	check(predicted.population == before + 4, "Upgrade preview retains expansion residents")
	check(game.upgrade(0), "Apply predicted upgrade")
	check(predicted == game.metrics(), "Preview and actual metrics agree after expansion")
	check(game.demolish(0), "Demolish legacy home")
	check(not game.territory.buildings.any(func(entry): return entry.get("legacy_plot", -1) == 0), "Demolition releases legacy footprint in territory")
	check(game.build(0, "cafe"), "Rebuild legacy lot as cafe")
	check(game.territory.buildings.any(func(entry): return entry.get("legacy_plot", -1) == 0 and entry.type_id == "cafe"), "Rebuilt type is synchronized with territory")
	var loaded := Simulation.new(true)
	loaded.save_path = game.save_path
	check(loaded.load_game() and loaded.buildings[0] == "cafe", "Rebuilt district reloads")
	check(loaded.territory.buildings.size() == game.territory.buildings.size(), "Synchronization does not duplicate building anchors")
	traffic.queue_free()
	await process_frame
	DirAccess.remove_absolute(game.save_path)
	DirAccess.remove_absolute(neglected.save_path)
	print("REVIEW REGRESSIONS: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
