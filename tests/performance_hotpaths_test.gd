extends SceneTree

class CountingGrid:
	extends "res://scripts/territory_grid.gd"
	var reveal_calls := 0
	func reveal_area(col: int, row: int, radius: int = 3) -> void:
		reveal_calls += 1
		super.reveal_area(col, row, radius)

class FoodGrid:
	extends "res://scripts/territory_grid.gd"
	func road_distance_between_buildings(_source: Dictionary, _destination: Dictionary, _max_distance: int = -1) -> int:
		return 3

class SupplySimulation:
	extends "res://scripts/simulation.gd"
	var coverage_calls := 0
	var center_available := true
	var supplied_ids := ["served_home", "restocked_shop"]
	func logistics_center_entry() -> Dictionary:
		return {"instance_id": "test_logistics"} if center_available else {}
	func logistics_covered_buildings(_source_id: String) -> Array[Dictionary]:
		coverage_calls += 1
		var supplied: Array[Dictionary] = []
		for entry: Dictionary in territory.buildings:
			if entry.instance_id in supplied_ids:
				supplied.append(entry)
		return supplied

class ServiceGrid:
	extends "res://scripts/territory_grid.gd"
	var nearest_calls := 0
	var path_calls := 0
	func nearest_road(_point: Vector3) -> Vector2i:
		nearest_calls += 1
		return Vector2i(1, 1) if nearest_calls % 2 == 1 else Vector2i(2, 1)
	func road_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
		path_calls += 1
		return [start, goal]

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var grid := CountingGrid.new()
	grid.initialize_natural_terrain()
	check(grid.install_starting_city_hall(), "Build an isolated starting network")
	grid.set_expansion_level(1)
	var calls_before: int = grid.reveal_calls
	var data_before := grid.data()
	for attempt in range(10):
		grid.set_expansion_level(1)
	check(grid.reveal_calls == calls_before and grid.data() == data_before, "Repeated level queries neither re-reveal the world nor change saved territory")
	for col in range(15, 18):
		grid.cells[19][col] = "road"
	grid.set_expansion_level(1)
	check(grid.reveal_calls > calls_before and grid.is_revealed(18, 19), "Road expansion invalidates the cached visibility result")
	calls_before = grid.reveal_calls
	grid.set_expansion_level(2)
	check(grid.reveal_calls > calls_before and grid.is_revealed(19, 19), "A new level still reveals its larger frontier")
	grid.reset_visibility()
	grid.set_expansion_level(2)
	check(grid.is_revealed(12, 19), "Resetting visibility invalidates the cache")
	var hidden_data := grid.data()
	for row: Array in hidden_data.revealed:
		row.fill(false)
	check(grid.restore(hidden_data), "Restore a valid isolated territory")
	grid.set_expansion_level(2)
	check(grid.is_revealed(12, 19), "Loading an identical road layout does not reuse stale visibility")

	var supply := SupplySimulation.new()
	supply.start_empty_city()
	supply.territory = FoodGrid.new()
	supply.territory.buildings = [
		{"instance_id": "served_home", "type_id": "house", "level": 1, "col": 11, "row": 19, "width": 2, "height": 2},
		{"instance_id": "local_home", "type_id": "house", "level": 2, "col": 12, "row": 19, "width": 2, "height": 2},
		{"instance_id": "restocked_shop", "type_id": "cafe", "level": 1, "col": 10, "row": 20, "width": 2, "height": 2, "food_stock": 100.0},
		{"instance_id": "local_shop", "type_id": "cafe", "level": 1, "col": 11, "row": 20, "width": 2, "height": 2, "food_stock": 100.0},
	]
	supply.advance_food_stocks()
	check(supply.coverage_calls == 1, "The complete delivery coverage is calculated once for a food-stock tick")
	check(is_equal_approx(float(supply.territory.buildings[2].food_stock), 111.76), "Delivery restocks the shop after demand from the 12 local residents")
	check(is_equal_approx(float(supply.territory.buildings[3].food_stock), 99.76), "An uncovered shop pays local demand; supplied residents do not drain it")
	supply.supplied_ids = ["served_home", "local_home", "restocked_shop", "local_shop"]
	supply.advance_food_stocks()
	check(supply.coverage_calls == 2 and is_equal_approx(float(supply.territory.buildings[3].food_stock), 111.76), "The next tick uses fresh delivery coverage and stock replenishment")
	supply.center_available = false
	supply.advance_food_stocks()
	check(supply.coverage_calls == 2 and is_equal_approx(float(supply.territory.buildings[3].food_stock), 111.36), "Without logistics, all 20 residents consume local stock and no network query is needed")
	supply.territory.buildings = supply.territory.buildings.filter(func(entry: Dictionary) -> bool: return entry.type_id == "house")
	supply.center_available = true
	supply.advance_food_stocks()
	check(supply.coverage_calls == 2, "A city with no food shops does not request unused delivery coverage")

	var service_simulation = load("res://scripts/simulation.gd").new()
	service_simulation.territory = ServiceGrid.new()
	service_simulation.territory.buildings = [
		{"instance_id": "workers", "type_id": "depot", "col": 1, "row": 1, "width": 2, "height": 2},
		{"instance_id": "home", "type_id": "house", "col": 3, "row": 1, "width": 2, "height": 2},
	]
	var first_assignment: Dictionary = service_simulation.service_assignment("home")
	var nearest_after_first: int = service_simulation.territory.nearest_calls
	var paths_after_first: int = service_simulation.territory.path_calls
	first_assignment.route.clear()
	var cached_assignment: Dictionary = service_simulation.service_assignment("home")
	check(service_simulation.territory.nearest_calls == nearest_after_first and service_simulation.territory.path_calls == paths_after_first, "Repeated service access checks reuse the assignment while topology is unchanged")
	check(not cached_assignment.route.is_empty(), "Callers cannot mutate the cached service route")
	service_simulation.territory.invalidate_routing_cache()
	service_simulation.service_assignment("home")
	check(service_simulation.territory.nearest_calls > nearest_after_first and service_simulation.territory.path_calls > paths_after_first, "A road topology revision invalidates cached service access")
	var paths_before_direct_building_change: int = service_simulation.territory.path_calls
	service_simulation.territory.buildings.append({"instance_id": "second_home", "type_id": "house", "col": 5, "row": 1, "width": 2, "height": 2})
	service_simulation.service_assignment("home")
	check(service_simulation.territory.path_calls > paths_before_direct_building_change, "A changed building topology invalidates cached service access")
	var replacement_grid := ServiceGrid.new()
	replacement_grid.buildings = service_simulation.territory.buildings.duplicate(true)
	service_simulation.territory = replacement_grid
	service_simulation.service_assignment("home")
	check(replacement_grid.path_calls > 0, "Replacing the territory object cannot reuse an assignment from the previous city")

	var scene = load("res://main.tscn").instantiate()
	scene.game.save_path = "user://test_performance_hotpaths.json"
	scene.settings_path = "user://test_performance_hotpaths_graphics.json"
	scene.set_process(false)
	root.add_child(scene)
	scene.audio.shutdown()
	for dy in range(2):
		for dx in range(2):
			scene.game.territory.cells[19 + dy][15 + dx] = "free"
	check(scene.game.territory.place_building(15, 19, "house"), "Place a house only in the isolated UI test")
	var home: Dictionary = scene.game.territory.building_at(15, 19)
	scene.refresh()
	var signature_before: String = scene.territory_signature
	var terrain_node_id: int = scene.territory_visuals.get_child(0).get_instance_id()
	scene.game.fire_damage[home.instance_id] = 9.0
	scene.refresh()
	check(scene.territory_signature == signature_before and scene.territory_visuals.get_child(0).get_instance_id() == terrain_node_id, "A fire damage tick does not reconstruct static terrain and invalidate logistics in normal map mode")
	scene.game.fire_ruins[home.instance_id] = true
	var state_updates_before: int = scene.territory_state_update_count
	scene.refresh()
	var home_visual = scene.territory_visuals.get_node_or_null(NodePath(str(home.instance_id)))
	check(scene.territory_signature == signature_before and scene.territory_visuals.get_child(0).get_instance_id() == terrain_node_id, "Actual destruction does not rebuild roads and terrain")
	check(scene.territory_state_update_count == state_updates_before + 1 and home_visual != null and home_visual.visual_override == "ruins", "Actual destruction still updates the affected building presentation")
	scene.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://test_performance_hotpaths.json")
	DirAccess.remove_absolute("user://test_performance_hotpaths_graphics.json")
	print("PERFORMANCE HOTPATH CHECKS: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
