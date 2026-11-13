extends Node3D

const Art = preload("res://scripts/art.gd")
const ObjectScene = preload("res://scenes/objects/game_object.tscn")
const TerritoryGrid = preload("res://scripts/territory_grid.gd")
const ROAD_X = [-57.6, -43.2, -28.8, -14.4, 0.0, 14.4, 28.8]
const ROAD_Z = [-43.2, -28.8, -14.4, 0.0, 14.4, 28.8, 43.2]
const STOP_LINE_DISTANCE = 3.9
const STOP_GAP = 0.2
const STOP_DISTANCE = 5.35
const SERVICE_STOP_DISTANCE = 5.5
const FOLLOW_DISTANCE = 3.6
const EXTERNAL_QUEUE_GAP = 0.55
const SERVICE_VEHICLE_SIZES = {
	"repair_van": Vector2(1.8, 3.0),
	"fire_engine": Vector2(2.2, 4.2),
	"police_car": Vector2(1.8, 3.0),
	"ambulance": Vector2(2.0, 3.0)
}
const SPEED = 5.2
const CYCLE = 19.0
const GRID_LANE_OFFSET = 0.76
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
var deadlock_cycles: Dictionary = {}
var deadlock_reroutes: Dictionary = {}
var recovery_vehicle_id := ""
var route_rng := RandomNumberGenerator.new()
var grid: RefCounted
var grid_roads: Array[Vector2i] = []
var grid_signature := ""

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
		node.visual_root.scale = Vector3.ONE * 0.70
		var axis := "H" if i % 4 < 2 else "V"
		var direction := 1 if i % 2 == 0 else -1
		var road: float = ROAD_Z[(i / 4 + 1) % ROAD_Z.size()] if axis == "H" else ROAD_X[(i / 4 + 2) % ROAD_X.size()]
		var coordinate: float = -44 + fposmod(i * 11.3, 82)
		var vehicle := {"id": "civilian_%d" % i, "node": node, "axis": axis, "direction": direction, "road": road, "coordinate": coordinate, "spacing": 5.8 if kind == "city_bus" else FOLLOW_DISTANCE,
			"randomized": kind != "city_bus", "speed_factor": route_rng.randf_range(0.72, 1.28), "turn_cooldown": 0.0}
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
	if grid != null:
		return false
	return not signal_fixed and is_equal_approx(intersection.x, -14.4) and is_zero_approx(intersection.z)

func update_lights() -> void:
	for intersection: Dictionary in intersections:
		if intersection.get("unsignalized", false) or intersection.get("node") == null:
			continue
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
		var reservation: Dictionary = reservations[key]
		reservation.remaining = float(reservation.get("remaining", 0.0)) - delta
		if reservation.get("grid_lock", false) and reservation.get("entered", false):
			continue
		if reservation.remaining <= 0:
			reservations.erase(key)
	update_lights()
	if grid != null:
		step_grid(delta)
		return
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
	vehicle.waiting_reason = ""
	vehicle.waiting_on = ""
	for other: Dictionary in vehicles:
		if other.id == vehicle.id or not other.node.visible:
			continue
		if vehicle.get("recovery_mode", false):
			continue
		var same_lane: bool = other.axis == vehicle.axis and other.direction == vehicle.direction and is_equal_approx(float(other.road), float(vehicle.road))
		if same_lane:
			var gap: float = (other.coordinate - vehicle.coordinate) * vehicle.direction
			if gap > 0 and gap < maxf(vehicle.spacing, other.spacing) + distance:
				distance = maxf(0, gap - maxf(vehicle.spacing, other.spacing))
				if distance <= 0.001:
					vehicle.waiting_reason = "queue"
					vehicle.waiting_on = str(other.id)
			continue
		# Different lanes only interact when both cars are actually approaching
		# the same crossing. A stable id priority prevents mutual deadlock.
		if other.axis == vehicle.axis:
			continue
		var other_position: Vector3 = lane_position(other)
		var proposed_position: Vector3 = current_position + Vector3(vehicle.direction * distance if vehicle.axis == "H" else 0, 0, vehicle.direction * distance if vehicle.axis == "V" else 0)
		if proposed_position.distance_to(other_position) < 2.8 and current_position.distance_to(other_position) < 7.0 and str(other.id) < str(vehicle.id):
			distance = 0.0
			vehicle.waiting_reason = "yield"
			vehicle.waiting_on = str(other.id)
	var position_value := lane_position(vehicle)
	var blockers := blocking_positions.duplicate()
	if service_active:
		blockers.append({"id": "primary_service", "position": service_position})
	for blocker: Dictionary in blockers:
		var block_position: Vector3 = blocker.position
		if blocker.get("moving_vehicle", false):
			if vehicle.get("recovery_mode", false):
				continue
			var own_half := grid_half_extents(vehicle)
			var block_half: Vector2 = blocker.get("half_extents", Vector2(0.7, 0.7))
			var blocker_axis := str(blocker.get("axis", ""))
			var blocker_direction := int(blocker.get("direction", 0))
			var blocker_id := str(blocker.get("id", ""))
			if blocker_axis == vehicle.axis and blocker_direction == int(vehicle.direction):
				# Moving trucks are queue leaders: stop by their full body length,
				# not at the point where a collision box is already touching.
				var lateral: float = absf(block_position.z - position_value.z) if vehicle.axis == "H" else absf(block_position.x - position_value.x)
				var lateral_extent: float = own_half.y + block_half.y if vehicle.axis == "H" else own_half.x + block_half.x
				var gap: float = ((block_position.x - position_value.x) if vehicle.axis == "H" else (block_position.z - position_value.z)) * float(vehicle.direction)
				if lateral < lateral_extent + 0.12 and gap > 0.0:
					var clearance := (own_half.x + block_half.x if vehicle.axis == "H" else own_half.y + block_half.y) + EXTERNAL_QUEUE_GAP
					distance = minf(distance, maxf(0.0, gap - clearance))
					if distance <= 0.001:
						vehicle.waiting_reason = "queue"
						vehicle.waiting_on = blocker_id
					continue
			var proposed_position := position_value + Vector3(vehicle.direction * distance if vehicle.axis == "H" else 0.0, 0, vehicle.direction * distance if vehicle.axis == "V" else 0.0)
			if absf(proposed_position.x - block_position.x) < own_half.x + block_half.x + 0.12 and absf(proposed_position.z - block_position.z) < own_half.y + block_half.y + 0.12:
				distance = 0.0
				vehicle.waiting_reason = "moving_vehicle"
				vehicle.waiting_on = blocker_id
			continue
		var lateral: float = absf(block_position.z - position_value.z) if vehicle.axis == "H" else absf(block_position.x - position_value.x)
		var gap: float = ((block_position.x - position_value.x) if vehicle.axis == "H" else (block_position.z - position_value.z)) * vehicle.direction
		if lateral < 1.8 and gap > 0 and gap < vehicle.spacing + distance:
			distance = maxf(0, gap - maxf(vehicle.spacing, 3.8))
			if distance <= 0.001:
				vehicle.waiting_reason = "static_blocker"
				vehicle.waiting_on = str(blocker.get("id", ""))
	for intersection: Dictionary in intersections:
		if absf((intersection.z if vehicle.axis == "H" else intersection.x) - vehicle.road) > 0.1:
			continue
		var crossing: float = intersection.x if vehicle.axis == "H" else intersection.z
		var ahead: float = (crossing - vehicle.coordinate) * vehicle.direction
		var reservation: Dictionary = reservations.get(intersection.key, {})
		if ahead < -1.5 and str(reservation.get("actor", "")) == str(vehicle.id) and not reservation.get("grid_lock", false):
			reservations.erase(intersection.key)
		var stop_distance: float = stop_distance_for(vehicle.node.type_id, grid != null)
		if ahead < stop_distance - 0.3:
			wait_times.erase(intersection.key + ":" + vehicle.id)
		if ahead >= stop_distance - 0.1 and ahead <= stop_distance + distance + 0.2:
			if not permission(intersection, vehicle.axis, vehicle.id, delta, int(vehicle.direction)):
				distance = minf(distance, maxf(0, ahead - stop_distance))
				if distance <= 0.001:
					vehicle.waiting_reason = "signal"
	if grid != null:
		var proposed := current_position + Vector3(vehicle.direction * distance if vehicle.axis == "H" else 0.0, 0, vehicle.direction * distance if vehicle.axis == "V" else 0.0)
		distance = grid_safe_distance(vehicle, current_position, proposed)
	return distance

func reserve_intersection(intersection: Dictionary, actor: String, axis: String = "", direction: int = 0, external_half_extents: Vector2 = Vector2.ZERO) -> void:
	var reservation := {"actor": actor, "remaining": 2.5, "approach_axis": axis, "direction": direction}
	var grid_vehicle: Dictionary = {}
	for vehicle: Dictionary in vehicles:
		if str(vehicle.get("id", "")) == actor:
			grid_vehicle = vehicle
			break
	if grid != null and not grid_vehicle.is_empty():
		# Reserve the entire conflict point conservatively across every approach
		# and turn. Store the manoeuvre and vehicle footprint so the lock remains
		# held until the rear, not just the center, clears the intersection.
		var half_extents := grid_half_extents(grid_vehicle)
		var exit_cell: Vector2i = grid_vehicle.get("waiting_next", grid_vehicle.get("turn_exit_cell", Vector2i(-1, -1)))
		var manoeuvre := "turn" if exit_cell != Vector2i(-1, -1) and grid_vehicle.get("cell", exit_cell) != exit_cell else "through"
		reservation = {"actor": actor, "remaining": 8.0, "grid_lock": true, "entered": false, "x": float(intersection.x), "z": float(intersection.z), "approach_axis": axis, "direction": direction, "manoeuvre": manoeuvre, "exit_cell": exit_cell, "half_extents": half_extents, "clearance_radius": half_extents.x + half_extents.y + 0.3}
	elif external_half_extents.length_squared() > 0.001:
		# Logistics trucks are external route actors rather than grid vehicles, but
		# they still own the whole conflict area until their rear clears it.
		reservation = {"actor": actor, "remaining": 8.0, "grid_lock": true, "entered": false, "x": float(intersection.x), "z": float(intersection.z), "approach_axis": axis, "direction": direction, "manoeuvre": "external_turn", "half_extents": external_half_extents, "clearance_radius": external_half_extents.x + external_half_extents.y + 0.7}
	reservations[intersection.key] = reservation

func release_grid_reservations_for_vehicle(vehicle: Dictionary) -> void:
	var position_value: Vector3 = vehicle.node.position
	for key in reservations.keys():
		var reservation: Dictionary = reservations[key]
		if not reservation.get("grid_lock", false) or str(reservation.get("actor", "")) != str(vehicle.id):
			continue
		var distance := Vector2(position_value.x - float(reservation.x), position_value.z - float(reservation.z)).length()
		var clearance_radius := float(reservation.get("clearance_radius", 3.0))
		if distance <= clearance_radius:
			reservation.entered = true
		elif reservation.get("entered", false):
			reservations.erase(key)

func release_external_reservations_for_vehicle(actor: String, position_value: Vector3) -> void:
	for key in reservations.keys():
		var reservation: Dictionary = reservations[key]
		if not reservation.get("grid_lock", false) or str(reservation.get("actor", "")) != actor:
			continue
		var distance := Vector2(position_value.x - float(reservation.x), position_value.z - float(reservation.z)).length()
		var clearance_radius := float(reservation.get("clearance_radius", 2.0))
		if distance <= clearance_radius:
			reservation.entered = true
		elif reservation.get("entered", false):
			reservations.erase(key)

func clear_external_vehicle_state(actor_prefix: String) -> void:
	var had_external_wait := false
	for key in reservations.keys():
		if str(reservations[key].get("actor", "")).begins_with(actor_prefix):
			reservations.erase(key)
	for key in wait_times.keys():
		var parts := str(key).split(":")
		if not parts.is_empty() and str(parts[parts.size() - 1]).begins_with(actor_prefix):
			wait_times.erase(key)
	for vehicle: Dictionary in vehicles:
		if str(vehicle.get("waiting_on", "")).begins_with(actor_prefix):
			had_external_wait = true
			vehicle.erase("waiting_on")
			vehicle.erase("waiting_reason")
			vehicle.stalled_time = 0.0
	if had_external_wait:
		# The recorded wait-for cycle may have depended on a truck that was just
		# recreated after the city changed. Re-evaluate it from fresh positions.
		deadlock_cycles.clear()
		deadlock_reroutes.clear()

func permission(intersection: Dictionary, axis: String, actor: String, delta: float, direction: int = 0, external_half_extents: Vector2 = Vector2.ZERO, emergency_priority: bool = false) -> bool:
	var reservation: Dictionary = reservations.get(intersection.key, {})
	if not reservation.is_empty() and str(reservation.get("actor", "")) == actor:
		# Once a vehicle has entered the junction, it owns the right of way until
		# its rear clears. Yielding again to a queue at the stop line can deadlock
		# two approaches nose-to-nose inside the junction.
		if reservation.get("grid_lock", false) and reservation.get("entered", false):
			return true
		if cross_traffic_clear(intersection, axis, actor, external_half_extents):
			return true
		return false
	if not cross_traffic_clear(intersection, axis, actor, external_half_extents):
		return false
	if not reservation.is_empty():
		return false
	if intersection.get("unsignalized", false):
		if not emergency_priority and not unsignalized_right_of_way_clear(intersection, axis, direction, actor):
			var wait_key: String = str(intersection.key) + ":" + actor
			wait_times[wait_key] = float(wait_times.get(wait_key, 0.0)) + delta
			return false
		reserve_intersection(intersection, actor, axis, direction, external_half_extents)
		return true
	if emergency_priority:
		# Emergency calls bypass the signal phase only after the conflict area is
		# clear and this vehicle has acquired the same exclusive reservation as
		# ordinary traffic. This makes approaching cars stop at their own stop line.
		reserve_intersection(intersection, actor, axis, direction, external_half_extents)
		wait_times.erase(str(intersection.key) + ":" + actor)
		return true
	if not is_broken(intersection):
		if phase(axis, clock + intersection.offset) != "green":
			return false
		wait_times.erase(intersection.key + ":" + actor)
		reserve_intersection(intersection, actor, axis, direction, external_half_extents)
		return true
	var wait_key: String = intersection.key + ":" + actor
	wait_times[wait_key] = float(wait_times.get(wait_key, 0)) + delta
	if wait_times[wait_key] < 0.9:
		return false
	# Сломанный узел пропускает машины по очереди после паузы.
	reserve_intersection(intersection, actor, axis, direction, external_half_extents)
	return true

func unsignalized_right_of_way_clear(intersection: Dictionary, axis: String, direction: int, actor: String) -> bool:
	if direction == 0:
		return true
	var velocity := Vector2(direction, 0) if axis == "H" else Vector2(0, direction)
	var right_of_actor := Vector2(-velocity.y, velocity.x)
	var junction := Vector2(float(intersection.x), float(intersection.z))
	for other: Dictionary in vehicles:
		if not other.node.visible or str(other.id) == actor or str(other.axis) == axis:
			continue
		if approach_is_from_right(junction, right_of_actor, lane_position(other), str(other.axis), int(other.direction)):
			return false
	for blocker: Dictionary in blocking_positions:
		if not blocker.get("moving_vehicle", false) or str(blocker.get("id", "")) == actor:
			continue
		var blocker_axis := str(blocker.get("axis", ""))
		if blocker_axis == "" or blocker_axis == axis:
			continue
		var blocker_direction := int(blocker.get("direction", 0))
		if approach_is_from_right(junction, right_of_actor, blocker.get("position", Vector3.ZERO), blocker_axis, blocker_direction):
			return false
	return true

func approach_is_from_right(junction: Vector2, right_of_actor: Vector2, position_value: Vector3, axis: String, direction: int) -> bool:
	if direction == 0:
		return false
	var offset := Vector2(position_value.x, position_value.z) - junction
	if offset.length() > 7.0:
		return false
	var other_velocity := Vector2(direction, 0) if axis == "H" else Vector2(0, direction)
	if other_velocity.dot(-offset) <= 0.0:
		return false
	# At an uncontrolled conflict, yield to a vehicle approaching from the
	# right. Signal-controlled junctions use their light phase instead.
	return offset.dot(right_of_actor) > 0.0

func cross_traffic_clear(intersection: Dictionary, axis: String, actor: String, supplied_half_extents: Vector2 = Vector2.ZERO) -> bool:
	# Не въезжать в ещё занятый пересекающийся поток, даже после смены фазы.
	var actor_vehicle: Dictionary = {}
	for vehicle: Dictionary in vehicles:
		if str(vehicle.get("id", "")) == actor:
			actor_vehicle = vehicle
			break
	var actor_half := grid_half_extents(actor_vehicle) if grid != null and not actor_vehicle.is_empty() else supplied_half_extents
	if actor_half.length_squared() <= 0.001:
		actor_half = Vector2(1.1, 0.75)
	for other: Dictionary in vehicles:
		if not other.node.visible or other.id == actor or other.axis == axis:
			continue
		var point: Vector3 = lane_position(other)
		var other_half := grid_half_extents(other) if grid != null else Vector2(2.3, 2.3)
		var clearance := actor_half + other_half + Vector2(0.12, 0.12)
		# Only a vehicle physically inside the conflict area blocks entry. The
		# previous fixed 3.5–4.6 m square included cars waiting at their stop lines,
		# so a continuous queue could hold a managed bus at the junction forever.
		if absf(point.x - intersection.x) < clearance.x and absf(point.z - intersection.z) < clearance.y:
			return false
	for blocker: Dictionary in blocking_positions:
		if not blocker.get("moving_vehicle", false) or str(blocker.get("id", "")) == actor:
			continue
		if str(blocker.get("axis", "")) == axis:
			continue
		var point: Vector3 = blocker.get("position", Vector3.ZERO)
		var other_half: Vector2 = blocker.get("half_extents", Vector2(0.8, 1.4))
		var clearance := actor_half + other_half + Vector2(0.12, 0.12)
		if absf(point.x - intersection.x) < clearance.x and absf(point.z - intersection.z) < clearance.y:
			return false
	return true

func lane_position(vehicle: Dictionary) -> Vector3:
	if grid != null:
		return vehicle.node.position
	if vehicle.axis == "H":
		return Vector3(vehicle.coordinate, 0.18, vehicle.road + vehicle.direction)
	return Vector3(vehicle.road - vehicle.direction, 0.18, vehicle.coordinate)

static func grid_lane_offset(axis: String, direction: int) -> Vector3:
	# Keep the whole vehicle body on its side of the longitudinal centre dash.
	# Positive-X traffic uses the +Z lane; positive-Z traffic uses the -X lane.
	return Vector3(0, 0.22, float(direction) * GRID_LANE_OFFSET) if axis == "H" else Vector3(-float(direction) * GRID_LANE_OFFSET, 0.22, 0)

static func grid_lane_position(center: Vector3, axis: String, direction: int) -> Vector3:
	return center + grid_lane_offset(axis, direction)

func grid_spawn_heading(source: RefCounted, cell: Vector2i, preferred_axis: String, preferred_direction: int) -> Dictionary:
	var horizontal: Array[int] = []
	var vertical: Array[int] = []
	if source.state_at(cell.x - 1, cell.y) == "road": horizontal.append(-1)
	if source.state_at(cell.x + 1, cell.y) == "road": horizontal.append(1)
	if source.state_at(cell.x, cell.y - 1) == "road": vertical.append(-1)
	if source.state_at(cell.x, cell.y + 1) == "road": vertical.append(1)
	var axis := preferred_axis
	if axis == "H" and horizontal.is_empty(): axis = "V"
	if axis == "V" and vertical.is_empty(): axis = "H"
	var directions: Array[int] = horizontal if axis == "H" else vertical
	if directions.is_empty():
		return {"axis": "H", "direction": 1}
	var direction := preferred_direction if preferred_direction in directions else directions[0]
	return {"axis": axis, "direction": direction}

func place_vehicle(vehicle: Dictionary) -> void:
	if grid != null and vehicle.get("managed", false):
		vehicle.node.position = grid_lane_position(Vector3(vehicle.coordinate, 0, vehicle.road) if vehicle.axis == "H" else Vector3(vehicle.road, 0, vehicle.coordinate), str(vehicle.axis), int(vehicle.direction))
	else:
		vehicle.node.position = lane_position(vehicle)
	vehicle.node.rotation.y = (PI / 2 * vehicle.direction) if vehicle.axis == "H" else (0.0 if vehicle.direction == 1 else PI)

static func stop_distance_for(type_id: String, grid_markings: bool = false) -> float:
	var front := 2.33 if type_id == "city_bus" else (1.02 if type_id == "delivery_truck" else (service_vehicle_size(type_id).y * 0.5 if type_id in SERVICE_VEHICLE_SIZES else 1.25))
	var gap := 0.35 if type_id == "delivery_truck" else STOP_GAP
	# New 2x2-growth streets draw the stop line 2.3 m from junction center.
	# The legacy road layout retains its original 3.9 m marking offset.
	var line_offset := 2.3 if grid_markings else STOP_LINE_DISTANCE
	return line_offset + front + gap

func service_allowed(current: Vector3, target: Vector3, delta: float) -> bool:
	return service_travel_distance(current, current.move_toward(target, 20 * delta), delta) > 0.0001

static func service_vehicle_size(vehicle_type: String) -> Vector2:
	return SERVICE_VEHICLE_SIZES.get(vehicle_type, SERVICE_VEHICLE_SIZES.repair_van)

static func service_half_extents(vehicle_type: String, axis: String) -> Vector2:
	var size := service_vehicle_size(vehicle_type)
	return Vector2(size.y * 0.5, size.x * 0.5) if axis == "H" else Vector2(size.x * 0.5, size.y * 0.5)

func service_travel_distance(current: Vector3, proposed: Vector3, delta: float, actor_id: String = "crew_0", emergency: bool = false, ignore_incident_id: String = "", vehicle_type: String = "repair_van") -> float:
	release_external_reservations_for_vehicle(actor_id, current)
	var direction_value := proposed - current
	var distance := direction_value.length()
	if distance < 0.0001:
		return 0
	var axis := "H" if absf(direction_value.x) > absf(direction_value.z) else "V"
	var direction: float = signf(direction_value.x if axis == "H" else direction_value.z)
	var priority_response := emergency and vehicle_type in ["fire_engine", "police_car", "ambulance"]
	for other: Dictionary in vehicles:
		if other.id == actor_id or not other.node.visible or other.axis != axis or other.direction != direction:
			continue
		# With lights and siren active, civilian traffic yields. The emergency
		# vehicle may pass a same-direction queue, while intersection occupancy and
		# other service vehicles remain protected by reservations/blockers below.
		if priority_response:
			continue
		var road: float = current.z if axis == "H" else current.x
		var other_road: float = float(other.road)
		var road_tolerance := 0.15
		if vehicle_type == "delivery_truck":
			# Delivery trucks are rendered inside the lane, while traffic records
			# the lane centre. Compare the actual lane for legacy streets and
			# normalized road centres for the cell grid.
			if grid != null:
				road += direction * GRID_LANE_OFFSET if axis == "V" else -direction * GRID_LANE_OFFSET
			else:
				other_road += float(other.direction) if axis == "H" else -float(other.direction)
				road_tolerance = 0.4
		if absf(road - other_road) > road_tolerance:
			continue
		var gap: float = (other.coordinate - (current.x if axis == "H" else current.z)) * direction
		if gap > 0:
			distance = minf(distance, maxf(0, gap - other.spacing))
	var blockers := blocking_positions.duplicate()
	if service_active:
		blockers.append({"id": "primary_service", "position": service_position})
	for blocker: Dictionary in blockers:
		var block_position: Vector3 = blocker.position
		# A lights-and-siren response may pass an ordinary moving queue in its
		# lane. Cross traffic inside a junction remains protected by
		# cross_traffic_clear() and the exclusive reservation below.
		if priority_response and blocker.get("moving_vehicle", false) and not blocker.get("emergency", false):
			continue
		if vehicle_type == "delivery_truck" and blocker.get("moving_vehicle", false):
			# A same-lane moving vehicle is a queue leader, with a clearance based
			# on both body lengths. Cross-lane/crossing conflicts remain the
			# oriented-footprint check in external_vehicle_step_is_clear().
			var block_axis := str(blocker.get("axis", ""))
			var block_direction := int(blocker.get("direction", 0))
			if block_axis == axis and block_direction == int(direction):
				var block_half: Vector2 = blocker.get("half_extents", Vector2(0.7, 0.7))
				var block_lateral := absf(block_position.z - current.z) if axis == "H" else absf(block_position.x - current.x)
				var own_half := Vector2(1.13, 0.60) if axis == "H" else Vector2(0.60, 1.13)
				var block_lateral_extent := own_half.y + block_half.y if axis == "H" else own_half.x + block_half.x
				var gap_to_blocker := ((block_position.x - current.x) if axis == "H" else (block_position.z - current.z)) * direction
				if block_lateral < block_lateral_extent + 0.12 and gap_to_blocker > 0.0:
					var block_longitudinal := block_half.x if axis == "H" else block_half.y
					distance = minf(distance, maxf(0.0, gap_to_blocker - 1.13 - block_longitudinal - EXTERNAL_QUEUE_GAP))
			continue
		if ignore_incident_id != "" and str(blocker.get("incident_id", "")) == ignore_incident_id:
			continue
		if str(blocker.get("id", "")) == "primary_service" and actor_id in ["crew_0", "fire_engine_1", "fire_engine_2"]:
			continue
		if str(blocker.get("id", "")) == actor_id:
			continue
		var lateral: float = absf((current.z - block_position.z) if axis == "H" else (current.x - block_position.x))
		var ahead_to_blocker: float = ((block_position.x - current.x) if axis == "H" else (block_position.z - current.z)) * direction
		if lateral < 1.7 and ahead_to_blocker > 0 and ahead_to_blocker < distance + 4.5:
			distance = minf(distance, maxf(0, ahead_to_blocker - 4.5))
	var stop_distance := stop_distance_for(vehicle_type, grid != null)
	for intersection: Dictionary in intersections:
		var lateral: float = absf((current.z - intersection.z) if axis == "H" else (current.x - intersection.x))
		if lateral > (0.9 if grid != null or vehicle_type == "delivery_truck" else 0.15):
			continue
		var ahead: float = ((intersection.x - current.x) if axis == "H" else (intersection.z - current.z)) * direction
		var reservation: Dictionary = reservations.get(intersection.key, {})
		if ahead < -1.5 and str(reservation.get("actor", "")) == actor_id and not reservation.get("grid_lock", false):
			reservations.erase(intersection.key)
		if ahead < stop_distance - 0.01:
			wait_times.erase(intersection.key + ":" + actor_id)
		if ahead >= stop_distance - 0.01 and ahead <= stop_distance + distance + 0.01:
			var external_footprint := service_half_extents(vehicle_type, axis) if vehicle_type in SERVICE_VEHICLE_SIZES else (Vector2(1.13, 0.60) if axis == "H" else Vector2(0.60, 1.13)) if vehicle_type == "delivery_truck" else Vector2.ZERO
			var has_priority := emergency and vehicle_type in ["fire_engine", "police_car", "ambulance"]
			var may_pass := permission(intersection, axis, actor_id, delta, int(direction), external_footprint, has_priority)
			if not may_pass:
				distance = minf(distance, maxf(0, ahead - stop_distance))
	return distance

func set_active_count(count: int) -> void:
	reservations.clear()
	for i in range(cars.size()):
		cars[i].visible = i < count or vehicles[i].get("managed", false)

func configure_grid(source: RefCounted, desired: int, bus_active: bool, signal_nodes: Array) -> void:
	grid = source
	intersections.clear()
	for node: Node3D in signal_nodes:
		intersections.append({"key": str(node.name), "x": node.position.x, "z": node.position.z, "offset": float(node.get_meta("signal_offset", 0.0)), "node": node})
	var roads: Array[Vector2i] = []
	for row in range(source.HEIGHT):
		for col in range(source.WIDTH):
			if source.state_at(col, row) == "road":
				roads.append(Vector2i(col, row))
	var signal_positions: Array[Vector2i] = []
	for signal_data: Dictionary in intersections:
		var signal_cell := Vector2i(
			int(round((signal_data.x - source.ORIGIN.x) / source.CELL_SIZE)),
			int(round((signal_data.z - source.ORIGIN.z) / source.CELL_SIZE))
		)
		signal_positions.append(signal_cell)
	# Corner bends are conflict points too. Add virtual (unlit) intersections so
	# No cars on the empty foundation: do not publish virtual traffic nodes.
	if desired > 0 or bus_active:
		# opposing cars reserve the same narrow turn space instead of meeting nose-to-nose.
		for road_cell: Vector2i in roads:
			var links: Array[Vector2i] = []
			for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if source.state_at(road_cell.x + direction.x, road_cell.y + direction.y) == "road":
					links.append(direction)
			if links.size() != 2:
				continue
			var has_horizontal := links.any(func(item: Vector2i) -> bool: return item.y == 0)
			var has_vertical := links.any(func(item: Vector2i) -> bool: return item.x == 0)
			if not has_horizontal or not has_vertical or road_cell in signal_positions:
				continue
			var corner_world: Vector3 = source.cell_world(road_cell.x, road_cell.y)
			intersections.append({"key": "grid_corner_%d_%d" % [road_cell.x, road_cell.y], "x": corner_world.x, "z": corner_world.z, "offset": 0.0, "node": null, "unsignalized": true})
	var signature := str(roads)
	var changed := signature != grid_signature
	grid_signature = signature
	grid_roads = roads
	if changed:
		# Reservations and wait-for edges belong to a particular road graph.
		reservations.clear()
		wait_times.clear()
		last_states.clear()
		deadlock_cycles.clear()
		deadlock_reroutes.clear()
		recovery_vehicle_id = ""
		for vehicle: Dictionary in vehicles:
			vehicle.erase("waiting_next")
			vehicle.erase("turn_exit_cell")
			vehicle.erase("waiting_on")
			vehicle.erase("waiting_reason")
			vehicle.erase("stalled_time")
			vehicle.erase("recovery_mode")
			vehicle.erase("recovery_remaining")
	if roads.is_empty() or (desired <= 0 and not bus_active):
		for car in cars:
			remove_child(car)
			car.queue_free()
		cars.clear()
		vehicles.clear()
		return
	if vehicles.is_empty():
		for index in range(9):
			var node := ObjectScene.instantiate()
			node.name = "grid_vehicle_%d" % index
			add_child(node)
			node.setup("city_bus" if index == 2 else "civilian_car", "grid_vehicle_%d" % index)
			node.interaction_area.collision_layer = 0
			node.visual_root.scale = Vector3.ONE * 0.70
			vehicles.append({"id": "grid_vehicle_%d" % index, "node": node, "axis": "H", "direction": 1, "road": 0.0, "coordinate": 0.0, "spacing": 5.8 if index == 2 else 3.6, "speed_factor": route_rng.randf_range(0.72, 1.28), "managed": index == 2})
			cars.append(node)
	var enabled := 0
	var limit := mini(desired, maxi(1, roads.size() / 6))
	for index in range(vehicles.size()):
		var vehicle: Dictionary = vehicles[index]
		if index == 2:
			vehicle.node.visible = bus_active
			continue
		var active := enabled < limit
		if active and (changed or not vehicle.node.visible or not vehicle.has("cell")):
			# Spread cars across all roads; taking every sixth row-major cell clustered them in one corner.
			var road_index := int(floor((float(enabled) + 0.5) * float(roads.size()) / float(maxi(1, limit))))
			var cell := roads[mini(road_index, roads.size() - 1)]
			var spawn_axis := "H" if enabled % 2 == 0 else "V"
			var spawn_direction := 1 if enabled % 4 < 2 else -1
			var heading := grid_spawn_heading(source, cell, spawn_axis, spawn_direction)
			vehicle.axis = str(heading.axis)
			vehicle.direction = int(heading.direction)
			vehicle.cell = cell
			vehicle.previous = Vector2i(-1, -1)
			vehicle.erase("waiting_next")
			vehicle.erase("turn_exit_cell")
			vehicle.road = grid.cell_world(cell.x, cell.y).z if vehicle.axis == "H" else grid.cell_world(cell.x, cell.y).x
			vehicle.coordinate = grid.cell_world(cell.x, cell.y).x if vehicle.axis == "H" else grid.cell_world(cell.x, cell.y).z
			vehicle.target = grid_lane_position(grid.cell_world(cell.x, cell.y), vehicle.axis, vehicle.direction)
			vehicle.node.position = vehicle.target
		vehicle.node.visible = active
		enabled += 1

func step_grid(delta: float) -> void:
	for vehicle: Dictionary in vehicles:
		if not vehicle.node.visible or vehicle.get("managed", false):
			continue
		var current: Vector3 = vehicle.node.position
		var target: Vector3 = vehicle.target
		var last_position: Vector3 = vehicle.get("last_position", current)
		var stalled_time: float = float(vehicle.get("stalled_time", 0.0))
		if current.distance_to(last_position) < 0.02:
			stalled_time += delta
		else:
			stalled_time = 0.0
		vehicle.last_position = current
		vehicle.stalled_time = stalled_time
		# Red-light waits, dead-end roads and queues do not trigger recovery by
		# elapsed time alone. _update_deadlock_recovery() requires a stalled cycle.
		if current.distance_to(target) < 0.08:
			if vehicle.has("turn_exit_cell"):
				var exit_cell: Vector2i = vehicle.turn_exit_cell
				vehicle.cell = exit_cell
				vehicle.erase("turn_exit_cell")
				var exit_center: Vector3 = grid.cell_world(exit_cell.x, exit_cell.y)
				vehicle.target = grid_lane_position(exit_center, str(vehicle.axis), int(vehicle.direction))
				target = vehicle.target
			else:
				var options: Array[Vector2i] = []
				for neighbour: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var candidate: Vector2i = vehicle.cell + neighbour
					if grid.state_at(candidate.x, candidate.y) == "road":
						options.append(candidate)
				if options.size() > 1:
					options.erase(vehicle.previous)
				if options.is_empty():
					vehicle.waiting_reason = "no_road_exit"
					vehicle.waiting_on = ""
					continue
				var forward := Vector2i(int(vehicle.direction), 0) if str(vehicle.axis) == "H" else Vector2i(0, int(vehicle.direction))
				var forward_cell: Vector2i = vehicle.cell + forward
				var next: Vector2i
				if vehicle.has("waiting_next"):
					next = vehicle["waiting_next"]
				else:
					next = options[route_rng.randi_range(0, options.size() - 1)]
					if forward_cell in options and options.size() > 1 and route_rng.randf() < 0.86:
						next = forward_cell
				var next_center: Vector3 = grid.cell_world(next.x, next.y)
				var crossing := find_intersection(next_center.x, next_center.z)
				var incoming_axis := "H" if next.x != vehicle.cell.x else "V"
				var crossing_direction: int = next.x - vehicle.cell.x if next.x != vehicle.cell.x else next.y - vehicle.cell.y
				if not crossing.is_empty() and not permission(crossing, incoming_axis, str(vehicle.id), delta, crossing_direction):
					vehicle.waiting_next = next
					vehicle.waiting_reason = "signal"
					vehicle.waiting_on = ""
					var current_center: Vector3 = grid.cell_world(vehicle.cell.x, vehicle.cell.y)
					var lane_shift := grid_lane_offset(str(vehicle.axis), int(vehicle.direction))
					vehicle.target = current_center + lane_shift + Vector3(float(forward.x), 0, float(forward.y)) * (TerritoryGrid.CELL_SIZE * 0.5 - 1.45)
					continue
				vehicle.erase("waiting_next")
				var offset: Vector2i = next - vehicle.cell
				var next_axis := "H" if offset.x != 0 else "V"
				var next_direction := offset.x if offset.x != 0 else offset.y
				if next_axis != str(vehicle.axis):
					# Turn within the junction footprint: leave the incoming lane, pass
					# through the unmarked centre, then join the outgoing lane before
					# leaving the junction. Never interpolate diagonally across a road.
					vehicle.previous = vehicle.cell
					vehicle.turn_exit_cell = next
					vehicle.axis = next_axis
					vehicle.direction = next_direction
					var turn_center: Vector3 = grid.cell_world(vehicle.cell.x, vehicle.cell.y)
					vehicle.road = turn_center.z if next_axis == "H" else turn_center.x
					var turn_forward := Vector3(float(next_direction), 0, 0) if next_axis == "H" else Vector3(0, 0, float(next_direction))
					target = turn_center + grid_lane_offset(next_axis, next_direction) + turn_forward * 1.3
					vehicle.target = target
				else:
					vehicle.previous = vehicle.cell
					vehicle.cell = next
					vehicle.axis = next_axis
					vehicle.direction = next_direction
					vehicle.road = next_center.z if vehicle.axis == "H" else next_center.x
					target = grid_lane_position(next_center, str(vehicle.axis), int(vehicle.direction))
					vehicle.target = target
		vehicle.coordinate = current.x if vehicle.axis == "H" else current.z
		var allowed := travel_distance(vehicle, delta)
		var proposed := current.move_toward(target, allowed)
		var safe_distance := grid_safe_distance(vehicle, current, proposed)
		vehicle.node.position = current.move_toward(proposed, safe_distance)
		var moved_distance := current.distance_to(vehicle.node.position)
		if moved_distance > 0.02:
			vehicle.stalled_time = 0.0
		if vehicle.get("recovery_mode", false):
			vehicle.recovery_remaining = maxf(0.0, float(vehicle.get("recovery_remaining", 0.0)) - moved_distance)
			if float(vehicle.recovery_remaining) <= 0.01:
				vehicle.erase("recovery_mode")
				vehicle.erase("recovery_remaining")
		vehicle.coordinate = vehicle.node.position.x if vehicle.axis == "H" else vehicle.node.position.z
		vehicle.node.rotation.y = PI / 2 * vehicle.direction if vehicle.axis == "H" else (0.0 if vehicle.direction > 0 else PI)
		release_grid_reservations_for_vehicle(vehicle)
	_update_deadlock_recovery(delta)

func _waiting_cycle(start_id: String) -> Array[String]:
	var path: Array[String] = []
	var positions: Dictionary = {}
	var current_id := start_id
	while path.size() <= vehicles.size():
		if positions.has(current_id):
			return path.slice(int(positions[current_id]))
		var vehicle: Dictionary = {}
		for candidate: Dictionary in vehicles:
			if str(candidate.get("id", "")) == current_id:
				vehicle = candidate
				break
		if vehicle.is_empty() or not vehicle.node.visible or float(vehicle.get("stalled_time", 0.0)) < 4.0:
			return []
		if str(vehicle.get("waiting_reason", "")) not in ["queue", "yield", "moving_vehicle", "vehicle_collision"]:
			return []
		var next_id := str(vehicle.get("waiting_on", ""))
		if next_id == "":
			return []
		positions[current_id] = path.size()
		path.append(current_id)
		current_id = next_id
	return []

func _update_deadlock_recovery(delta: float) -> void:
	var active_cycles: Dictionary = {}
	for vehicle: Dictionary in vehicles:
		if not vehicle.node.visible or vehicle.get("managed", false):
			continue
		var cycle := _waiting_cycle(str(vehicle.id))
		if cycle.size() < 2:
			continue
		cycle.sort()
		var key := ",".join(cycle)
		active_cycles[key] = cycle
	for key: String in deadlock_cycles.keys():
		if not active_cycles.has(key):
			deadlock_cycles.erase(key)
			deadlock_reroutes.erase(key)
	for key: String in active_cycles:
		deadlock_cycles[key] = float(deadlock_cycles.get(key, 0.0)) + delta
	if recovery_vehicle_id != "":
		for vehicle: Dictionary in vehicles:
			if str(vehicle.id) == recovery_vehicle_id and vehicle.get("recovery_mode", false):
				return
		recovery_vehicle_id = ""
	for key: String in deadlock_cycles:
		var cycle_elapsed := float(deadlock_cycles[key])
		var cycle: Array = active_cycles.get(key, [])
		if cycle_elapsed >= 4.0 and not deadlock_reroutes.has(key):
			deadlock_reroutes[key] = true
			if _try_cycle_detour(cycle):
				return
		if cycle_elapsed < 12.0:
			continue
		if cycle.is_empty():
			continue
		# Release one car at a time for a short road-bounded distance. Signals,
		# static blockers and the connected-road graph remain authoritative.
		var recovery_id := str(cycle[0])
		for vehicle: Dictionary in vehicles:
			if str(vehicle.id) == recovery_id:
				vehicle.recovery_mode = true
				vehicle.recovery_remaining = TerritoryGrid.CELL_SIZE * 1.5
				vehicle.stalled_time = 0.0
				recovery_vehicle_id = recovery_id
				return

func _try_cycle_detour(cycle: Array) -> bool:
	if grid == null:
		return false
	for identifier in cycle:
		var vehicle: Dictionary = {}
		for candidate: Dictionary in vehicles:
			if str(candidate.get("id", "")) == str(identifier):
				vehicle = candidate
				break
		if vehicle.is_empty() or not vehicle.has("cell"):
			continue
		var options: Array[Vector2i] = []
		var current_cell: Vector2i = vehicle.cell
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var candidate_cell := current_cell + direction
			if grid.state_at(candidate_cell.x, candidate_cell.y) == "road" and candidate_cell != vehicle.get("previous", Vector2i(-1, -1)) and candidate_cell != vehicle.get("waiting_next", Vector2i(-1, -1)):
				options.append(candidate_cell)
		for candidate_cell: Vector2i in options:
			var occupied := vehicles.any(func(other: Dictionary) -> bool: return str(other.get("id", "")) != str(vehicle.id) and other.node.visible and other.get("cell", Vector2i(-1, -1)) == candidate_cell)
			if occupied:
				continue
			var has_exit := false
			for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var exit_cell := candidate_cell + direction
				if exit_cell != current_cell and grid.state_at(exit_cell.x, exit_cell.y) == "road":
					has_exit = true
					break
			if not has_exit:
				continue
			vehicle.waiting_next = candidate_cell
			vehicle.waiting_reason = ""
			vehicle.waiting_on = ""
			return true
	return false

func has_nearby_incident_blocker(position_value: Vector3) -> bool:
	if service_active and position_value.distance_to(service_position) < 18.0:
		return true
	for blocker: Dictionary in blocking_positions:
		# Moving traffic is expected to clear by itself. Treat only fixed service
		# or incident blockers as a reason to suppress the local deadlock recovery.
		if blocker.get("moving_vehicle", false):
			continue
		if position_value.distance_to(blocker.position) < 18.0:
			return true
	return false

func grid_half_extents(vehicle: Dictionary) -> Vector2:
	var half_length := 1.8 if vehicle.node.type_id == "city_bus" else 1.1
	var half_width := 0.60 if vehicle.node.type_id == "city_bus" else 0.56
	return Vector2(half_length, half_width) if vehicle.axis == "H" else Vector2(half_width, half_length)

func external_vehicle_step_is_clear(current: Vector3, proposed: Vector3, half_length: float, half_width: float, actor_id: String, heading: Vector3 = Vector3.ZERO) -> bool:
	var movement := proposed - current
	var body_heading := Vector2(movement.x, movement.z) if movement.length_squared() > 0.0001 else Vector2(heading.x, heading.z)
	if body_heading.length_squared() < 0.0001:
		body_heading = Vector2.RIGHT
	body_heading = body_heading.normalized()
	var own_half := Vector2(half_length * absf(body_heading.x) + half_width * absf(body_heading.y), half_length * absf(body_heading.y) + half_width * absf(body_heading.x))
	var own_position := Vector2(proposed.x, proposed.z)
	var old_position := Vector2(current.x, current.z)
	for vehicle: Dictionary in vehicles:
		if not vehicle.node.visible or str(vehicle.id) == actor_id:
			continue
		var other_position: Vector3 = lane_position(vehicle)
		var other_half := grid_half_extents(vehicle)
		if grid != null and str(vehicle.axis) == ("H" if absf(body_heading.x) >= absf(body_heading.y) else "V") and int(vehicle.direction) == int(signf(body_heading.x if absf(body_heading.x) >= absf(body_heading.y) else body_heading.y)):
			var axis := str(vehicle.axis)
			var lateral := absf(own_position.y - other_position.z) if axis == "H" else absf(own_position.x - other_position.x)
			var lateral_extent := own_half.y + other_half.y if axis == "H" else own_half.x + other_half.x
			var direction := int(vehicle.direction)
			var current_gap := ((other_position.x - current.x) if axis == "H" else (other_position.z - current.z)) * direction
			var proposed_gap := ((other_position.x - proposed.x) if axis == "H" else (other_position.z - proposed.z)) * direction
			var clearance := (own_half.x + other_half.x if axis == "H" else own_half.y + other_half.y) + EXTERNAL_QUEUE_GAP
			if lateral < lateral_extent + 0.12 and current_gap > 0.0 and proposed_gap < clearance:
				return false
		var overlaps := absf(own_position.x - other_position.x) < own_half.x + other_half.x + 0.12 and absf(own_position.y - other_position.z) < own_half.y + other_half.y + 0.12
		if overlaps:
			var was_overlapping := absf(old_position.x - other_position.x) < own_half.x + other_half.x + 0.12 and absf(old_position.y - other_position.z) < own_half.y + other_half.y + 0.12
			if was_overlapping and own_position.distance_squared_to(Vector2(other_position.x, other_position.z)) > old_position.distance_squared_to(Vector2(other_position.x, other_position.z)):
				continue
			return false
	if service_active:
		var service_half := Vector2(0.95, 0.95)
		if absf(own_position.x - service_position.x) < own_half.x + service_half.x + 0.12 and absf(own_position.y - service_position.z) < own_half.y + service_half.y + 0.12:
			return false
	for blocker: Dictionary in blocking_positions:
		if str(blocker.get("id", "")) == actor_id:
			continue
		var block_position: Vector3 = blocker.position
		var block_half: Vector2 = blocker.get("half_extents", Vector2(0.85, 0.85))
		if blocker.get("moving_vehicle", false):
			var block_axis := str(blocker.get("axis", ""))
			var move_axis := "H" if absf(body_heading.x) >= absf(body_heading.y) else "V"
			var move_direction := int(signf(body_heading.x if move_axis == "H" else body_heading.y))
			if block_axis == move_axis and int(blocker.get("direction", 0)) == move_direction:
				var lateral := absf(own_position.y - block_position.z) if move_axis == "H" else absf(own_position.x - block_position.x)
				var lateral_extent := own_half.y + block_half.y if move_axis == "H" else own_half.x + block_half.x
				var current_gap := ((block_position.x - current.x) if move_axis == "H" else (block_position.z - current.z)) * move_direction
				var proposed_gap := ((block_position.x - proposed.x) if move_axis == "H" else (block_position.z - proposed.z)) * move_direction
				var clearance := (own_half.x + block_half.x if move_axis == "H" else own_half.y + block_half.y) + EXTERNAL_QUEUE_GAP
				if lateral < lateral_extent + 0.12 and current_gap > 0.0 and proposed_gap < clearance:
					return false
		if absf(own_position.x - block_position.x) < own_half.x + block_half.x + 0.12 and absf(own_position.y - block_position.z) < own_half.y + block_half.y + 0.12:
			var was_overlapping := absf(old_position.x - block_position.x) < own_half.x + block_half.x + 0.12 and absf(old_position.y - block_position.z) < own_half.y + block_half.y + 0.12
			if was_overlapping and own_position.distance_squared_to(Vector2(block_position.x, block_position.z)) > old_position.distance_squared_to(Vector2(block_position.x, block_position.z)):
				continue
			return false
	return true

func grid_safe_distance(vehicle: Dictionary, current: Vector3, proposed: Vector3) -> float:
	var own := grid_half_extents(vehicle)
	for other: Dictionary in vehicles:
		if other.id == vehicle.id or not other.node.visible:
			continue
		if vehicle.get("recovery_mode", false):
			continue
		var sum := own + grid_half_extents(other)
		var other_position: Vector3 = other.node.position
		if absf(proposed.x - other_position.x) < sum.x and absf(proposed.z - other_position.z) < sum.y:
			if proposed.distance_squared_to(other_position) > current.distance_squared_to(other_position) and absf(current.x - other_position.x) < sum.x and absf(current.z - other_position.z) < sum.y:
				continue
			vehicle.waiting_reason = "vehicle_collision"
			vehicle.waiting_on = str(other.id)
			return 0.0
	return current.distance_to(proposed)
