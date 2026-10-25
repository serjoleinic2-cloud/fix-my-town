extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const TerritoryGrid = preload("res://scripts/territory_grid.gd")

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
	var game := Simulation.new(false)
	game.save_path = "user://city_hall_scenario_test.json"
	game.start_empty_city()
	game.budget = 1200
	check(game.territory.buildings.is_empty() and game.all_buildings().is_empty(), "New City has no built objects")
	check(not game.has_city_hall() and game.construction_job.is_empty() and game.fire_assignments().is_empty(), "Clean start creates no City Hall model or work vehicles")
	check(game.territory.placement_reason(12, 19, "clear") == "" and game.territory.placement_reason(9, 20, "clear") == "", "Multiple revealed natural cells can be cleared")
	check(game.territory.placement_reason(16, 20, "clear") == "outside", "Fogged cells cannot be selected for clearing")
	check(not game.start_grid_construction(12, 19, "house"), "No other building can replace the mandatory City Hall")
	check(not game.start_grid_road(12, 18), "Road construction waits for City Hall")
	check(game.start_grid_clear(12, 19), "Start clearing the marked City Hall plot")
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
	check(game.territory.state_at(12, 19) == "free", "Clearing changes only the selected natural cell to buildable ground")
	check(game.construction_job.is_empty(), "First clearing removes machines and road-work signs after they leave")
	for cell in [Vector2i(13, 19), Vector2i(12, 20), Vector2i(13, 20), Vector2i(9, 20), Vector2i(15, 20), Vector2i(12, 17), Vector2i(12, 23)]:
		clear_cell(game, cell.x, cell.y)
	game.save_game()
	var cleared_reload := Simulation.new(false)
	cleared_reload.save_path = game.save_path
	check(cleared_reload.load_game(), "Saved natural clearing data loads")
	for cell in [Vector2i(12, 19), Vector2i(13, 19), Vector2i(12, 20), Vector2i(13, 20), Vector2i(9, 20), Vector2i(15, 20), Vector2i(12, 17), Vector2i(12, 23)]:
		check(cleared_reload.territory.state_at(cell.x, cell.y) == "free", "Cleared cell %d,%d stays buildable after reload" % [cell.x, cell.y])
	game = cleared_reload
	var main_script: Script = load("res://scripts/main.gd")
	var catalog_ui: Node = main_script.new()
	catalog_ui.game = game
	check(catalog_ui.catalog_items_for("residential").has("house"), "Catalog exposes houses")
	check(catalog_ui.catalog_items_for("commercial").has("cafe") and catalog_ui.catalog_items_for("commercial").has("park"), "Catalog exposes café and park")
	var service_items: Array = catalog_ui.catalog_items_for("services")
	check(service_items.has("fire_station") and service_items.has("police_station") and service_items.has("hospital") and service_items.has("depot"), "Catalog exposes all service buildings")
	check(catalog_ui.catalog_items_for("infrastructure").has("city_hall"), "Infrastructure catalog exposes City Hall")
	catalog_ui.catalog_category = "infrastructure"
	catalog_ui.catalog_grid_target = TerritoryGrid.CITY_HALL_SITE
	catalog_ui.select_catalog_item("city_hall")
	check(catalog_ui.territory_tool == "city_hall" and catalog_ui.territory_cell == TerritoryGrid.CITY_HALL_SITE, "Selecting City Hall targets its highlighted central footprint")
	catalog_ui.free()
	check(game.start_grid_construction(12, 19, "city_hall"), "Start the mandatory City Hall build")
	game.tick(6.05, false)
	check(game.has_city_hall(), "City Hall becomes the first built object")
	var hub_roads := 0
	for row in range(18, 22):
		for col in range(11, 15):
			if not (col in [12, 13] and row in [19, 20]) and game.territory.state_at(col, row) == "road":
				hub_roads += 1
	check(hub_roads >= 8 and game.territory.connected_road(12, 18), "City Hall automatically forms its first connected road loop")
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
		ui_again.catalog_grid_target = Vector2i(9, 19)
		ui_again.select_catalog_item(str(choice[1]))
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
