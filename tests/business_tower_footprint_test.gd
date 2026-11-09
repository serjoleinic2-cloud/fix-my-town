extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const TerritoryGrid = preload("res://scripts/territory_grid.gd")
const Catalog = preload("res://scripts/asset_catalog.gd")

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func finish_construction(game: RefCounted) -> void:
	for _step in range(3):
		if game.construction_job.is_empty():
			break
		game.tick(6.05, false)

func run() -> void:
	check(Catalog.footprint_cells("business_tower") == Vector2i(2, 2), "Business tower uses the common 2x2 grid footprint")
	check(not Catalog.LEVELS.has("business_tower"), "Business tower currently has one tall visual level, not separate upgrade footprints")

	var save_suffix := str(Time.get_ticks_usec())
	var save_path := "user://business_tower_footprint_%s.json" % save_suffix
	var game := Simulation.new(false)
	game.save_path = save_path
	game.start_empty_city()
	game.campaign_stage = 5
	game.budget = 10000
	game.renewal_credits = 0
	for row in range(19, 21):
		for col in range(9, 11):
			game.territory.cells[row][col] = "free"
	check(game.build_grid_building(9, 19, "house"), "Prepare a connected ordinary 2x2 lot")
	check(game.demolish_grid_building("pine_district_house_9_19"), "Demolish the test house without disturbing the city save")
	game.renewal_credits = 0 # The tower must not depend on the unrelated demolition-credit counter.
	check(game.territory.state_at(9, 19) == "free" and game.territory.state_at(10, 20) == "free", "One demolished house frees the complete 2x2 replacement lot")
	check(game.start_grid_construction(9, 19, "business_tower"), "Tower construction accepts the cleared 2x2 replacement parcel")
	check(game.renewal_credits == 0, "Tower construction requires and consumes no demolition credits")
	finish_construction(game)
	var tower := game.territory.building_at(9, 19)
	check(tower.get("type_id", "") == "business_tower" and int(tower.get("width", 0)) == 2 and int(tower.get("height", 0)) == 2, "Completed tower reserves exactly 2x2 cells")
	check(game.campaign_population_count("business_tower") == 1 and game.campaign_stage_goal_met(5) and is_equal_approx(game.campaign_stage_progress(), 1.0), "Stage-five tower objective counts the 2x2 building")
	var occupied_count := 0
	for row in range(19, 22):
		for col in range(9, 12):
			if game.territory.state_at(col, row) == "occupied":
				occupied_count += 1
	check(occupied_count == 4, "No cells outside the 2x2 footprint remain blocked as occupied")
	check(game.territory.building_at(11, 19).is_empty() and game.territory.building_at(9, 21).is_empty(), "Exterior cells do not select the tower")
	game.save_game()
	var loaded := Simulation.new(false)
	loaded.save_path = save_path
	check(loaded.load_game() and loaded.campaign_stage == 5 and loaded.territory.building_by_id(str(tower.instance_id)).width == 2, "Built tower and campaign stage survive a normal save/load")
	check(loaded.campaign_population_count("business_tower") == 1 and loaded.renewal_credits == 0, "Tower quest count and unrelated credits survive save/load")
	var exterior_road_state := loaded.territory.state_at(11, 19)
	check(loaded.demolish_grid_building(str(tower.instance_id)), "A 2x2 tower can be demolished normally")
	var cleared_tower_cells := true
	for row in range(19, 21):
		for col in range(9, 11):
			cleared_tower_cells = cleared_tower_cells and loaded.territory.state_at(col, row) == "free"
	check(cleared_tower_cells and loaded.territory.state_at(11, 19) == exterior_road_state, "Demolition frees only the 2x2 tower and preserves the exterior road")

	# Build an isolated legacy save fixture with a 4x4 tower, then exercise the
	# production load path. The user's save path and city are never opened.
	var legacy_source := Simulation.new(false)
	legacy_source.save_path = "user://business_tower_legacy_source_%s.json" % save_suffix
	legacy_source.start_empty_city()
	legacy_source.campaign_stage = 5
	legacy_source.campaign_elapsed_seconds = 321.0
	legacy_source.budget = 4321
	legacy_source.renewal_credits = 7
	legacy_source.save_game()
	var payload_file := FileAccess.open(legacy_source.save_path, FileAccess.READ)
	var legacy_payload: Dictionary = JSON.parse_string(payload_file.get_as_text())
	payload_file.close()
	var legacy_district: Dictionary = legacy_payload.districts.pine_district
	var tower_id := "legacy_business_tower"
	legacy_district.buildings.append({"type_id": "business_tower", "instance_id": tower_id, "col": 3, "row": 3, "width": 4, "height": 4, "level": 1, "inspected": false})
	for row in range(3, 7):
		for col in range(3, 7):
			legacy_district.cells[row][col] = "occupied"
	legacy_payload.districts.pine_district = legacy_district
	var legacy_path := "user://business_tower_legacy_%s.json" % save_suffix
	var legacy_file := FileAccess.open(legacy_path, FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(legacy_payload))
	legacy_file.close()
	var legacy_loaded := Simulation.new(false)
	legacy_loaded.save_path = legacy_path
	var migrated_ok: bool = legacy_loaded.load_game()
	var migrated_tower: Dictionary = legacy_loaded.territory.building_by_id(tower_id)
	check(migrated_ok and migrated_tower.get("width", 0) == 2 and migrated_tower.get("height", 0) == 2, "A saved 4x4 tower loads and migrates in place to 2x2")
	check(migrated_ok and migrated_tower.get("level", 0) == 1 and legacy_loaded.campaign_stage == 5 and legacy_loaded.campaign_elapsed_seconds == 321.0 and legacy_loaded.budget == 4321, "Legacy load preserves tower identity/level and city progress")
	check(migrated_ok and legacy_loaded.campaign_population_count("business_tower") == 1 and legacy_loaded.campaign_stage_goal_met(5), "Migrated tower still advances the campaign objective")
	check(migrated_ok and legacy_loaded.territory.state_at(5, 5) == "free" and legacy_loaded.territory.state_at(6, 6) == "free", "Legacy tower cells outside the new footprint are released")

	for path in [save_path, legacy_source.save_path, legacy_path]:
		var absolute := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute):
			DirAccess.remove_absolute(absolute)
		if FileAccess.file_exists(absolute + ".tmp"):
			DirAccess.remove_absolute(absolute + ".tmp")
	print("BUSINESS TOWER FOOTPRINT: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
