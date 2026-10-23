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
var service_neglect_clock: float = 0.0
var completed: bool = false
var target_instance_id: String = ""
var depot_instance_id: String = "pine_district_legacy_2"
var job_vehicle_id: String = ""
const FIRE_STATION_ID := "pine_district_fire_station"
const FIRST_FIRE_TARGET := "pine_district_legacy_0"
const FIRST_FIRE_NEIGHBOR := "pine_district_legacy_4"
var fire_triggered: bool = false
var fires: Dictionary = {}
var fire_damage: Dictionary = {}
var fire_ruins: Dictionary = {}
var fire_jobs: Dictionary = {}
var jam_cleared: Dictionary = {}
var police_job: Dictionary = {}
var construction_job: Dictionary = {}
var incident_seed: int = 48291
var incident_clock: float = 0.0
var incident_rng := RandomNumberGenerator.new()
var incidents: Dictionary = {}
var district_house_limit: int = 8
var district_tasks: Array = [
	{"id": "clear_3", "title": "Расчистить 3 участка", "done": false},
	{"id": "build_4", "title": "Построить 4 дома", "done": false},
	{"id": "fire_station", "title": "Построить пожарное депо", "done": false},
	{"id": "quality_60", "title": "Довести качество до 60", "done": false}
]
var save_path: String = SAVE_PATH

func _init() -> void:
	incident_rng.seed = incident_seed
	for i in range(24):
		levels.append(1)
		buildings.append("empty" if i in [3, 7, 9, 14] else "house")
	buildings[2] = "depot"
	territory = TerritoryGrid.new(buildings)
	# New city starts as untouched land: no inherited legacy roads.
	for row in range(TerritoryGrid.HEIGHT):
		for col in range(TerritoryGrid.WIDTH):
			territory.cells[row][col] = "forest"

func start_empty_city() -> void:
	# A clean sandbox for testing the first placement decisions. Keep the
	# terrain grid and roads, but remove every legacy building and incident.
	budget = 300
	leak_fixed = false
	signal_fixed = false
	completed = false
	buildings.clear()
	levels.clear()
	for i in range(24):
		buildings.append("empty")
		levels.append(1)
	territory = TerritoryGrid.new(buildings)
	job = ""
	job_phase = "travel"
	route.clear()
	route_index = 0
	fires.clear()
	fire_damage.clear()
	fire_ruins.clear()
	fire_jobs.clear()
	police_job.clear()
	jam_cleared.clear()
	construction_job.clear()
	incidents.clear()
	incident_clock = 0.0
	fire_triggered = false
	transit = Transit.new()
	district_tasks = [
		{"id": "clear_3", "title": "Расчистить 3 участка", "done": false},
		{"id": "build_4", "title": "Построить 4 дома", "done": false},
		{"id": "fire_station", "title": "Построить пожарное депо", "done": false},
		{"id": "quality_60", "title": "Довести качество до 60", "done": false}
	]

func plot_position(index: int) -> Vector3:
	return Vector3(-9 + (index % 4) * 6, 0, -7.5 + (index / 4) * 3)

func happiness() -> int:
	var value := 38 + (18 if leak_fixed else 0) + (14 if signal_fixed else 0)
	for i in range(24):
		if buildings[i] in ["cafe", "park"]:
			value += Catalog.level_data(buildings[i], building_level(i)).mood + placement_bonus(i, buildings[i])
	for entry: Dictionary in territory.buildings:
		if entry.type_id in ["cafe", "park"]:
			value += Catalog.level_data(entry.type_id, int(entry.get("level", 1))).mood + record_placement_bonus(entry)
	return clampi(value + (3 if transit_metrics().served > 0 else -5), 0, 100)

func city_level() -> int:
	var score := happiness()
	if score >= 82:
		return 3
	if score >= 60:
		return 2
	return 1

func district_house_count() -> int:
	var total := 0
	for entry: Dictionary in all_buildings():
		if entry.type_id == "house":
			total += 1
	return total

func district_task_progress() -> int:
	var done := 0
	var cleared := 0
	for row in territory.cells:
		for state in row:
			if state == "free":
				cleared += 1
	for task: Dictionary in district_tasks:
		var complete := bool(task.get("done", false))
		match str(task.id):
			"clear_3": complete = cleared >= 3
			"build_4": complete = district_house_count() >= 4
			"fire_station": complete = has_service_building("fire_station")
			"quality_60": complete = district_quality() >= 60.0
		task.done = complete
		if complete:
			done += 1
	return done

func record_placement_bonus(target: Dictionary) -> int:
	var bonus := 0
	var target_position: Vector3 = target.get("position", territory.building_center(territory.building_by_id(str(target.get("instance_id", "")))))
	for entry: Dictionary in all_buildings():
		if entry.instance_id == target.instance_id or entry.position.distance_to(target_position) >= AMENITY_RADIUS:
			continue
		if entry.type_id == "house":
			bonus += 2 * int(entry.get("level", 1))
		elif entry.type_id in ["cafe", "park"] and entry.type_id != target.type_id:
			bonus += 3 * int(entry.get("level", 1))
	return bonus

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
		if transit.stops.any(func(stop): return transit.in_range(entry.position, stop, territory)):
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
		if not transit.in_range(point, transit.stops[j], territory):
			continue
		for destination: Dictionary in all_buildings():
			if destination.type_id in ["cafe", "depot"] and transit.in_range(destination.position, transit.stops[1 - j], territory):
				best = maxi(best, destination.level)
	return best

func valid_stop_cell(cell: Vector2i, ignore_index: int = -1) -> bool:
	if territory.state_at(cell.x, cell.y) != "road" or territory.road_orientation(cell.x, cell.y) == "" or territory.path_to_city(cell.x, cell.y).is_empty():
		return false
	for index in range(transit.stops.size()):
		if index != ignore_index and transit.stop_cell(transit.stops[index], territory) == cell:
			return false
	return true

func stop_orientation(stop: Variant) -> String:
	if stop is Dictionary and str(stop.get("orientation", "")) in ["horizontal", "vertical"]:
		return str(stop.orientation)
	var cell := transit.stop_cell(stop, territory)
	return territory.road_orientation(cell.x, cell.y) if cell.x >= 0 else "vertical"

func place_stop(location: Variant) -> bool:
	if not completed or transit.stops.size() >= 2 or budget < Transit.STOP_COST:
		return false
	var stop: Variant = int(location) if location is int else {"col": location.x, "row": location.y} if location is Vector2i else {}
	if stop is Dictionary:
		if not valid_stop_cell(Vector2i(stop.col, stop.row)):
			return false
	elif not (stop is int and stop >= 0 and stop < 6) or transit.stops.has(stop):
		return false
	budget -= Transit.STOP_COST
	transit.stops.append(stop)
	save_game()
	return true

func move_stop(index: int, location: Variant) -> bool:
	if not completed or index < 0 or index >= transit.stops.size():
		return false
	var stop: Variant = int(location) if location is int else {"col": location.x, "row": location.y} if location is Vector2i else {}
	if stop is Dictionary:
		if not valid_stop_cell(Vector2i(stop.col, stop.row), index):
			return false
	elif not (stop is int and stop >= 0 and stop < 6):
		return false
	if typeof(transit.stops[index]) == typeof(stop) and transit.stops[index] == stop:
		return false
	for other_index in range(transit.stops.size()):
		if other_index == index:
			continue
		if typeof(transit.stops[other_index]) == typeof(stop) and transit.stops[other_index] == stop:
			return false
		if stop is Dictionary and transit.stop_cell(transit.stops[other_index], territory) == Vector2i(stop.col, stop.row):
			return false
	transit.stops[index] = stop
	if transit.active:
		transit.route_dirty = true
	save_game()
	return true

func start_transit() -> bool:
	if not completed or transit.active or transit.stops.size() != 2 or budget < Transit.BUS_COST:
		return false
	budget -= Transit.BUS_COST
	transit.active = true
	transit.funded = true
	transit.route_points.clear()
	transit.route_index = 0
	transit.current_target = 1
	transit.route_dirty = false
	if not transit.make_leg(territory, 0, 1):
		budget += Transit.BUS_COST
		transit.active = false
		return false
	transit.coordinate = transit.bus_position.z
	transit.direction = 1
	transit.visual_direction = 1
	transit.initial_dwell = true
	transit.target_z = transit.bus_position.z
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

func incident_penalty() -> int:
	# Unresolved failures drain the treasury every accounting period. Fires are
	# more expensive than routine service failures, so ignoring them has a clear
	# escalating cost even before a building becomes a ruin.
	var penalty := 0
	if not leak_fixed:
		penalty += 3
	if not signal_fixed:
		penalty += 2
	penalty += fires.size() * 4
	for identifier in fire_ruins:
		if bool(fire_ruins[identifier]):
			penalty += 2
	return penalty

func net_income() -> int:
	var result := income() - incident_penalty()
	return maxi(1, result) if budget <= 0 else result

func apply_service_neglect_damage(amount: int, identifiers: Array) -> void:
	for identifier in identifiers:
		if not is_house_id(str(identifier)) or is_ruined(str(identifier)):
			continue
		var key := str(identifier)
		fire_damage[key] = minf(100.0, float(fire_damage.get(key, 0.0)) + amount)
		if float(fire_damage[key]) >= 100.0:
			fire_ruins[key] = true

const CONSTRUCTION_DURATION := 6.0

func start_legacy_construction(index: int, type_id: String) -> bool:
	if not construction_job.is_empty() or index < 0 or index >= 24 or buildings[index] != "empty" or type_id not in ["house", "cafe", "park"] or budget < Catalog.cost(type_id) or city_level() < Catalog.unlock_level(type_id):
		return false
	return _start_construction({"kind": "build_legacy", "type_id": type_id, "index": index, "col": -1, "row": -1, "cost": Catalog.cost(type_id)})

func start_grid_construction(col: int, row: int, type_id: String) -> bool:
	if not construction_job.is_empty() or budget < Catalog.cost(type_id):
		return false
	var placement_kind := "landscaping" if Catalog.is_landscaping(type_id) else ("service" if Catalog.is_service(type_id) else "house")
	if territory.placement_reason(col, row, placement_kind) != "" or city_level() < Catalog.unlock_level(type_id):
		return false
	return _start_construction({"kind": "build_grid", "type_id": type_id, "col": col, "row": row, "cost": Catalog.cost(type_id)})

func start_grid_upgrade(identifier: String) -> bool:
	if not construction_job.is_empty():
		return false
	var entry := territory.building_by_id(identifier)
	if entry.is_empty() or entry.has("legacy_plot") or not Catalog.LEVELS.has(entry.type_id) or is_ruined(identifier):
		return false
	var level_value := int(entry.get("level", 1))
	var price: int = Catalog.level_data(entry.type_id, level_value).upgrade_cost
	if level_value >= 3 or price <= 0 or budget < price:
		return false
	return _start_construction({"kind": "upgrade_grid", "type_id": entry.type_id, "identifier": identifier,
		"col": entry.col, "row": entry.row, "level": level_value, "cost": price})

func start_legacy_upgrade(index: int) -> bool:
	var identifier := "pine_district_legacy_%d" % index
	if not construction_job.is_empty() or upgrade_cost(index) <= 0 or budget < upgrade_cost(index) or is_ruined(identifier):
		return false
	return _start_construction({"kind": "upgrade_legacy", "type_id": buildings[index], "index": index,
		"level": building_level(index), "col": -1, "row": -1, "cost": upgrade_cost(index)})

func start_grid_clear(col: int, row: int) -> bool:
	if not construction_job.is_empty() or budget < 5 or territory.placement_reason(col, row, "clear") != "":
		return false
	return _start_construction({"kind": "clear", "type_id": "", "col": col, "row": row, "cost": 5})

func start_grid_road(col: int, row: int) -> bool:
	if not construction_job.is_empty() or budget < 12 or territory.placement_reason(col, row, "road") != "":
		return false
	return _start_construction({"kind": "road", "type_id": "", "col": col, "row": row, "cost": 12})

func start_grid_demolition(identifier: String) -> bool:
	if not construction_job.is_empty() or not can_demolish_grid_building(identifier):
		return false
	var entry := territory.building_by_id(identifier)
	return _start_construction({"kind": "demolish_grid", "type_id": entry.type_id, "identifier": identifier, "col": entry.col, "row": entry.row, "cost": 0})

func start_legacy_demolition(index: int) -> bool:
	if not construction_job.is_empty() or index < 0 or index >= 24 or not Catalog.LEVELS.has(buildings[index]) or (job != "" and (target_instance_id == "pine_district_legacy_%d" % index or depot_instance_id == "pine_district_legacy_%d" % index)):
		return false
	return _start_construction({"kind": "demolish_legacy", "type_id": buildings[index], "index": index, "col": -1, "row": -1, "cost": 0})

func start_road_demolition(col: int, row: int) -> bool:
	if not construction_job.is_empty() or not can_demolish_road(col, row):
		return false
	return _start_construction({"kind": "demolish_road", "type_id": "", "col": col, "row": row, "cost": 0})

func _start_construction(fields: Dictionary) -> bool:
	var data := fields.duplicate(true)
	budget -= int(data.get("cost", 0))
	data.total = CONSTRUCTION_DURATION
	data.remaining = CONSTRUCTION_DURATION
	data.position = _construction_position(data)
	var site := Vector3(data.position[0], data.position[1], data.position[2])
	var road_cell: Vector2i = territory.nearest_road(site)
	var truck_target := territory.cell_world(road_cell.x, road_cell.y) if road_cell.x >= 0 else site
	var truck_start_cell := road_cell
	var access_path := territory.path_to_city(road_cell.x, road_cell.y) if road_cell.x >= 0 else []
	if access_path.size() > 1:
		truck_start_cell = access_path[access_path.size() - 2]
	elif road_cell.x >= 0:
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var candidate := road_cell + offset
			if territory.state_at(candidate.x, candidate.y) == "road" and territory.connected_road(candidate.x, candidate.y):
				truck_start_cell = candidate
				break
	var truck_start := territory.cell_world(truck_start_cell.x, truck_start_cell.y) if truck_start_cell.x >= 0 else truck_target
	var road_route: Array = []
	if road_cell.x >= 0:
		for route_cell: Vector2i in territory.path_to_city(road_cell.x, road_cell.y):
			var route_point := territory.cell_world(route_cell.x, route_cell.y)
			road_route.append([route_point.x, route_point.y, route_point.z])
	if road_route.size() < 2:
		road_route = [[truck_start.x, truck_start.y, truck_start.z], [truck_target.x, truck_target.y, truck_target.z]]
	data.truck_route = road_route
	data.truck_start_position = road_route[0].duplicate()
	data.truck_target_position = road_route[road_route.size() - 1].duplicate()
	data.truck_position = data.truck_start_position.duplicate()
	truck_start = Vector3(data.truck_start_position[0], data.truck_start_position[1], data.truck_start_position[2])
	truck_target = Vector3(data.truck_target_position[0], data.truck_target_position[1], data.truck_target_position[2])
	var digger_start := truck_start
	var digger_target := truck_target
	if truck_start_cell.x != road_cell.x or truck_start_cell.y != road_cell.y:
		var lateral := Vector3(0, 0, 0.82) if truck_start_cell.y == road_cell.y else Vector3(0.82, 0, 0)
		digger_start += lateral
		digger_target += lateral
	data.excavator_start_position = [digger_start.x, digger_start.y, digger_start.z]
	data.excavator_target_position = [digger_target.x, digger_target.y, digger_target.z]
	data.excavator_position = data.excavator_start_position.duplicate()
	data.excavator_route = road_route.duplicate(true)
	data.arrival_duration = 0.8
	construction_job = data
	save_game()
	return true

func _construction_position(data: Dictionary) -> Array:
	if str(data.get("kind", "")) in ["demolish_legacy", "build_legacy"]:
		var index := int(data.get("index", -1))
		var point := building_world(index) if index in range(24) else Vector3.ZERO
		return [point.x, point.y, point.z]
	var point := territory.cell_world(int(data.get("col", 0)), int(data.get("row", 0)))
	if str(data.get("kind", "")) in ["build_grid", "upgrade_grid", "restore_grid", "demolish_grid"]:
		var size := Catalog.footprint_cells(str(data.get("type_id", "house")))
		point += Vector3((size.x - 1) * TerritoryGrid.CELL_SIZE * 0.5, 0.0, (size.y - 1) * TerritoryGrid.CELL_SIZE * 0.5)
	return [point.x, point.y, point.z]

func normalize_construction_vehicle_paths(task: Dictionary, grid: RefCounted) -> void:
	if task.is_empty():
		return
	var stored_site: Array = task.get("position", [])
	if stored_site.size() != 3:
		return
	var site := Vector3(float(stored_site[0]), float(stored_site[1]), float(stored_site[2]))
	var road_cell: Vector2i = grid.nearest_road(site)
	if road_cell.x < 0:
		return
	var road_target: Vector3 = grid.cell_world(road_cell.x, road_cell.y)
	var start_cell := road_cell
	var path: Array = grid.path_to_city(road_cell.x, road_cell.y)
	if path.size() > 1:
		start_cell = path[path.size() - 2]
	else:
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var candidate := road_cell + offset
			if grid.state_at(candidate.x, candidate.y) == "road" and grid.connected_road(candidate.x, candidate.y):
				start_cell = candidate
				break
	var road_start: Vector3 = grid.cell_world(start_cell.x, start_cell.y)
	var truck_start := road_start
	var truck_target := road_target
	var excavator_start := road_start
	var excavator_target := road_target
	if start_cell.x != road_cell.x or start_cell.y != road_cell.y:
		var lateral := Vector3(0, 0, 0.82) if start_cell.y == road_cell.y else Vector3(0.82, 0, 0)
		excavator_start += lateral
		excavator_target += lateral
	var rebuilt := {
		"truck_start_position": [truck_start.x, truck_start.y, truck_start.z],
		"truck_target_position": [truck_target.x, truck_target.y, truck_target.z],
		"excavator_start_position": [excavator_start.x, excavator_start.y, excavator_start.z],
		"excavator_target_position": [excavator_target.x, excavator_target.y, excavator_target.z]
	}
	var road_route: Array = []
	for route_cell: Vector2i in path:
		var route_point: Vector3 = grid.cell_world(route_cell.x, route_cell.y)
		road_route.append([route_point.x, route_point.y, route_point.z])
	if road_route.size() < 2:
		road_route = [[truck_start.x, truck_start.y, truck_start.z], [truck_target.x, truck_target.y, truck_target.z]]
	rebuilt.truck_route = road_route
	rebuilt.excavator_route = road_route.duplicate(true)
	var arrival_ratio := clampf((float(task.get("total", 0.0)) - float(task.get("remaining", 0.0))) / maxf(0.1, float(task.get("arrival_duration", 0.8))), 0.0, 1.0)
	for machine in [
		["truck_position", "truck_start_position", "truck_target_position", "truck_route"],
		["excavator_position", "excavator_start_position", "excavator_target_position", "excavator_route"]
	]:
		var from: Array = rebuilt[machine[1]]
		var to: Array = rebuilt[machine[2]]
		var current: Vector3
		var route: Array = rebuilt[machine[3]]
		if route.size() >= 2:
			var route_index_float := arrival_ratio * float(route.size() - 1)
			var route_index := mini(int(floor(route_index_float)), route.size() - 2)
			var route_fraction := route_index_float - float(route_index)
			current = Vector3(route[route_index][0], route[route_index][1], route[route_index][2]).lerp(Vector3(route[route_index + 1][0], route[route_index + 1][1], route[route_index + 1][2]), route_fraction)
		else:
			current = Vector3(float(from[0]), float(from[1]), float(from[2])).lerp(Vector3(float(to[0]), float(to[1]), float(to[2])), arrival_ratio)
		task[machine[0]] = [current.x, current.y, current.z]
		task[machine[1]] = from
		task[machine[2]] = to
		task[machine[3]] = route

func construction_progress() -> float:
	if construction_job.is_empty():
		return 0.0
	return 1.0 - float(construction_job.remaining) / maxf(0.01, float(construction_job.total))

func _finish_construction() -> bool:
	var task := construction_job.duplicate(true)
	construction_job = {}
	var kind := str(task.kind)
	var result := false
	match kind:
		"build_legacy": result = build(int(task.index), str(task.type_id), true)
		"build_grid": result = build_grid_building(int(task.col), int(task.row), str(task.type_id), true)
		"upgrade_legacy": result = upgrade(int(task.index), true)
		"upgrade_grid": result = upgrade_grid_house(str(task.identifier), true)
		"restore_legacy": result = restore_legacy_ruin(int(task.index), true)
		"restore_grid": result = restore_grid_ruin(str(task.identifier), true)
		"clear": result = clear_grid_cell(int(task.col), int(task.row), true)
		"road": result = build_grid_road(int(task.col), int(task.row), true)
		"demolish_grid": result = demolish_grid_building(str(task.identifier))
		"demolish_legacy": result = demolish(int(task.index))
		"demolish_road": result = demolish_road(int(task.col), int(task.row))
	if not result:
		construction_job = task
		construction_job.failed = true
		save_game()
		return false
	save_game()
	return true

func record_income(entry: Dictionary) -> int:
	if not Catalog.LEVELS.has(entry.type_id):
		return 0
	var amount: int = Catalog.level_data(entry.type_id, entry.level).income
	if entry.type_id == "house":
		if not record_water(entry):
			amount /= 2
		amount = int(amount * float(100 - house_damage(entry.instance_id)) / 100.0)
	return amount

func clear_grid_cell(col: int, row: int, reserved: bool = false) -> bool:
	if (not reserved and budget < 5) or territory.placement_reason(col, row, "clear") != "" or not territory.clear_cell(col, row):
		return false
	if not reserved:
		budget -= 5
	save_game()
	return true

func build_grid_road(col: int, row: int, reserved: bool = false) -> bool:
	if (not reserved and budget < 12) or territory.placement_reason(col, row, "road") != "" or not territory.place_road(col, row):
		return false
	if not reserved:
		budget -= 12
	save_game()
	return true

func build_grid_house(col: int, row: int) -> bool:
	return build_grid_building(col, row, "house")

func build_grid_building(col: int, row: int, type_id: String, reserved: bool = false) -> bool:
	if not Catalog.TYPES.has(type_id) or type_id in ["empty", "ruins", "repair_van", "fire_engine", "police_car", "civilian_car", "bus_stop", "city_bus", "traffic_signal", "water_leak"]:
		return false
	if city_level() < Catalog.unlock_level(type_id):
		return false
	var placement_kind := "landscaping" if Catalog.is_landscaping(type_id) else ("service" if Catalog.is_service(type_id) else "house")
	var price: int = Catalog.cost(type_id)
	if (not reserved and budget < price) or territory.placement_reason(col, row, placement_kind) != "" or not territory.place_building(col, row, type_id):
		return false
	if not reserved:
		budget -= price
	save_game()
	return true

func build_grid_service(col: int, row: int, type_id: String) -> bool:
	return type_id in Catalog.SERVICE_TYPES and build_grid_building(col, row, type_id)

func can_demolish_grid_building(identifier: String) -> bool:
	var entry := territory.building_by_id(identifier)
	if entry.is_empty() or entry.has("legacy_plot") or Catalog.is_service(entry.type_id):
		return false
	if job != "" and (target_instance_id == identifier or depot_instance_id == identifier):
		return false
	if fire_assignment(identifier).size() > 0:
		return false
	return true

func demolish_grid_building(identifier: String) -> bool:
	if not can_demolish_grid_building(identifier):
		return false
	var entry := territory.building_by_id(identifier)
	budget += Catalog.cost(entry.type_id) / 4
	for dy in range(entry.height):
		for dx in range(entry.width):
			territory.cells[entry.row + dy][entry.col + dx] = "free"
	territory.buildings.erase(entry)
	save_game()
	return true

func can_demolish_road(col: int, row: int) -> bool:
	if not territory.can_remove_road(col, row, transit):
		return false
	var point := territory.cell_world(col, row)
	for path in [route, police_job.get("route", [])]:
		for waypoint in path:
			var world_point: Vector3 = DistrictWorld.world_position(waypoint) if waypoint is Vector3 or waypoint is Vector2 else Vector3.ZERO
			if world_point.distance_to(point) < TerritoryGrid.CELL_SIZE * 0.4:
				return false
	for waypoint: Vector3 in transit.route_points:
		if waypoint.distance_to(point) < TerritoryGrid.CELL_SIZE * 0.4:
			return false
	for assignment: Dictionary in fire_jobs.values():
		for waypoint in assignment.get("route", []):
			var world_point: Vector3 = DistrictWorld.world_position(waypoint) if waypoint is Vector3 else Vector3.ZERO
			if world_point.distance_to(point) < TerritoryGrid.CELL_SIZE * 0.4:
				return false
	return true

func demolish_road(col: int, row: int) -> bool:
	if not can_demolish_road(col, row):
		return false
	territory.cells[row][col] = "free"
	save_game()
	return true

func upgrade_grid_house(identifier: String, reserved: bool = false) -> bool:
	var entry := territory.building_by_id(identifier)
	if entry.is_empty() or entry.has("legacy_plot") or is_ruined(identifier) or not Catalog.LEVELS.has(entry.type_id):
		return false
	var level_value := int(entry.get("level", 1))
	var price: int = Catalog.level_data(entry.type_id, level_value).upgrade_cost
	if level_value >= 3 or price <= 0 or (not reserved and budget < price):
		return false
	if not reserved:
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

func build(index: int, kind: String, reserved: bool = false) -> bool:
	if index < 0 or index >= 24 or buildings[index] != "empty" or kind not in ["house", "cafe", "park"]:
		return false
	var cost := Catalog.cost(kind)
	if not reserved and budget < cost:
		return false
	if not reserved:
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
	# На старте района дежурный патруль выезжает из дома рабочих. Игрок
	# по-прежнему может построить отдельный участок позже.
	if type_id == "police_station":
		for entry: Dictionary in territory.buildings:
			if entry.type_id == "depot":
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

func is_ruined(identifier: String) -> bool:
	return bool(fire_ruins.get(identifier, false))

func fire_assignments() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if job == "fire":
		result.append({"instance_id": target_instance_id, "vehicle_id": job_vehicle_id if job_vehicle_id != "" else depot_instance_id + "_engine_1", "depot_instance_id": depot_instance_id,
			"phase": job_phase, "route": route, "route_index": route_index, "vehicle": vehicle, "repair_left": repair_left,
			"primary": true, "jam_cleared": bool(jam_cleared.get(target_instance_id, false))})
	for identifier in fire_jobs:
		var assignment: Dictionary = fire_jobs[identifier].duplicate(false)
		assignment.instance_id = str(identifier)
		assignment.primary = false
		assignment.jam_cleared = bool(jam_cleared.get(str(identifier), false))
		result.append(assignment)
	return result

func fire_assignment(identifier: String) -> Dictionary:
	for assignment in fire_assignments():
		if assignment.instance_id == identifier:
			return assignment
	return {}

func start_fire(identifier: String = FIRST_FIRE_TARGET) -> bool:
	if fires.size() >= 2 or fires.has(identifier) or is_ruined(identifier) or not is_house_id(identifier):
		return false
	fire_triggered = true
	fires[identifier] = {"phase": "warning", "warning_left": 18.0, "elapsed": 0.0, "danger": 1, "spread_checked": false}
	save_game()
	return true

func fire_target() -> String:
	if fires.has(FIRST_FIRE_TARGET):
		return FIRST_FIRE_TARGET
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
	var ruined := is_ruined(identifier)
	var price := 120 if ruined else 40 + damage
	if damage <= 0 or not fires.is_empty() or job != "" or not fire_jobs.is_empty() or not construction_job.is_empty() or budget < price:
		return false
	if ruined:
		var task_kind := "restore_legacy" if identifier.begins_with("pine_district_legacy_") else "restore_grid"
		var fields := {"kind": task_kind, "type_id": "house", "identifier": identifier, "col": -1, "row": -1, "index": -1, "level": 1, "cost": price}
		if task_kind == "restore_legacy":
			fields.index = int(identifier.trim_prefix("pine_district_legacy_"))
		else:
			var ruined_entry := territory.building_by_id(identifier)
			if ruined_entry.is_empty():
				return false
			fields.type_id = ruined_entry.type_id
			fields.col = ruined_entry.col
			fields.row = ruined_entry.row
			fields.level = int(ruined_entry.get("level", 1))
		return _start_construction(fields)
	budget -= price
	fire_damage.erase(identifier)
	fire_ruins.erase(identifier)
	jam_cleared.erase(identifier)
	if ruined:
		# A destroyed building returns as a basic one-storey property. Further
		# visual upgrades are a deliberate player action after restoration.
		if identifier.begins_with("pine_district_legacy_"):
			var legacy_index := int(identifier.trim_prefix("pine_district_legacy_"))
			if legacy_index in range(24):
				levels[legacy_index] = 1
		else:
			var restored_entry := territory.building_by_id(identifier)
			if not restored_entry.is_empty():
				restored_entry.level = 1
	save_game()
	return true

func restore_grid_ruin(identifier: String, reserved: bool = false) -> bool:
	var entry := territory.building_by_id(identifier)
	if entry.is_empty() or entry.has("legacy_plot") or not is_ruined(identifier):
		return false
	if not reserved:
		var price := 120
		if budget < price:
			return false
		budget -= price
	fire_damage.erase(identifier)
	fire_ruins.erase(identifier)
	jam_cleared.erase(identifier)
	entry.level = 1
	save_game()
	return true

func restore_legacy_ruin(index: int, reserved: bool = false) -> bool:
	if index < 0 or index >= 24 or buildings[index] != "house" or not is_ruined("pine_district_legacy_%d" % index):
		return false
	if not reserved:
		if budget < 120:
			return false
		budget -= 120
	var identifier := "pine_district_legacy_%d" % index
	fire_damage.erase(identifier)
	fire_ruins.erase(identifier)
	jam_cleared.erase(identifier)
	levels[index] = 1
	save_game()
	return true

func fire_route_from_station(station_position: Vector3, target_position: Vector3) -> Array:
	var start := territory.nearest_road(station_position)
	var finish := territory.nearest_road(target_position)
	var path := territory.road_path(start, finish)
	if path.is_empty() or territory.road_path(finish, start).is_empty():
		return []
	return logical_route(path)

func dispatch_fire(identifier: String = "") -> bool:
	if identifier == "":
		for key in fires:
			if fire_assignment(str(key)).is_empty():
				identifier = str(key)
				break
	var fire: Dictionary = fires.get(identifier, {})
	if identifier == "" or fire.is_empty() or fire.phase not in ["warning", "burning"] or fire_ruins.has(identifier) or not fire_assignment(identifier).is_empty():
		return false
	var used: Dictionary = {}
	for assignment in fire_assignments():
		used[assignment.vehicle_id] = true
	var selected_station: Dictionary = {}
	var engine_id := ""
	for station in territory.buildings:
		if station.type_id != "fire_station":
			continue
		for slot in range(2):
			var candidate_id := "%s_engine_%d" % [station.instance_id, slot + 1]
			if not used.has(candidate_id):
				selected_station = station.duplicate(true)
				selected_station.position = territory.building_center(station)
				engine_id = candidate_id
				break
		if engine_id != "":
			break
	# A pre-service-building save may still have an active legacy job, but it cannot start a new dispatch.
	if selected_station.is_empty():
		return false
	var planned := fire_route_from_station(selected_station.position, building_world_for_id(identifier))
	if planned.is_empty():
		return false
	var assignment := {"vehicle_id": engine_id, "depot_instance_id": selected_station.instance_id, "phase": "travel",
		"route": planned, "route_index": 0, "vehicle": planned[0], "repair_left": 4.0}
	jam_cleared[identifier] = false
	if job == "":
		job = "fire"
		target_instance_id = identifier
		depot_instance_id = selected_station.instance_id
		job_vehicle_id = engine_id
		job_phase = "travel"
		route = planned
		vehicle = route[0]
		route_index = 0
		repair_left = 4.0
	else:
		fire_jobs[identifier] = assignment
	save_game()
	return true

func can_dispatch_fire(identifier: String) -> bool:
	if not fires.has(identifier) or not fire_assignment(identifier).is_empty():
		return false
	var used: Dictionary = {}
	for assignment in fire_assignments():
		used[assignment.vehicle_id] = true
	for station in territory.buildings:
		if station.type_id != "fire_station":
			continue
		var center: Vector3 = territory.building_center(station)
		if fire_route_from_station(center, building_world_for_id(identifier)).is_empty():
			continue
		for slot in range(2):
			if not used.has("%s_engine_%d" % [station.instance_id, slot + 1]):
				return true
	return false

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

func fire_spread_target(source_id: String) -> String:
	var source := building_world_for_id(source_id)
	var best_id := ""
	var best_distance := 22.0
	for entry in all_buildings():
		if entry.type_id != "house" or entry.instance_id == source_id or fires.has(entry.instance_id) or is_ruined(entry.instance_id):
			continue
		var distance: float = entry.position.distance_to(source)
		if distance < best_distance:
			best_distance = distance
			best_id = entry.instance_id
	return best_id

func return_route_for_fire(route_value: Array, station_id: String) -> Array:
	var result: Array = route_value.duplicate()
	result.reverse()
	var station := territory.building_by_id(station_id)
	if station.is_empty():
		return result
	var end_point := DistrictWorld.logical_position(territory.building_center(station))
	if result.is_empty() or not result.back().is_equal_approx(end_point):
		result.append(end_point)
	return result

func begin_primary_fire_return() -> void:
	if job != "fire" or job_phase == "return":
		return
	route = return_route_for_fire(route, depot_instance_id)
	route_index = 0
	job_phase = "return"

func begin_secondary_fire_return(identifier: String) -> void:
	if not fire_jobs.has(identifier):
		return
	var assignment: Dictionary = fire_jobs[identifier]
	if assignment.phase == "return":
		return
	assignment.route = return_route_for_fire(assignment.route, assignment.depot_instance_id)
	assignment.route_index = 0
	assignment.phase = "return"
	fire_jobs[identifier] = assignment

func dispatch_police(incident_id: String) -> bool:
	if not jam_cleared.has(incident_id) or bool(jam_cleared[incident_id]) or not police_job.is_empty():
		return false
	var station: Dictionary = {}
	for entry: Dictionary in territory.buildings:
		if entry.type_id == "police_station":
			station = entry.duplicate(true)
			station.position = territory.building_center(entry)
			break
	if station.is_empty():
		for entry: Dictionary in territory.buildings:
			if entry.type_id == "depot":
				station = entry.duplicate(true)
				station.position = territory.building_center(entry)
				break
	if station.is_empty():
		return false
	var target := building_world_for_id(incident_id)
	var planned := fire_route_from_station(station.position, target)
	if planned.is_empty():
		return false
	police_job = {"incident_id": incident_id, "depot_instance_id": station.instance_id, "phase": "travel",
		"route": planned, "route_index": 0, "vehicle": planned[0], "clear_left": 3.0}
	save_game()
	return true

func tick(delta: float, movement_allowed: bool = true, movement_fraction: float = 1.0, fire_motion: Dictionary = {}) -> bool:
	var changed := false
	if movement_allowed:
		incident_clock += delta
		if incident_clock >= 90.0:
			incident_clock = 0.0
			if generate_incident():
				changed = true
	if not construction_job.is_empty():
		var previous_progress := floori(construction_progress() * 20.0)
		construction_job.remaining = maxf(0.0, float(construction_job.remaining) - delta)
		var elapsed_work := float(construction_job.total) - float(construction_job.remaining)
		var arrival_ratio := clampf(elapsed_work / maxf(0.1, float(construction_job.get("arrival_duration", 0.8))), 0.0, 1.0)
		for moving_machine in [["excavator_position", "excavator_start_position", "excavator_target_position", "excavator_route"], ["truck_position", "truck_start_position", "truck_target_position", "truck_route"]]:
			var from_point: Array = construction_job.get(moving_machine[1], construction_job.get(moving_machine[0], []))
			var to_point: Array = construction_job.get(moving_machine[2], construction_job.get(moving_machine[0], []))
			var current_world: Vector3
			var saved_route: Variant = construction_job.get(moving_machine[3], [])
			if saved_route is Array and saved_route.size() >= 2:
				var route_index_float := arrival_ratio * float(saved_route.size() - 1)
				var route_index := mini(int(floor(route_index_float)), saved_route.size() - 2)
				var route_fraction := route_index_float - float(route_index)
				var route_from: Array = saved_route[route_index]
				var route_to: Array = saved_route[route_index + 1]
				current_world = Vector3(route_from[0], route_from[1], route_from[2]).lerp(Vector3(route_to[0], route_to[1], route_to[2]), route_fraction)
			elif valid_point(from_point) and valid_point(to_point):
				current_world = Vector3(from_point[0], from_point[1], from_point[2]).lerp(Vector3(to_point[0], to_point[1], to_point[2]), arrival_ratio)
			else:
				continue
			if true:
				construction_job[moving_machine[0]] = [current_world.x, current_world.y, current_world.z]
		if float(construction_job.remaining) <= 0.0:
			_finish_construction()
			changed = true
		elif floori(construction_progress() * 20.0) != previous_progress:
			changed = true
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
			if float(fire.elapsed) >= 12.0 and not bool(fire.get("spread_checked", false)):
				fire.spread_checked = true
				if fires.size() < 2:
					var neighbor := fire_spread_target(identifier)
					if neighbor != "":
						fires[neighbor] = {"phase": "warning", "warning_left": 16.0, "elapsed": 0.0, "danger": 1, "spread_checked": false}
			if house_damage(identifier) >= 100:
				fire_ruins[identifier] = true
				fires.erase(identifier)
				if job == "fire" and target_instance_id == identifier:
					begin_primary_fire_return()
				if fire_jobs.has(identifier):
					begin_secondary_fire_return(identifier)
				changed = true
				continue
		fires[identifier] = fire
		if old_phase != fire.phase or old_warning != ceili(float(fire.warning_left)) or old_damage != house_damage(identifier) or old_severity != fire_severity(identifier):
			changed = true
	income_clock += delta
	if not leak_fixed or not signal_fixed:
		service_neglect_clock += delta
	if income_clock >= 12.0:
		income_clock -= 12.0
		var financial_change := income() - incident_penalty()
		# A city at zero receives a small operating subsidy, so lack of money
		# never becomes a hard loss condition or a permanent soft lock.
		if budget <= 0:
			financial_change = maxi(1, financial_change)
		budget = maxi(0, budget + financial_change)
		if service_neglect_clock >= 60.0:
			var neglect_cycles := floori(service_neglect_clock / 60.0)
			service_neglect_clock = fmod(service_neglect_clock, 60.0)
			if not leak_fixed:
				var water_homes: Array = []
				for index in WATER_AFFECTED_HOMES:
					water_homes.append("pine_district_legacy_%d" % index)
				apply_service_neglect_damage(4 * neglect_cycles, water_homes)
			if not signal_fixed:
				var city_homes: Array = []
				for entry: Dictionary in all_buildings():
					if entry.type_id == "house":
						city_homes.append(entry.instance_id)
				apply_service_neglect_damage(2 * neglect_cycles, city_homes)
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
			job_vehicle_id = ""
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
					fires.erase(target_instance_id)
				job_phase = "return"
				if job == "fire":
					route = return_route_for_fire(route, depot_instance_id)
					route_index = 0
				else:
					route.reverse()
					route.append(DistrictWorld.logical_position(job_depot_world()))
					route_index = 0
				check_complete()
				changed = true
	for identifier in fire_jobs.keys():
		var assignment: Dictionary = fire_jobs[identifier]
		if assignment.phase != "return" and (is_ruined(str(identifier)) or not fires.has(identifier)):
			begin_secondary_fire_return(str(identifier))
			assignment = fire_jobs[identifier]
		if int(assignment.route_index) < assignment.route.size():
			if movement_allowed:
				var target_point: Vector3 = assignment.route[int(assignment.route_index)]
				var current_point: Vector3 = assignment.vehicle
				var fraction: float = clampf(float(fire_motion.get(str(identifier), 1.0)), 0, 1)
				assignment.vehicle = current_point.move_toward(target_point, delta * 2.6 * fraction)
				if assignment.vehicle.distance_to(target_point) < 0.01:
					assignment.route_index = int(assignment.route_index) + 1
					if int(assignment.route_index) >= assignment.route.size() and assignment.phase == "travel":
						assignment.phase = "repair"
						changed = true
		else:
			if assignment.phase == "return":
				jam_cleared.erase(str(identifier))
				fire_jobs.erase(identifier)
				changed = true
				continue
			if assignment.phase == "travel":
				assignment.phase = "repair"
				changed = true
			else:
				assignment.repair_left = float(assignment.repair_left) - delta
				if float(assignment.repair_left) <= 0:
					fires.erase(identifier)
					assignment.route = return_route_for_fire(assignment.route, assignment.depot_instance_id)
					assignment.route_index = 0
					assignment.phase = "return"
					changed = true
		fire_jobs[identifier] = assignment
	if not police_job.is_empty():
		if police_job.route_index < police_job.route.size():
			if movement_allowed:
				var police_target: Vector3 = police_job.route[int(police_job.route_index)]
				var police_position: Vector3 = police_job.vehicle
				var police_fraction: float = clampf(float(fire_motion.get("police", 1.0)), 0, 1)
				police_job.vehicle = police_position.move_toward(police_target, delta * 2.8 * police_fraction)
				if police_job.vehicle.distance_to(police_target) < 0.01:
					police_job.route_index += 1
					if int(police_job.route_index) >= police_job.route.size():
						police_job.phase = "clearing"
						changed = true
		else:
			if police_job.phase == "travel":
				police_job.phase = "clearing"
				changed = true
			elif police_job.phase == "clearing":
				police_job.clear_left = float(police_job.clear_left) - delta
				if police_job.clear_left <= 0:
					jam_cleared[police_job.incident_id] = true
					police_job.route.reverse()
					var return_station := territory.building_by_id(str(police_job.depot_instance_id))
					if not return_station.is_empty():
						police_job.route.append(DistrictWorld.logical_position(territory.building_center(return_station)))
					police_job.route_index = 0
					police_job.phase = "return"
					changed = true
			else:
				police_job = {}
				changed = true
	if changed:
		save_game()
	return changed

func generate_incident() -> bool:
	if incidents.size() >= 2:
		return false
	var candidates: Array[String] = ["leak", "signal"]
	if has_service_building("fire_station"):
		candidates.append("fire")
	if has_service_building("hospital"):
		candidates.append("disease")
	if candidates.is_empty():
		return false
	var kind := candidates[incident_rng.randi_range(0, candidates.size() - 1)]
	var homes := all_buildings().filter(func(entry: Dictionary): return entry.type_id == "house")
	if homes.is_empty():
		return false
	var target: Dictionary = homes[incident_rng.randi_range(0, homes.size() - 1)]
	var id := "incident_%d" % incident_rng.randi()
	incidents[id] = {"id": id, "type": kind, "district_id": "pine_district", "target_id": str(target.instance_id),
		"seed": incident_rng.randi(), "state": "new", "difficulty": clampi(city_level(), 1, 4),
		"reward": 100 + city_level() * 50, "reaction_left": 45.0, "progress": 0.0}
	save_game()
	return true

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
		active_fires.append({"id": str(identifier), "phase": fire.phase, "warning_left": fire.warning_left, "elapsed": fire.elapsed, "danger": fire.danger, "spread_checked": bool(fire.get("spread_checked", false))})
	var encoded_fire_jobs: Dictionary = {}
	for identifier in fire_jobs:
		var assignment: Dictionary = fire_jobs[identifier].duplicate(true)
		var fire_points: Array = []
		for point: Vector3 in assignment.route:
			fire_points.append([point.x, point.y, point.z])
		assignment.route = fire_points
		var assigned_vehicle: Vector3 = assignment.vehicle
		assignment.vehicle = [assigned_vehicle.x, assigned_vehicle.y, assigned_vehicle.z]
		encoded_fire_jobs[str(identifier)] = assignment
	var encoded_police_job := police_job.duplicate(true)
	if not encoded_police_job.is_empty():
		var police_points: Array = []
		for point: Vector3 in encoded_police_job.route:
			police_points.append([point.x, point.y, point.z])
		encoded_police_job.route = police_points
		var police_position: Vector3 = encoded_police_job.vehicle
		encoded_police_job.vehicle = [police_position.x, police_position.y, police_position.z]
	var data := {"version": 7, "levels": levels, "completed": completed, "city_id": "fix_my_town", "districts": {"pine_district": territory.data()}, "vehicle_type_id": "fire_engine" if job == "fire" else "repair_van", "target_type_id": target_type_id(), "budget": budget, "language": language, "leak_fixed": leak_fixed,
		"signal_fixed": signal_fixed, "buildings": buildings, "job": job, "job_phase": job_phase, "route": points, "target_instance_id": target_instance_id, "depot_instance_id": depot_instance_id,
		"route_index": route_index, "vehicle": [vehicle.x, vehicle.y, vehicle.z],
		"repair_left": repair_left, "income_clock": income_clock, "service_neglect_clock": service_neglect_clock, "transit": transit.data(), "fire_triggered": fire_triggered, "fires": active_fires, "fire_damage": fire_damage,
		"fire_ruins": fire_ruins, "fire_jobs": encoded_fire_jobs, "job_vehicle_id": job_vehicle_id, "jam_cleared": jam_cleared, "police_job": encoded_police_job, "construction_job": construction_job,
		"incident_seed": incident_seed, "incident_clock": incident_clock, "incidents": incidents,
		"district_house_limit": district_house_limit, "district_tasks": district_tasks}
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
	if not data is Dictionary or not (data.get("version") is int or data.get("version") is float) or int(data.get("version")) not in [1, 2, 3, 4, 5, 6, 7]:
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
	for stop in loaded_transit.stops:
		if stop is Dictionary:
			var cell := Vector2i(int(stop.col), int(stop.row))
			if loaded_territory.state_at(cell.x, cell.y) != "road" or loaded_territory.path_to_city(cell.x, cell.y).is_empty():
				return false
			if str(stop.get("orientation", "")) not in ["", "horizontal", "vertical"]:
				return false
			var orientation := str(stop.get("orientation", "")) if stop.has("orientation") else loaded_territory.road_orientation(cell.x, cell.y)
			if orientation == "":
				return false
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
		if row.has("spread_checked") and typeof(row.spread_checked) != TYPE_BOOL:
			return false
		loaded_fires[row.id] = {"phase": row.phase, "warning_left": clampf(float(row.warning_left), 0, 18), "elapsed": clampf(float(row.elapsed), 0, 100000), "danger": clampi(int(row.danger), 1, 3), "spread_checked": bool(row.get("spread_checked", false))}
	var loaded_damage: Dictionary = {}
	var raw_damage: Variant = data.get("fire_damage", {})
	if not raw_damage is Dictionary or raw_damage.size() > 24 + TerritoryGrid.WIDTH * TerritoryGrid.HEIGHT:
		return false
	for identifier in raw_damage:
		var value: Variant = raw_damage[identifier]
		if not is_house_id_in(str(identifier), stored, loaded_territory) or not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0 or float(value) > 100:
			return false
		loaded_damage[str(identifier)] = float(value)
	var loaded_ruins: Dictionary = {}
	var raw_ruins: Variant = data.get("fire_ruins", {})
	if not raw_ruins is Dictionary or raw_ruins.size() > 24 + TerritoryGrid.WIDTH * TerritoryGrid.HEIGHT:
		return false
	for identifier in raw_ruins:
		if typeof(raw_ruins[identifier]) != TYPE_BOOL or not raw_ruins[identifier] or not is_house_id_in(str(identifier), stored, loaded_territory) or float(loaded_damage.get(str(identifier), 0.0)) < 100.0:
			return false
		loaded_ruins[str(identifier)] = true
	if int(data.version) < 5:
		for identifier in loaded_damage:
			if float(loaded_damage[identifier]) >= 100.0:
				loaded_ruins[str(identifier)] = true
	var loaded_fire_jobs: Dictionary = {}
	var raw_fire_jobs: Variant = data.get("fire_jobs", {})
	if not raw_fire_jobs is Dictionary or raw_fire_jobs.size() > 2:
		return false
	for identifier in raw_fire_jobs:
		var assignment: Variant = raw_fire_jobs[identifier]
		if not assignment is Dictionary or not is_house_id_in(str(identifier), stored, loaded_territory) or loaded_ruins.has(str(identifier)):
			return false
		if str(identifier) == stored_target and stored_job == "fire" or not loaded_fires.has(str(identifier)) and assignment.get("phase") != "return":
			return false
		var station_id: String = str(assignment.get("depot_instance_id", ""))
		var station := loaded_territory.building_by_id(station_id)
		var vehicle_id: String = str(assignment.get("vehicle_id", ""))
		if station.is_empty() or station.type_id != "fire_station" or not vehicle_id.begins_with(station_id + "_engine_") or assignment.get("phase") not in ["travel", "repair", "return"]:
			return false
		var raw_assignment_route: Variant = assignment.get("route", [])
		var raw_assignment_vehicle: Variant = assignment.get("vehicle", [])
		if not raw_assignment_route is Array or raw_assignment_route.is_empty() or raw_assignment_route.size() > TerritoryGrid.WIDTH * TerritoryGrid.HEIGHT + 2 or not valid_point(raw_assignment_vehicle):
			return false
		var assignment_route: Array = []
		for point in raw_assignment_route:
			if not valid_point(point):
				return false
			assignment_route.append(Vector3(point[0], point[1], point[2]))
		for key in ["route_index", "repair_left"]:
			var value: Variant = assignment.get(key, null)
			if not (value is int or value is float) or not is_finite(float(value)):
				return false
		if int(assignment.route_index) < 0 or int(assignment.route_index) > assignment_route.size() or float(assignment.repair_left) < 0:
			return false
		var normalized_assignment: Dictionary = assignment.duplicate(true)
		normalized_assignment.route = assignment_route
		normalized_assignment.vehicle = Vector3(raw_assignment_vehicle[0], raw_assignment_vehicle[1], raw_assignment_vehicle[2])
		loaded_fire_jobs[str(identifier)] = normalized_assignment
	var loaded_jam_cleared: Dictionary = {}
	var raw_jam_cleared: Variant = data.get("jam_cleared", {})
	if not raw_jam_cleared is Dictionary:
		return false
	for identifier in raw_jam_cleared:
		if typeof(raw_jam_cleared[identifier]) != TYPE_BOOL or not is_house_id_in(str(identifier), stored, loaded_territory):
			return false
		loaded_jam_cleared[str(identifier)] = raw_jam_cleared[identifier]
	var loaded_job_vehicle_id: String = str(data.get("job_vehicle_id", stored_depot_id + "_engine_1" if stored_job == "fire" else ""))
	if stored_job == "fire" and not loaded_job_vehicle_id.begins_with(stored_depot_id + "_engine_"):
		return false
	var assigned_vehicle_ids: Dictionary = {}
	if stored_job == "fire":
		assigned_vehicle_ids[loaded_job_vehicle_id] = true
	for identifier in loaded_fire_jobs:
		var vehicle_id: String = str(loaded_fire_jobs[identifier].vehicle_id)
		if assigned_vehicle_ids.has(vehicle_id):
			return false
		assigned_vehicle_ids[vehicle_id] = true
	var loaded_police_job: Dictionary = {}
	var raw_police_job: Variant = data.get("police_job", {})
	if not raw_police_job is Dictionary:
		return false
	if not raw_police_job.is_empty():
		var police_station := loaded_territory.building_by_id(str(raw_police_job.get("depot_instance_id", "")))
		var incident_id := str(raw_police_job.get("incident_id", ""))
		var phase_value: Variant = raw_police_job.get("phase", "")
		var police_route: Variant = raw_police_job.get("route", [])
		var police_position: Variant = raw_police_job.get("vehicle", [])
		if police_station.is_empty() or police_station.type_id != "police_station" or not loaded_jam_cleared.has(incident_id) or (loaded_jam_cleared[incident_id] and phase_value != "return") or phase_value not in ["travel", "clearing", "return"] or not police_route is Array or police_route.is_empty() or not valid_point(police_position):
			return false
		var normalized_police: Dictionary = raw_police_job.duplicate(true)
		var restored_police_route: Array = []
		for point in police_route:
			if not valid_point(point):
				return false
			restored_police_route.append(Vector3(point[0], point[1], point[2]))
		if not (normalized_police.get("route_index") is int or normalized_police.get("route_index") is float) or int(normalized_police.route_index) < 0 or int(normalized_police.route_index) > restored_police_route.size() or not (normalized_police.get("clear_left") is int or normalized_police.get("clear_left") is float):
			return false
		normalized_police.route = restored_police_route
		normalized_police.vehicle = Vector3(police_position[0], police_position[1], police_position[2])
		loaded_police_job = normalized_police
	var loaded_construction: Dictionary = {}
	var raw_construction: Variant = data.get("construction_job", {})
	if not raw_construction is Dictionary:
		return false
	if not raw_construction.is_empty():
		var construction_kind := str(raw_construction.get("kind", ""))
		if construction_kind not in ["build_legacy", "build_grid", "upgrade_legacy", "upgrade_grid", "restore_legacy", "restore_grid", "clear", "road", "demolish_grid", "demolish_legacy", "demolish_road"]:
			return false
		for key in ["remaining", "total"]:
			var number: Variant = raw_construction.get(key, null)
			if not (number is int or number is float) or not is_finite(float(number)) or float(number) <= 0 or float(number) > CONSTRUCTION_DURATION:
				return false
		if float(raw_construction.remaining) > float(raw_construction.total):
			return false
		var arrival_duration: Variant = raw_construction.get("arrival_duration", 0.0)
		if not (arrival_duration is int or arrival_duration is float) or not is_finite(float(arrival_duration)) or float(arrival_duration) < 0.0 or float(arrival_duration) > 2.0:
			return false
		var cc := int(raw_construction.get("col", -1))
		var cr := int(raw_construction.get("row", -1))
		var ct := str(raw_construction.get("type_id", ""))
		if construction_kind == "build_legacy" and (int(raw_construction.get("index", -1)) not in range(24) or stored[int(raw_construction.index)] != "empty" or ct not in ["house", "cafe", "park"]):
			return false
		if construction_kind == "upgrade_legacy" and (int(raw_construction.get("index", -1)) not in range(24) or stored[int(raw_construction.index)] != ct or levels[int(raw_construction.index)] != int(raw_construction.get("level", -1)) or int(raw_construction.get("level", 0)) >= 3):
			return false
		if construction_kind == "build_grid" and (not Catalog.TYPES.has(ct) or loaded_territory.placement_reason(cc, cr, "landscaping" if Catalog.is_landscaping(ct) else ("service" if Catalog.is_service(ct) else "house")) != ""):
			return false
		if construction_kind == "clear" and loaded_territory.placement_reason(cc, cr, "clear") != "":
			return false
		if construction_kind == "road" and loaded_territory.placement_reason(cc, cr, "road") != "":
			return false
		if construction_kind == "demolish_grid" and loaded_territory.building_by_id(str(raw_construction.get("identifier", ""))).is_empty():
			return false
		if construction_kind == "upgrade_grid":
			var upgrade_entry: Dictionary = loaded_territory.building_by_id(str(raw_construction.get("identifier", "")))
			if upgrade_entry.is_empty() or not Catalog.LEVELS.has(ct) or upgrade_entry.type_id != ct or loaded_ruins.has(str(raw_construction.get("identifier", ""))) or int(upgrade_entry.get("level", 1)) != int(raw_construction.get("level", -1)) or int(raw_construction.get("level", 0)) >= 3:
				return false
		if construction_kind == "restore_grid":
			var restore_entry: Dictionary = loaded_territory.building_by_id(str(raw_construction.get("identifier", "")))
			if restore_entry.is_empty() or restore_entry.has("legacy_plot") or not loaded_ruins.has(str(raw_construction.get("identifier", ""))) or restore_entry.type_id != ct:
				return false
		if construction_kind == "restore_legacy":
			var restore_index := int(raw_construction.get("index", -1))
			var restore_id := "pine_district_legacy_%d" % restore_index
			if restore_index not in range(24) or stored[restore_index] != "house" or not loaded_ruins.has(restore_id):
				return false
		if construction_kind == "demolish_road" and loaded_territory.state_at(cc, cr) != "road":
			return false
		if construction_kind == "demolish_legacy" and (int(raw_construction.get("index", -1)) not in range(24) or not Catalog.LEVELS.has(stored[int(raw_construction.index)])):
			return false
		var construction_position: Variant = raw_construction.get("position", [])
		if not valid_point(construction_position) or not valid_point(raw_construction.get("excavator_position", [])) or not valid_point(raw_construction.get("truck_position", [])):
			return false
		for position_key in ["excavator_start_position", "excavator_target_position", "truck_start_position", "truck_target_position"]:
			if raw_construction.has(position_key) and not valid_point(raw_construction[position_key]):
				return false
		loaded_construction = raw_construction.duplicate(true)
		normalize_construction_vehicle_paths(loaded_construction, loaded_territory)
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
	job_vehicle_id = loaded_job_vehicle_id
	job_phase = stored_phase
	fire_triggered = triggered
	fires = loaded_fires
	fire_damage = loaded_damage
	fire_ruins = loaded_ruins
	fire_jobs = loaded_fire_jobs
	jam_cleared = loaded_jam_cleared
	police_job = loaded_police_job
	construction_job = loaded_construction
	incident_seed = int(data.get("incident_seed", 48291))
	incident_clock = maxf(0.0, float(data.get("incident_clock", 0.0)))
	incidents = data.get("incidents", {}) if data.get("incidents", {}) is Dictionary else {}
	incident_rng.seed = incident_seed
	district_house_limit = clampi(int(data.get("district_house_limit", 8)), 1, 100)
	if data.get("district_tasks", []) is Array and not data.get("district_tasks", []).is_empty():
		district_tasks = data.get("district_tasks")
	route = loaded_route
	route_index = clampi(int(data.route_index), 0, route.size())
	vehicle = Vector3(stored_vehicle[0], stored_vehicle[1], stored_vehicle[2])
	repair_left = clampf(float(data.repair_left), 0.0, 4.0)
	income_clock = clampf(float(data.income_clock), 0.0, 12.0)
	service_neglect_clock = clampf(float(data.get("service_neglect_clock", 0.0)), 0.0, 60.0)
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

func upgrade(index: int, reserved: bool = false) -> bool:
	var price := upgrade_cost(index)
	if price <= 0 or (not reserved and budget < price):
		return false
	if not reserved:
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
