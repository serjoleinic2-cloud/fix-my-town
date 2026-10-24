extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const Grid = preload("res://scripts/territory_grid.gd")
var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := Simulation.new()
	game.save_path = "user://territory_grid_test.json"
	var old_buildings: int = game.buildings.count("house") + game.buildings.count("depot")
	var old_population: int = game.population()
	check(game.territory.buildings.size() == old_buildings, "Legacy homes and service building migrate to occupied multi-cell footprints")
	check(game.territory.state_at(12, 18) == "road" and game.territory.state_at(12, 19) == "forest", "Existing district joins a forest expansion edge")
	check(game.territory.data().has("buildings"), "Territory data has persistent building anchors")
	for cell in [Vector2i(12, 19), Vector2i(13, 19), Vector2i(14, 19), Vector2i(14, 20), Vector2i(14, 21), Vector2i(14, 22), Vector2i(15, 21), Vector2i(16, 21), Vector2i(15, 22), Vector2i(16, 22)]:
		check(game.clear_grid_cell(cell.x, cell.y), "Clear forest cell " + str(cell))
	check(not game.build_grid_road(17, 21), "Road cannot start without a connection to the existing district")
	check(game.build_grid_house(15, 21), "A first home can be placed on cleared land and creates its automatic access road")
	check(game.territory.has_constructed_network(), "The first building establishes the automatic road contour")
	check(game.territory.state_at(15, 21) == "occupied" and game.territory.state_at(16, 22) == "occupied", "All footprint cells become occupied")
	check(game.territory.path_to_city(14, 22).size() >= 2, "New neighborhood has a road path back into the city")
	check(game.population() == old_population + 8 and game.income() > 4, "Expansion contributes residents and shared city income")
	game.save_game()
	var grid_roundtrip := Grid.new()
	check(grid_roundtrip.restore(game.territory.data()), "Territory grid round-trips its own data")
	var loaded := Simulation.new()
	loaded.save_path = game.save_path
	check(loaded.load_game(), "Grid city save loads")
	check(loaded.territory.state_at(14, 21) == "road" and loaded.territory.buildings.any(func(entry): return entry.type_id == "house" and entry.col == 15 and entry.row == 21), "Road and building survive reload")
	check(loaded.buildings == game.buildings and loaded.budget == game.budget and loaded.population() == game.population(), "Original district and shared budget survive grid migration")
	var invalid := game.territory.data()
	invalid.cells[19][12] = "lava"
	var rejected := Grid.new()
	check(not rejected.restore(invalid), "Invalid terrain state is rejected")
	DirAccess.remove_absolute(game.save_path)
	print("TERRITORY GRID CHECKS: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
