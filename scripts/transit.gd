extends RefCounted

const WALK_RADIUS: float = 24.0
const STOP_COST: int = 40
const BUS_COST: int = 60
const UPKEEP: int = 3
const CAPACITY: int = 32
const SPEED: float = 5.2
const LEGACY_ROAD_X: float = -14.4
const LEGACY_ROW_Z = [-36.0, -21.6, -7.2, 7.2, 21.6, 36.0]

var stops: Array = [] # New stops are {col,row}; legacy integer rows are migrated on read.
var active: bool = false
var funded: bool = true
var coordinate: float = -36.0 # Legacy save field, kept for migration/debug tools.
var direction: int = 1
var visual_direction: int = 1
var target_z: float = -21.6
var turning_out: bool = false
var dwell: float = 0.0
var delay: float = 0.0
var last_delay: float = 0.0
var trips: int = 0
var route_points: Array[Vector3] = []
var route_index: int = 0
var bus_position := Vector3.ZERO
var current_target: int = 1
var route_dirty: bool = false
var legacy_route_pending: bool = false
var initial_dwell: bool = false

func stop_cell(stop: Variant, grid: RefCounted) -> Vector2i:
	if stop is Dictionary:
		var cell := Vector2i(int(stop.get("col", -1)), int(stop.get("row", -1)))
		return cell if grid.state_at(cell.x, cell.y) == "road" else Vector2i(-1, -1)
	if stop is int or stop is float:
		var row := clampi(int(stop), 0, LEGACY_ROW_Z.size() - 1)
		return grid.nearest_road(Vector3(LEGACY_ROAD_X, 0, LEGACY_ROW_Z[row]))
	return Vector2i(-1, -1)

func stop_position(stop: Variant, grid: RefCounted = null) -> Vector3:
	if stop is Dictionary and grid != null:
		var cell := stop_cell(stop, grid)
		if cell.x >= 0:
			return grid.cell_world(cell.x, cell.y)
	if stop is int or stop is float:
		var row := clampi(int(stop), 0, LEGACY_ROW_Z.size() - 1)
		return Vector3(LEGACY_ROAD_X, 0, LEGACY_ROW_Z[row])
	return Vector3.ZERO

func in_range(point: Vector3, stop: Variant, grid: RefCounted = null) -> bool:
	var target := stop_position(stop, grid)
	return absf(point.x - target.x) + absf(point.z - target.z) <= WALK_RADIUS

func route_for(grid: RefCounted, from_index: int, to_index: int) -> Array[Vector3]:
	if stops.size() < 2 or from_index < 0 or to_index < 0 or from_index >= stops.size() or to_index >= stops.size():
		return []
	var start := stop_cell(stops[from_index], grid)
	var finish := stop_cell(stops[to_index], grid)
	if start.x < 0 or finish.x < 0:
		return []
	return route_between(grid, start, finish)

func route_between(grid: RefCounted, start: Vector2i, finish: Vector2i) -> Array[Vector3]:
	var cells: Array[Vector2i] = grid.road_path(start, finish)
	var result: Array[Vector3] = []
	for cell: Vector2i in cells:
		result.append(grid.cell_world(cell.x, cell.y) + Vector3(0, 0.18, 0))
	return result

func data() -> Dictionary:
	var encoded_route: Array = []
	for point: Vector3 in route_points:
		encoded_route.append([point.x, point.y, point.z])
	return {"type_id": "city_bus", "stops": stops.duplicate(true), "active": active, "funded": funded,
		"coordinate": coordinate, "direction": direction, "visual_direction": visual_direction, "target_z": target_z,
		"turning_out": turning_out, "dwell": dwell, "delay": delay, "last_delay": last_delay, "trips": trips,
		"route_points": encoded_route, "route_index": route_index, "bus_position": [bus_position.x, bus_position.y, bus_position.z],
		"current_target": current_target, "route_dirty": route_dirty, "initial_dwell": initial_dwell}

func restore(value: Variant) -> bool:
	if not value is Dictionary or value.get("type_id", "city_bus") != "city_bus":
		return false
	var raw_stops: Variant = value.get("stops", [])
	if not raw_stops is Array or raw_stops.size() > 2:
		return false
	var normalized: Array = []
	for stop in raw_stops:
		if stop is Dictionary:
			var col: Variant = stop.get("col", null)
			var row: Variant = stop.get("row", null)
			if not (col is int or col is float) or not (row is int or row is float) or not is_finite(float(col)) or not is_finite(float(row)) or float(col) != int(col) or float(row) != int(row) or col < 0 or row < 0:
				return false
			var cell := {"col": int(col), "row": int(row)}
			if normalized.has(cell):
				return false
			normalized.append(cell)
		elif (stop is int or stop is float) and is_finite(float(stop)) and float(stop) == int(stop) and stop >= 0 and stop < LEGACY_ROW_Z.size():
			if normalized.has(int(stop)):
				return false
			normalized.append(int(stop))
		else:
			return false
	if typeof(value.get("active", false)) != TYPE_BOOL or typeof(value.get("funded", true)) != TYPE_BOOL:
		return false
	if value.get("active", false) and normalized.size() != 2:
		return false
	for key in ["coordinate", "direction", "dwell", "delay", "last_delay", "trips"]:
		var number: Variant = value.get(key, 0)
		if not (number is float or number is int) or not is_finite(float(number)):
			return false
	var restored_points: Array[Vector3] = []
	var raw_points: Variant = value.get("route_points", [])
	if not raw_points is Array:
		return false
	for point in raw_points:
		if not point is Array or point.size() != 3:
			return false
		for part in point:
			if not (part is int or part is float) or not is_finite(float(part)):
				return false
		restored_points.append(Vector3(float(point[0]), float(point[1]), float(point[2])))
	var raw_position: Variant = value.get("bus_position", [0.0, 0.18, 0.0])
	if not raw_position is Array or raw_position.size() != 3:
		return false
	for part in raw_position:
		if not (part is int or part is float) or not is_finite(float(part)):
			return false
	stops = normalized
	active = value.get("active", false)
	funded = value.get("funded", true)
	coordinate = float(value.get("coordinate", -36))
	direction = -1 if value.get("direction", 1) < 0 else 1
	visual_direction = -1 if value.get("visual_direction", direction) < 0 else 1
	target_z = float(value.get("target_z", -21.6))
	turning_out = value.get("turning_out", false)
	dwell = clampf(float(value.get("dwell", 0)), 0, 60)
	delay = clampf(float(value.get("delay", 0)), 0, 3600)
	last_delay = clampf(float(value.get("last_delay", 0)), 0, 3600)
	trips = clampi(int(value.get("trips", 0)), 0, 1000000)
	route_points = restored_points
	route_index = clampi(int(value.get("route_index", 0)), 0, maxi(0, route_points.size() - 1))
	bus_position = Vector3(float(raw_position[0]), float(raw_position[1]), float(raw_position[2]))
	current_target = clampi(int(value.get("current_target", 1)), 0, 1)
	route_dirty = bool(value.get("route_dirty", false))
	initial_dwell = bool(value.get("initial_dwell", false))
	legacy_route_pending = active and restored_points.is_empty()
	return true

func make_leg(grid: RefCounted, from_index: int, to_index: int) -> bool:
	var next_points := route_for(grid, from_index, to_index)
	return set_leg(next_points, to_index)

func set_leg(next_points: Array[Vector3], to_index: int) -> bool:
	if next_points.is_empty():
		return false
	route_points = next_points
	route_index = 0
	current_target = to_index
	bus_position = route_points[0]
	route_dirty = false
	return true

func tick(delta: float, traffic: Node3D, grid: RefCounted = null) -> void:
	if not active or stops.size() != 2 or traffic == null:
		return
	var bus: Dictionary = traffic.vehicles[2]
	bus.managed = true
	bus.node.visible = true
	if route_points.is_empty() and grid != null:
		if make_leg(grid, 0 if current_target == 1 else 1, current_target) and legacy_route_pending:
			var saved_position := Vector3(LEGACY_ROAD_X, 0.18, coordinate)
			var closest_index := 0
			var closest_distance := INF
			for index in range(route_points.size()):
				var distance := route_points[index].distance_squared_to(saved_position)
				if distance < closest_distance:
					closest_index = index
					closest_distance = distance
			route_index = closest_index
			bus_position = route_points[closest_index]
			legacy_route_pending = false
	if not funded or route_points.is_empty():
		place_bus(bus, traffic)
		return
	if dwell > 0:
		dwell = maxf(0, dwell - delta)
		if dwell <= 0:
			if initial_dwell:
				initial_dwell = false
			else:
				var to_index := 1 - current_target
				if grid != null:
					var start_cell: Vector2i = grid.nearest_road(bus_position)
					var target_cell: Vector2i = stop_cell(stops[to_index], grid)
					set_leg(route_between(grid, start_cell, target_cell), to_index)
	else:
		var remaining := SPEED * delta
		var moved := 0.0
		while remaining > 0.001 and route_index < route_points.size() - 1:
			var current := bus_position
			var target := route_points[route_index + 1]
			var step := minf(remaining, current.distance_to(target))
			var axis := "H" if absf(target.x - current.x) > absf(target.z - current.z) else "V"
			bus.axis = axis
			bus.road = current.z if axis == "H" else current.x
			bus.direction = 1 if (target.x - current.x if axis == "H" else target.z - current.z) > 0 else -1
			bus.coordinate = current.x if axis == "H" else current.z
			var allowed: float = minf(step, traffic.travel_distance(bus, delta))
			if allowed <= 0.0001:
				break
			bus_position = current.move_toward(target, allowed)
			moved += allowed
			remaining -= allowed
			if bus_position.distance_to(target) < 0.08:
				bus_position = target
				route_index += 1
		if moved < SPEED * delta:
			delay += delta
		if route_index >= route_points.size() - 1 and bus_position.distance_to(route_points.back()) < 0.1:
			trips += 1
			last_delay = delay
			delay = 0
			dwell = 3.0
		coordinate = bus_position.z
		place_bus(bus, traffic)

func place_bus(bus: Dictionary, traffic: Node3D) -> void:
	var tangent := Vector3(0, 0, 1)
	if route_index + 1 < route_points.size():
		tangent = (route_points[route_index + 1] - bus_position).normalized()
	elif route_index > 0:
		tangent = (bus_position - route_points[route_index - 1]).normalized()
	bus.axis = "H" if absf(tangent.x) > absf(tangent.z) else "V"
	bus.road = bus_position.z if bus.axis == "H" else bus_position.x
	bus.coordinate = bus_position.x if bus.axis == "H" else bus_position.z
	bus.direction = 1 if (tangent.x if bus.axis == "H" else tangent.z) > 0 else -1
	traffic.place_vehicle(bus)
