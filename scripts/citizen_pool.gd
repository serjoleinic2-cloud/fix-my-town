extends Node3D

const DistrictWorld = preload("res://scripts/district_world.gd")
const MAX_BY_QUALITY := {"low": 4, "medium": 8, "high": 12}
const CLOTHING := [Color("e76850"), Color("3687b4"), Color("e2a83d"), Color("708c5d"), Color("9a6eb1"), Color("e1789d"), Color("4b9c8e"), Color("d7d5cc")]
const HAIR := [Color("342b29"), Color("6b422c"), Color("ba824a"), Color("d6c18a"), Color("39383e"), Color("8c5146")]
const SKIN := [Color("f0c29c"), Color("d9966f"), Color("ba7658"), Color("87543f"), Color("edcfad")]
const TROUSERS := [Color("394458"), Color("55504a"), Color("304e51"), Color("806247"), Color("343943")]

var game: RefCounted
var map_position: Callable
var traffic_controller: Node3D
var quality: String = "high"
var walkers: Array[Dictionary] = []
var frame_cache: Array = []
var refresh_clock: float = 0.0
var clock: float = 0.0
var assignments_signature: String = ""

func setup(simulation: RefCounted, graphics_quality: String, position_mapper: Callable, traffic: Node3D = null) -> void:
	game = simulation
	quality = graphics_quality
	map_position = position_mapper
	traffic_controller = traffic
	refresh_routes(true)

func set_quality(value: String) -> void:
	if quality == value:
		return
	quality = value
	refresh_routes(true)

func visible_count() -> int:
	var count := 0
	for walker: Dictionary in walkers:
		var visual: Sprite3D = walker.visual
		if visual.visible and visual.modulate.a > 0.05:
			count += 1
	return count

func refresh_routes(force: bool = false) -> void:
	if game == null:
		return
	var buildings: Array[Dictionary] = game.all_buildings()
	var signature := str([quality, game.transit.active, game.transit.stops, buildings.map(func(item: Dictionary): return [item.instance_id, item.type_id, item.get("level", 1)])])
	if not force and signature == assignments_signature:
		return
	assignments_signature = signature
	for child in get_children():
		child.queue_free()
	walkers.clear()
	frame_cache.clear()
	var homes: Array[Dictionary] = []
	var destinations: Array[Dictionary] = []
	for building: Dictionary in buildings:
		if building.type_id == "house" and game.record_residents(building) > 0:
			homes.append(building)
		elif building.type_id in ["cafe", "park", "depot", "fire_station", "police_station", "hospital"]:
			destinations.append(building)
	if homes.is_empty() or destinations.is_empty():
		return
	var requested_count: int = int(MAX_BY_QUALITY.get(quality, 12))
	var commuting: bool = game.transit.active and game.transit.stops.size() == 2
	var count: int = mini(requested_count, maxi(2, homes.size() + destinations.size()))
	for index in range(count):
		var visual := Sprite3D.new()
		visual.name = "Citizen_%02d" % index
		visual.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		visual.pixel_size = 0.03
		visual.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		visual.position.y = 0.78
		visual.render_priority = 1
		add_child(visual)
		var variant := index % 12
		var frames := _make_frames(variant)
		frame_cache.append(frames)
		visual.texture = frames[0]
		var home: Dictionary = homes[index % homes.size()]
		var destination: Dictionary = destinations[(index * 3 + 1) % destinations.size()]
		var spawn := _entrance(home) + _spawn_offset(index)
		var destination_point := _entrance(destination) + _spawn_offset(index + 1)
		var walker := {"visual": visual, "frames": frames, "variant": variant, "position": spawn,
			"home": home, "destination": destination, "from_stop": index % 2, "to_stop": 1 - (index % 2),
			"uses_bus": false, "route": [], "route_index": 0, "state": "walk_dest", "state_time": 0.0, "step_time": 0.0,
			"phase": float(index) * 0.71, "fade": 0.0}
		walker.uses_bus = _assign_transit_stops(walker) if commuting else false
		if bool(walker.uses_bus):
			walker.state = "walk_stop"
			_set_route(walker, _sidewalk_route(spawn, _stop_curb(int(walker.from_stop))))
		else:
			_set_route(walker, _sidewalk_route(spawn, destination_point))
		walkers.append(walker)

func tick(delta: float) -> void:
	if game == null:
		return
	clock += delta
	refresh_clock += delta
	if refresh_clock >= 2.0:
		refresh_clock = 0.0
		refresh_routes()
	for index in range(walkers.size()):
		var walker: Dictionary = walkers[index]
		_update_walker(walker, delta)
		walkers[index] = walker

func _update_walker(walker: Dictionary, delta: float) -> void:
	var visual: Sprite3D = walker.visual
	var state := str(walker.state)
	walker.state_time = float(walker.state_time) + delta
	var is_moving := state in ["walk_stop", "walk_dest", "walk_home"]
	if is_moving:
		var points: Array = walker.route
		var point_index := int(walker.route_index)
		if point_index < points.size():
			var position_now: Vector3 = walker.position
			var target: Vector3 = points[point_index]
			if not _pedestrian_can_advance(position_now, target):
				walker.position = position_now
				visual.position = position_now + Vector3(0, 0.78, 0)
				walker.step_time = float(walker.step_time) + delta
				visual.texture = walker.frames[1 if int(walker.step_time / 0.32) % 2 == 1 else 0]
				return
			position_now = position_now.move_toward(target, delta * 1.45)
			if position_now.distance_to(target) < 0.045:
				position_now = target
				point_index += 1
				walker.route_index = point_index
			walker.position = position_now
		if int(walker.route_index) >= points.size():
			walker.state_time = 0.0
			match state:
				"walk_stop": walker.state = "waiting"
				"walk_dest": walker.state = "inside"
				"walk_home": walker.state = "inside_home"
			state = str(walker.state)
	if state == "waiting":
		if game.transit.active and game.transit.dwell > 0.0 and int(game.transit.current_target) == int(walker.from_stop):
			walker.state = "boarding"
			walker.state_time = 0.0
			state = "boarding"
	elif state == "boarding" and float(walker.state_time) >= 0.4:
		walker.state = "riding"
		walker.state_time = 0.0
		visual.visible = false
		return
	elif state == "riding":
		if game.transit.dwell > 0.0 and int(game.transit.current_target) == int(walker.to_stop):
			walker.position = _stop_curb(int(walker.to_stop))
			walker.state = "walk_dest"
			walker.state_time = 0.0
			var destination_position: Vector3 = _entrance(walker.destination)
			_set_route(walker, _sidewalk_route(walker.position, destination_position))
			visual.visible = true
			visual.modulate.a = 0.0
			state = "walk_dest"
	elif state == "inside":
		if float(walker.state_time) >= 1.5:
			var previous_home: Dictionary = walker.home
			walker.home = walker.destination
			walker.destination = previous_home
			walker.position = _entrance(walker.home)
			walker.state_time = 0.0
			if game.transit.active and game.transit.stops.size() == 2 and _assign_transit_stops(walker):
				walker.state = "walk_stop"
				_set_route(walker, _sidewalk_route(walker.position, _stop_curb(int(walker.from_stop))))
			else:
				walker.state = "walk_dest"
				_set_route(walker, _sidewalk_route(walker.position, _entrance(walker.destination)))
	elif state == "inside_home":
		if float(walker.state_time) >= 1.7:
			walker.position = _entrance(walker.home)
			walker.from_stop = int(walker.to_stop)
			walker.to_stop = 1 - int(walker.from_stop)
			walker.state = "walk_stop" if game.transit.active and game.transit.stops.size() == 2 else "walk_dest"
			walker.state_time = 0.0
			var target := _stop_curb(int(walker.from_stop)) if str(walker.state) == "walk_stop" else _entrance(walker.destination)
			_set_route(walker, _sidewalk_route(walker.position, target))
	state = str(walker.state)
	var walking: bool = state in ["walk_stop", "walk_dest", "walk_home"]
	visual.position = walker.position + Vector3(0, 0.78 + (sin(clock * 3.2 + float(walker.phase)) * 0.035 if not walking else 0.0), 0)
	if state == "boarding":
		visual.modulate.a = clampf(1.0 - float(walker.state_time) / 0.4, 0.0, 1.0)
	elif state in ["walk_dest", "walk_home", "walk_stop"]:
		visual.modulate.a = minf(1.0, visual.modulate.a + delta * 3.0)
	elif state in ["inside", "inside_home"]:
		visual.modulate.a = maxf(0.0, visual.modulate.a - delta * 2.5)
	visual.visible = state not in ["riding", "inside", "inside_home"] or visual.modulate.a > 0.05
	if walking:
		walker.step_time = float(walker.step_time) + delta
		var frames: Array = walker.frames
		visual.texture = frames[1 if int(walker.step_time / 0.19) % 2 == 1 else 0]

func _entrance(entry: Dictionary) -> Vector3:
	var point: Vector3 = entry.position
	return point + Vector3(0.0, 0.06, 4.65)

func _stop_world(index: int) -> Vector3:
	var stop: Variant = game.transit.stops[clampi(index, 0, game.transit.stops.size() - 1)]
	var point: Vector3 = game.transit.stop_position(stop, game.territory)
	if not stop is Dictionary:
		point = map_position.call(point)
	return point

func _stop_curb(index: int) -> Vector3:
	var stop: Variant = game.transit.stops[clampi(index, 0, game.transit.stops.size() - 1)]
	var orientation: String = str(game.stop_orientation(stop)) if stop is Dictionary else "horizontal"
	return _stop_world(index) + (Vector3(0, 0.06, 2.5) if orientation == "horizontal" else Vector3(2.5, 0.06, 0))

func _spawn_offset(index: int) -> Vector3:
	# Разводим визуальный пул по тротуару, чтобы одинаковые состояния не
	# складывали людей в одну точку у входа или остановки.
	if index <= 0:
		return Vector3.ZERO
	var lane := float((index % 3) - 1) * 0.62
	var step := float((index % 2)) * 0.28
	return Vector3(lane, 0, step)

func _assign_transit_stops(walker: Dictionary) -> bool:
	if not game.transit.active or game.transit.stops.size() != 2:
		walker.uses_bus = false
		return false
	var home_stop := _nearest_stop_index(_entrance(walker.home))
	var destination_stop := _nearest_stop_index(_entrance(walker.destination))
	walker.from_stop = home_stop
	walker.to_stop = destination_stop
	walker.uses_bus = home_stop != destination_stop
	return bool(walker.uses_bus)

func _nearest_stop_index(point: Vector3) -> int:
	var first_distance := point.distance_squared_to(_stop_world(0))
	var second_distance := point.distance_squared_to(_stop_world(1))
	return 0 if first_distance <= second_distance else 1

func _sidewalk_route(start: Vector3, finish: Vector3) -> Array[Vector3]:
	var result: Array[Vector3] = [start]
	var from_cell: Vector2i = game.territory.nearest_road(start)
	var to_cell: Vector2i = game.territory.nearest_road(finish)
	var road_cells: Array[Vector2i] = game.territory.road_path(from_cell, to_cell)
	if not road_cells.is_empty():
		for index in range(road_cells.size()):
			var cell: Vector2i = road_cells[index]
			var previous: Vector2i = road_cells[maxi(0, index - 1)]
			var next: Vector2i = road_cells[mini(road_cells.size() - 1, index + 1)]
			var center: Vector3 = game.territory.cell_world(cell.x, cell.y)
			var before := cell - previous
			var after := next - cell
			var sidewalk_offset := 2.5 if cell.y <= 18 else 1.85
			var sidewalk_height := 0.14 if cell.y <= 18 else 0.21
			var direction := after if after != Vector2i.ZERO else before
			# Keep pedestrians on one side of the road. The perpendicular vector
			# follows the actual turn direction instead of always using +X/+Z.
			var side := Vector2i(-direction.y, direction.x)
			var curb_offset := Vector3(float(side.x) * sidewalk_offset, sidewalk_height, float(side.y) * sidewalk_offset)
			var curb := center + curb_offset
			if result.back().distance_to(curb) > 0.8 and curb.distance_to(finish) > 1.0:
				result.append(curb)
	if result.back().distance_to(finish) > 0.2:
		result.append(finish)
	return result

func _pedestrian_can_advance(current: Vector3, target: Vector3) -> bool:
	if traffic_controller == null or not is_instance_valid(traffic_controller):
		return true
	var direction := target - current
	if direction.length_squared() < 0.0001:
		return true
	# Crossing east/west traffic requires its signal to be red; crossing north/south traffic does too.
	var crossing_axis := "V" if absf(direction.x) > absf(direction.z) else "H"
	for intersection: Dictionary in traffic_controller.intersections:
		var center := Vector3(float(intersection.x), 0, float(intersection.z))
		if current.distance_to(center) > 5.0 and target.distance_to(center) > 5.0:
			continue
		if traffic_controller.is_broken(intersection):
			continue
		var state: String = traffic_controller.phase(crossing_axis, traffic_controller.clock + float(intersection.offset))
		if state == "green" or state == "yellow":
			return false
	return true

func _set_route(walker: Dictionary, points: Array[Vector3]) -> void:
	walker.route = points
	walker.route_index = 0

func _make_frames(variant: int) -> Array[Texture2D]:
	return [_make_texture(variant, 0), _make_texture(variant, 1)]

func _make_texture(variant: int, pose: int) -> Texture2D:
	var image := Image.create(32, 48, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var shirt: Color = CLOTHING[variant % CLOTHING.size()]
	var hair_color: Color = HAIR[(variant * 5 + 1) % HAIR.size()]
	var skin_color: Color = SKIN[(variant * 3 + 2) % SKIN.size()]
	var pants: Color = TROUSERS[(variant * 7 + 3) % TROUSERS.size()]
	# Hair silhouette behind the head and shoulders.
	_paint_disc(image, 16, 12, 8, hair_color)
	_paint_rect(image, 8, 11, 24, 21, skin_color)
	_paint_rect(image, 7, 9, 25, 15, hair_color)
	_paint_rect(image, 8, 14, 10, 19, hair_color)
	_paint_rect(image, 22, 14, 24, 19, hair_color)
	# A second hair outline shape makes short and long styles alternate.
	if variant % 3 == 0:
		_paint_rect(image, 7, 17, 10, 24, hair_color)
	elif variant % 3 == 1:
		_paint_rect(image, 12, 8, 20, 10, hair_color)
	# Arms and shirt.
	_paint_rect(image, 5, 22, 9, 35, skin_color)
	_paint_rect(image, 23, 22, 27, 35, skin_color)
	_paint_rect(image, 9, 20, 23, 35, shirt)
	_paint_rect(image, 13, 18, 19, 21, shirt.lightened(0.1))
	# Bag, scarf, buttons, glasses, and hat vary without adding scene nodes.
	if variant % 4 == 0:
		_paint_rect(image, 20, 25, 25, 35, Color("704f3f"))
	elif variant % 4 == 1:
		_paint_rect(image, 9, 23, 23, 25, Color("f0d36e"))
	elif variant % 4 == 2:
		_paint_rect(image, 11, 15, 14, 17, Color("30343a"))
		_paint_rect(image, 18, 15, 21, 17, Color("30343a"))
	if variant % 5 == 0:
		_paint_rect(image, 8, 7, 24, 10, shirt.lightened(0.25))
	# Trousers and shoes animate in two small walking poses.
	var stride := 3 if pose == 0 else -3
	_paint_rect(image, 10, 35, 15 + stride, 44, pants)
	_paint_rect(image, 17 - stride, 35, 22, 44, pants)
	_paint_rect(image, 8 + stride, 43, 15 + stride, 46, Color("363638"))
	_paint_rect(image, 17 - stride, 43, 24 - stride, 46, Color("363638"))
	return ImageTexture.create_from_image(image)

func _paint_rect(image: Image, left: int, top: int, right: int, bottom: int, color: Color) -> void:
	for y in range(clampi(top, 0, image.get_height()), clampi(bottom, 0, image.get_height())):
		for x in range(clampi(left, 0, image.get_width()), clampi(right, 0, image.get_width())):
			image.set_pixel(x, y, color)

func _paint_disc(image: Image, center_x: int, center_y: int, radius: int, color: Color) -> void:
	for y in range(maxi(0, center_y - radius), mini(image.get_height(), center_y + radius + 1)):
		for x in range(maxi(0, center_x - radius), mini(image.get_width(), center_x + radius + 1)):
			if Vector2(x - center_x, y - center_y).length_squared() <= radius * radius:
				image.set_pixel(x, y, color)
