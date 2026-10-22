extends RefCounted

const ROAD_X: float = -14.4
const WALK_RADIUS: float = 24.0
const STOP_COST: int = 40
const BUS_COST: int = 60
const UPKEEP: int = 3
const CAPACITY: int = 32
const ROW_Z = [-36.0, -21.6, -7.2, 7.2, 21.6, 36.0]
var stops: Array = []
var active: bool = false
var funded: bool = true
var coordinate: float = -36
var direction: int = 1
var dwell: float = 0
var delay: float = 0
var last_delay: float = 0
var trips: int = 0

func stop_position(row: int) -> Vector3:
	return Vector3(ROAD_X, 0, ROW_Z[row])

func in_range(point: Vector3, row: int) -> bool:
	var stop := stop_position(row)
	return absf(point.x - stop.x) + absf(point.z - stop.z) <= WALK_RADIUS

func data() -> Dictionary:
	return {"type_id": "city_bus", "stops": stops, "active": active, "funded": funded, "coordinate": coordinate, "direction": direction, "dwell": dwell, "delay": delay, "last_delay": last_delay, "trips": trips}

func restore(value: Variant) -> bool:
	if not value is Dictionary or value.get("type_id", "city_bus") != "city_bus":
		return false
	var rows = value.get("stops", [])
	if not rows is Array or rows.size() > 2:
		return false
	for row in rows:
		if not (row is float or row is int) or not is_finite(float(row)) or row != int(row) or row < 0 or row > 5 or rows.count(row) > 1:
			return false
	if typeof(value.get("active", false)) != TYPE_BOOL or typeof(value.get("funded", true)) != TYPE_BOOL:
		return false
	if value.get("active", false) and rows.size() != 2:
		return false
	for key in ["coordinate", "direction", "dwell", "delay", "last_delay", "trips"]:
		if not (value.get(key, 0) is float or value.get(key, 0) is int) or not is_finite(float(value.get(key, 0))):
			return false
	stops.clear()
	for row in rows:
		stops.append(int(row))
	stops.sort()
	active = value.get("active", false)
	funded = value.get("funded", true)
	coordinate = clampf(float(value.get("coordinate", -36)), ROW_Z[stops[0]] if stops.size() == 2 else -36, ROW_Z[stops[1]] if stops.size() == 2 else 36)
	direction = -1 if value.get("direction", 1) < 0 else 1
	dwell = clampf(float(value.get("dwell", 0)), 0, 3)
	delay = clampf(float(value.get("delay", 0)), 0, 3600)
	last_delay = clampf(float(value.get("last_delay", 0)), 0, 3600)
	trips = clampi(int(value.get("trips", 0)), 0, 1000000)
	return true

func tick(delta: float, traffic: Node3D) -> void:
	if not active or stops.size() != 2:
		return
	var bus: Dictionary = traffic.vehicles[2]
	bus.axis = "V"
	bus.road = ROAD_X
	bus.direction = direction
	bus.coordinate = coordinate
	bus.managed = true
	bus.node.visible = true
	if not funded:
		traffic.place_vehicle(bus)
		return
	if dwell > 0:
		dwell = maxf(0, dwell - delta)
	else:
		var target: float = ROW_Z[stops[1] if direction == 1 else stops[0]]
		var distance: float = traffic.travel_distance(bus, delta)
		delay += maxf(0, delta - distance / traffic.SPEED)
		coordinate = move_toward(coordinate, target, distance)
		if is_equal_approx(coordinate, target):
			trips += 1
			last_delay = delay
			delay = 0
			dwell = 3
			direction *= -1
	bus.coordinate = coordinate
	# Сначала стоянка у платформы, разворот после неё.
	if dwell <= 0:
		bus.direction = direction
	traffic.place_vehicle(bus)
