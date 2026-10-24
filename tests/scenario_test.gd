extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const TerritoryGrid = preload("res://scripts/territory_grid.gd")
var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func finish_job(game: RefCounted) -> float:
	var duration := 0.0
	while game.job != "" and duration < 120:
		game.tick(0.1)
		duration += 0.1
	check(game.job == "", "Crew must finish the job")
	return duration

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = Simulation.new(true)
	game.save_path = "user://test_progress.json"
	check(game.buildings.size() == 24, "Expected 24 plots")
	check(game.dispatch("signal"), "Signal dispatch failed")
	check(game.budget == 230, "Signal repair must cost 70")
	check(not game.dispatch("leak"), "Only one job per crew")
	game.tick(2)
	game.language = "en"
	game.save_game()
	var resumed = Simulation.new(true)
	resumed.save_path = game.save_path
	check(resumed.load_game(), "Save must load")
	check(resumed.job == "signal" and resumed.vehicle == game.vehicle, "Active route must resume")
	check(resumed.language == "en", "Language must persist")
	check(resumed.budget == game.budget and resumed.income_clock == game.income_clock, "No offline simulation")
	finish_job(resumed)
	check(resumed.signal_fixed, "Signal must be repaired")
	check(not resumed.dispatch("signal"), "Cannot charge twice for repair")
	check(resumed.dispatch("leak"), "Leak dispatch failed")
	finish_job(resumed)
	check(resumed.leak_fixed, "Leak must be repaired")
	var before: int = resumed.budget
	check(resumed.build(3, "park"), "Park construction failed")
	check(resumed.budget == before - 100, "Park cost")
	check(resumed.completed and resumed.happiness() > 70, "Scenario must complete and improve happiness")
	check(not resumed.build(3, "cafe"), "Cannot build on occupied plot")
	check(not resumed.build(-1, "park"), "Reject invalid plot")
	check(not resumed.build(24, "park"), "Reject invalid plot")
	check(resumed.placement_bonus(9, "cafe") > resumed.placement_bonus(23, "cafe"), "Location must affect bonus")
	var loaded = Simulation.new(true)
	loaded.save_path = game.save_path
	check(loaded.load_game() and loaded.completed and loaded.buildings[3] == "park", "Completed district must persist")
	loaded.budget = 0
	check(not loaded.build(7, "cafe"), "Reject unaffordable construction")
	var slow = Simulation.new(true)
	slow.save_path = "user://test_slow.json"
	slow.dispatch("leak")
	var slow_time := finish_job(slow)
	var fast = Simulation.new(true)
	fast.save_path = "user://test_fast.json"
	fast.signal_fixed = true
	fast.dispatch("leak")
	var fast_time := finish_job(fast)
	check(slow_time > fast_time + 3, "Broken signal must delay vehicle")
	var poor = Simulation.new(true)
	poor.save_path = "user://test_poor.json"
	poor.budget = 0
	check(not poor.dispatch("leak"), "Reject unaffordable dispatch")
	poor.tick(12)
	check(poor.budget == maxi(0, poor.income() - poor.incident_penalty()), "Zero budget recovers only through earned net income")
	var staged = Simulation.new(true)
	staged.save_path = "user://test_phases.json"
	staged.dispatch("leak")
	staged.route_index = staged.route.size()
	staged.vehicle = staged.route[-1]
	staged.job_phase = "repair"
	staged.repair_left = 2.0
	staged.save_game()
	var phase_resume = Simulation.new(true)
	phase_resume.save_path = staged.save_path
	check(phase_resume.load_game() and phase_resume.job_phase == "repair" and phase_resume.repair_left == 2.0, "Repair phase must persist")
	phase_resume.tick(2.1)
	check(phase_resume.leak_fixed and phase_resume.job_phase == "return", "Repair begins return trip")
	var return_resume = Simulation.new(true)
	return_resume.save_path = staged.save_path
	check(return_resume.load_game() and return_resume.job_phase == "return", "Return trip must persist")
	finish_job(return_resume)
	check(return_resume.vehicle == Vector3(3, 0, -6), "Vehicle returns to depot")
	var corrupt := FileAccess.open(game.save_path, FileAccess.WRITE)
	corrupt.store_string('{"version":1,"buildings":[]}')
	corrupt.close()
	check(not game.load_game(), "Reject corrupt save")
	var old_layout := Simulation.new(true)
	old_layout.save_path = "user://test_startup.json"
	old_layout.save_game()
	var old_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(old_layout.save_path))
	old_data.erase("city_layout_version")
	old_data.erase("districts")
	old_data.empty_city_mode = false
	var old_file := FileAccess.open(old_layout.save_path, FileAccess.WRITE)
	old_file.store_string(JSON.stringify(old_data))
	old_file.close()
	var migrated := Simulation.new()
	migrated.save_path = "user://test_startup.json"
	check(migrated.load_game() and not migrated.territory.buildings.is_empty(), "Loading a pre-grid save migrates its legacy plots")
	var scene = load("res://main.tscn").instantiate()
	scene.game.save_path = "user://test_startup.json"
	root.add_child(scene)
	await process_frame
	check(scene.game.empty_city_mode and scene.game.budget == 0 and scene.game.income() == 0, "A clean app start opens a zero-budget empty city")
	var no_legacy_cells := true
	var roads_in_clean_map := 0
	for row in range(TerritoryGrid.HEIGHT):
		for col in range(TerritoryGrid.WIDTH):
			if scene.game.territory.state_at(col, row) != "forest":
				no_legacy_cells = false
			if scene.game.territory.state_at(col, row) == "road":
				roads_in_clean_map += 1
	check(scene.plots.get_child_count() == 0 and scene.car == null and scene.fire_car == null and scene.leak_effect == null, "The clean map does not create legacy plots, service vehicles, or incident effects")
	check(scene.world.get_node_or_null("LeakMarker") == null and scene.world.get_node_or_null("SignalMarker") == null and scene.fire_markers.is_empty(), "The clean map does not create incident markers")
	check(scene.game.district_house_count() == 0 and scene.game.all_buildings().is_empty() and scene.game.territory.buildings.is_empty() and no_legacy_cells and roads_in_clean_map == 0 and scene.game.city_layout_version == 3, "An old saved district migrates to natural terrain without retaining its 24 plots")
	check(scene.scenery.traffic_controller.vehicles.is_empty() and scene.scenery.traffic_controller.intersections.is_empty() and scene.scenery.get_child_count() == 1, "No traffic vehicles, road signals, or legacy scenery are instantiated on clean start")
	var subsidy_card := scene.subsidy_dialog.find_child("SubsidyOfferCard", true, false) as Control
	var subsidy_buttons: Array = scene.subsidy_dialog.find_children("*", "Button", true, false).filter(func(item): return item.text.begins_with("Получить"))
	check(subsidy_card != null and subsidy_buttons.size() == 2 and subsidy_card.get_global_rect().end.y <= scene.screen.size.y, "The startup subsidy options fit inside the phone screen")
	# Проверки изолированы от пользовательского сохранения.
	scene.game = Simulation.new(true)
	scene.game.save_path = "user://test_ui.json"
	# This section still exercises the retained legacy interaction layer, while
	# startup itself is now explicitly verified as an empty natural city.
	scene.scenery.visible = true
	scene.game.empty_city_mode = false
	if scene.subsidy_dialog != null and is_instance_valid(scene.subsidy_dialog):
		scene.subsidy_dialog.hide()
		scene.subsidy_dialog.queue_free()
		scene.subsidy_dialog = null
	scene.refresh()
	check(scene.stats.text.contains("Бюджет"), "Russian UI")
	scene.switch_language()
	check(scene.stats.text.contains("Budget"), "English UI")
	await process_frame
	var routed_click := InputEventMouseButton.new()
	routed_click.button_index = MOUSE_BUTTON_LEFT
	routed_click.pressed = true
	routed_click.position = scene.viewport_point(scene.world.get_node("LeakMarker").position)
	root.push_input(routed_click, true)
	routed_click.pressed = false
	root.push_input(routed_click, true)
	await process_frame
	check(scene.selection_kind == "leak", "Viewport input must select leak marker")
	scene.select_problem("signal")
	scene.dispatch()
	check(scene.game.job == "signal", "UI dispatch")
	finish_job(scene.game)
	scene.select_problem("leak")
	scene.dispatch()
	finish_job(scene.game)
	scene.selected = 3
	scene.selection_kind = "plot"
	scene.construct("cafe")
	check(not scene.game.completed and not scene.game.construction_job.is_empty(), "Construction starts as a saved worksite before the building appears")
	var cafe_task: Dictionary = scene.game.construction_job.duplicate(true)
	scene.game.tick(6.1)
	scene.handle_construction_finish(cafe_task)
	scene.refresh()
	check(scene.game.completed, "UI complete scenario with cafe")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	scene.game.leak_fixed = false
	scene.game.signal_fixed = false
	scene.refresh()
	click.position = scene.camera.unproject_position(scene.map_position(scene.game.plot_position(7))) * scene.viewport_container.stretch_shrink
	scene.map_input(click)
	check(scene.selected == 7, "Map picking")
	click.position = scene.camera.unproject_position(scene.world.get_node("LeakMarker").position) * scene.viewport_container.stretch_shrink
	scene.map_input(click)
	check(scene.selection_kind == "leak", "Leak on map opens action panel")
	click.position = scene.camera.unproject_position(scene.world.get_node("SignalMarker").position) * scene.viewport_container.stretch_shrink
	scene.map_input(click)
	check(scene.selection_kind == "signal", "Signal on map opens action panel")
	# Tap projected roof positions (not ground centers) across the full row set.
	for index in range(24):
		if scene.game.buildings[index] != "house":
			continue
		var roof_tap := InputEventMouseButton.new()
		roof_tap.button_index = MOUSE_BUTTON_LEFT
		roof_tap.position = scene.camera.unproject_position(scene.map_position(scene.game.plot_position(index) + Vector3(0, 4.7, 0))) * scene.viewport_container.stretch_shrink
		scene.map_input(roof_tap)
		check(scene.selected == index and scene.selection_kind == "plot", "Tap on each house roof opens its building card: " + str(index))
		var upgrade: Button = scene.sheet.find_child("UpgradeButton", true, false)
		check(upgrade != null and not upgrade.disabled, "Each house exposes its improvement action: " + str(index))
		if upgrade != null:
			upgrade.pressed.emit()
			await process_frame
			check(scene.selection_kind == "upgrade", "House upgrade action opens its confirmation preview: " + str(index))
			scene.cancel_upgrade()
	for path in [staged.save_path, game.save_path, slow.save_path, fast.save_path, poor.save_path, scene.game.save_path]:
		DirAccess.remove_absolute(path)
	scene.set_process(false)
	scene.audio.shutdown()
	await create_timer(0.2).timeout
	scene.queue_free()
	await process_frame
	print("SCENARIO CHECKS: ", "PASS" if failures == 0 else "FAIL", " | slow=", slow_time, " fast=", fast_time)
	quit(0 if failures == 0 else 1)
