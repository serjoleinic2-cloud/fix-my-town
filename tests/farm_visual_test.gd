extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func spawn(kind: String) -> Node:
	var holder := Node3D.new()
	var inner := Node3D.new()
	root.add_child(holder)
	holder.add_child(inner)
	var node: Node = load("res://scenes/visuals/%s.tscn" % kind).instantiate()
	inner.add_child(node)
	return node

func run() -> void:
	var pasture := spawn("pasture")
	var yard := spawn("livestock_yard")
	var mill := spawn("mill")
	await process_frame
	if pasture.farm_animals.size() < 4:
		failures.append("pasture must have small animals")
	if yard.farm_animals.is_empty():
		failures.append("livestock yard must have animals")
	var start: Vector3 = pasture.farm_animals[0].node.position
	var moved := false
	for i in range(200):
		pasture._process(0.1)
		if pasture.farm_animals[0].node.position.distance_to(start) > 0.2:
			moved = true
	if not moved:
		failures.append("pasture animals must wander")
	for animal in pasture.farm_animals:
		var home: Vector3 = animal.home
		if absf(animal.node.position.x - home.x) > animal.area + 0.5:
			failures.append("animal left its pen area")
	var before: float = mill.mill_blades.rotation.z
	mill._process(0.5)
	if mill.mill_blades.rotation.z <= before:
		failures.append("mill blades must rotate")
	print("FARM VISUAL CHECKS: ", "PASS" if failures.is_empty() else "FAIL")
	for f in failures:
		print(f)
	quit(0 if failures.is_empty() else 1)
