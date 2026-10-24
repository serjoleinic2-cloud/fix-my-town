extends Node3D

const Art = preload("res://scripts/art.gd")
const ObjectScene = preload("res://scenes/objects/game_object.tscn")
const ROAD_X = [-57.6, -43.2, -28.8, -14.4, 0.0, 14.4, 28.8]
const ROAD_Z = [-43.2, -28.8, -14.4, 0.0, 14.4, 28.8, 43.2]
const STOP_LINE_DISTANCE = 3.9
const STOP_GAP = 0.2
const STOP_DISTANCE = 5.35
const SERVICE_STOP_DISTANCE = 5.5
const FOLLOW_DISTANCE = 3.6
const SPEED = 5.2
const CYCLE = 19.0
var cars: Array[Node3D] = []
var vehicles: Array = []
var intersections: Array = []
var clock: float = 0
var signal_fixed: bool = false
var service_position := Vector3(1000, 0, 1000)
var service_active: bool = false
var blocking_positions: Array[Dictionary] = []
var wait_times: Dictionary = {}
var reservations: Dictionary = {}
var last_states: Dictionary = {}
var route_rng := RandomNumberGenerator.new()

func initialize_empty() -> void:
	# Keep routing/traffic APIs available without creating streets, signals or
	# vehicle nodes for a brand-new town.
	route_rng.seed = 48291
	cars.clear()
	vehicles.clear()
	intersections.clear()

func build() -> void:
	route_rng.seed = 48291
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
		var vehicle := {"id": "civilian_%d" % i, "node": node, "axis": axis, "direction": direction, "road": road, "coordinate": coordinate, "spacing": 5.8 if kind == "city_bus" else FOLLOW_DISTANCE,
			"randomized": kind != "city_bus", "speed_factor": route_rng.randf_range(0.86, 1.14), "turn_cooldown": 0.0}
		vehicles.append(vehicle)
		cars.append(node)
		place_vehicle(vehicle)

static func phase(axis: String, time: float) -> String:
	var local_time := fposmod(time, CYCLE)
	if local_time < 7:
		return "green" if axis == "H" else "red"
	if local_time < 8.2:
		return "yellow" if axis == "H" else "red"
	if local_time < 9.5:
		return "red"
	if local_time < 16.5:
		return "green" if axis == "V" else "red"
	if local_time < 17.7:
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
	var problem_intersection := find_intersection(-14.4, 0)
	return problem_intersection.get("node") as Node3D

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
		vehicle.turn_cooldown = maxf(0.0, float(vehicle.get("turn_cooldown", 0.0)) - delta)
		var distance := travel_distance(vehicle, delta)
		vehicle.coordinate += distance * vehicle.direction
		continue_road_loop(vehicle)
		maybe_random_turn(vehicle)
		place_vehicle(vehicle)

func maybe_random_turn(vehicle: Dictionary) -> void:
	if not bool(vehicle.get("randomized", false)) or float(vehicle.get("turn_cooldown", 0.0)) > 0.0:
		return
	# A civilian may choose a new direction at any visible intersection. The
	# choice is deterministic per run, but independent for every vehicle, so
	# cars no longer form a permanent column on the outer ring.
	for intersection: Dictionary in intersections:
		var crossing: float = float(intersection.x if vehicle.axis == "H" else intersection.z)
		if absf(vehicle.coordinate - crossing) > 0.22:
			continue
		var turn_chance := 0.24
		if route_rng.randf() > turn_chance:
			return
		var old_axis: String = str(vehicle.axis)
		var old_road: float = vehicle.road
		vehicle.axis = "V" if old_axis == "H" else "H"
		vehicle.road = intersection.x if vehicle.axis == "V" else intersection.z
		vehicle.coordinate = old_road
		vehicle.direction = 1 if route_rng.randf() >= 0.5 else -1
		vehicle.turn_cooldown = 1.2
		return

func continue_road_loop(vehicle: Dictionary) -> void:
	# Cars stay in the road network and turn at the outer intersections instead
	# of disappearing at an arbitrary screen edge. This forms a continuous
	# ring route around the district while retaining lane direction.
	if vehicle.axis == "H" and vehicle.direction > 0 and vehicle.coordinate >= ROAD_X.back():
		var old_z: float = vehicle.road
		vehicle.axis = "V"
		vehicle.road = ROAD_X.back()
		vehicle.coordinate = old_z
		vehicle.direction = 1
	elif vehicle.axis == "V" and vehicle.direction > 0 and vehicle.coordinate >= ROAD_Z.back():
		var old_x: float = vehicle.road
		vehicle.axis = "H"
		vehicle.road = ROAD_Z.back()
		vehicle.coordinate = old_x
		vehicle.direction = -1
	elif vehicle.axis == "H" and vehicle.direction < 0 and vehicle.coordinate <= ROAD_X.front():
		var old_z: float = vehicle.road
		vehicle.axis = "V"
		vehicle.road = ROAD_X.front()
		vehicle.coordinate = old_z
		vehicle.direction = -1
	elif vehicle.axis == "V" and vehicle.direction < 0 and vehicle.coordinate <= ROAD_Z.front():
		var old_x: float = vehicle.road
		vehicle.axis = "H"
		vehicle.road = ROAD_Z.front()
		vehicle.coordinate = old_x
		vehicle.direction = 1

func travel_distance(vehicle: Dictionary, delta: float) -> float:
	var distance := SPEED * delta * float(vehicle.get("speed_factor", 1.0))
	var current_position := lane_position(vehicle)
	for other: Dictionary in vehicles:
		if other.id == vehicle.id or not other.node.visible:
			continue
		var same_lane: bool = other.axis == vehicle.axis and other.direction == vehicle.direction and is_equal_approx(float(other.road), float(vehicle.road))
		if same_lane:
			var gap: float = (other.coordinate - vehicle.coordinate) * vehicle.direction
			if gap > 0 and gap < maxf(vehicle.spacing, other.spacing) + distance:
				distance = maxf(0, gap - maxf(vehicle.spacing, other.spacing))
			continue
		# Different lanes only interact when both cars are actually approaching
		# the same crossing. A stable id priority prevents mutual deadlock.
		if other.axis == vehicle.axis:
			continue
		var other_position: Vector3 = lane_position(other)
		var proposed_position: Vector3 = current_position + Vector3(vehicle.direction * distance if vehicle.axis == "H" else 0, 0, vehicle.direction * distance if vehicle.axis == "V" else 0)
		if proposed_position.distance_to(other_position) < 2.8 and current_position.distance_to(other_position) < 7.0 and str(other.id) < str(vehicle.id):
			distance = 0.0
	var position_value := lane_position(vehicle)
	var blockers := blocking_positions.duplicate()
	if service_active:
		blockers.append({"id": "primary_service", "position": service_position})
	for blocker: Dictionary in blockers:
		var block_position: Vector3 = blocker.position
		var lateral: float = absf(block_position.z - position_value.z) if vehicle.axis == "H" else absf(block_position.x - position_value.x)
		var gap: float = ((block_position.x - position_value.x) if vehicle.axis == "H" else (block_position.z - position_value.z)) * vehicle.direction
		if lateral < 1.8 and gap > 0 and gap < vehicle.spacing + distance:
			distance = maxf(0, gap - maxf(vehicle.spacing, 3.8))
	for intersection: Dictionary in intersections:
		if absf((intersection.z if vehicle.axis == "H" else intersection.x) - vehicle.road) > 0.1:
			continue
		var crossing: float = intersection.x if vehicle.axis == "H" else intersection.z
		var ahead: float = (crossing - vehicle.coordinate) * vehicle.direction
		var stop_distance: float = stop_distance_for(vehicle.node.type_id)
		if ahead < stop_distance - 0.3:
			wait_times.erase(intersection.key + ":" + vehicle.id)
		if ahead >= stop_distance - 0.1 and ahead <= stop_distance + distance + 0.2:
			if not permission(intersection, vehicle.axis, vehicle.id, delta):
				distance = minf(distance, maxf(0, ahead - stop_distance))
	return distance

func permission(intersection: Dictionary, axis: String, actor: String, delta: float) -> bool:
	if not cross_traffic_clear(intersection, axis, actor):
		return false
	if not is_broken(intersection):
		return phase(axis, clock + intersection.offset) == "green"
	var wait_key: String = intersection.key + ":" + actor
	wait_times[wait_key] = float(wait_times.get(wait_key, 0)) + delta
	if wait_times[wait_key] < 0.9:
		return false
	if reservations.has(intersection.key) and reservations[intersection.key].actor != actor:
		return false
	# Сломанный узел пропускает машины по очереди после паузы.
	reservations[intersection.key] = {"actor": actor, "remaining": 5.0}
	return true

func cross_traffic_clear(intersection: Dictionary, axis: String, actor: String) -> bool:
	# Не въезжать в ещё занятый пересекающийся поток, даже после смены фазы.
	for other: Dictionary in vehicles:
		if not other.node.visible or other.id == actor or other.axis == axis:
			continue
		var point := lane_position(other)
		var clearance: float = 4.6 if other.node.type_id == "city_bus" else 3.5
		if absf(point.x - intersection.x) < clearance and absf(point.z - intersection.z) < clearance:
			return false
	return true

func lane_position(vehicle: Dictionary) -> Vector3:
	if vehicle.axis == "H":
		return Vector3(vehicle.coordinate, 0.18, vehicle.road + vehicle.direction)
	return Vector3(vehicle.road - vehicle.direction, 0.18, vehicle.coordinate)

func place_vehicle(vehicle: Dictionary) -> void:
	vehicle.node.position = lane_position(vehicle)
	vehicle.node.rotation.y = (PI / 2 * vehicle.direction) if vehicle.axis == "H" else (0.0 if vehicle.direction == 1 else PI)

static func stop_distance_for(type_id: String) -> float:
	var front := 2.33 if type_id == "city_bus" else (1.4 if type_id == "repair_van" else 1.25)
	return STOP_LINE_DISTANCE + front + STOP_GAP

func service_allowed(current: Vector3, target: Vector3, delta: float) -> bool:
	return service_travel_distance(current, current.move_toward(target, 20 * delta), delta) > 0.0001

func service_travel_distance(current: Vector3, proposed: Vector3, delta: float, actor_id: String = "crew_0", emergency: bool = false, ignore_incident_id: String = "") -> float:
	var direction_value := proposed - current
	var distance := direction_value.length()
	if distance < 0.0001:
		return 0
	var axis := "H" if absf(direction_value.x) > absf(direction_value.z) else "V"
	var direction: float = signf(direction_value.x if axis == "H" else direction_value.z)
	for other: Dictionary in vehicles:
		if other.id == actor_id or not other.node.visible or other.axis != axis or other.direction != direction:
			continue
		var road: float = current.z if axis == "H" else current.x
		if absf(road - other.road) > 0.15:
			continue
		var gap: float = (other.coordinate - (current.x if axis == "H" else current.z)) * direction
		if gap > 0:
			distance = minf(distance, maxf(0, gap - other.spacing))
	var blockers := blocking_positions.duplicate()
	if service_active:
		blockers.append({"id": "primary_service", "position": service_position})
	for blocker: Dictionary in blockers:
		if ignore_incident_id != "" and str(blocker.get("incident_id", "")) == ignore_incident_id:
			continue
		if str(blocker.get("id", "")) == "primary_service" and actor_id in ["crew_0", "fire_engine_1", "fire_engine_2"]:
			continue
		if str(blocker.get("id", "")) == actor_id:
			continue
		var block_position: Vector3 = blocker.position
		var lateral: float = absf((current.z - block_position.z) if axis == "H" else (current.x - block_position.x))
		var ahead_to_blocker: float = ((block_position.x - current.x) if axis == "H" else (block_position.z - current.z)) * direction
		if lateral < 1.7 and ahead_to_blocker > 0 and ahead_to_blocker < distance + 4.5:
			distance = minf(distance, maxf(0, ahead_to_blocker - 4.5))
	var stop_distance := stop_distance_for("repair_van")
	for intersection: Dictionary in intersections:
		var lateral: float = absf((current.z - intersection.z) if axis == "H" else (current.x - intersection.x))
		if lateral > 0.15:
			continue
		var ahead: float = ((intersection.x - current.x) if axis == "H" else (intersection.z - current.z)) * direction
		if ahead < stop_distance - 0.01:
			wait_times.erase(intersection.key + ":" + actor_id)
		if ahead >= stop_distance - 0.01 and ahead <= stop_distance + distance + 0.01:
			var may_pass := cross_traffic_clear(intersection, axis, actor_id) if emergency else permission(intersection, axis, actor_id, delta)
			if not may_pass:
				distance = minf(distance, maxf(0, ahead - stop_distance))
	return distance

func set_active_count(count: int) -> void:
	reservations.clear()
	for i in range(cars.size()):
		cars[i].visible = i < count or vehicles[i].get("managed", false)
