extends Node3D

const Art = preload("res://scripts/art.gd")
const ObjectScene = preload("res://scenes/objects/game_object.tscn")
const ROAD_X = [-57.6, -43.2, -28.8, -14.4, 0.0, 14.4, 28.8]
const ROAD_Z = [-43.2, -28.8, -14.4, 0.0, 14.4, 28.8, 43.2]
const STOP_DISTANCE = 4.0
const FOLLOW_DISTANCE = 3.6
const SPEED = 5.2
const CYCLE = 18.0
var cars: Array[Node3D] = []
var vehicles: Array = []
var intersections: Array = []
var clock: float = 0
var signal_fixed: bool = false
var service_position := Vector3(1000, 0, 1000)
var service_active: bool = false
var wait_times: Dictionary = {}
var reservations: Dictionary = {}
var last_states: Dictionary = {}

func build() -> void:
	for ix in range(ROAD_X.size()):
		for iz in range(ROAD_Z.size()):
			var node := ObjectScene.instantiate()
			var key := "%d_%d" % [ix, iz]
			node.name = "intersection_" + key
			add_child(node)
			node.setup("traffic_signal", "intersection_" + key)
			node.position = Vector3(ROAD_X[ix], 0.18, ROAD_Z[iz])
			node.interaction_area.collision_layer = 0
			intersections.append({"key": key, "x": ROAD_X[ix], "z": ROAD_Z[iz], "offset": float((ix + iz) % 3) * 2, "node": node})
	make_cars()
	update_lights()

func make_cars() -> void:
	for i in range(24):
		var node := ObjectScene.instantiate()
		node.name = "traffic_vehicle_%d" % i
		add_child(node)
		var kind := "city_bus" if i == 2 else "civilian_car"
		node.setup(kind, "civilian_%d" % i)
		node.interaction_area.collision_layer = 0
		var axis := "H" if i % 4 < 2 else "V"
		var direction := 1 if i % 2 == 0 else -1
		var road: float = ROAD_Z[(i / 4 + 1) % ROAD_Z.size()] if axis == "H" else ROAD_X[(i / 4 + 2) % ROAD_X.size()]
		var coordinate: float = -44 + fposmod(i * 11.3, 82)
		var vehicle := {"id": "civilian_%d" % i, "node": node, "axis": axis, "direction": direction, "road": road, "coordinate": coordinate, "spacing": 5.8 if kind == "city_bus" else FOLLOW_DISTANCE}
		vehicles.append(vehicle)
		cars.append(node)
		place_vehicle(vehicle)

static func phase(axis: String, time: float) -> String:
	var local_time := fposmod(time, CYCLE)
	if local_time < 7:
		return "green" if axis == "H" else "red"
	if local_time < 8.2:
		return "yellow" if axis == "H" else "red"
	if local_time < 9:
		return "red"
	if local_time < 16:
		return "green" if axis == "V" else "red"
	if local_time < 17.2:
		return "yellow" if axis == "V" else "red"
	return "red"

func is_broken(intersection: Dictionary) -> bool:
	return not signal_fixed and is_equal_approx(intersection.x, -14.4) and is_zero_approx(intersection.z)

func update_lights() -> void:
	for intersection: Dictionary in intersections:
		var horizontal := phase("H", clock + intersection.offset)
		var vertical := phase("V", clock + intersection.offset)
		if is_broken(intersection):
			horizontal = "yellow" if fmod(clock, 1.0) < 0.5 else "off"
			vertical = horizontal
		var state := horizontal + ":" + vertical
		if last_states.get(intersection.key) != state:
			intersection.node.set_traffic_state(horizontal, vertical)
			last_states[intersection.key] = state

func find_intersection(x: float, z: float) -> Dictionary:
	for item: Dictionary in intersections:
		if absf(item.x - x) < 0.1 and absf(item.z - z) < 0.1:
			return item
	return {}

func get_problem_signal() -> Node3D:
	return find_intersection(-14.4, 0).node

func step(delta: float) -> void:
	clock += delta
	for key in reservations.keys():
		reservations[key].remaining -= delta
		if reservations[key].remaining <= 0:
			reservations.erase(key)
	update_lights()
	for vehicle: Dictionary in vehicles:
		if not vehicle.node.visible:
			continue
		if vehicle.get("managed", false):
			continue
		var distance := travel_distance(vehicle, delta)
		vehicle.coordinate += distance * vehicle.direction
		var low := -64.0 if vehicle.axis == "H" else -48.0
		var high := 34.0 if vehicle.axis == "H" else 48.0
		if vehicle.coordinate > high:
			vehicle.coordinate = low
		elif vehicle.coordinate < low:
			vehicle.coordinate = high
		place_vehicle(vehicle)

func travel_distance(vehicle: Dictionary, delta: float) -> float:
	var distance := SPEED * delta
	for other: Dictionary in vehicles:
		if other.id == vehicle.id or not other.node.visible or other.axis != vehicle.axis or other.direction != vehicle.direction or other.road != vehicle.road:
			continue
		var gap: float = (other.coordinate - vehicle.coordinate) * vehicle.direction
		if gap > 0 and gap < maxf(vehicle.spacing, other.spacing) + distance:
			distance = maxf(0, gap - maxf(vehicle.spacing, other.spacing))
	var position_value := lane_position(vehicle)
	if service_active:
		var lateral: float = absf(service_position.z - position_value.z) if vehicle.axis == "H" else absf(service_position.x - position_value.x)
		var gap: float = ((service_position.x - position_value.x) if vehicle.axis == "H" else (service_position.z - position_value.z)) * vehicle.direction
		if lateral < 0.9 and gap > 0 and gap < vehicle.spacing + distance:
			distance = maxf(0, gap - vehicle.spacing)
	for intersection: Dictionary in intersections:
		if absf((intersection.z if vehicle.axis == "H" else intersection.x) - vehicle.road) > 0.1:
			continue
		var crossing: float = intersection.x if vehicle.axis == "H" else intersection.z
		var ahead: float = (crossing - vehicle.coordinate) * vehicle.direction
		var stop_distance: float = 5.6 if vehicle.node.type_id == "city_bus" else STOP_DISTANCE
		if ahead < stop_distance - 0.3:
			wait_times.erase(intersection.key + ":" + vehicle.id)
		if ahead >= stop_distance - 0.1 and ahead <= stop_distance + distance + 0.2:
			if not permission(intersection, vehicle.axis, vehicle.id, delta):
				distance = minf(distance, maxf(0, ahead - stop_distance))
	return distance

func permission(intersection: Dictionary, axis: String, actor: String, delta: float) -> bool:
	# Не въезжать в ещё занятый пересекающийся поток, даже после смены фазы.
	for other: Dictionary in vehicles:
		if not other.node.visible or other.id == actor or other.axis == axis:
			continue
		var point := lane_position(other)
		var clearance: float = 4.6 if other.node.type_id == "city_bus" else 3.5
		if absf(point.x - intersection.x) < clearance and absf(point.z - intersection.z) < clearance:
			return false
	if not is_broken(intersection):
		return phase(axis, clock + intersection.offset) == "green"
	var wait_key: String = intersection.key + ":" + actor
	wait_times[wait_key] = float(wait_times.get(wait_key, 0)) + delta
	if wait_times[wait_key] < 0.9:
		return false
	if reservations.has(intersection.key) and reservations[intersection.key].actor != actor:
		return false
	# РЎР»РѕРјР°РЅРЅС‹Р№ СѓР·РµР» РїСЂРѕРїСѓСЃРєР°РµС‚ РјР°С€РёРЅС‹ РїРѕ РѕС‡РµСЂРµРґРё РїРѕСЃР»Рµ РїР°СѓР·С‹.
	reservations[intersection.key] = {"actor": actor, "remaining": 5.0}
	return true

func lane_position(vehicle: Dictionary) -> Vector3:
	if vehicle.axis == "H":
		return Vector3(vehicle.coordinate, 0.18, vehicle.road + vehicle.direction)
	return Vector3(vehicle.road - vehicle.direction, 0.18, vehicle.coordinate)

func place_vehicle(vehicle: Dictionary) -> void:
	vehicle.node.position = lane_position(vehicle)
	vehicle.node.rotation.y = (PI / 2 * vehicle.direction) if vehicle.axis == "H" else (0.0 if vehicle.direction == 1 else PI)

func service_allowed(current: Vector3, target: Vector3, delta: float) -> bool:
	var direction_value := target - current
	if direction_value.length() < 0.01:
		return true
	var axis := "H" if absf(direction_value.x) > absf(direction_value.z) else "V"
	var direction: float = signf(direction_value.x if axis == "H" else direction_value.z)
	for other: Dictionary in vehicles:
		if not other.node.visible or other.axis != axis or other.direction != direction:
			continue
		var road: float = current.z if axis == "H" else current.x
		if absf(road - other.road) > 0.15:
			continue
		var gap: float = (other.coordinate - (current.x if axis == "H" else current.z)) * direction
		if gap > 0 and gap < other.spacing:
			return false
	for intersection: Dictionary in intersections:
		var lateral: float = absf((current.z - intersection.z) if axis == "H" else (current.x - intersection.x))
		if lateral > 0.15:
			continue
		var ahead: float = ((intersection.x - current.x) if axis == "H" else (intersection.z - current.z)) * direction
		if ahead < 3.5:
			wait_times.erase(intersection.key + ":crew_0")
		if ahead >= 3.5 and ahead <= 4.5 and not permission(intersection, axis, "crew_0", delta):
			return false
	return true

func set_active_count(count: int) -> void:
	reservations.clear()
	for i in range(cars.size()):
		cars[i].visible = i < count or vehicles[i].get("managed", false)
