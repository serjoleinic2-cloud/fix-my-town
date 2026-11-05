extends SceneTree

const Traffic = preload("res://scripts/traffic_system.gd")
const Simulation = preload("res://scripts/simulation.gd")
var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var traffic := Traffic.new()
	root.add_child(traffic)
	traffic.build()
	traffic.signal_fixed = true
	check(absf(Traffic.stop_distance_for("civilian_car", true) - 3.75) < 0.001, "Grid traffic stops with its bumper just before the new 2.3 m stop line")
	check(absf(Traffic.stop_distance_for("civilian_car") - 5.35) < 0.001, "Legacy traffic retains its original stop-line offset")
	check(absf(Traffic.stop_distance_for("city_bus", true) - 4.83) < 0.001, "Grid bus uses its longer front overhang at the new stop line")
	check(traffic.grid_half_extents(traffic.vehicles[0]).y <= 0.56, "Civilian cars fit within their road lane instead of clipping opposing turns")
	var probe_car: Dictionary = traffic.vehicles[0]
	var original_probe_position: Vector3 = probe_car.node.position
	var original_probe_visibility: bool = probe_car.node.visible
	probe_car.node.visible = true
	probe_car.node.position = Vector3(1001, 0.22, 0)
	traffic.grid = RefCounted.new()
	traffic.blocking_positions.clear()
	check(not traffic.external_vehicle_step_is_clear(Vector3(1000, 0.22, 0), Vector3(1001, 0.22, 0), 0.78, 0.52, "delivery_probe"), "A delivery truck yields instead of driving through a road vehicle")
	probe_car.node.position = original_probe_position
	probe_car.node.visible = original_probe_visibility
	traffic.grid = null
	for i in range(380):
		var time := i * 0.05
		check(not (Traffic.phase("H", time) == "green" and Traffic.phase("V", time) == "green"), "Conflicting greens")
	check(traffic.intersections.size() == 49, "Every grid intersection controlled")
	var turn_lock := {"key": "synthetic_turn_lock", "x": 1000.0, "z": 1000.0, "offset": 0.0, "unsignalized": true}
	check(traffic.permission(turn_lock, "H", "turn_car_a", 0.05), "First car reserves an unsignalized turn conflict point")
	check(not traffic.permission(turn_lock, "V", "turn_car_b", 0.05), "Opposing car waits for the same turn conflict point")
	traffic.reservations.erase("synthetic_turn_lock")
	traffic.grid = RefCounted.new()
	var grid_actor: String = str(traffic.vehicles[0].id)
	check(traffic.permission(turn_lock, "H", grid_actor, 0.05), "Grid car reserves the turn conflict point")
	check(traffic.reservations["synthetic_turn_lock"].get("grid_lock", false), "Grid intersection lease is tracked until the vehicle clears")
	traffic.reservations["synthetic_turn_lock"].entered = true
	var saved_vehicles: Array = traffic.vehicles.duplicate()
	traffic.vehicles.clear()
	for _step in range(60):
		traffic.step(0.05)
	check(traffic.reservations.has("synthetic_turn_lock"), "Grid turn lease does not expire while a car still occupies the intersection")
	traffic.reservations.erase("synthetic_turn_lock")
	traffic.vehicles = saved_vehicles
	traffic.grid = null
	check(traffic.vehicles.filter(func(v): return v.node.type_id == "city_bus").size() == 1, "One replaceable bus")
	var speed_factors: Array = traffic.vehicles.filter(func(v): return bool(v.get("randomized", false))).map(func(v): return float(v.get("speed_factor", 1.0)))
	check(speed_factors.max() - speed_factors.min() > 0.08, "Civilian cars use different cruising speeds")
	for count in [8, 16, 24]:
		traffic.set_active_count(count)
		for axis in ["H", "V"]:
			for direction in [-1, 1]:
				check(traffic.vehicles.any(func(v): return v.node.visible and v.axis == axis and v.direction == direction), "Both directions on both axes")
	traffic.set_active_count(1)
	var car: Dictionary = traffic.vehicles[0]
	car.axis = "H"
	car.direction = 1
	car.road = 0.0
	car.coordinate = Traffic.ROAD_X.back() + 0.1
	traffic.continue_road_loop(car)
	check(car.axis == "V" and car.road == Traffic.ROAD_X.back() and car.direction == 1, "Cars turn onto the outer ring instead of disappearing at the edge")
	car.axis = "H"
	car.direction = 1
	car.road = 0.0
	car.coordinate = -20.0
	traffic.clock = 10.0
	for i in range(15):
		traffic.step(0.1)
	check(is_equal_approx(car.coordinate, -19.75), "Stop before red light at stop line")
	traffic.clock = 0
	traffic.step(0.1)
	check(car.coordinate > -19.75, "Proceed on green")
	traffic.set_active_count(24)
	traffic.signal_fixed = true
	var initial_axes: Dictionary = {}
	for vehicle: Dictionary in traffic.vehicles:
		initial_axes[vehicle.id] = vehicle.axis
	for frame in range(240):
		traffic.step(0.1)
	var changed_routes := traffic.vehicles.filter(func(v): return bool(v.get("randomized", false)) and str(v.axis) != str(initial_axes.get(v.id, v.axis))).size()
	check(changed_routes > 0, "Civilian cars choose independent turns instead of one permanent ring")
	car.axis = "H"
	car.direction = 1
	car.road = 0.0
	car.coordinate = -19.75
	traffic.clock = 7
	traffic.step(0.1)
	check(is_equal_approx(car.coordinate, -19.75), "Yellow stops approaching traffic")
	check(not traffic.service_allowed(Vector3(-19.9, 0, 0), Vector3(0, 0, 0), 0.1), "Service obeys lights")
	traffic.set_active_count(3)
	var bus: Dictionary = traffic.vehicles[2]
	bus.axis = "H"
	bus.direction = 1
	bus.road = 0.0
	bus.coordinate = -12.5
	car.coordinate = -19.75
	traffic.clock = 0
	traffic.step(0.1)
	check(bus.coordinate - car.coordinate >= 5.8, "Safe bus following distance")
	traffic.signal_fixed = false
	var crossing: Dictionary = traffic.find_intersection(-14.4, 0)
	traffic.reservations.clear()
	traffic.wait_times.clear()
	check(not traffic.permission(crossing, "H", "test_a", 0.1), "Broken signal requires stop")
	check(traffic.permission(crossing, "H", "test_a", 1), "First actor proceeds after yielding")
	check(not traffic.permission(crossing, "V", "test_b", 1), "Broken crossing excludes conflicting vehicle")
	# Проверка переднего края кузова, а не только центра, на всех подъездах.
	traffic.signal_fixed = true
	for vehicle_index in [0, 2]:
		traffic.set_active_count(0)
		var vehicle: Dictionary = traffic.vehicles[vehicle_index]
		vehicle.node.show()
		for axis in ["H", "V"]:
			for direction in [-1, 1]:
				vehicle.axis = axis
				vehicle.direction = direction
				vehicle.road = 0.0 if axis == "H" else -14.4
				var center: float = -14.4 if axis == "H" else 0.0
				var stop: float = Traffic.stop_distance_for(vehicle.node.type_id)
				vehicle.coordinate = center - direction * (stop + 2)
				traffic.clock = 10 if axis == "H" else 1
				for frame in range(20):
					traffic.step(0.05)
				check(absf(vehicle.coordinate - (center - direction * stop)) < 0.001, "Vehicle stops exactly before line")
				var front: float = 2.33 if vehicle.node.type_id == "city_bus" else 1.25
				check((center - vehicle.coordinate) * direction - front >= Traffic.STOP_LINE_DISTANCE + 0.19, "Entire body stays behind stop line and zebra")
	# Fire engines ignore the signal phase, while still yielding to an occupied crossing.
	traffic.set_active_count(0)
	traffic.signal_fixed = true
	var emergency_center := Vector3(-14.4, 0, 0)
	var emergency_current := emergency_center + Vector3(-6, 0, 0)
	var emergency_proposed := emergency_center + Vector3(2, 0, 0)
	traffic.clock = 10.0 # Horizontal approach is red.
	var normal_distance := traffic.service_travel_distance(emergency_current, emergency_proposed, 0.1, "fire_test", false)
	var emergency_distance := traffic.service_travel_distance(emergency_current, emergency_proposed, 0.1, "fire_test", true)
	check(normal_distance < 1.0 and emergency_distance > normal_distance, "Fire engine bypasses red signal during an emergency response")
	var crossing_car: Dictionary = traffic.vehicles[0]
	crossing_car.node.show()
	crossing_car.axis = "V"
	crossing_car.direction = 1
	crossing_car.road = -14.4
	crossing_car.coordinate = 0.0
	var blocked_emergency := traffic.service_travel_distance(emergency_current, emergency_proposed, 0.1, "fire_test", true)
	check(blocked_emergency < emergency_distance, "Emergency response still yields to a vehicle occupying the crossing")
	traffic.set_active_count(0)
	for axis in ["H", "V"]:
		for direction in [-1, 1]:
			traffic.clock = 10 if axis == "H" else 1
			var center := Vector3(-14.4, 0, 0)
			var forward := Vector3(direction, 0, 0) if axis == "H" else Vector3(0, 0, direction)
			var current := center - forward * 6
			var proposed := current + forward * 2
			var distance := traffic.service_travel_distance(current, proposed, 0.1)
			check(absf(distance - (6 - Traffic.stop_distance_for("repair_van"))) < 0.001, "Van movement clamps to front clearance")
	# During repair, the stopped van occupies the road and traffic from either direction must wait.
	traffic.intersections.clear()
	traffic.service_active = true
	traffic.service_position = Vector3(0, 0.18, 0)
	for index in [0, 1]:
		var vehicle: Dictionary = traffic.vehicles[index]
		vehicle.node.visible = index < 2
		vehicle.axis = "H"
		vehicle.direction = 1 if index == 0 else -1
		vehicle.road = -1.0 if vehicle.direction == 1 else 1.0
		vehicle.coordinate = -6.0 if vehicle.direction == 1 else 6.0
		var distance := traffic.travel_distance(vehicle, 0.5)
		check(distance <= 2.2, "Traffic yields to a stopped service van from both directions")
	traffic.service_active = false
	var released: Dictionary = traffic.vehicles[0]
	check(traffic.travel_distance(released, 0.5) > 2.2, "Traffic resumes after the service van leaves")
	traffic.blocking_positions = [{"id": "fire_engine_test", "incident_id": "fire_incident", "position": Vector3(0, 0.18, 0)}]
	var queued_vehicle: Dictionary = traffic.vehicles[0]
	queued_vehicle.node.show()
	queued_vehicle.axis = "H"
	queued_vehicle.direction = 1
	queued_vehicle.road = -1.0
	queued_vehicle.coordinate = -6.0
	check(traffic.travel_distance(queued_vehicle, 0.5) <= 2.2, "Civilian traffic queues behind a stopped fire engine")
	traffic.blocking_positions = [{"id": "construction_dump_truck", "position": Vector3(0, 0.18, 0)}]
	var works_vehicle: Dictionary = traffic.vehicles[0]
	works_vehicle.node.show()
	works_vehicle.axis = "H"
	works_vehicle.direction = 1
	works_vehicle.road = -1.0
	works_vehicle.coordinate = -6.0
	check(traffic.travel_distance(works_vehicle, 0.5) <= 2.2, "Civilian traffic queues behind the construction dump truck")
	traffic.blocking_positions = [{"id": "fire_engine_test", "incident_id": "fire_incident", "position": Vector3(0, 0.18, 0)}]
	var following_service := traffic.service_travel_distance(Vector3(-6, 0.18, 0), Vector3(0, 0.18, 0), 0.2, "repair_crew", true)
	check(following_service < 2.0, "A roadblock delays another service vehicle too")
	var police_clearance := traffic.service_travel_distance(Vector3(-6, 0.18, 0), Vector3(0, 0.18, 0), 0.2, "police", false, "fire_incident")
	check(police_clearance > following_service, "Police can reach the exact fire engine it was called to clear")
	traffic.blocking_positions.clear()
	traffic.service_active = true
	traffic.service_position = Vector3(100, 0.18, 100)
	check(not traffic.has_nearby_incident_blocker(Vector3.ZERO), "A distant service van does not block local jam recovery")
	traffic.service_position = Vector3(10, 0.18, 0)
	check(traffic.has_nearby_incident_blocker(Vector3.ZERO), "A nearby service van still blocks recovery")
	traffic.service_active = false
	# Полный сценарий с тем же дорожным контроллером, который вызывает main.
	# Изолированные проверки выше меняли полосы и удаляли перекрёстки.
	traffic.queue_free()
	await process_frame
	traffic = Traffic.new()
	root.add_child(traffic)
	traffic.build()
	check(traffic.intersections.size() == 49, "Integrated scenario retains all intersections")
	traffic.set_active_count(8)
	traffic.clock = 0
	var game := Simulation.new(true)
	game.save_path = "user://traffic_test.json"
	for kind in ["signal", "leak"]:
		check(game.dispatch(kind), "Dispatch integrated scenario")
		for i in range(6000):
			traffic.signal_fixed = game.signal_fixed
			traffic.step(0.05)
			var fraction := 1.0
			if game.route_index < game.route.size():
				var current := preload("res://scripts/district_world.gd").world_position(game.vehicle)
				var proposed := preload("res://scripts/district_world.gd").world_position(game.proposed_vehicle(0.05))
				if current.distance_to(proposed) > 0.0001:
					fraction = traffic.service_travel_distance(current, proposed, 0.05) / current.distance_to(proposed)
			game.tick(0.05, true, fraction)
			if game.job == "":
				break
		if game.job != "":
			print("STUCK ", game.job, " ", game.vehicle, " ", game.route_index, " ", game.job_phase, " phase=", traffic.clock)
		check(game.job == "", "Crew returns without traffic deadlock")
	check(game.signal_fixed and game.leak_fixed, "Integrated repairs complete")
	check(game.build(9, "park") and game.completed, "Integrated scenario completes")
	traffic.queue_free()
	await process_frame
	if failures == 0:
		print("TRAFFIC CHECKS: PASS")
	quit(0 if failures == 0 else 1)
