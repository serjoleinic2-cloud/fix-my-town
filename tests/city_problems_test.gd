extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const TerritoryGrid = preload("res://scripts/territory_grid.gd")
const Catalog = preload("res://scripts/asset_catalog.gd")

var failures: Array[String] = []
const TEST_SAVE := "user://city_problems_isolated_test.json"
const GENERATOR_SAVE := "user://city_problems_generator_test.json"
const HOME_ID := "problem_test_home"

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func make_city(save_path: String = TEST_SAVE) -> RefCounted:
	var game = Simulation.new()
	game.save_path = save_path
	game.start_empty_city()
	game.campaign_stage = 10
	# Construct one connected street beside the starting Hall and valid 2x2 lots.
	for cell in [Vector2i(14, 19), Vector2i(14, 18)]:
		game.territory.cells[cell.y][cell.x] = "road"
	for col in range(14, 25):
		game.territory.cells[18][col] = "road"
	for row in [16, 17]:
		for col in range(15, 17):
			game.territory.cells[row][col] = "free"
		for col in range(18, 20):
			game.territory.cells[row][col] = "free"
		for col in range(21, 23):
			game.territory.cells[row][col] = "free"
	check(game.territory.place_building(15, 16, "house"), "Isolated map has a residential target beside its road")
	check(game.territory.place_building(18, 16, "depot"), "Isolated map has a player-built maintenance depot")
	check(game.territory.place_building(21, 16, "police_station"), "Isolated map has a player-built police station")
	var house: Dictionary = game.territory.building_at(15, 16)
	if not house.is_empty():
		house.instance_id = HOME_ID
	return game

func enable_hooks(game: RefCounted) -> void:
	check(game.enable_isolated_problem_test_hooks(), "Problem injection is enabled only for the isolated test save namespace")

func all_building_record(game: RefCounted, identifier: String) -> Dictionary:
	for entry: Dictionary in game.all_buildings():
		if str(entry.instance_id) == identifier:
			return entry
	return {}

func problem_record(game: RefCounted, identifier: String, kind: String) -> Dictionary:
	var keys: Array = game.incidents.keys()
	for index in range(keys.size() - 1, -1, -1):
		var incident: Dictionary = game.incidents[keys[index]]
		if str(incident.get("target_id", "")) == identifier and str(incident.get("type", "")) == kind:
			return incident
	return {}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var guard = Simulation.new()
	check(not guard.debug_force_problem("leak", HOME_ID), "Forced-event hook refuses the ordinary player save path")
	var empty_city = Simulation.new()
	empty_city.save_path = "user://city_problems_empty_test.json"
	empty_city.start_empty_city()
	empty_city.campaign_stage = 10
	check(empty_city.problem_candidates().is_empty() and not empty_city.generate_incident(), "No event can generate on an empty natural map")
	check(Catalog.TYPES.has("supermarket") and "supermarket" in TerritoryGrid.BUILDINGS and Catalog.unlock_level("supermarket") == 2, "Stage-two grocery store exists as a real buildable type")
	var fire_gate_city = make_city("user://city_problems_fire_gate_test.json")
	check(not fire_gate_city.has_service_building("fire_station"), "Stage-ten test starts without a fire station")
	check(fire_gate_city.problem_candidates().any(func(candidate: Dictionary): return str(candidate.type) == "fire"), "An inhabited residential building can have a fire without a fire station")
	var fire_candidate: Dictionary = fire_gate_city.problem_candidates().filter(func(candidate: Dictionary): return str(candidate.type) == "fire")[0]
	var fire_id := str(fire_candidate.target.instance_id)
	check(fire_gate_city.start_fire(fire_id), "Natural fire lifecycle starts on an occupied home without requiring a station")
	fire_gate_city.tick(18.0)
	fire_gate_city.tick(30.0)
	check(fire_gate_city.house_damage(fire_id) > 0 and fire_gate_city.fires.has(fire_id), "Without firefighters a warned fire continues into damage instead of disappearing")
	check(not fire_gate_city.dispatch_fire(fire_id) and fire_gate_city.fires.has(fire_id), "A missing station prevents fictitious dispatch but never clears the fire")
	var no_crew_city = make_city("user://city_problems_no_crew_test.json")
	no_crew_city.territory.buildings.erase(no_crew_city.territory.building_by_id("pine_district_depot_18_16"))
	no_crew_city.fire_damage[HOME_ID] = 80
	no_crew_city.housing_neglect[HOME_ID] = 95.0
	no_crew_city.advance_housing_neglect(1)
	check(no_crew_city.housing_neglect_percent(HOME_ID) == 20 and not bool(all_building_record(no_crew_city, HOME_ID).get("shanty", false)), "A home cannot collapse before a reachable maintenance crew can be called")
	no_crew_city.housing_neglect.erase(HOME_ID)
	no_crew_city.fire_damage[HOME_ID] = 30
	no_crew_city.advance_housing_neglect(5)
	check(no_crew_city.housing_neglect_percent(HOME_ID) >= 20, "Lack of a maintenance depot no longer freezes deterioration before a warning event")
	enable_hooks(no_crew_city)
	check(no_crew_city.debug_force_problem("neglect", HOME_ID), "A deteriorating home can receive its maintenance warning without a depot")
	no_crew_city.tick_city_problems(75.0)
	var no_service_neglect_before := float(no_crew_city.housing_neglect[HOME_ID])
	no_crew_city.tick_city_problems(60.0)
	check(float(no_crew_city.housing_neglect[HOME_ID]) > no_service_neglect_before and not no_crew_city.dispatch_to_building(HOME_ID), "Without a depot neglect worsens gradually and remains active instead of disappearing")
	var no_police_city = make_city("user://city_problems_no_police_test.json")
	no_police_city.territory.buildings.erase(no_police_city.territory.building_by_id("pine_district_depot_18_16"))
	no_police_city.territory.buildings.erase(no_police_city.territory.building_by_id("pine_district_police_station_21_16"))
	no_police_city.fire_damage[HOME_ID] = 80
	no_police_city.housing_neglect[HOME_ID] = 100.0
	no_police_city.public_discontent_clock = Simulation.DISORDER_MINIMUM_SECONDS
	check(no_police_city.problem_candidates().any(func(candidate: Dictionary): return str(candidate.type) == "strike"), "Long-running unhappiness can create public disorder before a police station is built")
	enable_hooks(no_police_city)
	check(no_police_city.debug_force_problem("strike", HOME_ID), "An isolated no-police city can exercise the disorder lifecycle")
	no_police_city.tick_city_problems(75.0)
	no_police_city.tick_city_problems(60.0)
	var no_police_strike := str(problem_record(no_police_city, HOME_ID, "strike").get("id", ""))
	check(no_police_city.happiness() < 100 and not no_police_city.dispatch_police(no_police_strike) and str(problem_record(no_police_city, HOME_ID, "strike").get("state", "")) == "overdue", "Without police disorder consequences grow and the incident remains for later response")
	var generator = make_city(GENERATOR_SAVE)
	generator.incident_rng.seed = 20261110
	check(generator.generate_incident(), "Stage-10 generator creates one eligible seeded problem")
	var active_generated_count: int = generator.incidents.size() + generator.fires.size()
	check(active_generated_count == 1, "Natural generator creates at most one city problem at a time, including fires")
	var generated: Dictionary = generator.incidents.values()[0] if not generator.incidents.is_empty() else {}
	if generated.is_empty() and not generator.fires.is_empty():
		var generated_fire_id: String = str(generator.fires.keys()[0])
		generated = {"id": generated_fire_id, "type": "fire", "target_id": generated_fire_id}
	check(str(generated.get("type", "")) in ["leak", "supply", "fire"], "Generator chooses only an eligible problem with a real target/cause, including fire before a station exists")
	generator.save_game()
	var generator_reload = Simulation.new()
	generator_reload.save_path = GENERATOR_SAVE
	check(generator_reload.load_game(), "Seeded stage-10 scenario reloads from its isolated save")
	var generated_type := str(generated.get("type", ""))
	var resumed_problem: Dictionary = generator_reload.incidents.get(str(generated.get("id", "")), {})
	if generated_type == "fire":
		resumed_problem = generator_reload.fires.get(str(generated.get("target_id", "")), {})
	check((generated_type == "fire" and not resumed_problem.is_empty()) or (resumed_problem.get("type", "") == generated_type and resumed_problem.get("target_id", "") == generated.get("target_id", "")), "Reload keeps the same event type and target, including the fire-specific save record")
	check(generator.incident_rng.randi() == generator_reload.incident_rng.randi(), "Reload resumes the exact next random choice")
	var game = make_city()
	enable_hooks(game)
	check(game.service_route(HOME_ID).size() >= 2, "Repair crew has a connected route to the test home")
	check(game.food_access_for(game.territory.building_by_id(HOME_ID)) == false, "Home initially lacks food access without a shop or delivery coverage")
	check(game.problem_candidates().any(func(candidate: Dictionary): return str(candidate.type) == "supply"), "Supply shortage becomes eligible only for a housed, uncovered location")
	check(not game.problem_candidates().any(func(candidate: Dictionary): return str(candidate.type) == "leak"), "A maintained home does not receive an unexplained leak")
	game.housing_neglect[HOME_ID] = 20.0
	check(game.problem_candidates().any(func(candidate: Dictionary): return str(candidate.type) == "leak"), "Accumulated maintenance neglect on the connected home enables a leak")
	game.housing_neglect.erase(HOME_ID)
	check(not game.create_problem("leak", HOME_ID), "Natural leak creation rejects a home without the required deterioration")

	# Leak: warning first, then a gradual consequence, then a real maintenance dispatch.
	check(game.debug_force_problem("leak", HOME_ID), "Test-only forced leak starts on a real home")
	check(game.record_water(game.territory.building_by_id(HOME_ID)), "Leak warning does not cut the home's water before the reaction window")
	check(not game.debug_force_problem("supply", HOME_ID), "The active-event cap prevents an incident avalanche")
	game.tick_city_problems(74.0)
	check(int(game.fire_damage.get(HOME_ID, 0)) == 0, "Leak warning gives the player time before damage")
	game.tick_city_problems(1.0)
	check(str(problem_record(game, HOME_ID, "leak").get("state", "")) == "overdue", "Unanswered leak enters the consequence stage after its warning")
	check(not game.record_water(game.territory.building_by_id(HOME_ID)), "Water loss begins only after the leak warning expires")
	game.tick_city_problems(60.0)
	check(int(game.fire_damage.get(HOME_ID, 0)) == 1, "Leak consequence advances gradually after the reaction window")
	check(game.dispatch_to_building(HOME_ID), "Maintenance crew can accept the targeted leak repair")
	game.route_index = game.route.size()
	game.job_phase = "repair"
	game.repair_left = 0.1
	game.tick(1.0, false)
	check(str(problem_record(game, HOME_ID, "leak").get("state", "")) == "resolved", "Finishing the maintenance job resolves its leak")
	check(game.record_water(game.territory.building_by_id(HOME_ID)), "Water is restored when the leak work finishes")
	# Finish the return phase so other service jobs can start.
	game.route_index = game.route.size()
	game.tick(0.1, false)

	# Supply: residents and home quality react, then a nearby shop restores access.
	var residents_before: int = game.record_residents(game.territory.building_by_id(HOME_ID))
	check(game.debug_force_problem("supply", HOME_ID), "Test-only forced supply shortage starts on the home")
	var quality_before: int = game.record_quality(all_building_record(game, HOME_ID)).score
	check(game.record_residents(game.territory.building_by_id(HOME_ID)) == residents_before, "Supply warning gives the player its reaction window before population loss")
	check(game.record_quality(all_building_record(game, HOME_ID)).score == quality_before, "Supply warning gives the player its reaction window before quality loss")
	game.tick_city_problems(75.0)
	check(str(problem_record(game, HOME_ID, "supply").get("state", "")) == "overdue", "Supply starts consequences only after its warning window")
	game.tick_city_problems(60.0)
	check(game.record_residents(game.territory.building_by_id(HOME_ID)) < residents_before, "Ignored supply shortage gradually lowers occupied population")
	check(game.record_quality(all_building_record(game, HOME_ID)).score < quality_before, "Ignored supply shortage gradually lowers home quality")
	for col in [15, 16]:
		game.territory.cells[15][col] = "free"
	game.territory.buildings.append({"type_id": "supermarket", "instance_id": "problem_test_supermarket", "col": 15, "row": 13, "width": 2, "height": 2, "level": 1})
	game.territory.building_by_id("problem_test_supermarket").food_stock = 600.0
	var home_record: Dictionary = game.territory.building_by_id(HOME_ID)
	home_record.position = game.territory.building_center(home_record)
	check(not game.food_access_for(home_record), "A nearby shop without a connected road is not counted as accessible")
	for row in range(13, 18):
		game.territory.cells[row][14] = "road"
	game.territory.invalidate_routing_cache()
	check(game.food_access_for(home_record), "A nearby grocery store provides food access")
	game.territory.building_by_id("problem_test_supermarket").food_stock = 0.0
	check(not game.food_access_for(home_record), "An accessible but empty shop does not satisfy food demand")
	game.territory.building_by_id("problem_test_supermarket").food_stock = 600.0
	check(game.food_access_for(home_record), "Restocking a connected shop restores food access")
	game.tick_city_problems(0.1)
	check(str(problem_record(game, HOME_ID, "supply").get("state", "")) == "resolved", "Restored shop access resolves the shortage")
	check(game.record_quality(all_building_record(game, HOME_ID)).score == quality_before, "Restoring food access prevents a warning-only quality penalty")
	game.territory.buildings.erase(game.territory.building_by_id("problem_test_supermarket"))
	game.territory.buildings.append({"type_id": "logistics_center", "instance_id": "problem_test_logistics", "col": 24, "row": 16, "width": 2, "height": 2, "level": 1})
	game.territory.invalidate_routing_cache()
	check(game.food_access_for(game.territory.building_by_id(HOME_ID)), "Connected logistics delivery coverage also restores food access")
	game.territory.buildings.erase(game.territory.building_by_id("problem_test_logistics"))

	# Neglect: poor home quality and accumulated neglect trigger; maintenance helps but does not conceal the cause.
	game.housing_neglect[HOME_ID] = 30.0
	var neglected_quality: int = game.record_quality(all_building_record(game, HOME_ID)).score
	game.housing_neglect[HOME_ID] = 40.0
	check(game.record_quality(all_building_record(game, HOME_ID)).score < neglected_quality, "Accumulated service neglect gradually lowers visible home quality")
	game.housing_neglect[HOME_ID] = 30.0
	check(game.debug_force_problem("neglect", HOME_ID), "Test-only forced neglect starts for a deteriorating house")
	game.tick_city_problems(75.0)
	var neglect_before := float(game.housing_neglect[HOME_ID])
	game.tick_city_problems(60.0)
	check(float(game.housing_neglect[HOME_ID]) > neglect_before, "Ignoring the warning adds gradual housing neglect")
	check(game.dispatch_to_building(HOME_ID), "Maintenance crew can be dispatched to the neglected home")
	game.route_index = game.route.size()
	game.job_phase = "repair"
	game.repair_left = 0.1
	game.tick(1.0, false)
	check(str(problem_record(game, HOME_ID, "neglect").get("state", "")) == "resolved", "Completed inspection resolves the maintenance event")
	check(float(game.housing_neglect[HOME_ID]) < neglect_before + 10.0, "Maintenance reduces the neglect counter")
	game.route_index = game.route.size()
	game.tick(0.1, false)

	# Police restores order without repairing the low-quality home that caused it.
	game.fire_damage[HOME_ID] = 80
	game.public_discontent_clock = Simulation.DISORDER_MINIMUM_SECONDS
	check(game.problem_candidates().any(func(candidate: Dictionary): return str(candidate.type) == "strike"), "Low district quality plus a police station makes disorder eligible")
	var root_quality_before: int = game.record_quality(all_building_record(game, HOME_ID)).score
	var happiness_before: int = game.happiness()
	check(game.debug_force_problem("strike", HOME_ID), "Test-only forced public disorder starts at an inhabited low-quality home")
	check(game.happiness() == happiness_before, "Disorder warning does not apply consequences before the reaction window")
	game.tick_city_problems(75.0)
	game.tick_city_problems(60.0)
	check(game.happiness() < happiness_before, "Ignored disorder gradually lowers satisfaction after the warning")
	check(game.dispatch_police(str(problem_record(game, HOME_ID, "strike").get("id", ""))), "Police accept the disorder call")
	var strike_id := str(game.police_job.get("incident_id", ""))
	game.police_job.route_index = game.police_job.route.size()
	game.police_job.phase = "clearing"
	game.police_job.clear_left = 0.1
	game.tick(0.2, false)
	check(str(problem_record(game, HOME_ID, "strike").get("state", "")) == "resolved", "Police response ends the public-order incident")
	check(game.record_quality(all_building_record(game, HOME_ID)).score <= root_quality_before, "Police do not repair the root housing problem")
	check(strike_id != "", "Resolved police dispatch retains its target id during the return trip")

	# Fire uses the existing real fire lifecycle and its warning, not a ghost incident record.
	check(game.debug_force_problem("fire", HOME_ID), "Test-only fire hook starts the existing fire lifecycle")
	check(game.fires.has(HOME_ID) and game.fire_warning_left(HOME_ID) > 0, "Fire is a real warned event on the selected residence")
	var fire_warning: float = game.fire_warning_left(HOME_ID)
	check(is_equal_approx(game.fire_warning_left(HOME_ID), fire_warning), "Fire warning remains unchanged until active simulation advances")
	game.fires.erase(HOME_ID)
	check(game.debug_force_problem("supply", HOME_ID), "A new isolated supply event can begin after the previous incident is handled")
	game.tick_city_problems(10.0)
	var saved_reaction_left: float = float(problem_record(game, HOME_ID, "supply").get("reaction_left", -1.0))

	# RNG state must continue after save/load on an isolated path.
	game.save_game()
	var loaded = Simulation.new()
	loaded.save_path = TEST_SAVE
	check(loaded.load_game(), "Stage-10 test city and active event save reload successfully")
	check(loaded.incident_rng.state == game.incident_rng.state, "Random event generator resumes from the saved RNG state")
	check(str(problem_record(loaded, HOME_ID, "supply").get("state", "")) == "new", "Unaccepted event remains new after reload")
	check(is_equal_approx(float(problem_record(loaded, HOME_ID, "supply").get("reaction_left", -1.0)), saved_reaction_left), "Reaction time is saved without offline advancement")
	check(loaded.campaign_stage == 10 and loaded.incidents.size() == game.incidents.size(), "Reload keeps campaign stage and active problem records")
	for path in [TEST_SAVE, GENERATOR_SAVE, "user://city_problems_empty_test.json", "user://city_problems_fire_gate_test.json", "user://city_problems_no_crew_test.json", "user://city_problems_no_police_test.json"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		if FileAccess.file_exists(path + ".tmp"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".tmp"))
	if failures.is_empty():
		print("CITY_PROBLEMS_TEST: all checks passed")
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)
