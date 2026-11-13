extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const Catalog = preload("res://scripts/asset_catalog.gd")
const GameObjectScene = preload("res://scenes/objects/game_object.tscn")
const MainScript = preload("res://scripts/main.gd")
const Traffic = preload("res://scripts/traffic_system.gd")
const Transit = preload("res://scripts/transit.gd")
const DistrictWorld = preload("res://scripts/district_world.gd")
const TerritoryGrid = preload("res://scripts/territory_grid.gd")

var failures := 0

func has_batched_feature(model: Node, feature: StringName) -> bool:
	for batch in model.find_children("*", "MultiMeshInstance3D", true, false):
		if batch.has_meta(feature):
			return true
	return false

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func prepare_footprint(game: RefCounted, col: int, row: int, size: Vector2i) -> void:
	for dy in range(size.y):
		for dx in range(size.x):
			if game.territory.state_at(col + dx, row + dy) == "forest":
				game.territory.cells[row + dy][col + dx] = "free"

func footprints_overlap(first_position: Vector3, first_half: Vector2, second_position: Vector3, second_half: Vector2, padding: float = 0.0) -> bool:
	return absf(first_position.x - second_position.x) < first_half.x + second_half.x + padding and absf(first_position.z - second_position.z) < first_half.y + second_half.y + padding

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var motion_routes: Array = [
		[Vector3.ZERO, Vector3(10, 0, 0)],
		[Vector3(10, 0, 0), Vector3(20, 0, 0)]
	]
	var halted_progress := MainScript.logistics_progress_after_motion(motion_routes, 0, 3.0, 2.0, 0.0)
	check(int(halted_progress.route_index) == 0 and is_equal_approx(float(halted_progress.progress), 3.0), "A logistics vehicle stopped at a signal does not consume route progress")
	var partial_progress := MainScript.logistics_progress_after_motion(motion_routes, 0, 3.0, 2.0, 0.5)
	check(int(partial_progress.route_index) == 0 and is_equal_approx(float(partial_progress.progress), 4.0), "A logistics vehicle commits only its allowed movement distance")
	var resumed_progress := MainScript.logistics_progress_after_motion(motion_routes, 0, 9.5, 1.0, 1.0)
	check(int(resumed_progress.route_index) == 1 and is_equal_approx(float(resumed_progress.progress), 0.5), "A logistics vehicle advances to the next delivery leg only after reaching the route end")
	var turn_route: Array = MainScript.logistics_driving_route([Vector3.ZERO, Vector3(6, 0, 0), Vector3(6, 0, 6)])
	var incoming_turn := (turn_route[1] as Vector3) - (turn_route[0] as Vector3) if turn_route.size() > 1 else Vector3.ZERO
	var junction_turn := (turn_route[2] as Vector3) - (turn_route[1] as Vector3) if turn_route.size() > 2 else Vector3.ZERO
	var outgoing_turn := (turn_route[3] as Vector3) - (turn_route[2] as Vector3) if turn_route.size() > 3 else Vector3.ZERO
	check(turn_route.size() == 4 and incoming_turn.x > 0.0 and junction_turn.z > 0.0 and outgoing_turn.z > 0.0, "A right turn at a T junction follows the direct south branch without a reverse or counter-clockwise center loop")
	var diagonal_half := MainScript.logistics_vehicle_half_extents(Vector3(1, 0, 1))
	check(diagonal_half.x > 0.90 and diagonal_half.y > 0.90, "A turning truck reserves the rotated body bounds instead of cardinal-only extents")
	check(footprints_overlap(Vector3.ZERO, diagonal_half, Vector3(1.0, 0, 0), Vector2(0.78, 0.52), 0.0), "Diagonal truck body bounds detect overlap with a vehicle approaching the turn")
	var route_grid := TerritoryGrid.new()
	for point: Vector2i in [Vector2i(10, 10), Vector2i(11, 10), Vector2i(12, 10), Vector2i(13, 10), Vector2i(14, 10), Vector2i(10, 11), Vector2i(13, 11), Vector2i(14, 11), Vector2i(10, 12), Vector2i(11, 12), Vector2i(12, 12), Vector2i(13, 12), Vector2i(14, 12)]:
		route_grid.cells[point.y][point.x] = "road"
	var mid_block_outbound: Array[Vector2i] = [Vector2i(10, 10), Vector2i(11, 10), Vector2i(12, 10)]
	var legal_return := route_grid.road_route_legal_return(mid_block_outbound)
	check(legal_return.size() > 2 and legal_return[0] == Vector2i(12, 10) and legal_return[1] == Vector2i(13, 10) and legal_return[1] != mid_block_outbound[mid_block_outbound.size() - 2], "A delivery from the middle of a road continues to the next legal node instead of turning around in the segment")
	check(legal_return[legal_return.size() - 2] != mid_block_outbound[1], "A delivery loop returns to its source from a legal approach before continuing on the outbound edge")
	var legal_return_no_midblock_uturn := true
	for route_index in range(2, legal_return.size()):
		var previous_cell: Vector2i = legal_return[route_index - 2]
		var current_cell: Vector2i = legal_return[route_index - 1]
		var next_cell: Vector2i = legal_return[route_index]
		if next_cell == previous_cell and route_grid.road_neighbours(current_cell).size() > 1:
			legal_return_no_midblock_uturn = false
	check(legal_return_no_midblock_uturn, "A delivery return route never reverses at a through road cell")
	var culdesac_grid := TerritoryGrid.new()
	for col in range(20, 25):
		culdesac_grid.cells[30][col] = "road"
	var culdesac_return := culdesac_grid.road_route_legal_return([Vector2i(22, 30), Vector2i(23, 30), Vector2i(24, 30)])
	check(culdesac_return.size() >= 7 and culdesac_return[1] == Vector2i(23, 30) and culdesac_return[2] == Vector2i(22, 30) and culdesac_return[3] == Vector2i(21, 30), "A U-turn is allowed at a cul-de-sac but the return loop avoids reversing at the source mid-block")
	var t_route_grid := TerritoryGrid.new()
	for point: Vector2i in [Vector2i(20, 20), Vector2i(21, 20), Vector2i(22, 20), Vector2i(21, 21)]:
		t_route_grid.cells[point.y][point.x] = "road"
	var right_branch := t_route_grid.road_path(Vector2i(20, 20), Vector2i(21, 21))
	check(right_branch == [Vector2i(20, 20), Vector2i(21, 20), Vector2i(21, 21)], "A T-junction right turn selects the direct branch rather than looping around the block")
	var spawn_route: Array = [Vector3(0, 0.32, 0), Vector3(0, 0.32, -20)]
	var occupied_start: Array = [{"position": Vector3(0, 0.32, 0), "half_extents": Vector2(1.8, 0.6)}]
	var safe_spawn_progress := MainScript.logistics_spawn_progress(spawn_route, 0.0, occupied_start)
	var safe_spawn_pose := MainScript.logistics_route_pose(spawn_route, safe_spawn_progress)
	check(safe_spawn_progress > 0.0 and safe_spawn_pose.position.distance_to(Vector3.ZERO) > 2.5, "A logistics truck does not spawn on top of an occupied bus or car")
	var game := Simulation.new(false)
	game.save_path = "user://logistics_network_test.json"
	game.start_empty_city()
	game.campaign_stage = 6
	game.budget = 20000
	check(Catalog.footprint_cells("logistics_center") == Vector2i(2, 2) and Catalog.footprint_cells("warehouse") == Vector2i(2, 2), "Logistics center and warehouse both fit standard 2x2 lots")
	check(game.can_build_logistics_center() and not game.can_build_warehouse(), "Stage six unlocks one logistics center before warehouses")
	prepare_footprint(game, 9, 19, Vector2i(2, 2))
	check(game.build_grid_building(9, 19, "logistics_center"), "Connected city can build its aligned logistics center")
	var center: Dictionary = game.territory.building_by_id("pine_district_logistics_center_9_19")
	check(not center.is_empty() and game.logistics_warehouse_limit() == 1, "Level-one center authorizes one warehouse")
	if center.is_empty():
		quit(1)
		return
	prepare_footprint(game, 15, 19, Vector2i(2, 2))
	check(game.can_build_warehouse() and game.build_grid_building(15, 19, "warehouse"), "A warehouse can be built on a connected 2x2 site")
	var warehouse: Dictionary = game.territory.building_by_id("pine_district_warehouse_15_19")
	if warehouse.is_empty():
		quit(1)
		return
	check(not warehouse.is_empty() and game.territory.road_distance_between_buildings(center, warehouse, game.logistics_center_range()) >= 0, "Warehouse is connected to the dispatch center within its road range")
	var dispatch_routes: Array = game.logistics_vehicle_routes(str(center.instance_id))
	check(not dispatch_routes.is_empty(), "Center dispatch trucks receive a road route to the warehouse")
	if not dispatch_routes.is_empty():
		var dispatch_route: Array = dispatch_routes[0]
		check((dispatch_route[0] as Vector3).distance_to(dispatch_route[dispatch_route.size() - 1]) < 0.01, "A full logistics tour returns to its source by a separately calculated road path")
		var tour_avoids_midsegment_turnaround := true
		for route_index in range(2, dispatch_route.size()):
			var previous_point: Vector3 = dispatch_route[route_index - 2]
			var current_point: Vector3 = dispatch_route[route_index - 1]
			var next_point: Vector3 = dispatch_route[route_index]
			var previous_cell := Vector2i(roundi((previous_point.x - game.territory.ORIGIN.x) / game.territory.CELL_SIZE), roundi((previous_point.z - game.territory.ORIGIN.z) / game.territory.CELL_SIZE))
			var current_cell := Vector2i(roundi((current_point.x - game.territory.ORIGIN.x) / game.territory.CELL_SIZE), roundi((current_point.z - game.territory.ORIGIN.z) / game.territory.CELL_SIZE))
			var next_cell := Vector2i(roundi((next_point.x - game.territory.ORIGIN.x) / game.territory.CELL_SIZE), roundi((next_point.z - game.territory.ORIGIN.z) / game.territory.CELL_SIZE))
			if next_cell == previous_cell and game.territory.road_neighbours(current_cell).size() > 1:
				tour_avoids_midsegment_turnaround = false
		check(tour_avoids_midsegment_turnaround, "The dispatch tour has no U-turn at a through cell")
	# Recreate the refresh order where configure_grid() leaves the bus at its
	# placeholder until Transit places the saved position. Truck spawns must use
	# the authoritative bus position and avoid every vehicle footprint.
	var jam_traffic := Traffic.new()
	root.add_child(jam_traffic)
	jam_traffic.configure_grid(game.territory, 5, true, [])
	var city_bus: Dictionary = {}
	for traffic_vehicle: Dictionary in jam_traffic.vehicles:
		if traffic_vehicle.node.type_id == "city_bus":
			city_bus = traffic_vehicle
			break
	var center_road_routes := game.logistics_vehicle_routes(str(center.instance_id))
	var center_driving_route := MainScript.logistics_driving_route(center_road_routes[0])
	var bus_conflict_pose: Dictionary = MainScript.logistics_route_pose(center_driving_route, 8.0)
	var original_transit: Variant = game.transit
	var transit_probe := Transit.new()
	transit_probe.active = true
	transit_probe.route_points = [bus_conflict_pose.position, bus_conflict_pose.position + Vector3(0, 0, -12)]
	transit_probe.bus_position = bus_conflict_pose.position
	transit_probe.route_index = 0
	game.transit = transit_probe
	city_bus.node.position = Vector3(1000, 0.22, 1000) # stale grid placeholder immediately after configure_grid()
	var jam_world := DistrictWorld.new()
	root.add_child(jam_world)
	jam_world.traffic_controller = jam_traffic
	var jam_ui: Node = MainScript.new()
	jam_ui.game = game
	jam_ui.scenery = jam_world
	var jam_blockers: Array = jam_ui.logistics_spawn_blockers()
	var placed_bus_position: Vector3 = jam_traffic.lane_position(city_bus)
	check(Vector2(city_bus.node.position.x, city_bus.node.position.z).distance_to(Vector2(placed_bus_position.x, placed_bus_position.z)) < 0.01 and city_bus.node.position.distance_to(Vector3(1000, 0.22, 1000)) > 100, "Logistics spawn synchronizes the visible bus to Transit’s saved position")
	var fleet_blockers: Array = jam_blockers.duplicate(true)
	var fleet_positions: Array[Vector3] = []
	var fleet_clear := true
	for truck_index in range(3):
		var preferred := 8.0 + float(truck_index) * 4.2
		var spawn_progress := MainScript.logistics_spawn_progress(center_driving_route, preferred, fleet_blockers)
		var spawn_pose: Dictionary = MainScript.logistics_route_pose(center_driving_route, spawn_progress)
		var truck_half: Vector2 = MainScript.logistics_vehicle_half_extents(spawn_pose.direction)
		for blocker: Dictionary in fleet_blockers:
			var blocker_position: Vector3 = blocker.position
			var blocker_half: Vector2 = blocker.half_extents
			if absf(spawn_pose.position.x - blocker_position.x) < truck_half.x + blocker_half.x + 0.12 and absf(spawn_pose.position.z - blocker_position.z) < truck_half.y + blocker_half.y + 0.12:
				fleet_clear = false
				break
		fleet_positions.append(spawn_pose.position)
		fleet_blockers.append({"id": "delivery_center_%d" % truck_index, "position": spawn_pose.position, "half_extents": truck_half})
	check(fleet_clear and fleet_positions.size() == 3, "Several logistics trucks receive non-overlapping starts while civilian cars and a bus occupy the center roads")
	check(fleet_positions[0].distance_to(bus_conflict_pose.position) > 2.5, "A logistics truck does not spawn on the bus and remain permanently entangled")
	jam_ui.free()
	jam_world.queue_free()
	jam_traffic.queue_free()
	await process_frame
	var motion_traffic := Traffic.new()
	root.add_child(motion_traffic)
	motion_traffic.make_cars()
	motion_traffic.intersections.clear()
	var ordinary_cars: Array = []
	for traffic_vehicle: Dictionary in motion_traffic.vehicles:
		traffic_vehicle.node.hide()
		if traffic_vehicle.node.type_id == "civilian_car" and ordinary_cars.size() < 2:
			ordinary_cars.append(traffic_vehicle)
	for car_index in range(ordinary_cars.size()):
		var ordinary_car: Dictionary = ordinary_cars[car_index]
		ordinary_car.node.show()
		ordinary_car.axis = "H"
		ordinary_car.direction = 1
		ordinary_car.road = 0.0
		ordinary_car.coordinate = 4.0 + float(car_index) * 8.0
		ordinary_car.node.position = motion_traffic.lane_position(ordinary_car)
	var motion_world := DistrictWorld.new()
	root.add_child(motion_world)
	motion_world.traffic_controller = motion_traffic
	var motion_ui: Node = MainScript.new()
	motion_ui.game = game
	motion_ui.scenery = motion_world
	var moving_truck := GameObjectScene.instantiate()
	root.add_child(moving_truck)
	moving_truck.setup("delivery_truck", "logistics_center_traffic_regression")
	var straight_route: Array = [Vector3(0, 0.32, 0), Vector3(400, 0.32, 0)]
	moving_truck.position = Vector3(0, 0.22, 0)
	motion_ui.logistics_vehicles.clear()
	motion_ui.logistics_vehicles.append({"id": "delivery_center_regression", "object": moving_truck, "routes": [straight_route], "route_index": 0, "progress": 0.0, "speed": 4.5})
	var motion_collision := false
	for frame in range(1200):
		motion_ui.tick_logistics_vehicles(0.05)
		for car_index in range(ordinary_cars.size()):
			var ordinary_car: Dictionary = ordinary_cars[car_index]
			ordinary_car.coordinate += (4.2 + float(car_index) * 0.6) * 0.05
			ordinary_car.node.position = motion_traffic.lane_position(ordinary_car)
			if absf(moving_truck.position.x - ordinary_car.node.position.x) < 2.0 and absf(moving_truck.position.z - ordinary_car.node.position.z) < 1.08:
				motion_collision = true
	check(not motion_collision, "A logistics truck follows moving civilian traffic without becoming entangled or clipping through cars")
	check(moving_truck.position.x > 25.0 and absf(moving_truck.position.z) < 0.01, "A logistics truck continues along its road lane during a 60-second traffic simulation")
	for traffic_vehicle: Dictionary in motion_traffic.vehicles:
		traffic_vehicle.node.hide()
	motion_traffic.blocking_positions.clear()
	motion_traffic.intersections = [{"key": "logistics_t_turn", "x": 0.0, "z": 0.0, "offset": 0.0, "unsignalized": true}]
	var turn_centers: Array[Vector3] = [Vector3(-12, 0.32, 0), Vector3(-6, 0.32, 0), Vector3(0, 0.32, 0), Vector3(0, 0.32, 6), Vector3(0, 0.32, 12)]
	var truck_turn_loop: Array = MainScript.logistics_driving_route(turn_centers)
	motion_traffic.blocking_positions.clear()
	motion_traffic.intersections = [{"key": "logistics_t_turn", "x": 0.0, "z": 0.0, "offset": 0.0}]
	motion_traffic.clock = 18.0
	var waiting_truck := GameObjectScene.instantiate()
	root.add_child(waiting_truck)
	waiting_truck.setup("delivery_truck", "logistics_waiting_turn_front")
	var following_truck := GameObjectScene.instantiate()
	root.add_child(following_truck)
	following_truck.setup("delivery_truck", "logistics_waiting_turn_rear")
	var turn_end_progress: float = MainScript.logistics_route_length([truck_turn_loop[0], truck_turn_loop[1], truck_turn_loop[2], truck_turn_loop[3], truck_turn_loop[4]])
	var front_stop_progress := 6.73
	var rear_safe_progress := front_stop_progress - 2.82
	var waiting_pose: Dictionary = MainScript.logistics_route_pose(truck_turn_loop, front_stop_progress)
	var following_pose: Dictionary = MainScript.logistics_route_pose(truck_turn_loop, rear_safe_progress)
	waiting_truck.position = waiting_pose.position + Vector3(0, -0.10, 0)
	following_truck.position = following_pose.position + Vector3(0, -0.10, 0)
	waiting_truck.rotation.y = atan2(waiting_pose.direction.x, waiting_pose.direction.z)
	following_truck.rotation.y = atan2(following_pose.direction.x, following_pose.direction.z)
	motion_ui.logistics_vehicles.clear()
	motion_ui.logistics_vehicles.append({"id": "delivery_waiting_front", "object": waiting_truck, "routes": [truck_turn_loop], "route_index": 0, "progress": front_stop_progress, "speed": 0.0})
	motion_ui.logistics_vehicles.append({"id": "delivery_waiting_rear", "object": following_truck, "routes": [truck_turn_loop], "route_index": 0, "progress": rear_safe_progress, "speed": 4.5})
	var no_turn_overlap := true
	for frame in range(160):
		motion_ui.tick_logistics_vehicles(0.05)
		var first_heading := Vector3(sin(waiting_truck.rotation.y), 0, cos(waiting_truck.rotation.y))
		var second_heading := Vector3(sin(following_truck.rotation.y), 0, cos(following_truck.rotation.y))
		if footprints_overlap(waiting_truck.position, MainScript.logistics_vehicle_half_extents(first_heading), following_truck.position, MainScript.logistics_vehicle_half_extents(second_heading)):
			no_turn_overlap = false
	check(no_turn_overlap, "Two logistics truck body footprints remain separate while one waits at a turn and the other approaches")
	check(float(motion_ui.logistics_vehicles[1].progress) < front_stop_progress and waiting_truck.position.distance_to(following_truck.position) > 2.7, "A following logistics truck waits behind the stop line outside the leader's footprint")
	motion_ui.logistics_vehicles[0].speed = 4.5
	motion_traffic.clock = 0.0
	var moving_turn_no_overlap := true
	var made_turn_progress := false
	for frame in range(100):
		motion_ui.tick_logistics_vehicles(0.05)
		if float(motion_ui.logistics_vehicles[0].progress) > turn_end_progress + 0.5:
			made_turn_progress = true
		var first_heading := Vector3(sin(waiting_truck.rotation.y), 0, cos(waiting_truck.rotation.y))
		var second_heading := Vector3(sin(following_truck.rotation.y), 0, cos(following_truck.rotation.y))
		if footprints_overlap(waiting_truck.position, MainScript.logistics_vehicle_half_extents(first_heading), following_truck.position, MainScript.logistics_vehicle_half_extents(second_heading)):
			moving_turn_no_overlap = false
	check(moving_turn_no_overlap and made_turn_progress, "Multiple logistics truck bodies do not overlap as they queue, turn and resume through the T junction")
	# Same-lane queues include full truck length and a stable following buffer;
	# the stop line and signal remain independent constraints.
	motion_traffic.blocking_positions.clear()
	motion_traffic.intersections = [{"key": "red_queue", "x": 0.0, "z": 0.0, "offset": 0.0}]
	motion_traffic.clock = 18.0
	var red_front_position := Vector3(-5.27, 0.32, 0.68)
	var truck_half := Vector2(1.13, 0.60)
	var front_red_advance := motion_traffic.service_travel_distance(Vector3(-12, 0.32, 0.68), Vector3(-5, 0.32, 0.68), 0.1, "delivery_red_front", false, "", "delivery_truck")
	check(is_equal_approx(front_red_advance, 6.73) and Traffic.phase("H", motion_traffic.clock) == "red", "A logistics truck stops its front bumper before the red-light stop line")
	motion_traffic.blocking_positions.append({"id": "delivery_red_front", "position": red_front_position, "half_extents": truck_half, "moving_vehicle": true, "axis": "H", "direction": 1})
	var behind_red_ahead := motion_traffic.service_travel_distance(Vector3(-12, 0.32, 0.68), Vector3(-5, 0.32, 0.68), 0.1, "delivery_red_rear", false, "", "delivery_truck")
	check(is_equal_approx(behind_red_ahead, 3.92), "A following logistics truck yields to the leader's full body length before reaching the stop line")
	var follower_can_reach_safe_gap := motion_traffic.external_vehicle_step_is_clear(Vector3(-12, 0.32, 0.68), Vector3(-8.10, 0.32, 0.68), truck_half.x, truck_half.y, "delivery_red_rear", Vector3.RIGHT)
	var follower_cannot_close_gap := motion_traffic.external_vehicle_step_is_clear(Vector3(-12, 0.32, 0.68), Vector3(-8.00, 0.32, 0.68), truck_half.x, truck_half.y, "delivery_red_rear", Vector3.RIGHT)
	check(follower_can_reach_safe_gap and not follower_cannot_close_gap, "A second logistics truck stops behind the first with a 0.55 m clearance instead of touching its body")
	# A civilian car uses the same physical queue rule behind an external truck.
	motion_traffic.blocking_positions[0] = {"id": "civilian_queue_leader", "position": Vector3(-5.0, 0.18, 0.68), "half_extents": Vector2(1.1, 0.56), "moving_vehicle": true, "axis": "H", "direction": 1}
	var car_can_hold_gap := motion_traffic.external_vehicle_step_is_clear(Vector3(-10, 0.18, 0.68), Vector3(-7.80, 0.18, 0.68), 1.1, 0.56, "civilian_following_truck", Vector3.RIGHT)
	var car_clips_queue_leader := motion_traffic.external_vehicle_step_is_clear(Vector3(-10, 0.18, 0.68), Vector3(-7.70, 0.18, 0.68), 1.1, 0.56, "civilian_following_truck", Vector3.RIGHT)
	check(car_can_hold_gap and not car_clips_queue_leader, "A truck behind a normal car uses both vehicles' dimensions and keeps a safe queue interval")
	# A red queue on one approach does not occupy the perpendicular approach.
	var horizontal_approach := Vector3(-5.27, 0.32, 0.68)
	var vertical_approach := Vector3(-0.68, 0.32, -5.27)
	var vertical_half := Vector2(0.60, 1.13)
	var vertical_red_advance := motion_traffic.service_travel_distance(Vector3(-0.68, 0.32, -12), Vector3(-0.68, 0.32, -5), 0.1, "delivery_vertical_red", false, "", "delivery_truck")
	check(is_equal_approx(vertical_red_advance, 6.73) and not footprints_overlap(horizontal_approach, truck_half, vertical_approach, vertical_half, 0.12), "Independent horizontal and vertical red queues stop before their lines without overlapping the junction")
	# Once the signal turns green, the leading truck can reserve and clear the
	# junction; the following truck is then free to advance with the queue.
	motion_traffic.blocking_positions.clear()
	motion_traffic.clock = 0.0
	var green_advance := motion_traffic.service_travel_distance(red_front_position, Vector3(0.0, 0.32, 0.68), 0.1, "delivery_red_front", false, "", "delivery_truck")
	check(Traffic.phase("H", motion_traffic.clock) == "green" and green_advance > 5.0 and motion_traffic.reservations.has("red_queue"), "After green, the waiting truck enters the junction and reserves it rather than remaining deadlocked")
	var no_spawn_route: Array = [Vector3.ZERO, Vector3(30, 0, 0)]
	var impossible_spawn_blockers: Array = [{"position": Vector3.ZERO, "half_extents": Vector2(100, 100)}]
	check(MainScript.logistics_spawn_progress(no_spawn_route, 0.0, impossible_spawn_blockers) < 0.0, "A logistics vehicle is not spawned into a point occupied by an existing vehicle")
	# A city road edit invalidates the TrafficSystem graph state and the route is
	# queried again from the changed network rather than retaining old cells.
	var changed_grid := TerritoryGrid.new()
	for point: Vector2i in [Vector2i(20, 20), Vector2i(21, 20), Vector2i(22, 20), Vector2i(22, 21), Vector2i(22, 22), Vector2i(21, 22), Vector2i(20, 22), Vector2i(20, 21)]:
		changed_grid.cells[point.y][point.x] = "road"
	motion_traffic.reservations["obsolete_delivery_lock"] = {"actor": "delivery_waiting_front", "grid_lock": true, "entered": false, "remaining": 8.0}
	motion_traffic.deadlock_cycles["obsolete_delivery_cycle"] = 8.0
	motion_traffic.configure_grid(changed_grid, 1, false, [])
	motion_traffic.reservations["recreated_delivery_lock"] = {"actor": "delivery_old_route", "grid_lock": true, "entered": true, "remaining": 8.0}
	motion_traffic.wait_times["junction:delivery_old_route"] = 3.0
	motion_traffic.deadlock_cycles["grid_vehicle_0,grid_vehicle_1"] = 4.0
	motion_traffic.deadlock_reroutes["grid_vehicle_0,grid_vehicle_1"] = true
	var blocked_by_old_truck: Dictionary = motion_traffic.vehicles[0]
	blocked_by_old_truck.waiting_on = "delivery_old_route"
	blocked_by_old_truck.waiting_reason = "moving_vehicle"
	blocked_by_old_truck.stalled_time = 5.0
	motion_traffic.blocking_positions = [{"id": "delivery_old_route", "position": Vector3.ZERO}, {"id": "police_blocker", "position": Vector3.ONE}]
	motion_ui.clear_logistics_traffic_blockers()
	var changed_return := changed_grid.road_route_legal_return([Vector2i(20, 20), Vector2i(21, 20), Vector2i(22, 20)])
	check(not motion_traffic.reservations.has("obsolete_delivery_lock") and not motion_traffic.deadlock_cycles.has("obsolete_delivery_cycle"), "A road network edit clears old delivery reservations and wait-cycle state")
	check(motion_traffic.blocking_positions.size() == 1 and str(motion_traffic.blocking_positions[0].id) == "police_blocker", "A road network rebuild removes obsolete logistics truck blockers while retaining unrelated service blockers")
	check(not motion_traffic.reservations.has("recreated_delivery_lock") and not motion_traffic.wait_times.has("junction:delivery_old_route") and not blocked_by_old_truck.has("waiting_on") and motion_traffic.deadlock_cycles.is_empty(), "Refreshing the city removes delivery-specific reservations and stale mutual waits without clearing unrelated physical blockers")
	check(changed_return.size() > 2 and changed_return[1] == Vector2i(22, 21), "A truck recalculates its legal return route after a city network rebuild")
	motion_ui.free()
	motion_world.queue_free()
	motion_traffic.queue_free()
	moving_truck.queue_free()
	waiting_truck.queue_free()
	following_truck.queue_free()
	await process_frame
	game.transit = original_transit
	check(not game.can_build_warehouse() and not game.logistics_upgrade_allowed(warehouse), "Center level one blocks extra warehouses and warehouse upgrades")
	prepare_footprint(game, 12, 16, Vector2i(2, 2))
	check(game.build_grid_building(12, 16, "house"), "A home can be built beside the local road network")
	check(game.logistics_covered_buildings(warehouse.instance_id).any(func(entry: Dictionary): return entry.instance_id == "pine_district_house_12_16"), "Warehouse coverage follows connected roads and reaches nearby homes")
	check(not game.logistics_vehicle_routes(str(warehouse.instance_id)).is_empty(), "Warehouse delivery trucks receive local road routes")
	var police := GameObjectScene.instantiate()
	root.add_child(police)
	police.setup("police_station", "police_visual_test")
	var police_model: Variant = police.visual_root.get_child(0)
	var heli: Node3D = police_model.find_child("PoliceHelicopter", true, false)
	check(has_batched_feature(police_model, "HelipadH") and heli != null, "Police station displays an H helipad and its procedural helicopter")
	police_model._process(100.0)
	check(heli.visible and police_model.helicopter_state == "landing", "Helicopter periodically approaches the helipad")
	police_model._process(10.0)
	check(police_model.helicopter_state == "landed", "Helicopter lands and waits at the police station")
	police_model._process(30.0)
	check(police_model.helicopter_state == "departing" and Vector2(police_model.helicopter_departure_target.x - police_model.helicopter_pad.x, police_model.helicopter_departure_target.z - police_model.helicopter_pad.z).length() > 15.0, "Helicopter departs in a randomized direction")
	police_model._process(10.0)
	check(police_model.helicopter_state == "waiting" and not heli.visible, "Helicopter leaves the scene and returns after a delay")
	police.queue_free()
	await process_frame
	var fire_station := GameObjectScene.instantiate()
	root.add_child(fire_station)
	fire_station.setup("fire_station", "fire_visual_test")
	var fire_model: Variant = fire_station.visual_root.get_child(0)
	var fire_sign: Label3D = fire_model.find_child("FireStation911", true, false) as Label3D
	check(fire_sign != null and fire_sign.text == "911" and has_batched_feature(fire_model, "FireStation911Badge"), "Fire station keeps its visible 911 identification")
	check(has_batched_feature(fire_model, "FireEngineLadder") and has_batched_feature(fire_model, "FireEngineHoseReel") and not has_batched_feature(fire_model, "FireEngineRoofBadge"), "Fire engine uses ladders and hose reels instead of a medical cross")
	fire_station.queue_free()
	await process_frame
	var hospital := GameObjectScene.instantiate()
	root.add_child(hospital)
	hospital.setup("hospital", "hospital_visual_test")
	var hospital_model: Variant = hospital.visual_root.get_child(0)
	check(has_batched_feature(hospital_model, "HospitalRoofBadge") and has_batched_feature(hospital_model, "AmbulanceRoofBadge") and has_batched_feature(hospital_model, "AmbulanceSideBadge"), "Hospital and ambulance carry visible medical emblems")
	hospital.queue_free()
	await process_frame
	var depot := GameObjectScene.instantiate()
	root.add_child(depot)
	depot.setup("depot", "repair_visual_test")
	var depot_model: Variant = depot.visual_root.get_child(0)
	check(has_batched_feature(depot_model, "RepairServiceRoofBadge") and has_batched_feature(depot_model, "RepairVehicleRoofBadge"), "Repair depot and work van have matching roof emblems")
	depot.queue_free()
	await process_frame
	var truck := GameObjectScene.instantiate()
	root.add_child(truck)
	truck.setup("delivery_truck", "delivery_shape_test")
	var truck_model: Variant = truck.visual_root.get_child(0)
	check(has_batched_feature(truck_model, "DeliveryCargoBox") and has_batched_feature(truck_model, "DeliveryCab"), "Logistics truck has a distinct enclosed cargo box and cab")
	check(float(truck_model.delivery_cargo_height) > float(truck_model.delivery_cab_height), "Closed cargo box stands higher than the cab roof")
	truck.queue_free()
	await process_frame
	var logistics_object := GameObjectScene.instantiate()
	root.add_child(logistics_object)
	logistics_object.setup("logistics_center", "logistics_loading_yard_test")
	var logistics_model: Node3D = logistics_object.visual_root.get_child(0)
	var loading_yard: Node3D = logistics_model.get_node_or_null("LogisticsLoadingYard") as Node3D
	check(loading_yard != null, "Logistics center has a distinct unloading yard inside its replaceable visual")
	if loading_yard != null:
		var parked_trucks := loading_yard.find_children("ParkedDeliveryTruck*", "Node3D", true, false)
		var unloading_pallets := loading_yard.find_children("UnloadingBoxes*", "Node3D", true, false)
		check(parked_trucks.size() == 2, "Logistics center displays two parked delivery trucks at its loading bays")
		check(unloading_pallets.size() == 2, "Logistics center displays box pallets beside both parked trucks")
		for parked_truck: Node in parked_trucks:
			check(str(parked_truck.get_meta("yard_role", "")) == "parked_delivery_truck", "Loading-yard trucks are static visual props, not traffic vehicles")
	logistics_object.queue_free()
	await process_frame
	check(not game.can_demolish_grid_building(center.instance_id), "A logistics center with active warehouses cannot be removed")
	check(game.upgrade_grid_house(center.instance_id, true), "The logistics center can be upgraded")
	check(game.logistics_warehouse_limit() == 2 and game.can_build_warehouse() and game.logistics_upgrade_allowed(warehouse), "Center level two permits a second warehouse and level-two warehouse upgrades")
	check(game.upgrade_grid_house(warehouse.instance_id, true) and int(game.territory.building_by_id(warehouse.instance_id).level) == 2, "Warehouse upgrade changes its stored level")
	var ui_script: Script = load("res://scripts/main.gd")
	var ui: Node = ui_script.new()
	ui.game = game
	check(ui.catalog_items_for("infrastructure").has("logistics_center") and ui.catalog_items_for("infrastructure").has("warehouse"), "Construction menu exposes logistics buildings")
	ui.free()
	game.save_game()
	var restored := Simulation.new(false)
	restored.save_path = game.save_path
	check(restored.load_game() and restored.logistics_warehouse_limit() == 2 and int(restored.territory.building_by_id(warehouse.instance_id).level) == 2, "Center and warehouse progression survive saving")
	DirAccess.remove_absolute(game.save_path)
	DirAccess.remove_absolute(game.save_path + ".tmp")
	print("LOGISTICS NETWORK CHECKS: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
