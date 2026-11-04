extends RefCounted

const Art = preload("res://scripts/art.gd")
const CELL_SIZE := 4.8

static func cleared_color(col: int, row: int) -> Color:
	# A small fixed palette stays stable across reloads and batches cheaply.
	var palette := [Color("bca47c"), Color("c3ab83"), Color("c9b18b"), Color("c0a781")]
	return palette[posmod(col * 17 + row * 31, palette.size())]

static func cleared_tile(parent: Node3D, center: Vector3, col: int, row: int) -> MeshInstance3D:
	return Art.box(parent, center + Vector3(0, 0.012, 0), Vector3(CELL_SIZE, 0.035, CELL_SIZE), cleared_color(col, row))

static func junction_markings(parent: Node3D, center: Vector3, direction: Vector2i) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	var along := Vector3(direction.x, 0, direction.y)
	var across := Vector3(-direction.y, 0, direction.x)
	# Long edges follow vehicle travel; five stripes sit side by side across it.
	for index in range(-2, 3):
		var stripe_center := center + along * 1.72 + across * (index * 0.52) + Vector3(0, 0.23, 0)
		var stripe_size := Vector3(0.80, 0.018, 0.36) if direction.x != 0 else Vector3(0.36, 0.018, 0.80)
		result.append(Art.box(parent, stripe_center, stripe_size, Color("f4f0d8")))
	# The incoming lane stops outside the crossing, with a visible asphalt gap.
	var stop_center := center + along * 2.30 - across * 0.70 + Vector3(0, 0.25, 0)
	var stop_size := Vector3(0.10, 0.02, 1.30) if direction.x != 0 else Vector3(1.30, 0.02, 0.10)
	result.append(Art.box(parent, stop_center, stop_size, Color("f4f0d8")))
	return result
