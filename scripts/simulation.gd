extends RefCounted

const Transit = preload("res://scripts/transit.gd")
const TerritoryGrid = preload("res://scripts/territory_grid.gd")
var transit = Transit.new()
var territory = TerritoryGrid.new()
const WATER_AFFECTED_HOMES = [12, 16, 20]
const AMENITY_RADIUS: float = 22.0

const Catalog = preload("res://scripts/asset_catalog.gd")

const SAVE_PATH = "user://progress.json"
var budget: int = 300
var language: String = "ru"
var leak_fixed: bool = false
var signal_fixed: bool = false
var buildings: Array = []
var levels: Array = []
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
		levels.append(1)
		buildings.append("empty" if i in [3, 7, 9, 14] else "house")
	buildings[2] = "depot"
	territory = TerritoryGrid.new(buildings)

func plot_position(index: int) -> Vector3:
	return Vector3(-9 + (index % 4) * 6, 0, -7.5 + (index / 4) * 3)

func happiness() -> int:
	var value := 38 + (18 if leak_fixed else 0) + (14 if signal_fixed else 0)
	for i in range(24):
		if buildings[i] in ["cafe", "park"]:
			value += Catalog.level_data(buildings[i], building_level(i)).mood + placement_bonus(i, buildings[i])
	return clampi(value + (3 if transit_metrics().served > 0 else -5), 0, 100)

func placement_bonus(index: int, kind: String) -> int:
	var bonus := 0
	for i in range(24):
		if i != index and building_world(i).distance_to(building_world(index)) < AMENITY_RADIUS:
			if buildings[i] == "house":
				bonus += 2 * building_level(i)
			if (kind == "cafe" and buildings[i] == "park") or (kind == "park" and buildings[i] == "cafe"):
				bonus += 3 * building_level(i)
	return bonus

func house_residents(index: int) -> int:
	if buildings[index] != "house":
		return 0
	var capacity: int = Catalog.level_data("house", building_level(index)).residents
	return capacity if has_water(index) else capacity / 2

func population() -> int:
	var total := 0
	for index in range(24):
		total += house_residents(index)
	for building in territory.buildings:
		if building.type_id == "house" and not building.has("legacy_plot"):
			total += 8
	return total

func has_water(index: int) -> bool:
	return leak_fixed or index not in WATER_AFFECTED_HOMES

func building_world(index: int) -> Vector3:
	return preload("res://scripts/district_world.gd").world_position(plot_position(index))

func transit_metrics() -> Dictionary:
	var covered := 0
	var served := 0
	var demand := 0.0
	for i in range(24):
		if buildings[i] != "house":
			continue
		if transit.stops.any(func(row): return transit.in_range(building_world(i), row)):
			covered += house_residents(i)
		if house_transit(i):
			served += house_residents(i)
			demand += house_residents(i) * (0.25 + 0.05 * (house_destination_level(i) - 1))
	return {"covered": covered, "served": served, "demand": ceili(demand), "load": mini(Transit.CAPACITY, ceili(demand)), "capacity": Transit.CAPACITY}

func house_transit(index: int) -> bool:
	return house_destination_level(index) > 0

func house_destination_level(index: int) -> int:
	if not transit.active or not transit.funded or transit.stops.size() != 2:
		return 0
	var best := 0
	var point := building_world(index)
	for j in range(2):
		if not transit.in_range(point, transit.stops[j]):
			continue
		for i in range(24):
			if buildings[i] in ["cafe", "depot"] and transit.in_range(building_world(i), transit.stops[1 - j]):
				best = maxi(best, building_level(i))
	return best

func place_stop(row: int) -> bool:
	if not completed or row < 0 or row > 5 or transit.stops.size() >= 2 or row in transit.stops or budget < Transit.STOP_COST:
		return false
	budget -= Transit.STOP_COST
	transit.stops.append(row)
	transit.stops.sort()
	save_game()
	return true

func move_stop(index: int, row: int) -> bool:
	if not completed or index < 0 or index >= transit.stops.size() or row < 0 or row > 5:
		return false
	if row in transit.stops and transit.stops[index] != row or transit.stops[index] == row:
		return false
	transit.stops[index] = row
	transit.stops.sort()
	if transit.active and transit.dwell > 0:
		transit.target_z = Transit.ROW_Z[transit.stops[1] if transit.direction == 1 else transit.stops[0]]
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
	transit.visual_direction = 1
	transit.target_z = Transit.ROW_Z[transit.stops[1]]
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
			environment += Catalog.level_data(buildings[i], building_level(i)).environment
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
	var total := 0
	for i in range(24):
		total += building_income(i)
	for building in territory.buildings:
		if building.type_id == "house" and not building.has("legacy_plot"):
			total += 1
	return maxi(4, total)

func clear_grid_cell(col: int, row: int) -> bool:
	if budget < 5 or not territory.clear_cell(col, row):
		return false
	budget -= 5
	save_game()
	return true

func build_grid_road(col: int, row: int) -> bool:
	if budget < 12 or not territory.place_road(col, row):
		return false
	budget -= 12
	save_game()
	return true

func build_grid_house(col: int, row: int) -> bool:
	if budget < Catalog.cost("house") or not territory.build_house(col, row):
		return false
	budget -= Catalog.cost("house")
	save_game()
	return true

func build(index: int, kind: String) -> bool:
	if index < 0 or index >= 24 or buildings[index] != "empty" or kind not in ["house", "cafe", "park"]:
		return false
	var cost := Catalog.cost(kind)
	if budget < cost:
		return false
	budget -= cost
	buildings[index] = kind
	levels[index] = 1
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

func tick(delta: float, movement_allowed: bool = true, movement_fraction: float = 1.0) -> bool:
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
				vehicle = vehicle.move_toward(target, delta * speed * clampf(movement_fraction, 0, 1))
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
	completed = completed or (leak_fixed and signal_fixed and (buildings.has("cafe") or buildings.has("park")))

func save_game() -> void:
	territory.sync_legacy(buildings)
	var points: Array = []
	for point: Vector3 in route:
		points.append([point.x, point.y, point.z])
	var data := {"version": 3, "levels": levels, "completed": completed, "city_id": "fix_my_town", "districts": {"pine_district": territory.data()}, "vehicle_type_id": "repair_van", "target_type_id": target_type_id(), "budget": budget, "language": language, "leak_fixed": leak_fixed,
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
	if not data is Dictionary or not (data.get("version") is int or data.get("version") is float) or int(data.get("version")) not in [1, 2, 3]:
		return false
	var stored = data.get("buildings", [])
	if not stored is Array or stored.size() != 24:
		return false
	for kind in stored:
		if kind not in ["house", "empty", "depot", "cafe", "park"]:
			return false
	var stored_levels: Variant = data.get("levels", [])
	if data.version == 1 and not data.has("levels"):
		stored_levels = []
		stored_levels.resize(24)
		stored_levels.fill(1)
	if not stored_levels is Array or stored_levels.size() != 24:
		return false
	var loaded_levels: Array = []
	for i in range(24):
		var value: Variant = stored_levels[i]
		if not (value is float or value is int) or not is_finite(float(value)) or value != int(value) or value < 1 or value > 3:
			return false
		if not Catalog.LEVELS.has(stored[i]) and value != 1:
			return false
		loaded_levels.append(int(value))
	if data.has("completed") and typeof(data.completed) != TYPE_BOOL:
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
	var loaded_territory := TerritoryGrid.new()
	var district_data: Variant = data.get("districts", {}).get("pine_district") if data.get("districts", {}) is Dictionary else null
	if district_data != null:
		if not loaded_territory.restore(district_data):
			return false
	else:
		loaded_territory = TerritoryGrid.new(stored)
	loaded_territory.sync_legacy(stored)
	transit = loaded_transit
	territory = loaded_territory
	budget = clampi(int(data.budget), 0, 1000000)
	language = "en" if data.get("language") == "en" else "ru"
	leak_fixed = data.leak_fixed
	signal_fixed = data.signal_fixed
	buildings = stored
	levels = loaded_levels
	completed = data.get("completed", false)
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

func building_level(index: int) -> int:
	return int(levels[index])

func building_income(index: int) -> int:
	var kind: String = buildings[index]
	if not Catalog.LEVELS.has(kind):
		return 0
	var amount: int = Catalog.level_data(kind, building_level(index)).income
	return amount / 2 if kind == "house" and not has_water(index) else amount

func upgrade_cost(index: int) -> int:
	if index < 0 or index >= 24 or not Catalog.LEVELS.has(buildings[index]) or building_level(index) >= 3:
		return 0
	return Catalog.level_data(buildings[index], building_level(index)).upgrade_cost

func upgrade(index: int) -> bool:
	var price := upgrade_cost(index)
	if price <= 0 or budget < price:
		return false
	budget -= price
	levels[index] += 1
	save_game()
	return true

func demolition_refund(index: int) -> int:
	if index < 0 or index >= 24 or not Catalog.LEVELS.has(buildings[index]):
		return 0
	var value := Catalog.cost(buildings[index])
	for previous in range(1, building_level(index)):
		value += Catalog.level_data(buildings[index], previous).upgrade_cost
	return value / 4

func demolish(index: int) -> bool:
	if index < 0 or index >= 24 or not Catalog.LEVELS.has(buildings[index]):
		return false
	budget += demolition_refund(index)
	buildings[index] = "empty"
	levels[index] = 1
	save_game()
	return true

func metrics() -> Dictionary:
	var transport := transit_metrics()
	return {"population": population(), "income": income(), "rating": happiness(), "quality": district_quality(), "covered": transport.covered, "served": transport.served, "demand": transport.demand}

func project_change(index: int, demolition: bool = false) -> Dictionary:
	# Только расчёт: ни записи файла, ни расходования средств.
	var projected = get_script().new()
	projected.buildings = buildings.duplicate()
	projected.levels = levels.duplicate()
	projected.territory.restore(territory.data())
	projected.leak_fixed = leak_fixed
	projected.signal_fixed = signal_fixed
	projected.transit.restore(transit.data())
	if demolition:
		projected.buildings[index] = "empty"
		projected.levels[index] = 1
	else:
		projected.levels[index] = mini(3, building_level(index) + 1)
	return projected.metrics()

func proposed_vehicle(delta: float) -> Vector3:
	if job == "" or route_index >= route.size():
		return vehicle
	var speed := 0.55 if not signal_fixed and absf(vehicle.z) < 1.8 else 2.6
	return vehicle.move_toward(route[route_index], delta * speed)
