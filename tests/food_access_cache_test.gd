extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const TerritoryGrid = preload("res://scripts/territory_grid.gd")

class CacheGrid:
	extends "res://scripts/territory_grid.gd"
	var connected := true
	var distance_calls := 0

	func road_distance_between_buildings(_source: Dictionary, _destination: Dictionary, _max_distance: int = -1) -> int:
		distance_calls += 1
		return 3 if connected else -1

	func set_connected(value: bool) -> void:
		connected = value
		invalidate_routing_cache()

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := Simulation.new(false)
	game.start_empty_city()
	var grid := CacheGrid.new()
	game.territory = grid
	grid.buildings = [
		{"instance_id": "home", "type_id": "house", "level": 1, "col": 10, "row": 10, "width": 2, "height": 2},
		{"instance_id": "shop", "type_id": "cafe", "level": 1, "col": 12, "row": 10, "width": 2, "height": 2, "food_stock": 100.0},
		{"instance_id": "center", "type_id": "logistics_center", "level": 1, "col": 8, "row": 10, "width": 2, "height": 2},
	]
	game.reset_food_access_stats()
	check(game.food_access_for(grid.buildings[0]), "A connected stocked shop supplies a residential building")
	var first_calls := grid.distance_calls
	var first_stats := game.food_access_stats()
	check(int(first_stats.misses) == 1 and int(first_stats.buildings_checked) > 0, "The first access query records a miss and the buildings it inspected")
	check(game.food_access_for(grid.buildings[0]), "A repeated access query preserves the result")
	var repeat_stats := game.food_access_stats()
	check(grid.distance_calls == first_calls and int(repeat_stats.hits) == 1, "A repeated query uses the food-access cache without another route search")

	grid.set_connected(false)
	check(not game.food_access_for(grid.buildings[0]), "Changing the road network invalidates cached supply")
	var disconnected_stats := game.food_access_stats()
	check(int(disconnected_stats.misses) == 2 and grid.distance_calls > first_calls, "The disconnected network is recalculated instead of returning stale access")

	grid.buildings = [grid.buildings[0], grid.buildings[2]]
	grid.set_connected(true)
	check(game.food_access_for(grid.buildings[0]), "A logistics center can supply a home without a local shop")
	var logistics_calls := grid.distance_calls
	check(game.food_access_for(grid.buildings[0]) and grid.distance_calls == logistics_calls, "Repeated logistics access reuses both food and coverage caches")
	var logistics_stats := game.food_access_stats()
	check(int(logistics_stats.logistics_misses) > 0, "Coverage cache misses are counted")

	grid.buildings[1].level = 2
	check(game.food_access_for(grid.buildings[0]), "A logistics building upgrade keeps valid supply")
	check(grid.distance_calls > logistics_calls, "A building-level network change invalidates coverage without stale routes")

	grid.buildings = [grid.buildings[0], {"instance_id": "shop", "type_id": "cafe", "level": 1, "col": 12, "row": 10, "width": 2, "height": 2, "food_stock": 0.0}]
	grid.invalidate_routing_cache()
	check(not game.food_access_for(grid.buildings[0]), "An empty shop does not provide food")
	grid.buildings[1].food_stock = 100.0
	check(game.food_access_for(grid.buildings[0]), "Stock changes invalidate food access without changing roads")

	var real_grid := TerritoryGrid.new()
	for col in range(5, 10):
		real_grid.cells[10][col] = "road"
	real_grid.invalidate_routing_cache()
	var source := {"instance_id": "source", "type_id": "house", "col": 5, "row": 8, "width": 2, "height": 2}
	var destination := {"instance_id": "destination", "type_id": "cafe", "col": 8, "row": 8, "width": 2, "height": 2}
	var connected_distance := real_grid.road_distance_between_buildings(source, destination)
	var route_stats_before := real_grid.routing_cache_stats()
	check(connected_distance >= 0, "A real road route connects the supply buildings")
	check(real_grid.road_distance_between_buildings(source, destination) == connected_distance, "The cached real route preserves its distance")
	var route_stats_after := real_grid.routing_cache_stats()
	check(int(route_stats_after.hits) > int(route_stats_before.hits), "A repeated real route query records a cache hit")
	real_grid.cells[10][7] = "free"
	real_grid.invalidate_routing_cache()
	check(real_grid.road_distance_between_buildings(source, destination) < 0, "Removing a road invalidates the cached route")
	real_grid.cells[10][7] = "road"
	real_grid.invalidate_routing_cache()
	check(real_grid.road_distance_between_buildings(source, destination) == connected_distance, "Restoring a road recalculates the valid route")

	print("FOOD ACCESS CACHE CHECKS: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
