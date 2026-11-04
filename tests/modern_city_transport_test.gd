extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const Traffic = preload("res://scripts/traffic_system.gd")
const Grid = preload("res://scripts/territory_grid.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := Simulation.new(false)
	game.save_path = "user://modern_city_transport_test.json"
	game.start_empty_city()
	game.budget = 10000
	game.campaign_stage = 4
	for row in range(19, 21):
		for col in range(9, 11):
			game.territory.cells[row][col] = "free"
	check(game.build_grid_building(9, 19, "house"), "Build starter home on ordinary lot")
	check(game.demolish_grid_building("pine_district_house_9_19"), "Demolish one home for replacement")
	game.renewal_credits = 0
	check(game.start_grid_construction(9, 19, "elite_residence"), "One former house lot accepts elite home without two demolition credits")
	game.tick(6.1, false)
	game.tick(1.3, false)
	check(game.territory.building_at(9, 19).get("type_id", "") == "elite_residence", "Timed construction completes a compact elite home")
	game.save_game()
	var loaded := Simulation.new(false)
	loaded.save_path = game.save_path
	check(loaded.load_game() and loaded.territory.building_at(9, 19).width == 2, "Compact elite saves without loss")
	var traffic := Traffic.new()
	root.add_child(traffic)
	traffic.initialize_empty()
	traffic.configure_grid(game.territory, 0, false, [])
	check(traffic.vehicles.is_empty(), "No vehicles are instantiated before population traffic is enabled")
	traffic.configure_grid(game.territory, 5, false, [])
	check(traffic.cars.any(func(car): return car.visible) and not traffic.vehicles[2].node.visible, "Civilians appear on current roads; unlaunched bus stays hidden")
	var before: Vector3 = traffic.vehicles[0].node.position
	var on_roads := true
	var no_overlaps := true
	for frame in range(800):
		traffic.step(0.05)
		for car in traffic.cars:
			if not car.visible:
				continue
			var cell := Vector2i(roundi((car.position.x - Grid.ORIGIN.x) / Grid.CELL_SIZE), roundi((car.position.z - Grid.ORIGIN.z) / Grid.CELL_SIZE))
			on_roads = on_roads and game.territory.state_at(cell.x, cell.y) == "road"
		for first in range(traffic.vehicles.size()):
			var one: Dictionary = traffic.vehicles[first]
			if not one.node.visible:
				continue
			for second in range(first + 1, traffic.vehicles.size()):
				var two: Dictionary = traffic.vehicles[second]
				if not two.node.visible:
					continue
				var half := traffic.grid_half_extents(one) + traffic.grid_half_extents(two)
				no_overlaps = no_overlaps and not (absf(one.node.position.x - two.node.position.x) < half.x - 0.01 and absf(one.node.position.z - two.node.position.z) < half.y - 0.01)
	check(no_overlaps, "Grid vehicles keep physical clearance through turns and queues")
	check(on_roads, "Every sampled civilian position remains on the actual constructed road network")
	check(traffic.vehicles[0].node.position.distance_to(before) > 0.1, "New-city traffic actually moves")
	check(game.transit_available() and not game.completed, "Campaign transit does not require the obsolete legacy repair mission")
	var stops: Array[Vector2i] = []
	for cell in traffic.grid_roads:
		if game.valid_stop_cell(cell):
			stops.append(cell)
	check(stops.size() >= 2, "Current roads offer stop placement")
	if stops.size() >= 2:
		check(game.place_stop(stops[0]) and game.place_stop(stops[-1]) and game.start_transit(), "Player can place two stops and launch bus in new city")
		traffic.configure_grid(game.territory, 0, true, [])
		game.transit.tick(0.1, traffic, game.territory)
		check(traffic.vehicles[2].node.visible, "Launched route gets a visible replaceable bus model")
		game.save_game()
		check(loaded.load_game() and loaded.transit.active and loaded.transit.stops.size() == 2, "Bus and route persist")
	traffic.queue_free()
	await process_frame
	DirAccess.remove_absolute(game.save_path)
	print("MODERN CITY TRANSPORT: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
