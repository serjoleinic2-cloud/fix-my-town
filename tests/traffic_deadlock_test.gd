extends SceneTree

const Traffic = preload("res://scripts/traffic_system.gd")
const TerritoryGrid = preload("res://scripts/territory_grid.gd")
const Transit = preload("res://scripts/transit.gd")

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func add_road(grid: RefCounted, cells: Array) -> void:
	for value in cells:
		var cell: Vector2i = value
		grid.cells[cell.y][cell.x] = "road"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var traffic := Traffic.new()
	root.add_child(traffic)
	traffic.make_cars()
	var a: Dictionary = traffic.vehicles[0]
	var b: Dictionary = traffic.vehicles[1]
	traffic.grid = TerritoryGrid.new()
	traffic.reserve_intersection({"key": "reservation_metadata", "x": 0.0, "z": 0.0}, str(a.id), "H", 1)
	var metadata_reservation: Dictionary = traffic.reservations["reservation_metadata"]
	check(metadata_reservation.get("approach_axis", "") == "H" and int(metadata_reservation.get("direction", 0)) == 1 and metadata_reservation.has("manoeuvre") and metadata_reservation.has("half_extents"), "Intersection reservations retain approach, turn intent and vehicle footprint")
	traffic.reservations.clear()
	traffic.grid = null
	for vehicle: Dictionary in traffic.vehicles:
		vehicle.node.hide()
	var logistics_intersection := {"key": "logistics_conflict", "x": 3.0, "z": 4.0, "unsignalized": true}
	check(traffic.permission(logistics_intersection, "H", "delivery_1", 0.1, 1, Vector2(0.78, 0.52)), "A logistics truck may enter a clear unsignalized junction")
	var logistics_lock: Dictionary = traffic.reservations.get("logistics_conflict", {})
	check(logistics_lock.get("grid_lock", false) and logistics_lock.get("manoeuvre", "") == "external_turn", "A logistics truck reserves the conflict area for its full body and maneuver")
	check(not traffic.permission(logistics_intersection, "V", "delivery_2", 0.1, -1, Vector2(0.78, 0.52)), "A second logistics truck cannot enter an occupied conflict area")
	traffic.release_external_reservations_for_vehicle("delivery_1", Vector3(3.2, 0.22, 4.1))
	traffic.step(10.0)
	check(traffic.reservations.has("logistics_conflict") and traffic.reservations.logistics_conflict.get("entered", false), "An entered truck retains its junction reservation past the short timer")
	traffic.release_external_reservations_for_vehicle("delivery_1", Vector3(7.0, 0.22, 4.1))
	check(not traffic.reservations.has("logistics_conflict"), "The intersection lock releases only after the logistics truck's rear clears")
	traffic.grid = null
	traffic.reservations.clear()
	for vehicle: Dictionary in traffic.vehicles:
		vehicle.node.hide()
	a.node.show()
	b.node.show()
	a.stalled_time = 5.0
	b.stalled_time = 5.0
	a.waiting_reason = "queue"
	b.waiting_reason = "moving_vehicle"
	a.waiting_on = str(b.id)
	b.waiting_on = str(a.id)
	check(traffic._waiting_cycle(str(a.id)).size() == 2, "Mutually blocked vehicles form a confirmed wait-for cycle")
	b.waiting_reason = "signal"
	b.waiting_on = ""
	check(traffic._waiting_cycle(str(a.id)).is_empty(), "A red signal at the head of a queue is not classified as a deadlock")
	b.waiting_reason = "moving_vehicle"
	b.waiting_on = str(a.id)
	for _frame in range(125):
		traffic._update_deadlock_recovery(0.1)
	check(traffic.recovery_vehicle_id != "" and (a.get("recovery_mode", false) != b.get("recovery_mode", false)), "A confirmed deadlock starts one short recovery vehicle at a time")
	traffic.blocking_positions = [{"id": "fixed_worksite", "position": Vector3(0.5, 0.22, 0), "half_extents": Vector2(0.7, 0.7)}]
	var recovery_vehicle: Dictionary = a if a.get("recovery_mode", false) else b
	recovery_vehicle.axis = "H"
	recovery_vehicle.direction = 1
	recovery_vehicle.road = 0.0
	recovery_vehicle.coordinate = 0.0
	check(traffic.travel_distance(recovery_vehicle, 0.2) < 0.01, "Recovery never passes through a fixed construction or incident blocker")

	var layouts: Array[Dictionary] = [
		{"name": "cross", "cells": [Vector2i(20, 20), Vector2i(19, 20), Vector2i(18, 20), Vector2i(21, 20), Vector2i(22, 20), Vector2i(20, 19), Vector2i(20, 18), Vector2i(20, 21), Vector2i(20, 22)], "start": Vector2i(19, 20), "finish": Vector2i(20, 21)},
		{"name": "T", "cells": [Vector2i(30, 30), Vector2i(29, 30), Vector2i(31, 30), Vector2i(30, 29)], "start": Vector2i(29, 30), "finish": Vector2i(30, 29)},
		{"name": "ring", "cells": [Vector2i(40, 40), Vector2i(41, 40), Vector2i(42, 40), Vector2i(40, 41), Vector2i(42, 41), Vector2i(40, 42), Vector2i(41, 42), Vector2i(42, 42)], "start": Vector2i(40, 41), "finish": Vector2i(42, 41)},
		{"name": "logistics_turn", "cells": [Vector2i(50, 50), Vector2i(51, 50), Vector2i(52, 50), Vector2i(52, 51), Vector2i(52, 52)], "start": Vector2i(50, 50), "finish": Vector2i(52, 52)},
		{"name": "stop_near_crossing", "cells": [Vector2i(60, 60), Vector2i(59, 60), Vector2i(61, 60), Vector2i(60, 59), Vector2i(60, 61), Vector2i(60, 62)], "start": Vector2i(59, 60), "finish": Vector2i(60, 62)},
		{"name": "multi_truck_grid", "cells": [Vector2i(70, 70), Vector2i(71, 70), Vector2i(72, 70), Vector2i(73, 70), Vector2i(72, 71), Vector2i(72, 72), Vector2i(71, 72), Vector2i(70, 72), Vector2i(70, 71)], "start": Vector2i(70, 70), "finish": Vector2i(70, 72)}
	]
	var previous_signature := ""
	for layout: Dictionary in layouts:
		var grid := TerritoryGrid.new()
		grid.reset()
		add_road(grid, layout.cells)
		check(not grid.road_path(layout.start, layout.finish).is_empty(), "%s roads remain connected through their intended turn/loop" % layout.name)
		traffic.reservations["stale_%s" % layout.name] = {"actor": "old_vehicle"}
		traffic.deadlock_cycles["old_cycle"] = 3.0
		traffic.configure_grid(grid, 3, false, [])
		check(traffic.reservations.is_empty() and traffic.deadlock_cycles.is_empty(), "%s road changes clear stale intersection and deadlock state" % layout.name)
		if layout.name == "cross":
			var detour_vehicle: Dictionary = traffic.vehicles[0]
			detour_vehicle.cell = Vector2i(20, 20)
			detour_vehicle.previous = Vector2i(19, 20)
			detour_vehicle.waiting_next = Vector2i(20, 19)
			check(traffic._try_cycle_detour([str(detour_vehicle.id)]) and detour_vehicle.waiting_next == Vector2i(21, 20), "A confirmed conflict first tries an open connected-road detour")
		if layout.name == "stop_near_crossing":
			var bus_route := Transit.new()
			bus_route.stops = [{"col": 59, "row": 60}, {"col": 60, "row": 62}]
			check(bus_route.route_for(grid, 0, 1).size() >= 3, "Transit stops beside the crossing remain connected by a multi-cell road route")
		previous_signature = traffic.grid_signature
		var start_positions: Dictionary = {}
		for vehicle: Dictionary in traffic.vehicles:
			if vehicle.node.visible:
				start_positions[str(vehicle.id)] = vehicle.node.position
		for _frame in range(300):
			traffic.step(0.1)
		var moved := false
		for vehicle: Dictionary in traffic.vehicles:
			if not vehicle.node.visible:
				continue
			if vehicle.node.position.distance_to(start_positions.get(str(vehicle.id), vehicle.node.position)) > 0.5:
				moved = true
			var lane_error := absf(vehicle.node.position.z - float(vehicle.road)) if str(vehicle.axis) == "H" else absf(vehicle.node.position.x - float(vehicle.road))
			check(lane_error <= 0.85, "%s traffic stays aligned with its selected lane" % layout.name)
		check(moved, "%s traffic either advances through its layout or reaches a valid short wait" % layout.name)
		check(traffic.grid_signature != "", "%s publishes a current road graph" % layout.name)
	check(not previous_signature.is_empty(), "All representative road layouts were exercised")
	print("TRAFFIC DEADLOCK CHECKS: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
