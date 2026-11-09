extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const Traffic = preload("res://scripts/traffic_system.gd")
const Grid = preload("res://scripts/territory_grid.gd")
const Catalog = preload("res://scripts/asset_catalog.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check(Catalog.footprint_cells("business_tower") == Vector2i(2, 2), "Business tower fits standard 2x2 lot")
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
	var positive_lane := Traffic.grid_lane_position(Vector3.ZERO, "H", 1)
	var negative_lane := Traffic.grid_lane_position(Vector3.ZERO, "H", -1)
	check(positive_lane.z > 0.56 and negative_lane.z < -0.56, "Opposing horizontal cars stay entirely on their own side of the centre dash")
	check(positive_lane.distance_to(negative_lane) >= 1.12, "Opposing lanes have enough clearance to avoid head-on contact")
	var northbound_lane := Traffic.grid_lane_position(Vector3.ZERO, "V", 1)
	var southbound_lane := Traffic.grid_lane_position(Vector3.ZERO, "V", -1)
	check(northbound_lane.x < -0.56 and southbound_lane.x > 0.56, "Opposing vertical cars stay entirely on their own side of the centre dash")
	var starting_positions: Array[Vector3] = []
	for vehicle: Dictionary in traffic.vehicles:
		starting_positions.append(vehicle.node.position)
	var on_roads := true
	var no_overlaps := true
	var stayed_out_of_center_dash := true
	for frame in range(800):
		traffic.step(0.05)
		for car in traffic.cars:
			if not car.visible:
				continue
			var cell := Vector2i(roundi((car.position.x - Grid.ORIGIN.x) / Grid.CELL_SIZE), roundi((car.position.z - Grid.ORIGIN.z) / Grid.CELL_SIZE))
			on_roads = on_roads and game.territory.state_at(cell.x, cell.y) == "road"
		for vehicle: Dictionary in traffic.vehicles:
			if not vehicle.node.visible or vehicle.get("managed", false) or vehicle.has("turn_exit_cell"):
				continue
			var center: Vector3 = game.territory.cell_world(vehicle.cell.x, vehicle.cell.y)
			var side_clearance := absf(vehicle.node.position.z - center.z) if str(vehicle.axis) == "H" else absf(vehicle.node.position.x - center.x)
			stayed_out_of_center_dash = stayed_out_of_center_dash and side_clearance >= 0.56 + 0.055
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
	check(stayed_out_of_center_dash, "Vehicles do not overlap the longitudinal centre dash outside junction turns")
	check(on_roads, "Every sampled civilian position remains on the actual constructed road network")
	var moving_count := 0
	var active_count := 0
	for index in range(traffic.vehicles.size()):
		if not traffic.vehicles[index].node.visible:
			continue
		active_count += 1
		if traffic.vehicles[index].node.position.distance_to(starting_positions[index]) > 0.5:
			moving_count += 1
	check(moving_count >= mini(2, active_count), "Traffic does not freeze as a single jammed group")
	check(traffic.vehicles[0].node.position.distance_to(starting_positions[0]) > 0.1, "New-city traffic actually moves")
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
	var elite_entry: Dictionary = game.territory.building_at(9, 19)
	check(not elite_entry.is_empty() and game.demolish_grid_building(str(elite_entry.get("instance_id", ""))), "Open the compact parcel for the tower-size regression")
	game.campaign_stage = 5
	game.renewal_credits = 0
	game.budget = 10000
	check(game.start_grid_construction(9, 19, "business_tower"), "Stage-five tower accepts the standard cleared 2x2 parcel")
	check(game.renewal_credits == 0, "Stage-five tower is available without demolition credits")
	game.tick(6.1, false)
	game.tick(1.3, false)
	var tower_entry: Dictionary = game.territory.building_at(9, 19)
	check(tower_entry.get("type_id", "") == "business_tower" and tower_entry.get("width", 0) == 2, "Tall business tower completes in 2x2 cells")
	traffic.queue_free()
	await process_frame
	DirAccess.remove_absolute(game.save_path)
	print("MODERN CITY TRANSPORT: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
