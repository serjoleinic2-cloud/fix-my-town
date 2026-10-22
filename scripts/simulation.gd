extends RefCounted

const Transit = preload("res://scripts/transit.gd")
var transit = Transit.new()
const WATER_AFFECTED_HOMES = [12, 16, 20]
const AMENITY_RADIUS: float = 22.0

const Catalog = preload("res://scripts/asset_catalog.gd")

const SAVE_PATH = "user://progress.json"
var budget: int = 300
var language: String = "ru"
var leak_fixed: bool = false
var signal_fixed: bool = false
var buildings: Array = []
var job: String = ""
var job_phase: String = "travel"
var route: Array = []
var route_index: int = 0
var vehicle: Vector3 = Vector3(3, 0, -6)
var repair_left: float = 4.0
var income_clock: float = 0.0
var completed: bool = false
var save_path: String = SAVE_PATH

func _init() -> void:
	for i in range(24):
		buildings.append("empty" if i in [3, 7, 9, 14] else "house")
	buildings[2] = "depot"

func plot_position(index: int) -> Vector3:
	return Vector3(-9 + (index % 4) * 6, 0, -7.5 + (index / 4) * 3)

func happiness() -> int:
	var value := 38 + (18 if leak_fixed else 0) + (14 if signal_fixed else 0)
	for i in range(24):
		if buildings[i] in ["cafe", "park"]:
			value += Catalog.TYPES[buildings[i]].mood + placement_bonus(i, buildings[i])
	return clampi(value + (3 if transit_metrics().served > 0 else -5), 0, 100)

func placement_bonus(index: int, kind: String) -> int:
	var bonus := 0
	for i in range(24):
		if i != index and building_world(i).distance_to(building_world(index)) < AMENITY_RADIUS:
			if buildings[i] == "house":
				bonus += 2
			if (kind == "cafe" and buildings[i] == "park") or (kind == "park" and buildings[i] == "cafe"):
				bonus += 3
	return bonus

func house_residents(index: int) -> int:
	if buildings[index] != "house":
		return 0
	return 8 if has_water(index) else 4

func population() -> int:
	var total := 0
	for index in range(24):
		total += house_residents(index)
	return total

func has_water(index: int) -> bool:
	return leak_fixed or index not in WATER_AFFECTED_HOMES

func building_world(index: int) -> Vector3:
	return preload("res://scripts/district_world.gd").world_position(plot_position(index))

func transit_metrics() -> Dictionary:
	var covered := 0
	var served := 0
	for i in range(24):
		if buildings[i] != "house":
			continue
		if transit.stops.any(func(row): return transit.in_range(building_world(i), row)):
			covered += house_residents(i)
		if house_transit(i):
			served += house_residents(i)
	return {"covered": covered, "served": served, "demand": ceili(served * 0.25), "load": mini(Transit.CAPACITY, ceili(served * 0.25)), "capacity": Transit.CAPACITY}

func house_transit(index: int) -> bool:
	if not transit.active or not transit.funded or transit.stops.size() != 2:
		return false
	var point := building_world(index)
	for j in range(2):
		if not transit.in_range(point, transit.stops[j]):
			continue
		for i in range(24):
			if buildings[i] in ["cafe", "depot"] and transit.in_range(building_world(i), transit.stops[1 - j]):
				return true
	return false

func place_stop(row: int) -> bool:
	if not completed or row < 0 or row > 5 or transit.stops.size() >= 2 or row in transit.stops or budget < Transit.STOP_COST:
		return false
	budget -= Transit.STOP_COST
	transit.stops.append(row)
	transit.stops.sort()
	save_game()
	return true

func start_transit() -> bool:
	if not completed or transit.active or transit.stops.size() != 2 or budget < Transit.BUS_COST:
		return false
	budget -= Transit.BUS_COST
	transit.active = true
	transit.funded = true
	transit.coordinate = Transit.ROW_Z[transit.stops[0]]
	transit.direction = 1
	transit.dwell = 3
	save_game()
	return true

func house_quality(index: int) -> Dictionary:
	var water := has_water(index)
	var point := building_world(index)
	var services := signal_fixed or point.x >= 0 or point.z < 0
	var transport := house_transit(index)
	var environment := 12
	for i in range(24):
		if buildings[i] in ["cafe", "park"] and building_world(i).distance_to(point) < AMENITY_RADIUS:
			environment += 8 if buildings[i] == "cafe" else 10
	var score := (30 if water else 0) + (20 if services else 10) + (20 if transport else 0) + mini(environment, 30)
	if not water:
		score = mini(score, 19)
	return {"score": clampi(score, 0, 100), "water": water, "services": services, "transport": transport, "environment": mini(environment, 30)}

func district_quality() -> float:
	var total := 0
	var weighted := 0
	for i in range(24):
		var residents := house_residents(i)
		weighted += residents * house_quality(i).score
		total += residents
	return float(weighted) / total if total > 0 else -1.0

static func quality_band(score: float) -> int:
	return clampi(int(score) / 20, 0, 4)

func income() -> int:
	return 12 + (8 if leak_fixed else 0) + buildings.count("cafe") * 6 - buildings.count("park") * 2

func build(index: int, kind: String) -> bool:
	if index < 0 or index >= 24 or buildings[index] != "empty" or kind not in ["cafe", "park"]:
		return false
	var cost := Catalog.cost(kind)
	if budget < cost:
		return false
	budget -= cost
	buildings[index] = kind
	check_complete()
	save_game()
	return true

func dispatch(kind: String) -> bool:
	if job != "" or kind not in ["signal", "leak"]:
		return false
	if (kind == "signal" and signal_fixed) or (kind == "leak" and leak_fixed):
		return false
	var cost := Catalog.cost("traffic_signal" if kind == "signal" else "water_leak")
	if budget < cost:
		return false
	budget -= cost
	job = kind
	job_phase = "travel"
	vehicle = Vector3(3, 0, -6)
	route = [Vector3(-7, 0, -6), Vector3(-7, 0, -3), Vector3(-7, 0, 0)]
	if kind == "leak":
		route.append(Vector3(-7, 0, 6))
		route.append(Vector3(-9, 0, 6))
	route_index = 0
	repair_left = 4.0
	save_game()
	return true

func tick(delta: float, movement_allowed: bool = true) -> bool:
	var changed := false
	income_clock += delta
	if income_clock >= 12.0:
		income_clock -= 12.0
		budget += income()
		if transit.active:
			transit.funded = budget >= Transit.UPKEEP
			if transit.funded:
				budget -= Transit.UPKEEP
		changed = true
	if job != "":
		if route_index < route.size():
			if movement_allowed:
				var target: Vector3 = route[route_index]
				var speed := 2.6
				if not signal_fixed and absf(vehicle.z) < 1.8:
					speed = 0.55
				vehicle = vehicle.move_toward(target, delta * speed)
				if vehicle.distance_to(target) < 0.01:
					route_index += 1
		elif job_phase == "return":
			job = ""
			job_phase = "travel"
			changed = true
		else:
			job_phase = "repair"
			repair_left -= delta
			if repair_left <= 0:
				if job == "signal":
					signal_fixed = true
				else:
					leak_fixed = true
				job_phase = "return"
				route.reverse()
				route.append(Vector3(3, 0, -6))
				route_index = 0
				check_complete()
				changed = true
	if changed:
		save_game()
	return changed

func check_complete() -> void:
	completed = leak_fixed and signal_fixed and (buildings.has("cafe") or buildings.has("park"))

func save_game() -> void:
	var points: Array = []
	for point: Vector3 in route:
		points.append([point.x, point.y, point.z])
	var data := {"version": 1, "vehicle_type_id": "repair_van", "target_type_id": target_type_id(), "budget": budget, "language": language, "leak_fixed": leak_fixed,
		"signal_fixed": signal_fixed, "buildings": buildings, "job": job, "job_phase": job_phase, "route": points,
		"route_index": route_index, "vehicle": [vehicle.x, vehicle.y, vehicle.z],
		"repair_left": repair_left, "income_clock": income_clock, "transit": transit.data()}
	var file := FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data))
	file.close()
	DirAccess.rename_absolute(save_path + ".tmp", save_path)

func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return false
	var data = JSON.parse_string(file.get_as_text())
	if not data is Dictionary or data.get("version") != 1:
		return false
	var stored = data.get("buildings", [])
	if not stored is Array or stored.size() != 24:
		return false
	for kind in stored:
		if kind not in ["house", "empty", "depot", "cafe", "park"]:
			return false
	var stored_job = data.get("job", "")
	if stored_job not in ["", "signal", "leak"]:
		return false
	var stored_phase = data.get("job_phase", "travel")
	if stored_phase not in ["travel", "repair", "return"]:
		return false
	var expected_target := "traffic_signal" if stored_job == "signal" else ("water_leak" if stored_job == "leak" else "")
	if data.get("vehicle_type_id", "repair_van") != "repair_van" or data.get("target_type_id", expected_target) != expected_target:
		return false
	var stored_route = data.get("route", [])
	if not stored_route is Array or stored_route.size() > 8:
		return false
	if stored_job != "" and stored_route.is_empty():
		return false
	var loaded_route: Array = []
	for point in stored_route:
		if not valid_point(point):
			return false
		loaded_route.append(Vector3(point[0], point[1], point[2]))
	var stored_vehicle = data.get("vehicle", [])
	if not valid_point(stored_vehicle):
		return false
	for key in ["budget", "route_index", "repair_left", "income_clock"]:
		if not (data.get(key) is float or data.get(key) is int) or not is_finite(float(data[key])):
			return false
	if typeof(data.get("leak_fixed")) != TYPE_BOOL or typeof(data.get("signal_fixed")) != TYPE_BOOL:
		return false
	var loaded_transit := Transit.new()
	if not loaded_transit.restore(data.get("transit", {})):
		return false
	transit = loaded_transit
	budget = clampi(int(data.budget), 0, 1000000)
	language = "en" if data.get("language") == "en" else "ru"
	leak_fixed = data.leak_fixed
	signal_fixed = data.signal_fixed
	buildings = stored
	job = stored_job
	job_phase = stored_phase
	route = loaded_route
	route_index = clampi(int(data.route_index), 0, route.size())
	vehicle = Vector3(stored_vehicle[0], stored_vehicle[1], stored_vehicle[2])
	repair_left = clampf(float(data.repair_left), 0.0, 4.0)
	income_clock = clampf(float(data.income_clock), 0.0, 12.0)
	check_complete()
	return true

func valid_point(point: Variant) -> bool:
	if not point is Array or point.size() != 3:
		return false
	for component in point:
		if not (component is float or component is int) or not is_finite(float(component)) or absf(float(component)) > 100:
			return false
	return true


func target_type_id() -> String:
	return "traffic_signal" if job == "signal" else ("water_leak" if job == "leak" else "")
