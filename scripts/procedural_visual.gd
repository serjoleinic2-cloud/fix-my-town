extends Node3D

# Сцена-обёртка: здесь будет импортированный GLB вместо примитивов.
@export var visual_type: String = "house"
@export var alternate: bool = false
var windows: Array[MeshInstance3D] = []

func _ready() -> void:
	if visual_type in ["house", "cafe", "depot"]:
		var height := 2.1 if alternate else (1.6 if visual_type == "house" else 1.0)
		var color := Color("d7d6bd") if visual_type == "house" else (Color("e6b18f") if visual_type == "cafe" else Color("8fadb8"))
		if alternate:
			color = Color("cda77d")
		box(Vector3(0, height / 2, 0), Vector3(3, height, 1.3), color)
		box(Vector3(0, height + 0.1, 0), Vector3(3.3, 0.25, 1.6), Color("b56e61") if alternate else Color("607d80"))
		for x in [-0.8, 0.8]:
			windows.append(box(Vector3(x, 0.9, 0.67), Vector3(0.5, 0.5, 0.05), Color("94a9aa")))
	elif visual_type == "park":
		for x in [-1.2, 0, 1.2]:
			box(Vector3(x, 0.5, 0), Vector3(0.2, 1, 0.2), Color("927456"))
			box(Vector3(x, 1.2, 0), Vector3(0.9, 0.9, 0.9), Color("4f936f"))
	elif visual_type == "repair_van":
		box(Vector3(0, 0.45, 0), Vector3(0.8, 0.55, 1.3), Color("699fc8") if alternate else Color("f4d18a"))
		box(Vector3(0, 0.85, 0.2), Vector3(0.7, 0.4, 0.6), Color("e5f2e8"))
		if alternate:
			box(Vector3(0, 1.12, 0), Vector3(0.6, 0.15, 0.2), Color("e7956c"))
		for x in [-0.45, 0.45]:
			for z in [-0.4, 0.4]:
				box(Vector3(x, 0.2, z), Vector3(0.15, 0.3, 0.3), Color("34464e"))
	elif visual_type == "traffic_signal":
		box(Vector3(0, 1, 0), Vector3(0.13, 2, 0.13), Color("3d5153"))
		windows.append(box(Vector3(0, 2, 0), Vector3(0.5, 0.7, 0.4), Color("df9560")))
	elif visual_type == "water_leak":
		for i in range(7):
			box(Vector3(sin(i) * 0.5, 0.4 + i * 0.17, 0), Vector3(0.14, 0.2, 0.14), Color("68cbe2"))

func box(pos: Vector3, size_value: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	instance.material_override = material
	instance.position = pos
	add_child(instance)
	return instance

func set_serviced(value: bool) -> void:
	for window: MeshInstance3D in windows:
		var material := window.material_override as StandardMaterial3D
		if visual_type == "traffic_signal":
			material.albedo_color = Color("77c79a") if value else Color("df9560")
		else:
			material.albedo_color = Color("eaf2c8") if value else Color("94a9aa")
