extends Node3D

const Catalog = preload("res://scripts/asset_catalog.gd")
@export var type_id: String
@export var instance_id: String
var visual_root: Node3D
var interaction_area: Area3D
var mounts: Node3D
var footprint: Vector2
var level: int = 1
var serviced_value: bool = true
var language_value: String = "ru"
var traffic_horizontal: String = "red"
var traffic_vertical: String = "red"
var visual_override: String = ""

func setup(object_type: String, persistent_id: String) -> void:
	type_id = object_type
	instance_id = persistent_id
	footprint = Catalog.TYPES[type_id].footprint
	visual_root = get_node_or_null("VisualRoot")
	if visual_root == null:
		visual_root = Node3D.new()
		visual_root.name = "VisualRoot"
		add_child(visual_root)
	mounts = Node3D.new()
	mounts.name = "Mounts"
	add_child(mounts)
	var sockets := {"Entrance": Vector3(0, 0, 4.5), "Smoke": Vector3(0, 5, 0), "Water": Vector3(0, 0.3, 4.5),
		"LightFront": Vector3(0, 0.7, 1.3), "LightRoof": Vector3(0, 1.7, 0.7),
		"WheelFrontLeft": Vector3(-0.85, 0.37, 0.9), "WheelFrontRight": Vector3(0.85, 0.37, 0.9),
		"WheelRearLeft": Vector3(-0.85, 0.37, -0.85), "WheelRearRight": Vector3(0.85, 0.37, -0.85)}
	if type_id == "city_bus":
		sockets.LightFront = Vector3(0, 1, 2.33)
		sockets.LightRoof = Vector3(0, 2.1, 0.4)
		sockets.WheelFrontLeft = Vector3(-0.85, 0.3, 1.5)
		sockets.WheelFrontRight = Vector3(0.85, 0.3, 1.5)
		sockets.WheelRearLeft = Vector3(-0.85, 0.3, -1.5)
		sockets.WheelRearRight = Vector3(0.85, 0.3, -1.5)
	for socket: String in sockets:
		var point := Marker3D.new()
		point.name = socket
		point.position = sockets[socket]
		mounts.add_child(point)
	interaction_area = Area3D.new()
	interaction_area.name = "InteractionArea"
	interaction_area.collision_layer = 1
	interaction_area.collision_mask = 0
	add_child(interaction_area)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(footprint.x, 5, footprint.y)
	collision.shape = shape
	collision.position.y = 2.5
	interaction_area.add_child(collision)
	replace_visual()

func replace_visual(alternate: bool = false) -> void:
	for child in visual_root.get_children():
		visual_root.remove_child(child)
		child.queue_free()
	var scene := load(Catalog.scene_path(visual_override if visual_override != "" else type_id, alternate, level)) as PackedScene
	visual_root.add_child(scene.instantiate())
	set_serviced(serviced_value)
	set_language(language_value)
	set_traffic_state(traffic_horizontal, traffic_vertical)

func set_ruined(value: bool) -> void:
	var desired := "ruins" if value else ""
	if visual_override == desired:
		return
	visual_override = desired
	replace_visual()

func set_serviced(value: bool) -> void:
	serviced_value = value
	# Только визуальное состояние; игровой источник истины находится в Simulation.
	var model := visual_root.get_child(0)
	if model.has_method("set_serviced"):
		model.set_serviced(value)

func set_language(language: String) -> void:
	language_value = language
	var model := visual_root.get_child(0)
	if model.has_method("set_language"):
		model.set_language(language)

func set_traffic_state(horizontal: String, vertical: String) -> void:
	traffic_horizontal = horizontal
	traffic_vertical = vertical
	var model := visual_root.get_child(0)
	if model.has_method("set_signal_states"):
		model.set_signal_states(horizontal, vertical)

func set_emergency_lights(enabled: bool, time_value: float = 0.0) -> void:
	if visual_root.get_child_count() > 0:
		var model := visual_root.get_child(0)
		if model.has_method("set_emergency_lights"):
			model.set_emergency_lights(enabled, time_value)

func set_level(value: int) -> void:
	value = clampi(value, 1, 3) if Catalog.LEVELS.has(type_id) else 1
	if value == level:
		return
	level = value
	replace_visual()
