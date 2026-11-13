extends SceneTree

const Traffic = preload("res://scripts/traffic_system.gd")
const Catalog = preload("res://scripts/asset_catalog.gd")

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var traffic := Traffic.new()
	root.add_child(traffic)
	traffic.build()
	traffic.signal_fixed = true
	traffic.set_active_count(0)
	var intersection := {"key": "service_test_junction", "x": -14.4, "z": 0.0, "offset": 0.0, "node": null}
	traffic.intersections = [intersection]
	var center := Vector3(-14.4, 0.22, 0.0)
	var approach := center + Vector3(-8.0, 0.0, 0.0)
	var beyond := center + Vector3(3.0, 0.0, 0.0)
	var vehicle_types := ["fire_engine", "police_car", "ambulance"]

	check(Traffic.service_vehicle_size("fire_engine").is_equal_approx(Catalog.TYPES.fire_engine.footprint), "Fire engine collision dimensions agree with the model footprint")
	check(Traffic.service_vehicle_size("police_car").is_equal_approx(Catalog.TYPES.police_car.footprint), "Police car collision dimensions agree with the model footprint")
	check(Traffic.service_vehicle_size("ambulance") == Vector2(2.0, 3.0), "Ambulance uses a conservative footprint matching its visible body")
	for vehicle_type: String in vehicle_types:
		traffic.reservations.clear()
		traffic.wait_times.clear()
		traffic.blocking_positions.clear()
		traffic.clock = 10.0 # Horizontal approach has red.
		var normal_distance: float = traffic.service_travel_distance(approach, beyond, 0.1, "normal_%s" % vehicle_type, false, "", vehicle_type)
		var priority_distance: float = traffic.service_travel_distance(approach, beyond, 0.1, "emergency_%s" % vehicle_type, true, "", vehicle_type)
		check(priority_distance > normal_distance + 1.0, "%s proceeds on red only for an active emergency call" % vehicle_type)
		var grant: Dictionary = traffic.reservations.get(intersection.key, {})
		check(str(grant.get("actor", "")) == "emergency_%s" % vehicle_type and grant.has("half_extents"), "%s reserves the junction with its own footprint before entering" % vehicle_type)
		check(not traffic.permission(intersection, "H", "ordinary_after_%s" % vehicle_type, 0.1, 1), "Ordinary traffic yields while %s owns the junction reservation" % vehicle_type)

		traffic.reservations.clear()
		var crossing_car: Dictionary = traffic.vehicles[0]
		crossing_car.node.show()
		crossing_car.axis = "V"
		crossing_car.direction = 1
		crossing_car.road = intersection.x + 1.0
		crossing_car.coordinate = intersection.z
		var blocked_distance: float = traffic.service_travel_distance(approach, beyond, 0.1, "blocked_%s" % vehicle_type, true, "", vehicle_type)
		var expected_stop_advance := 8.0 - Traffic.stop_distance_for(vehicle_type)
		check(absf(blocked_distance - expected_stop_advance) < 0.05, "%s safely waits at its vehicle-specific stop distance when the crossing is occupied" % vehicle_type)
		check(not traffic.reservations.has(intersection.key), "%s does not reserve an occupied crossing" % vehicle_type)
		crossing_car.node.hide()

		traffic.reservations.clear()
		crossing_car.node.show()
		crossing_car.axis = "H"
		crossing_car.direction = 1
		crossing_car.road = -1.0
		crossing_car.coordinate = approach.x + 4.0
		crossing_car.spacing = 3.6
		traffic.blocking_positions.clear()
		var car_ahead_distance: float = traffic.service_travel_distance(approach, beyond, 0.1, "following_%s" % vehicle_type, true, "", vehicle_type)
		check(car_ahead_distance >= approach.distance_to(beyond) - 0.02, "%s with an active siren may pass a yielded civilian queue" % vehicle_type)
		crossing_car.node.hide()

		# Release after the rear of the emergency vehicle clears; ordinary green
		# traffic must then be able to use the same junction again.
		traffic.reservations.clear()
		traffic.clock = 10.0
		traffic.service_travel_distance(approach, beyond, 0.1, "release_%s" % vehicle_type, true, "", vehicle_type)
		traffic.service_travel_distance(center + Vector3(0.5, 0, 0), center + Vector3(1.0, 0, 0), 0.1, "release_%s" % vehicle_type, true, "", vehicle_type)
		traffic.service_travel_distance(center + Vector3(5.0, 0, 0), center + Vector3(6.0, 0, 0), 0.1, "release_%s" % vehicle_type, true, "", vehicle_type)
		traffic.clock = 0.0 # Horizontal green.
		traffic.blocking_positions.clear()
		check(traffic.permission(intersection, "H", "ordinary_after_clear_%s" % vehicle_type, 0.1, 1), "%s reservation releases and ordinary traffic resumes" % vehicle_type)

	traffic.queue_free()
	print("EMERGENCY PRIORITY CHECKS: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
