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
	for i in range(360):
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
	check(is_equal_approx(car.coordinate, -18.4), "Stop before red light at stop line")
	traffic.clock = 0
	traffic.step(0.1)
	check(car.coordinate > -18.4, "Proceed on green")
	car.coordinate = -18.4
	traffic.clock = 7
	traffic.step(0.1)
	check(is_equal_approx(car.coordinate, -18.4), "Yellow stops approaching traffic")
	check(not traffic.service_allowed(Vector3(-18.4, 0, 0), Vector3(0, 0, 0), 0.1), "Service obeys lights")
	traffic.set_active_count(3)
	var bus: Dictionary = traffic.vehicles[2]
	bus.axis = "H"
	bus.direction = 1
	bus.road = 0.0
	bus.coordinate = -12.5
	car.coordinate = -18.4
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
			var allowed := true
			if game.route_index < game.route.size():
				allowed = traffic.service_allowed(preload("res://scripts/district_world.gd").world_position(game.vehicle), preload("res://scripts/district_world.gd").world_position(game.route[game.route_index]), 0.05)
			game.tick(0.05, allowed)
			if game.job == "":
				break
		check(game.job == "", "Crew returns without traffic deadlock")
	check(game.signal_fixed and game.leak_fixed, "Integrated repairs complete")
	check(game.build(9, "park") and game.completed, "Integrated scenario completes")
	traffic.queue_free()
	await process_frame
	if failures == 0:
		print("TRAFFIC CHECKS: PASS")
	quit(0 if failures == 0 else 1)
