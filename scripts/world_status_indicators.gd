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
	if game.job != "" and game.job != "fire" and game.job_phase == "repair":
		var repair_position: Vector3 = game.building_world_for_id(game.target_instance_id)
		if repair_position != Vector3.ZERO:
			specs.append({"id": "service:" + game.target_instance_id, "kind": "repair", "progress": 1.0 - game.repair_left / 4.0,
				"position": repair_position + Vector3(0, 6.3, 0)})
	return specs

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
