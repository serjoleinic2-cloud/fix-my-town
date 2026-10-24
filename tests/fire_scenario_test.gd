extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const Catalog = preload("res://scripts/asset_catalog.gd")
const GameObjectScene = preload("res://scenes/objects/game_object.tscn")

var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func build_service(game: RefCounted, col: int, kind: String) -> String:
	for row in [19, 20]:
		for x in [col, col + 1]:
			if game.territory.state_at(x, row) == "forest":
				game.clear_grid_cell(x, row)
	check(game.build_grid_service(col, 19, kind), "Player can build %s on connected cleared land" % kind)
	var entry: Dictionary = game.territory.building_at(col, 19)
	return str(entry.get("instance_id", ""))

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for kind in ["fire_station", "fire_engine", "police_station", "police_car", "ruins"]:
		var wrapper: PackedScene = load(Catalog.scene_path(kind))
		check(wrapper != null, "%s resolves through the visual catalog" % kind)
		if wrapper != null:
			var visual: Node3D = GameObjectScene.instantiate()
			root.add_child(visual)
			visual.setup(kind, "fire_test_%s" % kind)
			await process_frame
			check(visual.visual_root.get_child_count() > 0, "%s creates its replaceable VisualRoot model" % kind)
			visual.queue_free()
	var ruin_test: Node3D = GameObjectScene.instantiate()
	root.add_child(ruin_test)
	ruin_test.setup("house", "ruin_visual_swap")
	ruin_test.set_ruined(true)
	check(ruin_test.type_id == "house" and ruin_test.visual_root.get_child(0).visual_type == "ruins", "Ruin appearance swaps independently of the house gameplay type")
	ruin_test.set_ruined(false)
	check(ruin_test.type_id == "house" and ruin_test.visual_root.get_child(0).visual_type == "house", "Rebuilding restores the house visual without changing its stable ID")
	ruin_test.queue_free()

	var save_path := "user://fire_scenario_test.json"
	var game = Simulation.new()
	game.save_path = save_path
	game.budget = 5000
	game.leak_fixed = true
	game.signal_fixed = true
	var station_id := build_service(game, 12, "fire_station")
	var police_id := build_service(game, 16, "police_station")
	var income_before := game.income()
	check(not game.has_service_building("hospital"), "Unplaced service buildings do not appear automatically")
	check(game.job == "", "Fire warning does not dispatch a vehicle automatically")
	check(game.start_fire(), "Opening incident starts at its stable house ID")
	check(game.fires[Simulation.FIRST_FIRE_TARGET].phase == "warning", "Ignition begins with a visible warning stage")
	var warning_before: float = game.fire_warning_left(Simulation.FIRST_FIRE_TARGET)
	var offline_reload = Simulation.new()
	offline_reload.save_path = save_path
	check(offline_reload.load_game(), "Warning state loads from the player-built station save")
	check(is_equal_approx(offline_reload.fire_warning_left(Simulation.FIRST_FIRE_TARGET), warning_before), "Closed-game time does not advance warning")
	for i in range(70):
		offline_reload.tick(1.0, true)
	check(offline_reload.house_damage(Simulation.FIRST_FIRE_TARGET) > 0, "Fire damages only its named building")
	check(offline_reload.fires.has(Simulation.FIRST_FIRE_NEIGHBOR), "Unattended fire warns a nearby house before spreading")
	check(str(offline_reload.fires.get(Simulation.FIRST_FIRE_NEIGHBOR, {}).get("phase", "")) == "burning", "The warned neighboring house becomes a second burning incident")
	check(offline_reload.house_damage(Simulation.FIRST_FIRE_NEIGHBOR) > 0, "Spreading fire damages the neighboring property")
	check(offline_reload.record_residents(offline_reload.legacy_record(0)) < game.record_residents(game.legacy_record(0)), "Damage reduces residents in affected homes")
	check(offline_reload.income() < income_before, "Fire damage reduces city income")
	check(game.start_fire(Simulation.FIRST_FIRE_NEIGHBOR), "A second house can burn at the same time")
	check(not game.start_fire(Simulation.FIRST_FIRE_TARGET), "One house cannot receive duplicate active fire incidents")
	check(game.fires.size() == 2, "Concurrent fire count is capped at two")
	for identifier in game.fires:
		game.fires[identifier].phase = "burning"
		game.fires[identifier].warning_left = 0.0
		game.fires[identifier].elapsed = 12.0
		game.fires[identifier].spread_checked = true
	game.save_game()
	offline_reload = Simulation.new()
	offline_reload.save_path = save_path
	var loaded_second_scene: bool = offline_reload.load_game()
	check(loaded_second_scene, "Two simultaneous fire states load")
	check(offline_reload.can_dispatch_fire(Simulation.FIRST_FIRE_TARGET), "An available fire engine can be assigned to a selected fire")
	check(offline_reload.dispatch_fire(Simulation.FIRST_FIRE_TARGET), "First fire engine dispatches on the common road network")
	var second_dispatch: bool = offline_reload.dispatch_fire(Simulation.FIRST_FIRE_NEIGHBOR)
	check(second_dispatch, "Second fire engine can dispatch while the first is busy")
	if offline_reload.fire_jobs.has(Simulation.FIRST_FIRE_NEIGHBOR):
		offline_reload.fire_jobs[Simulation.FIRST_FIRE_NEIGHBOR].repair_left = 500.0
	check(offline_reload.job == "fire" and offline_reload.target_instance_id == Simulation.FIRST_FIRE_TARGET, "Primary engine retains its own target")
	check(offline_reload.fire_jobs.has(Simulation.FIRST_FIRE_NEIGHBOR), "Second engine retains its separate target")
	check(offline_reload.fire_assignment(Simulation.FIRST_FIRE_TARGET).vehicle_id != offline_reload.fire_assignment(Simulation.FIRST_FIRE_NEIGHBOR).vehicle_id, "Each burning house receives a different vehicle")
	check(offline_reload.depot_instance_id == station_id and offline_reload.fire_assignment(Simulation.FIRST_FIRE_NEIGHBOR).depot_instance_id == station_id, "Both engines dispatch from the player-built station")
	check(not offline_reload.route.is_empty() and not offline_reload.fire_jobs[Simulation.FIRST_FIRE_NEIGHBOR].route.is_empty(), "Both trucks receive saved road routes")

	offline_reload.save_game()
	var in_transit = Simulation.new()
	in_transit.save_path = save_path
	check(in_transit.load_game(), "Two outbound fire assignments load")
	check(in_transit.fire_jobs.has(Simulation.FIRST_FIRE_NEIGHBOR) and in_transit.route.size() == offline_reload.route.size(), "Both vehicle routes and phases restore")
	var ticks := 0
	while (in_transit.job_phase == "travel" or in_transit.fire_jobs[Simulation.FIRST_FIRE_NEIGHBOR].phase == "travel") and ticks < 400:
		in_transit.tick(1.0, true)
		ticks += 1
	check(in_transit.job_phase == "repair" and in_transit.fire_jobs[Simulation.FIRST_FIRE_NEIGHBOR].phase == "repair", "Both engines arrive at their assigned houses")
	in_transit.repair_left = 4.0
	in_transit.fire_jobs[Simulation.FIRST_FIRE_NEIGHBOR].repair_left = 500.0
	in_transit.save_game()
	check(in_transit.jam_cleared.has(Simulation.FIRST_FIRE_NEIGHBOR) and not in_transit.jam_cleared[Simulation.FIRST_FIRE_NEIGHBOR], "A stationary fire engine occupies its road until police clear it")
	var police_dispatched: bool = in_transit.dispatch_police(Simulation.FIRST_FIRE_NEIGHBOR)
	check(police_dispatched, "Police can be called to a blocked fire location")
	if police_dispatched:
		check(in_transit.police_job.depot_instance_id == police_id, "Police respond from the player-built police station")
	var police_reload = Simulation.new()
	police_reload.save_path = save_path
	var police_loaded: bool = police_reload.load_game() and not police_reload.police_job.is_empty()
	check(police_loaded, "Police route and clearance phase survive reload")
	var police_ticks := 0
	while police_loaded and police_reload.police_job.phase == "travel" and police_ticks < 400:
		police_reload.tick(1.0, true)
		police_ticks += 1
	if police_loaded:
		check(police_reload.police_job.phase == "clearing", "Police reaches the selected roadblock")
		for i in range(4):
			police_reload.tick(1.0, true)
		check(police_reload.jam_cleared[Simulation.FIRST_FIRE_NEIGHBOR], "Police clears the fire-engine blockage")
		check(police_reload.police_job.phase == "return", "Police returns to its own station after clearing the lane")
	var clear_reload = Simulation.new()
	clear_reload.save_path = save_path
	var clear_loaded: bool = clear_reload.load_game()
	check(clear_loaded, "Cleared lane and returning police state restore")
	check(clear_reload.jam_cleared.get(Simulation.FIRST_FIRE_NEIGHBOR, false) and str(clear_reload.police_job.get("phase", "")) == "return", "The completed road clearance persists")
	clear_reload.repair_left = 0.5
	clear_reload.fire_jobs[Simulation.FIRST_FIRE_NEIGHBOR].repair_left = 0.5
	var return_jobs := 0
	while not clear_reload.fire_jobs.is_empty() and return_jobs < 400:
		clear_reload.tick(1.0, true)
		return_jobs += 1
	check(not clear_reload.fires.has(Simulation.FIRST_FIRE_TARGET), "Primary crew extinguishes only its assigned incident")
	check(not clear_reload.fires.has(Simulation.FIRST_FIRE_NEIGHBOR), "Secondary crew extinguishes its own assigned incident")
	check(clear_reload.fire_jobs.is_empty(), "Secondary crew finishes its separate return trip")
	check(clear_reload.house_damage(Simulation.FIRST_FIRE_TARGET) > 0, "Extinguished homes remain damaged and recoverable")
	var damage_stopped := clear_reload.house_damage(Simulation.FIRST_FIRE_TARGET)
	for i in range(5):
		clear_reload.tick(1.0, true)
	check(clear_reload.house_damage(Simulation.FIRST_FIRE_TARGET) == damage_stopped, "Extinguished house stops accumulating damage")
	var damaged_save = Simulation.new()
	damaged_save.save_path = save_path
	check(damaged_save.load_game() and damaged_save.fires.is_empty(), "Extinguished state persists without replaying the incident")
	damaged_save.budget = 5000 # Keep the restoration/upgrade assertions independent of incident accounting.
	var residents_damaged := damaged_save.population()
	check(damaged_save.repair_fire_damage(Simulation.FIRST_FIRE_TARGET), "A player can restore an extinguished home")
	check(damaged_save.population() > residents_damaged, "Restoration returns residents")

	# Ignore a third ignition until it reaches ruin; the result must survive a restart.
	check(damaged_save.start_fire(Simulation.FIRST_FIRE_TARGET), "A repaired home may suffer a later incident")
	check(damaged_save.upgrade(0) and damaged_save.upgrade(0), "A restored home can reach level three before a later fire")
	for i in range(190):
		damaged_save.tick(1.0, true)
	check(damaged_save.is_ruined(Simulation.FIRST_FIRE_TARGET), "100 percent fire damage leaves persistent ruins")
	check(damaged_save.record_residents(damaged_save.legacy_record(0)) == 0, "Destroyed house loses its residents")
	var ruined_load = Simulation.new()
	ruined_load.save_path = save_path
	damaged_save.save_game()
	check(ruined_load.load_game() and ruined_load.is_ruined(Simulation.FIRST_FIRE_TARGET), "Ruins survive save and reload")
	ruined_load.budget = 5000
	check(ruined_load.repair_fire_damage(Simulation.FIRST_FIRE_TARGET), "A ruin starts a visible restoration worksite")
	check(ruined_load.construction_job.get("kind", "") == "restore_legacy", "Ruins use a dedicated restoration construction kind")
	check(ruined_load.is_ruined(Simulation.FIRST_FIRE_TARGET) and ruined_load.building_level(0) == 3, "A ruin stays damaged and keeps its old level until work finishes")
	ruined_load.tick(6.1)
	check(not ruined_load.is_ruined(Simulation.FIRST_FIRE_TARGET), "Restoration removes the ruin state only after construction")
	check(ruined_load.building_level(0) == 1, "A rebuilt ruin returns as a one-storey home")
	check(ruined_load.start_legacy_upgrade(0) and ruined_load.construction_job.get("kind", "") == "upgrade_legacy", "Further improvement is a separate action after restoration")
	ruined_load.tick(6.1)
	check(ruined_load.building_level(0) == 2, "The restored home reaches level two only after a second worksite")
	var final_load = Simulation.new()
	final_load.save_path = save_path
	ruined_load.save_game()
	check(final_load.load_game() and not final_load.is_ruined(Simulation.FIRST_FIRE_TARGET), "Rebuilt home is saved")

	# Grid ruins follow the same two-step rule and never jump directly to level two.
	var grid_save := Simulation.new()
	grid_save.save_path = "user://grid_ruin_restore_test.json"
	grid_save.budget = 5000
	for cell in [Vector2i(12, 19), Vector2i(13, 19), Vector2i(14, 19), Vector2i(15, 19), Vector2i(14, 20), Vector2i(15, 20)]:
		grid_save.clear_grid_cell(cell.x, cell.y)
	grid_save.build_grid_road(12, 19)
	grid_save.build_grid_road(13, 19)
	check(grid_save.build_grid_building(14, 19, "house"), "Grid house can be prepared for ruin restoration")
	var grid_id := str(grid_save.territory.building_at(14, 19).instance_id)
	grid_save.fire_damage[grid_id] = 100.0
	grid_save.fire_ruins[grid_id] = true
	check(not grid_save.start_grid_upgrade(grid_id), "Ruined grid home cannot open an upgrade")
	check(grid_save.repair_fire_damage(grid_id) and grid_save.construction_job.kind == "restore_grid", "Grid ruin opens a visible first-floor restoration")
	grid_save.tick(6.1)
	check(grid_save.territory.building_by_id(grid_id).level == 1 and not grid_save.is_ruined(grid_id), "Grid restoration finishes at level one")
	check(grid_save.start_grid_upgrade(grid_id) and grid_save.territory.building_by_id(grid_id).level == 1, "Level two remains a separate work order")
	grid_save.tick(6.1)
	check(grid_save.territory.building_by_id(grid_id).level == 2, "Grid upgrade reaches level two only after its own work")
	for suffix in ["", ".tmp"]:
		var absolute := ProjectSettings.globalize_path(save_path + suffix)
		if FileAccess.file_exists(absolute):
			DirAccess.remove_absolute(absolute)
	var grid_absolute := ProjectSettings.globalize_path("user://grid_ruin_restore_test.json")
	if FileAccess.file_exists(grid_absolute):
		DirAccess.remove_absolute(grid_absolute)
	if failures.is_empty():
		print("FIRE SCENARIO CHECKS: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
