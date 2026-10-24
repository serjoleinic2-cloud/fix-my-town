extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const Catalog = preload("res://scripts/asset_catalog.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1

func finish_task(game: RefCounted, seconds: float) -> void:
	game.tick(seconds)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var legacy_game := Simulation.new(true)
	legacy_game.save_path = "user://legacy_upgrade_work_test.json"
	legacy_game.budget = 400
	check(legacy_game.start_legacy_upgrade(16), "Start a legacy-house upgrade worksite")
	legacy_game.tick(2.25)
	var legacy_upgrade_progress := legacy_game.construction_progress()
	legacy_game.save_game()
	var legacy_resume := Simulation.new(true)
	legacy_resume.save_path = legacy_game.save_path
	check(legacy_resume.load_game() and legacy_resume.construction_job.kind == "upgrade_legacy", "Legacy upgrade work restores after restart")
	check(is_equal_approx(legacy_resume.construction_progress(), legacy_upgrade_progress), "Legacy upgrade progress is restored")
	legacy_resume.tick(3.8)
	check(legacy_resume.building_level(16) == 2 and legacy_resume.construction_job.is_empty(), "Legacy house level changes after the saved work finishes")
	DirAccess.remove_absolute(legacy_game.save_path)

	var game := Simulation.new(true)
	game.save_path = "user://construction_work_test.json"
	game.budget = 2000
	for cell in [Vector2i(12, 19), Vector2i(13, 19), Vector2i(12, 20), Vector2i(13, 20)]:
		check(game.clear_grid_cell(cell.x, cell.y), "Prepare the 2×2 construction lot")
	var starting_budget := game.budget
	check(game.start_grid_construction(12, 19, "house"), "Start a grid house worksite")
	check(game.budget == starting_budget - Catalog.cost("house"), "Construction cost is reserved at dispatch")
	check(game.territory.building_at(12, 19).is_empty(), "Lot remains free until work completes")
	check_construction_vehicles_on_roads(game, "Before arrival")
	var excavator_start: Array = game.construction_job.excavator_position.duplicate()
	game.tick(0.4)
	var excavator_moved: Array = game.construction_job.excavator_position
	check(not Vector3(exact_float(excavator_start, 0), exact_float(excavator_start, 1), exact_float(excavator_start, 2)).is_equal_approx(Vector3(exact_float(excavator_moved, 0), exact_float(excavator_moved, 1), exact_float(excavator_moved, 2))), "Excavator visibly approaches the work area")
	check_construction_vehicles_on_roads(game, "During arrival")
	game.tick(1.6)
	var first_progress := game.construction_progress()
	game.save_game()
	var loaded := Simulation.new(true)
	loaded.save_path = game.save_path
	check(loaded.load_game() and loaded.construction_job.kind == "build_grid", "In-progress construction is restored")
	check(is_equal_approx(loaded.construction_progress(), first_progress), "Saved work progress is restored exactly")
	var old_truck: Array = game.construction_job.truck_position
	var loaded_truck: Array = loaded.construction_job.truck_position
	var old_digger: Array = game.construction_job.excavator_position
	var loaded_digger: Array = loaded.construction_job.excavator_position
	check(Vector3(old_truck[0], old_truck[1], old_truck[2]).is_equal_approx(Vector3(loaded_truck[0], loaded_truck[1], loaded_truck[2])) and Vector3(old_digger[0], old_digger[1], old_digger[2]).is_equal_approx(Vector3(loaded_digger[0], loaded_digger[1], loaded_digger[2])), "Both construction vehicle positions survive reload")
	check(loaded.territory.building_at(12, 19).is_empty() and loaded.budget == game.budget, "Reload preserves the reserved budget and unfinished footprint")
	finish_task(loaded, 4.1)
	var house := loaded.territory.building_at(12, 19)
	check(loaded.construction_job.is_empty() and house.type_id == "house", "Work finishes and places the building")
	check(loaded.population() > 0, "Placed house contributes population")
	var identifier := str(house.instance_id)
	var upgrade_budget := loaded.budget
	check(loaded.start_grid_upgrade(identifier), "Start a visible upgrade worksite")
	check(int(loaded.territory.building_by_id(identifier).level) == 1 and loaded.budget == upgrade_budget - Catalog.level_data("house", 1).upgrade_cost, "Upgrade reserves funds but keeps the old level during work")
	loaded.tick(2.0)
	var upgrade_progress := loaded.construction_progress()
	loaded.save_game()
	var upgrade_reload := Simulation.new(true)
	upgrade_reload.save_path = loaded.save_path
	check(upgrade_reload.load_game() and upgrade_reload.construction_job.kind == "upgrade_grid", "Unfinished upgrade restores after a restart")
	check(is_equal_approx(upgrade_reload.construction_progress(), upgrade_progress), "Upgrade progress survives reload")
	upgrade_reload.tick(4.1)
	check(int(upgrade_reload.territory.building_by_id(identifier).level) == 2 and upgrade_reload.construction_job.is_empty(), "Upgrade changes level only when work finishes")
	var before_population := loaded.population()
	before_population = upgrade_reload.population()
	check(upgrade_reload.can_demolish_grid_building(identifier) and upgrade_reload.start_grid_demolition(identifier), "Start demolition from the selected building")
	check(not upgrade_reload.territory.building_by_id(identifier).is_empty(), "Demolition keeps the building in place until completion")
	upgrade_reload.tick(2.5)
	var demolition_progress := upgrade_reload.construction_progress()
	upgrade_reload.save_game()
	var resumed := Simulation.new(true)
	resumed.save_path = upgrade_reload.save_path
	check(resumed.load_game() and resumed.construction_job.kind == "demolish_grid", "Unfinished demolition is restored")
	check(is_equal_approx(resumed.construction_progress(), demolition_progress), "Demolition progress survives reload")
	resumed.tick(3.6)
	check(resumed.territory.building_by_id(identifier).is_empty() and resumed.territory.state_at(12, 19) == "free", "Demolition frees the complete footprint")
	check(resumed.population() < before_population, "Demolition recalculates population immediately")
	check(resumed.start_grid_construction(12, 19, "lawn"), "A freed cell accepts landscaping")
	resumed.tick(6.1)
	check(resumed.territory.building_at(12, 19).type_id == "lawn", "Landscaping is placed after work finishes")
	var lawn_id := str(resumed.territory.building_at(12, 19).instance_id)
	check(resumed.start_grid_demolition(lawn_id), "Landscaping can be demolished from its object card")
	resumed.tick(6.1)
	check(resumed.territory.building_at(12, 19).is_empty(), "Landscaping demolition frees one cell")
	check(Catalog.unlock_level("police_station") == 2 and Catalog.unlock_level("hospital") == 3, "Service buildings use city-level unlocks")
	check(Catalog.is_service("fire_station") and Catalog.is_landscaping("flower_bed"), "Catalog retains stable gameplay types")
	check(not resumed.can_demolish_road(12, 18), "The city connection cannot be severed")
	DirAccess.remove_absolute(game.save_path)
	print("CONSTRUCTION WORK: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

func exact_float(point: Array, index: int) -> float:
	return float(point[index])

func check_construction_vehicles_on_roads(game: RefCounted, phase: String) -> void:
	for vehicle in [["truck_position", "truck_start_position", "truck_target_position"], ["excavator_position", "excavator_start_position", "excavator_target_position"]]:
		var raw: Array = game.construction_job[vehicle[0]]
		var raw_start: Array = game.construction_job[vehicle[1]]
		var raw_target: Array = game.construction_job[vehicle[2]]
		var point := Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
		var start := Vector3(float(raw_start[0]), float(raw_start[1]), float(raw_start[2]))
		var target := Vector3(float(raw_target[0]), float(raw_target[1]), float(raw_target[2]))
		var start_cell: Vector2i = game.territory.nearest_road(start)
		var target_cell: Vector2i = game.territory.nearest_road(target)
		var segment: Vector3 = target - start
		var fraction: float = clampf((point - start).dot(segment) / maxf(0.01, segment.length_squared()), 0.0, 1.0)
		var on_segment: Vector3 = start.lerp(target, fraction)
		check(start_cell.x >= 0 and target_cell.x >= 0 and game.territory.state_at(start_cell.x, start_cell.y) == "road" and game.territory.state_at(target_cell.x, target_cell.y) == "road" and
			(start_cell.x == target_cell.x or start_cell.y == target_cell.y) and point.distance_to(on_segment) <= 0.9,
			"Construction vehicle follows a connected road segment " + phase + ": " + str(vehicle[0]))
