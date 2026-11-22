extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const Catalog = preload("res://scripts/asset_catalog.gd")

var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check(Catalog.TYPES.has("ambulance"), "The ambulance is in the catalog")
	check(ResourceLoader.exists(str(Catalog.TYPES.ambulance.scene)), "The ambulance scene exists")
	var scene: PackedScene = load(str(Catalog.TYPES.ambulance.scene))
	var holder := Node3D.new()
	var inner := Node3D.new()
	holder.add_child(inner)
	root.add_child(holder)
	var node: Node3D = scene.instantiate()
	inner.add_child(node)
	check(node.get_node_or_null("BeaconRed") != null and node.get_node_or_null("BeaconBlue") != null, "The ambulance has emergency beacons")
	node.set_emergency_lights(true, 0.0)
	print("AMBULANCE DISPATCH CHECKS: ", "PASS" if failures.is_empty() else "FAIL")
	for message in failures:
		push_error(message)
	quit(0 if failures.is_empty() else 1)
