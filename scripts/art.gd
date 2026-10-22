extends RefCounted

static var materials: Dictionary = {}
static var cube: BoxMesh
static var crown_mesh: ArrayMesh
static var cylinders: Dictionary = {}

static func material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not materials.has(key):
		var value := StandardMaterial3D.new()
		value.albedo_color = Color.from_hsv(color.h, color.s * (0.9 if color.r > color.g * 1.15 and color.g > color.b else 0.65), color.v).srgb_to_linear()
		value.roughness = 0.9
		materials[key] = value
	return materials[key]

static func box(parent: Node3D, pos: Vector3, size_value: Vector3, color: Color) -> MeshInstance3D:
	if cube == null:
		cube = BoxMesh.new()
	var item := MeshInstance3D.new()
	item.mesh = cube
	item.material_override = material(color)
	item.position = pos
	item.scale = size_value
	parent.add_child(item)
	return item

static func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, top_ratio: float = 1.0, segments: int = 12) -> MeshInstance3D:
	var key := str(top_ratio) + ":" + str(segments)
	if not cylinders.has(key):
		var mesh := CylinderMesh.new()
		mesh.top_radius = top_ratio
		mesh.bottom_radius = 1
		mesh.height = 1
		mesh.radial_segments = segments
		cylinders[key] = mesh
	var item := MeshInstance3D.new()
	item.mesh = cylinders[key]
	item.material_override = material(color)
	item.position = pos
	item.scale = Vector3(radius, height, radius)
	parent.add_child(item)
	return item

static func triangles(parent: Node3D, vertices: PackedVector3Array, color: Color) -> MeshInstance3D:
	var normals := PackedVector3Array()
	for i in range(0, vertices.size(), 3):
		var normal := (vertices[i + 1] - vertices[i]).cross(vertices[i + 2] - vertices[i]).normalized()
		for j in range(3):
			normals.append(normal)
	var data: Array = []
	data.resize(Mesh.ARRAY_MAX)
	data[Mesh.ARRAY_VERTEX] = vertices
	data[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data)
	var item := MeshInstance3D.new()
	item.mesh = mesh
	var mat := material(color).duplicate() as StandardMaterial3D
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	item.material_override = mat
	parent.add_child(item)
	return item

static func tree(parent: Node3D, pos: Vector3, size_value: float = 1.0, pine: bool = false, tint: int = 0) -> void:
	var node := Node3D.new()
	node.position = pos
	node.scale = Vector3.ONE * size_value
	parent.add_child(node)
	cylinder(node, Vector3(0, 0.85, 0), 0.17, 1.7, Color("78634a"), 0.8, 6)
	var colors := [Color("6e9148"), Color("81a351"), Color("577e48"), Color("94aa5b")]
	var color: Color = colors[posmod(tint, colors.size())]
	if pine:
		for i in range(3):
			cylinder(node, Vector3(0, 1.2 + i * 0.85, 0), 1.15 - i * 0.21, 2.1, color.darkened(i * 0.05), 0, 7)
	else:
		if crown_mesh == null:
			var verts := PackedVector3Array()
			for i in range(7):
				var a := TAU * i / 7
				var b := TAU * (i + 1) / 7
				var p := Vector3(cos(a), 0.4, sin(a))
				var q := Vector3(cos(b), 0.4, sin(b))
				var u := Vector3(cos(a) * 0.78, 1.7, sin(a) * 0.78)
				var v := Vector3(cos(b) * 0.78, 1.7, sin(b) * 0.78)
				verts.append_array([Vector3(0, 0, 0), p, q, p, v, q, p, u, v, u, Vector3(0, 2.2, 0), v])
			var temp := triangles(node, verts, color)
			crown_mesh = temp.mesh
			node.remove_child(temp)
			temp.free()
		var crown := MeshInstance3D.new()
		crown.mesh = crown_mesh
		crown.material_override = material(color)
		crown.position.y = 1.0
		crown.rotation.y = tint * 1.17
		node.add_child(crown)

static func hedge(parent: Node3D, pos: Vector3, size_value: Vector3) -> void:
	box(parent, pos, size_value, Color("66864a"))
	box(parent, pos + Vector3(0, size_value.y * 0.5, 0), Vector3(size_value.x * 0.85, 0.18, size_value.z * 0.85), Color("7e9b53"))

static func bench(parent: Node3D, pos: Vector3, angle: float = 0, scale_value: float = 1.0) -> Node3D:
	var node := Node3D.new()
	node.name = "ParkBench"
	node.position = pos
	node.rotation.y = angle
	node.scale = Vector3.ONE * scale_value
	parent.add_child(node)
	for x in [-0.65, 0.65]:
		box(node, Vector3(x, 0.36, 0), Vector3(0.1, 0.72, 0.5), Color("4d6254"))
	for z in [-0.22, 0.02, 0.26]:
		box(node, Vector3(0, 0.65, z), Vector3(1.7, 0.1, 0.17), Color("aa8756"))
	box(node, Vector3(0, 1.1, -0.3), Vector3(1.7, 0.38, 0.12), Color("aa8756"))
	return node

static func lamp(parent: Node3D, pos: Vector3) -> void:
	cylinder(parent, pos + Vector3(0, 2, 0), 0.055, 4, Color("56646a"), 1, 7)
	box(parent, pos + Vector3(0.2, 4, 0), Vector3(0.5, 0.1, 0.14), Color("58666c"))
	box(parent, pos + Vector3(0.4, 3.96, 0), Vector3(0.32, 0.12, 0.28), Color("edf0dc"))

static func fence(parent: Node3D, pos: Vector3, length: float, angle: float = 0) -> void:
	var node := Node3D.new()
	node.position = pos
	node.rotation.y = angle
	parent.add_child(node)
	box(node, Vector3(0, 0.45, 0), Vector3(length, 0.7, 0.12), Color("c4c2ac"))
	for i in range(int(length / 1.2) + 1):
		box(node, Vector3(-length / 2 + i * 1.2, 0.5, 0), Vector3(0.17, 1, 0.2), Color("d8d4bc"))

static func sign_text(parent: Node3D, pos: Vector3, text_value: String, size_value: int = 60) -> Label3D:
	var label := Label3D.new()
	label.text = text_value
	label.position = pos
	label.font_size = size_value
	label.pixel_size = 0.018
	label.outline_size = 0
	label.modulate = Color("fff9e6")
	parent.add_child(label)
	return label

# Объединение статичных примитивов снижает число вызовов отрисовки.
static func batch(parent: Node3D) -> void:
	var groups: Dictionary = {}
	for child in parent.find_children("*", "MeshInstance3D", true, false):
		if child.has_meta("dynamic"):
			continue
		var key := str(child.mesh.get_instance_id()) + ":" + str(child.material_override.get_instance_id())
		if not groups.has(key):
			groups[key] = {"mesh": child.mesh, "material": child.material_override, "transforms": []}
		groups[key].transforms.append(parent.global_transform.affine_inverse() * child.global_transform)
		child.get_parent().remove_child(child)
		child.free()
	for group in groups.values():
		var instance := MultiMeshInstance3D.new()
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = group.mesh
		multi.instance_count = group.transforms.size()
		for i in range(multi.instance_count):
			multi.set_instance_transform(i, group.transforms[i])
		instance.multimesh = multi
		instance.material_override = group.material
		parent.add_child(instance)
