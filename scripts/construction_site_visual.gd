extends Node3D

const Art = preload("res://scripts/art.gd")
var frame: Node3D

func _ready() -> void:
	var fence := Node3D.new()
	fence.name = "TronFence"
	add_child(fence)
	draw_tron_worksite_fence(fence, 9.6, 9.6)
	Art.box(self, Vector3(0, 0.12, 0), Vector3(9.25, 0.22, 9.25), Color("b7a184")).name = "SquareGround"
	for side in [-1, 1]:
		Art.box(self, Vector3(side * 4.5, 0.27, 0), Vector3(0.14, 0.16, 9.1), Color("d5c6a3"))
		Art.box(self, Vector3(0, 0.27, side * 4.5), Vector3(9.1, 0.16, 0.14), Color("d5c6a3"))
	var bricks := Node3D.new()
	bricks.name = "Bricks"
	add_child(bricks)
	for layer in range(3):
		for col in range(4):
			for row in range(2):
				Art.box(bricks, Vector3(-3.15 + col * 0.48, 0.38 + layer * 0.24, 2.6 + row * 0.4), Vector3(0.43, 0.21, 0.35), Color("be7654").lightened(layer * 0.04))
	var boards := Node3D.new()
	boards.name = "Boards"
	add_child(boards)
	for index in range(5):
		var board := Art.box(boards, Vector3(2.45, 0.32 + index * 0.12, 2.7), Vector3(3.1, 0.1, 0.35), Color("c39e69"))
		board.rotation.y = 0.08 * (index % 2)
	var barrels := Node3D.new()
	barrels.name = "Barrels"
	add_child(barrels)
	for index in range(2):
		var pos := Vector3(3.3, 0.77, -2.6 + index * 1.05)
		Art.cylinder(barrels, pos, 0.4, 1.0, Color("647d82"))
		for offset in [-0.3, 0.3]:
			Art.cylinder(barrels, pos + Vector3(0, offset, 0), 0.42, 0.07, Color("8d9b99"))
	var pipes := Node3D.new()
	pipes.name = "Pipes"
	add_child(pipes)
	for index in range(3):
		var pos := Vector3(-2.9 + index * 0.7, 0.57, -2.9)
		var pipe := Art.cylinder(pipes, pos, 0.29, 2.3, Color("8e9899"))
		pipe.rotation.x = PI / 2
		var hole := Art.cylinder(pipes, pos + Vector3(0, 0, 1.16), 0.21, 0.025, Color("404c50"))
		hole.rotation.x = PI / 2
	frame = Node3D.new()
	frame.name = "BuildingFrame"
	add_child(frame)
	for x in [-1.8, 1.8]:
		for z in [-1.7, 1.7]:
			Art.box(frame, Vector3(x, 1.1, z), Vector3(0.17, 2.0, 0.17), Color("b99865"))
	for z in [-1.7, 1.7]:
		Art.box(frame, Vector3(0, 2.1, z), Vector3(3.9, 0.18, 0.18), Color("b99865"))
	for x in [-1.8, 1.8]:
		Art.box(frame, Vector3(x, 2.1, 0), Vector3(0.18, 0.18, 3.6), Color("b99865"))

func set_progress(value: float) -> void:
	if frame != null:
		frame.scale.y = lerpf(0.35, 1.0, clampf(value, 0.0, 1.0))

func draw_tron_worksite_fence(parent: Node3D, width: float, depth: float) -> void:
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.albedo_color = Color(0.10, 0.88, 1.0, 0.42)
	glow.emission_enabled = true
	glow.emission = Color(0.05, 0.75, 1.0)
	glow.roughness = 0.25
	var inner_x := width * 0.46
	var inner_z := depth * 0.46
	var fence_y := 3.2
	for x in [-inner_x, inner_x]:
		for z in [-inner_z, inner_z]:
			add_tron_fence_box(parent, Vector3(x, fence_y * 0.5, z), Vector3(0.09, fence_y, 0.09), glow)
		add_tron_fence_box(parent, Vector3(x, fence_y * 0.88, 0), Vector3(0.055, 0.045, depth * 0.78), glow)
		add_tron_fence_box(parent, Vector3(x, fence_y * 0.48, 0), Vector3(0.035, 0.025, depth * 0.78), glow)
	for z in [-inner_z, inner_z]:
		add_tron_fence_box(parent, Vector3(0, fence_y * 0.88, z), Vector3(width * 0.78, 0.045, 0.055), glow)
		add_tron_fence_box(parent, Vector3(0, fence_y * 0.48, z), Vector3(width * 0.78, 0.025, 0.035), glow)

	for x in [-inner_x, inner_x]:
		add_tron_fence_box(parent, Vector3(x, fence_y * 0.5, 0), Vector3(0.025, fence_y, depth * 0.92), glow)
	for z in [-inner_z, inner_z]:
		add_tron_fence_box(parent, Vector3(0, fence_y * 0.5, z), Vector3(width * 0.92, fence_y, 0.025), glow)

func add_tron_fence_box(parent: Node3D, point: Vector3, dimensions: Vector3, material: StandardMaterial3D) -> void:
	var segment := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	segment.mesh = mesh
	segment.material_override = material
	segment.position = point
	segment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(segment)

