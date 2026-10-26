extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const Catalog = preload("res://scripts/asset_catalog.gd")

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func prepare_footprint(game: RefCounted, col: int, row: int, size: Vector2i) -> void:
	for dy in range(size.y):
		for dx in range(size.x):
			if game.territory.state_at(col + dx, row + dy) == "forest":
				game.territory.cells[row + dy][col + dx] = "free"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := Simulation.new(false)
	game.save_path = "user://logistics_network_test.json"
	game.start_empty_city()
	game.campaign_stage = 6
	game.budget = 20000
	check(Catalog.footprint_cells("logistics_center") == Vector2i(3, 3) and Catalog.footprint_cells("warehouse") == Vector2i(2, 2), "Logistics center is a 3x3 campus and warehouse fits a standard 2x2 lot")
	check(game.can_build_logistics_center() and not game.can_build_warehouse(), "Stage six unlocks one logistics center before warehouses")
	prepare_footprint(game, 8, 17, Vector2i(3, 3))
	check(game.build_grid_building(8, 17, "logistics_center"), "Connected city can build its logistics center")
	var center: Dictionary = game.territory.building_by_id("pine_district_logistics_center_8_17")
	check(not center.is_empty() and game.logistics_warehouse_limit() == 1, "Level-one center authorizes one warehouse")
	prepare_footprint(game, 15, 19, Vector2i(2, 2))
	check(game.can_build_warehouse() and game.build_grid_building(15, 19, "warehouse"), "A warehouse can be built on a connected 2x2 site")
	var warehouse: Dictionary = game.territory.building_by_id("pine_district_warehouse_15_19")
	check(not warehouse.is_empty() and game.territory.road_distance_between_buildings(center, warehouse, game.logistics_center_range()) >= 0, "Warehouse is connected to the dispatch center within its road range")
	check(not game.logistics_vehicle_routes(str(center.instance_id)).is_empty(), "Center dispatch trucks receive a road route to the warehouse")
	check(not game.can_build_warehouse() and not game.logistics_upgrade_allowed(warehouse), "Center level one blocks extra warehouses and warehouse upgrades")
	prepare_footprint(game, 12, 16, Vector2i(2, 2))
	check(game.build_grid_building(12, 16, "house"), "A home can be built beside the local road network")
	check(game.logistics_covered_buildings(warehouse.instance_id).any(func(entry: Dictionary): return entry.instance_id == "pine_district_house_12_16"), "Warehouse coverage follows connected roads and reaches nearby homes")
	check(not game.logistics_vehicle_routes(str(warehouse.instance_id)).is_empty(), "Warehouse delivery trucks receive local road routes")
	check(not game.can_demolish_grid_building(center.instance_id), "A logistics center with active warehouses cannot be removed")
	check(game.upgrade_grid_house(center.instance_id, true), "The logistics center can be upgraded")
	check(game.logistics_warehouse_limit() == 2 and game.can_build_warehouse() and game.logistics_upgrade_allowed(warehouse), "Center level two permits a second warehouse and level-two warehouse upgrades")
	check(game.upgrade_grid_house(warehouse.instance_id, true) and int(game.territory.building_by_id(warehouse.instance_id).level) == 2, "Warehouse upgrade changes its stored level")
	var ui_script: Script = load("res://scripts/main.gd")
	var ui: Node = ui_script.new()
	ui.game = game
	check(ui.catalog_items_for("infrastructure").has("logistics_center") and ui.catalog_items_for("infrastructure").has("warehouse"), "Construction menu exposes logistics buildings")
	ui.free()
	game.save_game()
	var restored := Simulation.new(false)
	restored.save_path = game.save_path
	check(restored.load_game() and restored.logistics_warehouse_limit() == 2 and int(restored.territory.building_by_id(warehouse.instance_id).level) == 2, "Center and warehouse progression survive saving")
	DirAccess.remove_absolute(game.save_path)
	DirAccess.remove_absolute(game.save_path + ".tmp")
	print("LOGISTICS NETWORK CHECKS: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
