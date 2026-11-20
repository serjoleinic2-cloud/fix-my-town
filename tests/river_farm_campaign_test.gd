extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const Catalog = preload("res://scripts/asset_catalog.gd")

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var suffix := str(Time.get_ticks_usec())
	var save_path := "user://river_farm_campaign_%s.json" % suffix
	var game := Simulation.new(false)
	game.save_path = save_path
	game.start_empty_city()
	game.campaign_stage = 11
	game.territory.set_expansion_level(11)
	check(game.territory.river_frontier_ready(), "Stage 11 exposes a real river frontier before offering the bridge goal")
	check(Catalog.unlock_level("bridge") == 11 and Catalog.unlock_level("field") == 12 and Catalog.unlock_level("mill") == 13 and Catalog.unlock_level("livestock_yard") == 14 and Catalog.unlock_level("farm_warehouse") == 15, "Farming buildings unlock chapter by chapter")
	var site: Vector2i = game.territory.bridge_site
	check(game.territory.place_bridge(site.x, site.y), "The bridge occupies its real river crossing")
	for col in range(game.territory.river_cols.x - 1, game.territory.farm_access_col() + 1):
		check(game.territory.state_at(col, site.y) == "road", "The bridge and farm approach form one continuous road segment")
	var crossing_route := game.territory.road_path(Vector2i(game.territory.river_cols.x - 1, site.y), Vector2i(game.territory.river_cols.y + 1, site.y))
	check(crossing_route.size() == 4 and crossing_route.all(func(cell: Vector2i) -> bool: return cell.y == site.y), "Vehicles cross the river on one straight road row without a sideways detour")
	for col in range(game.territory.river_cols.x, game.territory.river_cols.y + 1):
		check(game.territory.state_at(col, site.y + 1) != "road" and game.territory.is_river_cell(col, site.y + 1), "The obsolete second asphalt row remains river water")
	var bridge := game.territory.building_by_id("pine_district_bridge")
	check(int(bridge.get("width", 0)) == 2 and int(bridge.get("height", 0)) == 1, "Bridge metadata matches its single road corridor")
	check(game.campaign_stage_goal_met(11), "A completed connected bridge completes stage 11")
	game.campaign_complete_pending = true
	game.campaign_completed_stage = 11
	game.continue_campaign()
	check(game.campaign_stage == 12 and not game.campaign_finished, "The campaign continues into the first farming chapter")
	check(game.territory.farm_frontier_ready(), "Stage 12 opens a connected farm street and two prepared construction sites")
	check(not game.campaign_stage_goal_met(12), "Stage 12 is not complete until field and barn actually exist")
	var farm_sites := game.territory.farm_start_sites()
	check(game.territory.farm_site_allowed(farm_sites[0].x, farm_sites[0].y, Vector2i(2, 2)), "Stage 12 has usable farmland on the far bank")
	check(not game.territory.farm_site_allowed(game.territory.river_cols.x - 4, site.y, Vector2i(2, 2)), "Farm buildings cannot appear in the old city")
	var stage12_roads_before := 0
	for row in range(game.territory.HEIGHT):
		for col in range(game.territory.WIDTH):
			stage12_roads_before += int(game.territory.state_at(col, row) == "road")
	check(game.territory.place_building(farm_sites[0].x, farm_sites[0].y, "field"), "A field can use the first highlighted farm site")
	check(game.territory.place_building(farm_sites[1].x, farm_sites[1].y, "barn"), "A barn can use the second highlighted farm site")
	var stage12_roads_after := 0
	for row in range(game.territory.HEIGHT):
		for col in range(game.territory.WIDTH):
			stage12_roads_after += int(game.territory.state_at(col, row) == "road")
	check(stage12_roads_after == stage12_roads_before, "Field and barn do not generate crosswalk and signal rings")
	check(game.campaign_stage_goal_met(12), "Stage 12 completes after both required farm buildings really exist")
	game.campaign_stage = 15
	game.territory.set_expansion_level(15)
	var roads_before_farms := 0
	for row in range(game.territory.HEIGHT):
		for col in range(game.territory.WIDTH):
			roads_before_farms += int(game.territory.state_at(col, row) == "road")
	var campaign_sites := game.territory.farm_campaign_sites()
	var remaining_types := ["mill", "pasture", "livestock_yard", "farm_warehouse"]
	for index in range(remaining_types.size()):
		var farm_site: Vector2i = campaign_sites[index + 2]
		check(game.territory.place_building(farm_site.x, farm_site.y, remaining_types[index]), "%s fits the shared farm street" % remaining_types[index])
	var roads_after_farms := 0
	for row in range(game.territory.HEIGHT):
		for col in range(game.territory.WIDTH):
			roads_after_farms += int(game.territory.state_at(col, row) == "road")
	check(roads_after_farms == roads_before_farms, "Farm buildings use the prepared street without generating crosswalk and signal rings")
	game.acknowledge_campaign_intro()
	var legacy_ring_cell := Vector2i(campaign_sites[0].x - 1, campaign_sites[0].y)
	game.territory.cells[legacy_ring_cell.y][legacy_ring_cell.x] = "road"
	game.territory.river_layout_version = 1
	game.save_game()
	var loaded := Simulation.new(false)
	loaded.save_path = save_path
	check(loaded.load_game(), "The extended campaign save loads")
	check(loaded.campaign_stage == 15 and loaded.campaign_intro_acknowledged_stage == 15 and loaded.territory.bridge_built, "Stage, briefing acknowledgement and bridge survive reload")
	check(loaded.territory.state_at(legacy_ring_cell.x, legacy_ring_cell.y) != "road", "Old saved farm contour roads are removed during layout migration")
	check(loaded.territory.state_at(loaded.territory.farm_access_col(), loaded.territory.bridge_site.y) == "road", "Farm layout migration preserves the shared access street")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + ".tmp"))
	if failures == 0:
		print("RIVER FARM CAMPAIGN TEST PASSED")
	quit(failures)
