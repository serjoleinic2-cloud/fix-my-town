extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const Traffic = preload("res://scripts/traffic_system.gd")
const District = preload("res://scripts/district_world.gd")
var failures: int = 0

func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := Simulation.new()
	game.save_path = "user://expansion_scenario_test.json"
	game.budget = 5000
	game.leak_fixed = true
	game.signal_fixed = true
	game.build(3, "cafe")
	game.place_stop(0)
	game.place_stop(5)
	game.start_transit()
	check(game.territory.building_by_id(Simulation.FIRE_STATION_ID).is_empty(), "A new city has no automatically placed fire station")
	var before: Dictionary = game.metrics()
	var roads := [Vector2i(9, 19), Vector2i(9, 20), Vector2i(9, 21), Vector2i(10, 21), Vector2i(11, 21), Vector2i(11, 22)]
	var lots := [Vector2i(10, 19), Vector2i(12, 21)]
	var budget := game.budget
	check(not game.build_grid_road(17, 27) and game.budget == budget, "Invalid placement has no charge")
	for cell in roads:
		check(game.clear_grid_cell(cell.x, cell.y), "Clear a road cell")
		check(game.build_grid_road(cell.x, cell.y), "Build a connected road with a turn")
	for lot in lots:
		for dy in range(2):
			for dx in range(2):
				check(game.clear_grid_cell(lot.x + dx, lot.y + dy), "Clear the whole footprint")
		check(game.build_grid_house(lot.x, lot.y), "Build a home by the new road")
	var near_id: String = game.territory.building_at(10, 19).instance_id
	var far_id: String = game.territory.building_at(12, 21).instance_id
	check(game.metrics().population == before.population + 16 and game.metrics().income == before.income + 2, "Both expansion homes enter the shared economy")
	check(game.transit_metrics().served == before.served + 8 and game.transit_metrics().covered == before.covered + 8, "Only the home within walking distance enters route coverage and demand")
	var weighted := 0
	for record: Dictionary in game.all_buildings():
		weighted += game.record_residents(record) * game.record_quality(record).score
	check(is_equal_approx(game.district_quality(), float(weighted) / game.population()), "District quality includes every home weighted by its residents")
	check(game.upgrade_grid_house(near_id) and game.transit_metrics().served == before.served + 12, "An expansion upgrade immediately recalculates transit demand")
	check(game.dispatch_to_building(far_id), "A crew finds the new road and its return route")
	check(not game.dispatch_to_building(near_id) and not game.demolish_grid_house(far_id), "Crew stays busy and its target cannot be removed")
	var saw_turn := false
	for point: Vector3 in game.route:
		if District.world_position(point).z > 50:
			saw_turn = true
	check(saw_turn, "Service route reaches beyond the new corner")
	var traffic := Traffic.new()
	root.add_child(traffic)
	traffic.build()
	traffic.signal_fixed = true
	traffic.set_active_count(3)
	var saved_phases: Dictionary = {}
	for step in range(12000):
		var phase: String = game.job_phase
		if not saved_phases.has(phase):
			game.save_game()
			var loaded := Simulation.new()
			loaded.save_path = game.save_path
			check(loaded.load_game(), "Reload service phase: " + phase)
			check(loaded.target_instance_id == far_id and loaded.vehicle == game.vehicle and loaded.route == game.route, "Target and exact route persist: " + phase)
			game = loaded
			saved_phases[phase] = true
		traffic.service_active = game.job != ""
		traffic.service_position = District.world_position(game.vehicle)
		traffic.step(0.05)
		game.transit.tick(0.05, traffic)
		var current := District.world_position(game.vehicle)
		var next := District.world_position(game.proposed_vehicle(0.05))
		var intended := current.distance_to(next)
		var fraction := traffic.service_travel_distance(current, next, 0.05) / intended if intended > 0.0001 else 1.0
		game.tick(0.05, true, fraction)
		if game.job == "":
			break
	check(game.job == "" and game.vehicle.is_equal_approx(Vector3(3, 0, -6)), "Crew obeys real traffic lights, works and returns to its own depot")
	check(saved_phases.has("travel") and saved_phases.has("repair") and saved_phases.has("return"), "All service phases have survived reload")
	check(game.territory.building_by_id(far_id).get("inspected", false), "Inspection result persists")
	game.save_game()
	var final := Simulation.new()
	final.save_path = game.save_path
	check(final.load_game() and final.metrics() == game.metrics(), "City economy, quality, route demand and levels reload consistently")
	check(final.territory.building_by_id(near_id).get("level", 1) == 2, "Expansion visual level survives restart")
	var served: int = final.transit_metrics().served
	check(final.demolish_grid_house(near_id) and final.transit_metrics().served == served - 12, "Demolition frees four cells and removes the home's transport demand")
	check(final.territory.state_at(10, 19) == "free", "Expansion footprint is released")
	for dy in range(2):
		for dx in range(2):
			check(final.clear_grid_cell(12 + dx, 19 + dy), "Clear a service-building footprint")
	check(final.build_grid_service(12, 19, "fire_station"), "Player can place a fire station beside a connected road")
	var station: Dictionary = final.territory.building_at(12, 19)
	check(station.type_id == "fire_station" and station.get("service_building", false), "Fire station uses a stable type and a saved footprint")
	check(final.territory.state_at(12, 19) == "occupied" and not final.build_grid_road(12, 19), "Service footprint cannot be overbuilt with a road")
	check(not final.build_grid_house(12, 19), "Service footprint cannot be overbuilt with a house")
	final.save_game()
	var service_reload := Simulation.new()
	service_reload.save_path = game.save_path
	check(service_reload.load_game() and service_reload.territory.building_by_id(station.instance_id).type_id == "fire_station", "Player-built service location survives save and load")
	traffic.queue_free()
	await process_frame
	DirAccess.remove_absolute(game.save_path)
	print("EXPANSION SCENARIO: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
