extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")

var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := Simulation.new(false)
	game.start_empty_city()
	game.territory.buildings.clear()
	game.territory.buildings.append({"type_id": "police_station", "instance_id": "far_police", "col": 2, "row": 2, "width": 2, "height": 2, "level": 1})
	game.territory.buildings.append({"type_id": "police_station", "instance_id": "near_police", "col": 30, "row": 30, "width": 2, "height": 2, "level": 1})
	game.territory.buildings.append({"type_id": "depot", "instance_id": "depot_only", "col": 31, "row": 30, "width": 2, "height": 2, "level": 1})
	var near_point: Vector3 = game.territory.building_center(game.territory.buildings[1]) + Vector3(5, 0, 5)
	var far_point: Vector3 = game.territory.building_center(game.territory.buildings[0]) + Vector3(-3, 0, 2)
	check(str(game.stations_by_distance("police_station", near_point)[0].instance_id) == "near_police", "The police station closest to the call comes first")
	check(str(game.stations_by_distance("police_station", far_point)[0].instance_id) == "far_police", "A call by the other station goes to that station")
	check(game.nearest_station_center(["police_station", "depot"], near_point).distance_to(game.territory.building_center(game.territory.buildings[1])) < 0.01, "The nearest centre is returned")
	check(game.nearest_station_center(["hospital", "depot"], near_point).distance_to(game.territory.building_center(game.territory.buildings[2])) < 0.01, "Missing station types fall back to the next type")
	check(game.nearest_station_center(["hospital"], near_point) == Vector3.INF, "No station gives INF")
	if failures.is_empty():
		print("NEAREST STATION CHECKS: PASS")
		quit(0)
	else:
		print("NEAREST STATION CHECKS: FAIL")
		for failure in failures:
			push_error(failure)
		quit(1)
