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
	for i in range(380):
		var time := i * 0.05
		check(not (Traffic.phase("H", time) == "green" and Traffic.phase("V", time) == "green"), "Conflicting greens")
	check(traffic.intersections.size() == 49, "Every grid intersection controlled")
	check(traffic.vehicles.filter(func(v): return v.node.type_id == "city_bus").size() == 1, "One replaceable bus")
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
	car.coordinate = -20.0
	traffic.clock = 10.0
	for i in range(15):
		traffic.step(0.1)
	check(is_equal_approx(car.coordinate, -19.75), "Stop before red light at stop line")
	traffic.clock = 0
	traffic.step(0.1)
	check(car.coordinate > -19.75, "Proceed on green")
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
	# Полный сценарий с тем же дорожным контроллером, который вызывает main.
	traffic.set_active_count(8)
	traffic.clock = 0
	var game := Simulation.new()
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
