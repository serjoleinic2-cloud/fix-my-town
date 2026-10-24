extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const CitizenPool = preload("res://scripts/citizen_pool.gd")
const DistrictWorld = preload("res://scripts/district_world.gd")
const TrafficSystem = preload("res://scripts/traffic_system.gd")

var failures: int = 0

func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := Simulation.new(true)
	game.buildings[3] = "cafe"
	game.transit.stops = [0, 5]
	game.transit.active = true
	game.transit.funded = true
	var population_before: int = game.population()
	var budget_before: int = game.budget
	var transit_demand_before: int = int(game.transit_metrics().demand)
	var pool := CitizenPool.new()
	root.add_child(pool)
	var traffic := TrafficSystem.new()
	root.add_child(traffic)
	traffic.build()
	traffic.signal_fixed = true
	pool.setup(game, "high", Callable(DistrictWorld, "world_position"), traffic)
	check(pool.get_child_count() == 12 and pool.walkers.size() == 12, "High quality uses a bounded 12-person visual pool")
	check(pool.walkers[0].position.distance_to(game.building_world(0) + Vector3(0, 0.06, 4.65)) < 0.01,
		"Legacy building positions already use world coordinates and are not transformed a second time")
	check(pool.walkers[0].state == ("walk_stop" if pool.walkers[0].uses_bus else "walk_dest"), "Residents use the bus only when their destination belongs to the other stop")
	var route_probe := {"home": {"position": Vector3(-14.4, 0, -31.35)}, "destination": {"position": Vector3(-14.4, 0, 31.35)}}
	check(pool._assign_transit_stops(route_probe) and route_probe.from_stop == 0 and route_probe.to_stop == 1,
		"Commuters board at the stop nearest home and alight at the stop nearest their destination")
	var first: Sprite3D = pool.walkers[0].visual
	check(first.billboard == BaseMaterial3D.BILLBOARD_ENABLED and first.texture != null, "Pedestrians are camera-facing 2D figures")
	check(pool.walkers[0].frames.size() == 2 and pool.walkers[0].frames[0] != pool.walkers[1].frames[0], "Walk cycles and resident appearances use distinct generated frames")
	var sidewalk_start: Vector3 = game.territory.cell_world(12, 18)
	var sidewalk_finish: Vector3 = game.territory.cell_world(15, 18)
	var sidewalk_route: Array[Vector3] = pool._sidewalk_route(sidewalk_start, sidewalk_finish)
	check(sidewalk_route.size() >= 3 and is_equal_approx(absf(sidewalk_route[1].z - sidewalk_start.z), 2.5),
		"Residents use legacy pavement outside the 2.1m asphalt lane instead of walking on the roadway")
	traffic.clock = 0.0
	check(pool._pedestrian_can_advance(Vector3(-16.0, 0, 0), Vector3(-14.4, 0, 0)), "Residents can cross while the traffic signal for that crossing is red")
	traffic.clock = 10.0
	check(not pool._pedestrian_can_advance(Vector3(-16.0, 0, 0), Vector3(-14.4, 0, 0)), "Residents wait at the crosswalk while the crossing traffic has a green light")
	var walker: Dictionary = pool.walkers[0]
	walker.home = {"position": Vector3(-14.4, 0, -31.35)}
	walker.destination = {"position": Vector3(-14.4, 0, 31.35)}
	walker.state = "waiting"
	walker.from_stop = 0
	walker.to_stop = 1
	walker.position = pool._stop_curb(0)
	walker.route = []
	pool.walkers[0] = walker
	game.transit.current_target = 0
	game.transit.dwell = 2.0
	pool.tick(0.1)
	check(pool.walkers[0].state == "boarding", "Waiting passengers board when their bus arrives")
	pool.tick(0.5)
	check(pool.walkers[0].state == "riding" and not (pool.walkers[0].visual as Sprite3D).visible, "Boarded people ride inside the bus and leave the street sprites")
	game.transit.current_target = 1
	game.transit.dwell = 2.0
	pool.tick(0.1)
	check(pool.walkers[0].state == "walk_dest" and (pool.walkers[0].visual as Sprite3D).visible, "Passengers get off at their destination stop")
	walker = pool.walkers[0]
	walker.route = []
	walker.route_index = 0
	pool.walkers[0] = walker
	pool.tick(0.1)
	check(pool.walkers[0].state == "inside", "Residents enter a destination building after walking from the stop")
	pool.tick(0.5)
	check(not (pool.walkers[0].visual as Sprite3D).visible, "A visitor fades out at the destination entrance")
	pool.tick(1.6)
	check(pool.walkers[0].state == "walk_stop" and pool.walkers[0].from_stop == 1, "After a visit, a resident walks back toward the return stop")
	check((pool.walkers[0].visual as Sprite3D).visible, "A resident appears again at the door before walking away")
	for _frame in range(60):
		pool.tick(0.1)
	check(game.population() == population_before and game.budget == budget_before and int(game.transit_metrics().demand) == transit_demand_before,
		"Visual pedestrian movement does not simulate per-person population, budget, or transit demand")
	pool.set_quality("low")
	await process_frame
	check(pool.get_child_count() == 4 and pool.walkers.size() == 4, "Low quality limits pedestrians to four sprites")
	pool.set_quality("medium")
	await process_frame
	check(pool.get_child_count() == 8 and pool.walkers.size() == 8, "Medium quality uses an eight-person cap")
	print("CITIZEN POOL: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
