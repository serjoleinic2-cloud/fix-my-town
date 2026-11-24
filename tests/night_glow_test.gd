extends SceneTree

const Art = preload("res://scripts/art.gd")
const Simulation = preload("res://scripts/simulation.gd")

var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func visual(kind: String) -> Node:
	var holder := Node3D.new()
	var inner := Node3D.new()
	root.add_child(holder)
	holder.add_child(inner)
	var node: Node = load("res://scenes/visuals/%s.tscn" % kind).instantiate()
	inner.add_child(node)
	return node

func run() -> void:
	Art.night_on = false
	Art.lamps_on = false
	var car := visual("civilian_car")
	var house := visual("house_1") if ResourceLoader.exists("res://scenes/visuals/house_1.tscn") else visual("street_lamp")
	var lamp := visual("street_lamp")
	await process_frame
	var glow_parts := get_nodes_in_group("night_glow")
	var lamp_parts := get_nodes_in_group("night_lamps")
	check(glow_parts.size() >= 5, "A car has headlights, tail lights and a beam")
	check(lamp_parts.size() >= 2, "A street lamp has a bulb and a pool of light")
	check(glow_parts.all(func(node: Node) -> bool: return not (node as Node3D).visible), "Glow parts are off by day")
	Art.night_on = true
	Art.lamps_on = true
	get_nodes_in_group("night_glow").map(func(node: Node) -> void: (node as Node3D).visible = true)
	var new_car := visual("civilian_car")
	await process_frame
	check(new_car.find_children("*", "MeshInstance3D", true, false).any(func(item: Node) -> bool: return item.is_in_group("night_glow") and (item as Node3D).visible), "A vehicle spawned at night starts with its lights on")
	check(Simulation.new(false).lamp_lit(), "Lamps are lit when power is fine")
	if failures.is_empty():
		print("NIGHT GLOW CHECKS: PASS")
		quit(0)
	else:
		print("NIGHT GLOW CHECKS: FAIL")
		for failure in failures:
			push_error(failure)
		quit(1)
