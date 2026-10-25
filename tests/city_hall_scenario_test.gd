extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const TerritoryGrid = preload("res://scripts/territory_grid.gd")
const Catalog = preload("res://scripts/asset_catalog.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1

func finish_work(game: RefCounted) -> void:
	game.tick(6.05, false)
	if not game.construction_job.is_empty():
		game.tick(1.3, false)

func clear_cell(game: RefCounted, col: int, row: int) -> void:
	if game.territory.state_at(col, row) == "forest":
		check(game.clear_grid_cell(col, row), "Clear revealed cell %d,%d" % [col, row])

func build_type(game: RefCounted, col: int, row: int, type_id: String) -> void:
	var size := Vector2i(1, 1) if type_id in ["lawn", "flower_bed", "street_tree", "bush"] else Vector2i(2, 2)
	for dy in range(size.y):
		for dx in range(size.x):
			clear_cell(game, col + dx, row + dy)
	check(game.start_grid_construction(col, row, type_id), "Start actual %s construction at %d,%d" % [type_id, col, row])
	finish_work(game)
	check(game.construction_job.is_empty(), "%s work and vehicle departure finish" % type_id)
	check(game.territory.building_at(col, row).get("type_id", "") == type_id, "%s is placed in the selected footprint" % type_id)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var campaign_contract := Simulation.new(false)
	campaign_contract.start_empty_city()
	check(campaign_contract.campaign_stage == 1 and not campaign_contract.campaign_stage_goal_met(), "A fresh city begins at campaign stage one with no completed objectives")
	check(campaign_contract.campaign_stars_for_time(600.0) == 3 and campaign_contract.campaign_stars_for_time(601.0) == 2 and campaign_contract.campaign_stars_for_time(1801.0) == 1, "Stage time converts to the intended three/two/one-star rating")
	check(Catalog.footprint_cells("elite_residence") == Vector2i(4, 4) and Catalog.footprint_cells("business_tower") == Vector2i(4, 4), "Elite buildings reserve a 4x4-cell site")
	campaign_contract.territory.buildings.append({"type_id": "elite_residence", "instance_id": "test_elite", "col": 5, "row": 5, "width": 4, "height": 4})
	campaign_contract.territory.buildings.append({"type_id": "business_tower", "instance_id": "test_tower", "col": 12, "row": 5, "width": 4, "height": 4})
	check(campaign_contract.fire_service_duration("test_elite") == 8.0 and campaign_contract.fire_service_duration("test_tower") == 12.0, "Fire response takes longer for elite residences and towers")
	campaign_contract.territory.buildings.clear()
	campaign_contract.campaign_stage = 4
	campaign_contract.campaign_elapsed_seconds = 245.0
	campaign_contract.campaign_complete_pending = true
	campaign_contract.campaign_completed_stage = 3
	campaign_contract.campaign_star_rating = 2
	campaign_contract.renewal_credits = 1
	campaign_contract.save_path = "user://campaign_state_test.json"
	campaign_contract.save_game()
	var campaign_reload := Simulation.new(false)
	campaign_reload.save_path = campaign_contract.save_path
	check(campaign_reload.load_game() and campaign_reload.campaign_stage == 4 and campaign_reload.campaign_elapsed_seconds == 245.0 and campaign_reload.campaign_complete_pending and campaign_reload.campaign_star_rating == 2 and campaign_reload.renewal_credits == 1, "Campaign stage, clock, result and renewal credit survive saving")
	DirAccess.remove_absolute(campaign_contract.save_path)
	DirAccess.remove_absolute(campaign_contract.save_path + ".tmp")
	var game := Simulation.new(false)
	game.save_path = "user://city_hall_scenario_test.json"
	game.start_empty_city()
	game.budget = 1200
	check(game.has_city_hall() and game.territory.buildings.size() == 1 and game.construction_job.is_empty() and game.fire_assignments().is_empty(), "New City starts with a permanent City Hall and no work vehicles")
	check(game.territory.placement_reason(9, 20, "clear") == "" and game.territory.placement_reason(15, 20, "clear") == "", "Nearby frontier cells can be prepared")
	check(game.territory.placement_reason(17, 20, "clear") == "outside", "Fogged cells cannot be selected for clearing")
	check(not game.start_grid_construction(12, 19, "house"), "The starting City Hall cannot be replaced")
	for row in [19, 20]:
		for col in [8, 9]:
			game.territory.cells[row][col] = "free"
	check(game.territory.placement_reason(8, 19, "house") == "no_road", "A cleared but disconnected lot cannot be built on")
	for row in [19, 20]:
		for col in [8, 9]:
			game.territory.cells[row][col] = "forest"
	check(game.start_grid_clear(10, 19), "Start clearing a nearby expansion cell")
	var start_position: Array = game.construction_job.excavator_position.duplicate()
	game.tick(0.35, false)
	var moving_position: Array = game.construction_job.excavator_position
	check(not Vector3(start_position[0], start_position[1], start_position[2]).is_equal_approx(Vector3(moving_position[0], moving_position[1], moving_position[2])), "Work vehicle visibly arrives at the first plot")
	game.save_game()
	var resume := Simulation.new(false)
	resume.save_path = game.save_path
	check(resume.load_game() and resume.construction_job.kind == "clear", "Unfinished clearing and vehicle route restore after reload")
	game = resume
	finish_work(game)
	check(game.territory.state_at(10, 19) == "free", "Clearing changes only the selected natural cell to buildable ground")
	check(game.construction_job.is_empty(), "First clearing removes machines and road-work signs after they leave")
	for cell in [Vector2i(9, 19), Vector2i(9, 20), Vector2i(10, 20), Vector2i(15, 20), Vector2i(12, 17), Vector2i(12, 23)]:
		clear_cell(game, cell.x, cell.y)
	game.save_game()
	var cleared_reload := Simulation.new(false)
	cleared_reload.save_path = game.save_path
	check(cleared_reload.load_game(), "Saved natural clearing data loads")
	for cell in [Vector2i(9, 19), Vector2i(10, 19), Vector2i(9, 20), Vector2i(10, 20), Vector2i(15, 20), Vector2i(12, 17), Vector2i(12, 23)]:
		check(cleared_reload.territory.state_at(cell.x, cell.y) == "free", "Cleared cell %d,%d stays buildable after reload" % [cell.x, cell.y])
	game = cleared_reload
	var main_script: Script = load("res://scripts/main.gd")
	var catalog_ui: Node = main_script.new()
	catalog_ui.game = game
	check(catalog_ui.catalog_items_for("residential").has("house"), "Catalog exposes houses")
	check(catalog_ui.catalog_items_for("commercial").has("cafe") and catalog_ui.catalog_items_for("commercial").has("park"), "Catalog exposes café and park")
	var service_items: Array = catalog_ui.catalog_items_for("services")
	check(service_items.has("fire_station") and service_items.has("police_station") and service_items.has("hospital") and service_items.has("depot"), "Catalog exposes all service buildings")
	check(not catalog_ui.catalog_items_for("infrastructure").has("city_hall"), "The permanent City Hall is not offered as a construction item")
	catalog_ui.free()
	var hub_roads := 0
	for row in range(18, 22):
		for col in range(11, 15):
			if not (col in [12, 13] and row in [19, 20]) and game.territory.state_at(col, row) == "road":
				hub_roads += 1
	check(hub_roads == 12 and game.territory.connected_road(12, 18), "City Hall starts with a complete connected road loop")
	check(not game.can_demolish_grid_building("pine_district_city_hall_12_19"), "The city growth centre cannot be demolished")
	game.save_game()
	var hub_reload := Simulation.new(false)
	hub_reload.save_path = game.save_path
	check(hub_reload.load_game() and hub_reload.has_city_hall(), "City Hall and its road loop survive reload")
	if not hub_reload.construction_job.is_empty():
		check(hub_reload.construction_job.kind == "departing", "Vehicle departure phase is saved separately")
		finish_work(hub_reload)
	game = hub_reload
	check(game.territory.is_revealed(9, 19) and game.territory.is_revealed(15, 20), "The initial frontier is revealed outward from City Hall and its road loop")
	var ui_again: Node = main_script.new()
	ui_again.game = game
	var choices := [["residential", "house"], ["commercial", "cafe"], ["commercial", "park"], ["services", "fire_station"], ["services", "depot"]]
	for choice: Array in choices:
		ui_again.catalog_category = str(choice[0])
		ui_again.catalog_screen_mode = "items"
		ui_again.catalog_grid_target = Vector2i(9, 19)
		ui_again.select_catalog_item(str(choice[1]))
		check(ui_again.selection_kind == "catalog_detail" and ui_again.selected_catalog_type == str(choice[1]), "Catalog item opens details for %s" % str(choice[1]))
		ui_again.begin_catalog_placement(str(choice[1]))
		check(ui_again.territory_tool == str(choice[1]) and ui_again.selection_kind == "territory", "Catalog selection starts grid placement for %s" % str(choice[1]))
	ui_again.free()
	build_type(game, 9, 19, "house")
	check(game.population() > 0, "New house enters population calculations")
	check(game.territory.is_revealed(6, 19), "New building reveals the next area outward")
	build_type(game, 6, 19, "cafe")
	build_type(game, 3, 19, "park")
	build_type(game, 9, 22, "fire_station")
	check(game.has_service_building("fire_station") and game.district_house_count() == 1, "Service and residential buildings are both retained in the town")
	check(game.all_buildings().size() == 5, "City Hall, house, café, park and service coexist")
	check(game.territory.placement_reason(50, 50, "clear") == "outside", "Hidden land beyond the town remains locked")
	DirAccess.remove_absolute(game.save_path)
	print("CITY HALL AND BUILDING FLOW: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
