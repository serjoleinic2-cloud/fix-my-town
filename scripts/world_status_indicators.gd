extends Node3D

const Simulation = preload("res://scripts/simulation.gd")

var indicators: Dictionary = {}

static func construction_task_world(game: RefCounted, task: Dictionary) -> Vector3:
	var identifier := str(task.get("identifier", ""))
	if not identifier.is_empty():
		var entry: Dictionary = game.territory.building_by_id(identifier)
		if not entry.is_empty():
			return game.territory.building_center(entry)
		if identifier.begins_with("pine_district_legacy_"):
			return game.building_world(int(identifier.trim_prefix("pine_district_legacy_")))
	var cells: Array[Vector2i] = game.construction_cells(task)
	if cells.is_empty():
		return Vector3.ZERO
	var result := Vector3.ZERO
	for cell: Vector2i in cells:
		result += game.territory.cell_world(cell.x, cell.y)
	return result / float(cells.size())

static func specs_for(game: RefCounted) -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	for identifier in game.fires:
		var assignment: Dictionary = game.fire_assignment(str(identifier))
		if not assignment.is_empty() and str(assignment.get("phase", "")) == "repair":
			var duration := maxf(0.1, game.fire_service_duration(str(identifier)))
			specs.append({"id": "building:" + str(identifier), "kind": "repair", "progress": 1.0 - float(assignment.get("repair_left", duration)) / duration,
				"position": game.building_world_for_id(str(identifier)) + Vector3(0, 6.3, 0)})
		else:
			specs.append({"id": "building:" + str(identifier), "kind": "fire", "progress": float(game.house_damage(str(identifier))) / 100.0,
				"position": game.building_world_for_id(str(identifier)) + Vector3(0, 6.3, 0)})
	for task: Dictionary in game.active_construction_jobs():
		if str(task.get("kind", "")) == "departing":
			continue
		var total := maxf(0.1, float(task.get("total", Simulation.CONSTRUCTION_DURATION)))
		var progress := 1.0 - float(task.get("remaining", total)) / total
		specs.append({"id": "construction:" + str(task.get("job_id", task.get("identifier", "%s_%s" % [task.get("col", -1), task.get("row", -1)]))),
			"kind": "construction", "progress": progress, "position": construction_task_world(game, task) + Vector3(0, 4.8, 0)})
	if game.has_method("farm_ready_count"):
		for entry: Dictionary in game.territory.buildings:
			var farm_type := str(entry.get("type_id", ""))
			if game.is_farm_producer(farm_type) and game.farm_is_ready(entry) and game.farm_building_issue(entry) == "":
				var capacity: float = game.farm_building_capacity(entry)
				specs.append({"id": "harvest:" + str(entry.get("instance_id", "")), "kind": "harvest", "crop": farm_type,
					"progress": game.farm_ready_amount(entry) / maxf(1.0, capacity), "position": game.territory.building_center(entry) + Vector3(0, 5.6, 0)})
	if game.job != "" and game.job != "fire" and game.job_phase == "repair":
		var repair_position: Vector3 = game.building_world_for_id(game.target_instance_id)
		if repair_position != Vector3.ZERO:
			specs.append({"id": "service:" + game.target_instance_id, "kind": "repair", "progress": 1.0 - game.repair_left / 4.0,
				"position": repair_position + Vector3(0, 6.3, 0)})
	return specs

static func _disc(image: Image, cx: int, cy: int, radius: int, color: Color) -> void:
	for y in range(maxi(0, cy - radius), mini(image.get_height(), cy + radius + 1)):
		for x in range(maxi(0, cx - radius), mini(image.get_width(), cx + radius + 1)):
			if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= radius * radius:
				image.set_pixel(x, y, color)

static func harvest_texture(crop: String, full: bool) -> ImageTexture:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var fill := {"field": Color("e6b43c"), "pasture": Color("8cc56b"), "livestock_yard": Color("d9905a"), "mill": Color("e8e2d2"), "bakery": Color("e9b27a")}.get(crop, Color("e6b43c")) as Color
	_disc(image, 32, 32, 30, Color("ffffff") if not full else Color("7ec45a"))
	_disc(image, 32, 32, 26, fill)
	var ink := Color("fffdf3") if crop != "mill" else Color("8a6a3a")
	match crop:
		"pasture":
			_disc(image, 32, 39, 10, ink)
			image.fill_rect(Rect2i(30, 15, 4, 10), ink)
			image.fill_rect(Rect2i(27, 24, 10, 6), ink)
		"livestock_yard":
			_disc(image, 32, 34, 13, ink)
			_disc(image, 32, 21, 7, ink)
			image.fill_rect(Rect2i(24, 44, 4, 8), ink)
			image.fill_rect(Rect2i(36, 44, 4, 8), ink)
		"bakery":
			_disc(image, 32, 36, 14, ink)
			_disc(image, 22, 36, 8, ink)
			_disc(image, 42, 36, 8, ink)
			image.fill_rect(Rect2i(24, 18, 16, 4), ink)
		"mill":
			image.fill_rect(Rect2i(19, 25, 26, 22), ink)
			_disc(image, 32, 25, 13, ink)
			image.fill_rect(Rect2i(28, 14, 8, 6), ink)
		_:
			image.fill_rect(Rect2i(30, 20, 4, 30), ink)
			for i in range(3):
				_disc(image, 25, 24 + i * 9, 4, ink)
				_disc(image, 39, 24 + i * 9, 4, ink)
			_disc(image, 32, 17, 4, ink)
	return ImageTexture.create_from_image(image)

func _texture(kind: String, progress: float) -> ImageTexture:
	var image := Image.create(72, 10, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.08, 0.10, 0.12, 0.82))
	var color := Color("d9413d") if kind == "fire" else (Color("efbd3e") if kind == "repair" else Color("399de8"))
	var width := clampi(roundi(68.0 * clampf(progress, 0.0, 1.0)), 1, 68)
	image.fill_rect(Rect2i(2, 2, width, 6), color)
	return ImageTexture.create_from_image(image)

func sync(specs: Array[Dictionary]) -> void:
	var active: Dictionary = {}
	for spec: Dictionary in specs:
		var identifier := str(spec.get("id", ""))
		if identifier.is_empty():
			continue
		active[identifier] = true
		var sprite := indicators.get(identifier) as Sprite3D
		if sprite == null or not is_instance_valid(sprite):
			sprite = Sprite3D.new()
			sprite.name = "Status_" + identifier.validate_node_name()
			sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			sprite.no_depth_test = true
			sprite.pixel_size = 0.038
			add_child(sprite)
			indicators[identifier] = sprite
		var kind := str(spec.get("kind", "fire"))
		if kind == "harvest":
			var crop := str(spec.get("crop", "field"))
			var is_full := float(spec.get("progress", 0.0)) >= 0.999
			if sprite.get_meta("kind", "") != kind or sprite.get_meta("crop", "") != crop or bool(sprite.get_meta("full", false)) != is_full:
				sprite.texture = harvest_texture(crop, is_full)
				sprite.set_meta("kind", kind)
				sprite.set_meta("crop", crop)
				sprite.set_meta("full", is_full)
			sprite.pixel_size = 0.05
			var bob := sin(Time.get_ticks_msec() / 1000.0 * 3.0) * 0.18
			sprite.position = spec.get("position", Vector3.ZERO) + Vector3(0, bob, 0)
			continue
		var progress := clampf(float(spec.get("progress", 0.0)), 0.0, 1.0)
		var bucket := roundi(progress * 40.0)
		if sprite.get_meta("kind", "") != kind or int(sprite.get_meta("bucket", -1)) != bucket:
			sprite.texture = _texture(kind, float(bucket) / 40.0)
			sprite.set_meta("kind", kind)
			sprite.set_meta("bucket", bucket)
		sprite.set_meta("progress", progress)
		sprite.position = spec.get("position", Vector3.ZERO)
	for identifier in indicators.keys():
		if active.has(identifier):
			continue
		var stale := indicators[identifier] as Sprite3D
		if is_instance_valid(stale):
			stale.queue_free()
		indicators.erase(identifier)
