extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const TerritoryGrid = preload("res://scripts/territory_grid.gd")

var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := Simulation.new(false)
	game.save_path = "user://demolish_rebuild_%s.json" % str(Time.get_ticks_usec())
	game.start_empty_city()
	game.budget = 1000000
	game.campaign_stage = 15
	game.territory.set_expansion_level(15)
	var site := TerritoryGrid.CITY_HALL_SITE
	check(game.has_city_hall(), "City hall exists")
	for cy in range(site.y - 8, site.y + 9):
		for cx in range(site.x - 8, site.x + 9):
			game.territory.clear_cell(cx, cy)
	var placed: Array[Dictionary] = []
	for dy in range(-12, 13):
		for dx in range(-12, 13):
			var col: int = site.x + dx
			var row: int = site.y + dy
			if placed.size() < 8 and game.territory.placement_reason(col, row, "house") == "":
				if game.territory.place_building(col, row, "house"):
					placed.append(game.territory.buildings[game.territory.buildings.size() - 1])
	check(placed.size() >= 4, "Several homes placed (%d)" % placed.size())
	if placed.size() < 4:
		print("DEMOLISH REBUILD CHECKS: FAIL")
		print(failures)
		quit(1)
		return
	var target: Dictionary = placed[placed.size() - 1]
	var col := int(target.col)
	var row := int(target.row)
	var roads_before := 0
	for y in range(row - 1, row + int(target.height) + 1):
		for x in range(col - 1, col + int(target.width) + 1):
			if game.territory.state_at(x, y) == "road":
				roads_before += 1
	check(game.demolish_grid_building(str(target.instance_id)), "Home demolished")
	var free_cells := 0
	for y in range(row, row + int(target.height)):
		for x in range(col, col + int(target.width)):
			if game.territory.state_at(x, y) == "free":
				free_cells += 1
	check(free_cells == int(target.width) * int(target.height), "The plot itself is free")
	# The same lot takes a home again, and every surviving building keeps access.
	check(game.territory.placement_reason(col, row, "house") == "", "The same lot can be rebuilt: " + game.territory.placement_reason(col, row, "house"))
	for entry: Dictionary in game.territory.buildings:
		if entry.type_id in ["lawn", "flower_bed", "street_tree", "bush", "street_lamp"]:
			continue
		check(not game.territory.access_path(entry, Vector2i(12, 18)).is_empty(), "Building keeps access: " + str(entry.instance_id))
	var roads_after := 0
	for y in range(row - 1, row + int(target.height) + 1):
		for x in range(col - 1, col + int(target.width) + 1):
			if game.territory.state_at(x, y) == "road":
				roads_after += 1
	check(roads_after <= roads_before, "Demolition never adds roads")
	print("roads ring before/after: ", roads_before, "/", roads_after)
	print("DEMOLISH REBUILD CHECKS: ", "PASS" if failures.is_empty() else "FAIL")
	for f in failures:
		print(f)
	quit(0 if failures.is_empty() else 1)
