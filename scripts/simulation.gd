extends RefCounted

const Transit = preload("res://scripts/transit.gd")
const TerritoryGrid = preload("res://scripts/territory_grid.gd")
var transit = Transit.new()
var territory = TerritoryGrid.new()
const WATER_AFFECTED_HOMES = [12, 16, 20]
const AMENITY_RADIUS: float = 22.0

const Catalog = preload("res://scripts/asset_catalog.gd")
const DistrictWorld = preload("res://scripts/district_world.gd")

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
var target_instance_id: String = ""
var depot_instance_id: String = "pine_district_legacy_2"
const FIRE_STATION_ID := "pine_district_fire_station"
const FIRST_FIRE_TARGET := "pine_district_legacy_0"
const FIRST_FIRE_NEIGHBOR := "pine_district_legacy_1"
var fire_triggered: bool = false
var fires: Dictionary = {}
var fire_damage: Dictionary = {}
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
	for entry: Dictionary in all_buildings():
		if entry.get("legacy_plot", -1) != index and entry.position.distance_to(building_world(index)) < AMENITY_RADIUS:
			if entry.type_id == "house":
				bonus += 2 * entry.level
			if (kind == "cafe" and entry.type_id == "park") or (kind == "park" and entry.type_id == "cafe"):
				bonus += 3 * entry.level
	return bonus

func house_residents(index: int) -> int:
	return record_residents(legacy_record(index))

func legacy_record(index: int) -> Dictionary:
	return {"instance_id": "pine_district_legacy_%d" % index, "type_id": buildings[index], "legacy_plot": index, "level": building_level(index), "position": building_world(index)}

func all_buildings() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(24):
		if buildings[index] != "empty":
			result.append(legacy_record(index))
	for entry: Dictionary in territory.buildings:
		if not entry.has("legacy_plot"):
			var record := entry.duplicate(true)
			record.position = territory.building_center(entry)
			record.level = int(entry.get("level", 1))
			result.append(record)
	return result

func record_water(entry: Dictionary) -> bool:
	return has_water(entry.legacy_plot) if entry.has("legacy_plot") else true

func record_residents(entry: Dictionary) -> int:
	if entry.type_id != "house":
		return 0
	var capacity: int = Catalog.level_data("house", entry.level).residents
	var damage := int(fire_damage.get(entry.instance_id, 0))
	if damage >= 100:
		return 0
	var occupied := capacity if record_water(entry) else capacity / 2
	return int(occupied * (1.0 - float(damage) / 140.0))

func population() -> int:
	var total := 0
	for entry: Dictionary in all_buildings():
		total += record_residents(entry)
	return total

func has_water(index: int) -> bool:
	return leak_fixed or index not in WATER_AFFECTED_HOMES

func building_world(index: int) -> Vector3:
	return preload("res://scripts/district_world.gd").world_position(plot_position(index))

func transit_metrics() -> Dictionary:
	var covered := 0
	var served := 0
	var demand := 0.0
	for entry: Dictionary in all_buildings():
		if entry.type_id != "house":
			continue
		var residents := record_residents(entry)
		if transit.stops.any(func(row): return transit.in_range(entry.position, row)):
			covered += residents
		var destination := record_destination_level(entry)
		if destination > 0:
			served += residents
			demand += residents * (0.25 + 0.05 * (destination - 1))
	return {"covered": covered, "served": served, "demand": ceili(demand), "load": mini(Transit.CAPACITY, ceili(demand)), "capacity": Transit.CAPACITY}

func house_transit(index: int) -> bool:
	return house_destination_level(index) > 0

func house_destination_level(index: int) -> int:
	return record_destination_level(legacy_record(index))

func record_destination_level(entry: Dictionary) -> int:
	if not transit.active or not transit.funded or transit.stops.size() != 2:
		return 0
	var best := 0
	var point: Vector3 = entry.position
	for j in range(2):
		if not transit.in_range(point, transit.stops[j]):
			continue
		for destination: Dictionary in all_buildings():
			if destination.type_id in ["cafe", "depot"] and transit.in_range(destination.position, transit.stops[1 - j]):
				best = maxi(best, destination.level)
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
	return record_quality(legacy_record(index))

func record_quality(entry: Dictionary) -> Dictionary:
	var water := record_water(entry)
	var point: Vector3 = entry.position
	var services := signal_fixed or point.x >= 0 or point.z < 0
	if not entry.has("legacy_plot"):
		services = not service_route(entry.instance_id).is_empty() and services
	var transport := record_destination_level(entry) > 0
	var environment := 12
	for neighbor: Dictionary in all_buildings():
		if neighbor.type_id in ["cafe", "park"] and neighbor.position.distance_to(point) < AMENITY_RADIUS:
			environment += Catalog.level_data(neighbor.type_id, neighbor.level).environment
	var damage := house_damage(entry.instance_id) if entry.type_id == "house" else 0
	var score := (30 if water else 0) + (20 if services else 10) + (20 if transport else 0) + mini(environment, 30) - int(damage * 0.35)
	if not water:
		score = mini(score, 19)
	return {"score": clampi(score, 0, 100), "water": water, "services": services, "transport": transport, "environment": mini(environment, 30)}

func district_quality() -> float:
	var total := 0
	var weighted := 0
	for entry: Dictionary in all_buildings():
		var residents := record_residents(entry)
		weighted += residents * record_quality(entry).score
		total += residents
	return float(weighted) / total if total > 0 else -1.0

static func quality_band(score: float) -> int:
	return clampi(int(score) / 20, 0, 4)

func income() -> int:
	var total := 0
	for entry: Dictionary in all_buildings():
		total += record_income(entry)
	return maxi(4, total)

func record_income(entry: Dictionary) -> int:
	if not Catalog.LEVELS.has(entry.type_id):
		return 0
	var amount: int = Catalog.level_data(entry.type_id, entry.level).income
	if entry.type_id == "house":
		if not record_water(entry):
			amount /= 2
		amount = int(amount * float(100 - house_damage(entry.instance_id)) / 100.0)
	return amount

func clear_grid_cell(col: int, row: int) -> bool:
	if budget < 5 or territory.placement_reason(col, row, "clear") != "" or not territory.clear_cell(col, row):
		return false
	budget -= 5
	save_game()
	return true

func build_grid_road(col: int, row: int) -> bool:
	if budget < 12 or territory.placement_reason(col, row, "road") != "" or not territory.place_road(col, row):
		return false
	budget -= 12
	save_game()
	return true

func build_grid_house(col: int, row: int) -> bool:
	if budget < Catalog.cost("house") or territory.placement_reason(col, row, "house") != "" or not territory.build_house(col, row):
		return false
	budget -= Catalog.cost("house")
	save_game()
	return true

func build_grid_service(col: int, row: int, type_id: String) -> bool:
	if type_id not in ["fire_station", "police_station", "hospital", "depot"]:
		return false
	var price: int = Catalog.cost(type_id)
	if budget < price or territory.placement_reason(col, row, "service") != "" or not territory.place_building(col, row, type_id):
		return false
	budget -= price
	save_game()
	return true

func upgrade_grid_house(identifier: String) -> bool:
	var entry := territory.building_by_id(identifier)
	if entry.is_empty() or entry.has("legacy_plot"):
		return false
	var level_value := int(entry.get("level", 1))
	var price: int = Catalog.level_data(entry.type_id, level_value).upgrade_cost
	if level_value >= 3 or budget < price:
		return false
	budget -= price
	entry.level = level_value + 1
	save_game()
	return true

func grid_demolition_refund(identifier: String) -> int:
	var entry := territory.building_by_id(identifier)
	if entry.is_empty():
		return 0
	var value := Catalog.cost(entry.type_id)
	for previous in range(1, int(entry.get("level", 1))):
		value += Catalog.level_data(entry.type_id, previous).upgrade_cost
	return value / 4

func demolish_grid_house(identifier: String) -> bool:
	var entry := territory.building_by_id(identifier)
	if entry.is_empty() or entry.has("legacy_plot") or (job != "" and (target_instance_id == identifier or depot_instance_id == identifier)):
		return false
	budget += grid_demolition_refund(identifier)
	for dy in range(entry.height):
		for dx in range(entry.width):
			territory.cells[entry.row + dy][entry.col + dx] = "free"
	territory.buildings.erase(entry)
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

func depot_world() -> Vector3:
	return DistrictWorld.world_position(Vector3(3, 0, -6))

func service_route(identifier: String) -> Array:
	var entry := territory.building_by_id(identifier)
	if entry.is_empty():
		return []
	var start := territory.nearest_road(depot_world())
	var path := territory.access_path(entry, start)
	if path.is_empty() or territory.road_path(path[-1], start).is_empty():
		return []
	return logical_route(path)

func logical_route(path: Array[Vector2i]) -> Array:
	# Сохраняем повороты и крайние точки; путь остаётся на дорожных клетках.
	var result: Array = []
	for index in range(path.size()):
		if index == 0 or index == path.size() - 1 or path[index] - path[index - 1] != path[index + 1] - path[index]:
			result.append(DistrictWorld.logical_position(territory.cell_world(path[index].x, path[index].y)))
	return result

func route_to_world(point: Vector3) -> Array:
	return route_between_world(depot_world(), point)

func route_between_world(from_point: Vector3, point: Vector3) -> Array:
	var start := territory.nearest_road(from_point)
	var goal := territory.nearest_road(point)
	var path := territory.road_path(start, goal)
	if path.is_empty() or territory.road_path(goal, start).is_empty():
		return []
	var result := logical_route(path)
	var end := DistrictWorld.logical_position(point)
	if result.is_empty() or not result[-1].is_equal_approx(end):
		result.append(end)
	return result

func fire_station_world() -> Vector3:
	for entry: Dictionary in territory.buildings:
		if entry.type_id == "fire_station":
			return territory.building_center(entry)
	# Legacy route endpoint for saves made before service buildings became placeable.
	return DistrictWorld.world_position(Vector3(9, 0, -7.5))

func fire_station_record() -> Dictionary:
	for entry: Dictionary in territory.buildings:
		if entry.type_id == "fire_station":
			var result := entry.duplicate(true)
			result.position = territory.building_center(entry)
			return result
	return {}

func has_service_building(type_id: String) -> bool:
	for entry: Dictionary in territory.buildings:
		if entry.type_id == type_id:
			return true
	return false

func job_depot_world() -> Vector3:
	if job == "fire":
		var source := territory.building_by_id(depot_instance_id)
		return territory.building_center(source) if not source.is_empty() else DistrictWorld.world_position(Vector3(9, 0, -7.5))
	return depot_world()

func building_world_for_id(identifier: String) -> Vector3:
	for entry: Dictionary in all_buildings():
		if entry.instance_id == identifier:
			return entry.position
	return Vector3.ZERO

func is_house_id(identifier: String) -> bool:
	for entry: Dictionary in all_buildings():
		if entry.instance_id == identifier:
			return entry.type_id == "house"
	return false

func house_damage(identifier: String) -> int:
	return int(fire_damage.get(identifier, 0))

func start_fire(identifier: String = FIRST_FIRE_TARGET) -> bool:
	if fire_triggered or not fires.is_empty() or not is_house_id(identifier):
		return false
	fire_triggered = true
	fires[identifier] = {"phase": "warning", "warning_left": 18.0, "elapsed": 0.0, "danger": 1}
	save_game()
	return true

func fire_target() -> String:
	for identifier in fires:
		return str(identifier)
	return ""

func fire_severity(identifier: String) -> int:
	var fire: Dictionary = fires.get(identifier, {})
	if fire.is_empty():
		return 0
	return clampi(1 + int(float(fire.get("elapsed", 0.0)) / 18.0), 1, 3)

func fire_warning_left(identifier: String) -> float:
	return float(fires.get(identifier, {}).get("warning_left", 0.0))

func repair_fire_damage(identifier: String) -> bool:
	var damage := house_damage(identifier)
	var price := 40 + damage
	if damage <= 0 or not fires.is_empty() or job != "" or budget < price:
		return false
	budget -= price
	fire_damage.erase(identifier)
	save_game()
	return true

func dispatch_fire() -> bool:
	var identifier := fire_target()
	var station := fire_station_record()
	if job != "" or station.is_empty() or identifier == "" or fires[identifier].phase not in ["warning", "burning"]:
		return false
	var planned := route_between_world(station.position, building_world_for_id(identifier))
	if planned.is_empty():
		return false
	job = "fire"
	target_instance_id = identifier
	depot_instance_id = station.instance_id
	job_phase = "travel"
	route = planned
	vehicle = route[0]
	route_index = 0
	repair_left = 4.0
	save_game()
	return true

func dispatch_to_building(identifier: String) -> bool:
	var entry := territory.building_by_id(identifier)
	if job != "" or entry.is_empty() or entry.type_id != "house" or entry.has("legacy_plot"):
		return false
	var planned := service_route(identifier)
	if planned.is_empty():
		return false
	job = "inspection"
	job_phase = "travel"
	target_instance_id = identifier
	vehicle = Vector3(3, 0, -6)
	route = planned
	route_index = 0
	repair_left = 4.0
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
	var destination := Vector3(-14.4, 0, 0) if kind == "signal" else DistrictWorld.world_position(Vector3(-9, 0, 6))
	var planned := route_to_world(destination)
	if planned.is_empty():
		return false
	budget -= cost
	job = kind
	target_instance_id = "signal_0" if kind == "signal" else "leak_0"
	job_phase = "travel"
	vehicle = Vector3(3, 0, -6)
	route = planned
	route_index = 0
	repair_left = 4.0
	save_game()
	return true

func tick(delta: float, movement_allowed: bool = true, movement_fraction: float = 1.0) -> bool:
	var changed := false
	for raw_id in fires.keys():
		var identifier := str(raw_id)
		var fire: Dictionary = fires[identifier]
		var old_phase: String = fire.phase
		var old_warning := ceili(float(fire.warning_left))
		var old_damage := house_damage(identifier)
		var old_severity := fire_severity(identifier)
		if fire.phase == "warning":
			fire.warning_left = maxf(0.0, float(fire.warning_left) - delta)
			if fire.warning_left <= 0.0:
				fire.phase = "burning"
		else:
			fire.elapsed = float(fire.elapsed) + delta
			fire_damage[identifier] = minf(100.0, float(fire_damage.get(identifier, 0.0)) + delta * 0.6)
			fire.danger = clampi(1 + int(float(fire.elapsed) / 18.0), 1, 3)
			if float(fire.elapsed) >= 12.0 and not fires.has(FIRST_FIRE_NEIGHBOR) and is_house_id(FIRST_FIRE_NEIGHBOR):
				fires[FIRST_FIRE_NEIGHBOR] = {"phase": "warning", "warning_left": 16.0, "elapsed": 0.0, "danger": 1}
		fires[identifier] = fire
		if old_phase != fire.phase or old_warning != ceili(float(fire.warning_left)) or old_damage != house_damage(identifier) or old_severity != fire_severity(identifier):
			changed = true
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
			target_instance_id = ""
			depot_instance_id = "pine_district_legacy_2"
			job_phase = "travel"
			changed = true
		else:
			job_phase = "repair"
			repair_left -= delta
			if repair_left <= 0:
				if job == "signal":
					signal_fixed = true
				elif job == "leak":
					leak_fixed = true
				elif job == "inspection":
					var entry := territory.building_by_id(target_instance_id)
					if not entry.is_empty():
						entry.inspected = true
				elif job == "fire":
					fires.clear()
				job_phase = "return"
				route.reverse()
				route.append(DistrictWorld.logical_position(job_depot_world()))
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
	var active_fires: Array = []
	for identifier in fires:
		var fire: Dictionary = fires[identifier]
		active_fires.append({"id": str(identifier), "phase": fire.phase, "warning_left": fire.warning_left, "elapsed": fire.elapsed, "danger": fire.danger})
	var data := {"version": 4, "levels": levels, "completed": completed, "city_id": "fix_my_town", "districts": {"pine_district": territory.data()}, "vehicle_type_id": "fire_engine" if job == "fire" else "repair_van", "target_type_id": target_type_id(), "budget": budget, "language": language, "leak_fixed": leak_fixed,
		"signal_fixed": signal_fixed, "buildings": buildings, "job": job, "job_phase": job_phase, "route": points, "target_instance_id": target_instance_id, "depot_instance_id": depot_instance_id,
		"route_index": route_index, "vehicle": [vehicle.x, vehicle.y, vehicle.z],
		"repair_left": repair_left, "income_clock": income_clock, "transit": transit.data(), "fire_triggered": fire_triggered, "fires": active_fires, "fire_damage": fire_damage}
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
	if not data is Dictionary or not (data.get("version") is int or data.get("version") is float) or int(data.get("version")) not in [1, 2, 3, 4]:
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
	if stored_job not in ["", "signal", "leak", "inspection", "fire"]:
		return false
	var stored_phase = data.get("job_phase", "travel")
	if stored_phase not in ["travel", "repair", "return"]:
		return false
	var expected_target := "traffic_signal" if stored_job == "signal" else ("water_leak" if stored_job == "leak" else ("house" if stored_job in ["inspection", "fire"] else ""))
	var expected_vehicle := "fire_engine" if stored_job == "fire" else "repair_van"
	if data.get("vehicle_type_id", "repair_van") != expected_vehicle or data.get("target_type_id", expected_target) != expected_target:
		return false
	var stored_route = data.get("route", [])
	if not stored_route is Array or stored_route.size() > TerritoryGrid.WIDTH * TerritoryGrid.HEIGHT + 2:
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
	var stored_target: String = str(data.get("target_instance_id", ""))
	if stored_job == "inspection" and loaded_territory.building_by_id(stored_target).is_empty():
		return false
	if stored_job == "fire" and not is_house_id_in(stored_target, stored, loaded_territory):
		return false
	var stored_depot_id: String = str(data.get("depot_instance_id", "pine_district_legacy_2"))
	if stored_job == "fire":
		var stored_station := loaded_territory.building_by_id(stored_depot_id)
		# Accept the old fixed station identifier only for legacy in-flight jobs.
		if not ((not stored_station.is_empty() and stored_station.type_id == "fire_station") or (stored_depot_id == FIRE_STATION_ID and stored_station.is_empty())):
			return false
	elif stored_depot_id != "pine_district_legacy_2":
		return false
	var loaded_fires: Dictionary = {}
	var raw_fires: Variant = data.get("fires", [])
	if not raw_fires is Array or raw_fires.size() > 2:
		return false
	for row in raw_fires:
		if not row is Dictionary or typeof(row.get("id")) != TYPE_STRING or not is_house_id_in(row.id, stored, loaded_territory):
			return false
		if row.get("phase") not in ["warning", "burning"]:
			return false
		for key in ["warning_left", "elapsed", "danger"]:
			if not (row.get(key) is int or row.get(key) is float) or not is_finite(float(row[key])) or float(row[key]) < 0:
				return false
		loaded_fires[row.id] = {"phase": row.phase, "warning_left": clampf(float(row.warning_left), 0, 18), "elapsed": clampf(float(row.elapsed), 0, 100000), "danger": clampi(int(row.danger), 1, 3)}
	var loaded_damage: Dictionary = {}
	var raw_damage: Variant = data.get("fire_damage", {})
	if not raw_damage is Dictionary or raw_damage.size() > 24 + TerritoryGrid.WIDTH * TerritoryGrid.HEIGHT:
		return false
	for identifier in raw_damage:
		var value: Variant = raw_damage[identifier]
		if not is_house_id_in(str(identifier), stored, loaded_territory) or not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0 or float(value) > 100:
			return false
		loaded_damage[str(identifier)] = float(value)
	if stored_job == "fire" and stored_phase != "return" and (not loaded_fires.has(stored_target) or loaded_fires.is_empty()):
		return false
	var triggered: Variant = data.get("fire_triggered", not loaded_fires.is_empty())
	if typeof(triggered) != TYPE_BOOL or (not triggered and not loaded_fires.is_empty()):
		return false
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
	target_instance_id = stored_target
	depot_instance_id = str(data.get("depot_instance_id", "pine_district_legacy_2"))
	job_phase = stored_phase
	fire_triggered = triggered
	fires = loaded_fires
	fire_damage = loaded_damage
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

func is_house_id_in(identifier: String, legacy: Array, grid: RefCounted) -> bool:
	if identifier.begins_with("pine_district_legacy_"):
		var index_text := identifier.trim_prefix("pine_district_legacy_")
		if not index_text.is_valid_int():
			return false
		var index := int(index_text)
		return index >= 0 and index < legacy.size() and legacy[index] == "house"
	return not grid.building_by_id(identifier).is_empty() and grid.building_by_id(identifier).type_id == "house"


func target_type_id() -> String:
	return "traffic_signal" if job == "signal" else ("water_leak" if job == "leak" else ("house" if job in ["inspection", "fire"] else ""))

func building_level(index: int) -> int:
	return int(levels[index])

func building_income(index: int) -> int:
	return record_income(legacy_record(index))

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
