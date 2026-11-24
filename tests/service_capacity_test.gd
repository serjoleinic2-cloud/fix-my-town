extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(540, 1200)
	root.add_child(viewport)
	var scene = load("res://main.tscn").instantiate()
	scene.game.save_path = "user://service_capacity_test.json"
	viewport.add_child(scene)
	scene.set_process(false)
	var game: RefCounted = Simulation.new(true)
	game.save_path = "user://service_capacity_test.json"
	scene.game = game
	game.territory.buildings.clear()
	game.territory.buildings.append({"type_id": "hospital", "instance_id": "h_far", "col": 2, "row": 2, "width": 2, "height": 2, "level": 1})
	game.territory.buildings.append({"type_id": "hospital", "instance_id": "h_near", "col": 30, "row": 30, "width": 2, "height": 2, "level": 1})
	game.territory.buildings.append({"type_id": "police_station", "instance_id": "p_a", "col": 2, "row": 30, "width": 2, "height": 2, "level": 1})
	game.territory.buildings.append({"type_id": "police_station", "instance_id": "p_b", "col": 30, "row": 2, "width": 2, "height": 2, "level": 1})
	var near_point: Vector3 = game.territory.building_center(game.territory.buildings[1]) + Vector3(4, 0, 4)
	check(str(scene.free_hospital_for(near_point).instance_id) == "h_near", "The closest free hospital answers")
	check(scene.ambulance_available(), "Ambulances are available at the start")
	scene.ambulance_jobs.append({"problem_id": "x", "station_id": "h_near"})
	check(str(scene.free_hospital_for(near_point).instance_id) == "h_far", "With the nearest ambulance out, the next hospital sends its own")
	scene.ambulance_jobs.append({"problem_id": "y", "station_id": "h_far"})
	check(scene.free_hospital_for(near_point).is_empty() and not scene.ambulance_available(), "With every ambulance out, a call must wait")
	scene.ambulance_jobs.clear()
	check(not scene.ambulance_jobs.any(func(job: Dictionary) -> bool: return true), "Ambulances return to the hospital after the job")
	var corner: Vector3 = game.territory.building_center(game.territory.buildings[2]) + Vector3(3, 0, -3)
	check(str(scene.free_police_station_for(corner).instance_id) == "p_a", "The closest police station sends a patrol")
	scene.road_police_units.append({"station_id": "p_a"})
	check(str(scene.free_police_station_for(corner).instance_id) == "p_b", "A second station adds a second patrol")
	scene.road_police_units.append({"station_id": "p_b"})
	check(scene.free_police_station_for(corner).is_empty(), "With every patrol out, the call waits in the queue")
	check(scene.start_road_police(corner) == -1, "A busy city reports that all patrols are out")
	if failures.is_empty():
		print("SERVICE CAPACITY CHECKS: PASS")
		quit(0)
	else:
		print("SERVICE CAPACITY CHECKS: FAIL")
		for failure in failures:
			push_error(failure)
		quit(1)
