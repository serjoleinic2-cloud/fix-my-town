extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const Catalog = preload("res://scripts/asset_catalog.gd")
const GameObjectScene = preload("res://scenes/objects/game_object.tscn")

var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for kind in ["fire_station", "fire_engine"]:
		var wrapper: PackedScene = load(Catalog.scene_path(kind))
		check(wrapper != null, "%s resolves through the visual catalog" % kind)
		if wrapper != null:
			var visual: Node3D = GameObjectScene.instantiate()
			root.add_child(visual)
			visual.setup(kind, "fire_test_%s" % kind)
			await process_frame
			check(visual.visual_root.get_child_count() > 0, "%s creates its replaceable VisualRoot model" % kind)
			visual.queue_free()

	var save_path := "user://fire_scenario_test.json"
	var game = Simulation.new()
	game.save_path = save_path
	check(game.start_fire(), "one opening fire starts at its stable house ID")
	check(not game.start_fire(), "the scenario allows only one ignition sequence")
	check(game.fires[Simulation.FIRST_FIRE_TARGET].phase == "warning", "fire begins with a readable warning stage")
	var warning_before: float = game.fire_warning_left(Simulation.FIRST_FIRE_TARGET)
	var offline_reload = Simulation.new()
	offline_reload.save_path = save_path
	check(offline_reload.load_game(), "warning state loads")
	check(is_equal_approx(offline_reload.fire_warning_left(Simulation.FIRST_FIRE_TARGET), warning_before), "closed-game time does not advance the warning")
	for i in range(50):
		offline_reload.tick(1.0, true)
	check(offline_reload.fires.has(Simulation.FIRST_FIRE_NEIGHBOR), "unattended fire warns the neighboring house before spread")
	check(offline_reload.house_damage(Simulation.FIRST_FIRE_TARGET) > 0, "active fire damages only its named building")
	check(offline_reload.fires[Simulation.FIRST_FIRE_NEIGHBOR].phase == "burning", "neighbor warning advances to a spreading fire while ignored")
	check(offline_reload.house_damage(Simulation.FIRST_FIRE_NEIGHBOR) > 0, "spreading fire damages the neighboring property")
	check(offline_reload.record_residents(offline_reload.legacy_record(0)) < game.record_residents(game.legacy_record(0)), "fire damage reduces residents only in affected houses")
	check(offline_reload.income() < game.income(), "fire damage reduces city income")
	offline_reload.save_game()
	check(offline_reload.dispatch_fire(), "fire station can dispatch on the shared road network")
	check(offline_reload.job == "fire" and offline_reload.target_instance_id == Simulation.FIRST_FIRE_TARGET, "fire engine receives the stable target assignment")
	check(offline_reload.depot_instance_id == Simulation.FIRE_STATION_ID and not offline_reload.route.is_empty(), "vehicle keeps its station and planned route")

	var in_transit = Simulation.new()
	in_transit.save_path = save_path
	check(in_transit.load_game(), "active fire departure saves and loads")
	check(in_transit.job == "fire" and in_transit.vehicle.distance_to(offline_reload.vehicle) < 0.001 and in_transit.route.size() == offline_reload.route.size(), "job phase, vehicle and route restore")
	var ticks := 0
	while in_transit.job_phase == "travel" and ticks < 500:
		in_transit.tick(1.0, true)
		ticks += 1
	check(in_transit.job_phase == "repair", "engine travels along the route and reaches the burning property")
	var damage_before := in_transit.house_damage(Simulation.FIRST_FIRE_TARGET)
	check(damage_before > 0, "burning property accumulates damage while the engine is travelling")
	for i in range(5):
		in_transit.tick(1.0, true)
	check(in_transit.fires.is_empty() and in_transit.job_phase == "return", "fire crew extinguishes the incident before returning")
	check(in_transit.route.back().distance_to(Simulation.DistrictWorld.logical_position(in_transit.fire_station_world())) < 0.01, "return route ends at the fire station")

	var returning = Simulation.new()
	returning.save_path = save_path
	check(returning.load_game(), "extinguished damage and return trip load")
	check(returning.job == "fire" and returning.job_phase == "return" and returning.fires.is_empty(), "return assignment survives restart without restarting fire")
	var return_ticks := 0
	while returning.job != "" and return_ticks < 500:
		returning.tick(1.0, true)
		return_ticks += 1
	check(returning.job == "" and returning.depot_instance_id == "pine_district_legacy_2", "fire engine returns and becomes available")
	check(returning.house_damage(Simulation.FIRST_FIRE_TARGET) > 0, "fire leaves recoverable building damage")
	var residents_before := returning.population()
	check(returning.repair_fire_damage(Simulation.FIRST_FIRE_TARGET), "extinguished house can be restored")
	check(returning.population() > residents_before, "repair restores residents affected by damage")
	var final_load = Simulation.new()
	final_load.save_path = save_path
	check(final_load.load_game() and final_load.house_damage(Simulation.FIRST_FIRE_TARGET) == 0, "restoration persists after reload")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + ".tmp"))
	if failures.is_empty():
		print("FIRE SCENARIO CHECKS: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
