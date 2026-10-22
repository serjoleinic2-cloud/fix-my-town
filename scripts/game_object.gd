extends Node3D

const Catalog = preload("res://scripts/asset_catalog.gd")
@export var type_id: String
@export var instance_id: String
var visual_root: Node3D
var interaction_area: Area3D
var mounts: Node3D
var footprint: Vector2

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
	var scene := load(Catalog.scene_path(type_id, alternate)) as PackedScene
	visual_root.add_child(scene.instantiate())

func set_serviced(value: bool) -> void:
	# Только визуальное состояние; игровой источник истины находится в Simulation.
	var model := visual_root.get_child(0)
	if model.has_method("set_serviced"):
		model.set_serviced(value)

func set_language(language: String) -> void:
	var model := visual_root.get_child(0)
	if model.has_method("set_language"):
		model.set_language(language)

func set_traffic_state(horizontal: String, vertical: String) -> void:
	var model := visual_root.get_child(0)
	if model.has_method("set_signal_states"):
		model.set_signal_states(horizontal, vertical)
