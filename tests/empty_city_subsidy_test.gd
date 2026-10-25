extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const TerritoryGrid = preload("res://scripts/territory_grid.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var brand_new := Simulation.new()
	var initial_roads := 0
	for row in range(TerritoryGrid.HEIGHT):
		for col in range(TerritoryGrid.WIDTH):
			if brand_new.territory.state_at(col, row) == "road":
				initial_roads += 1
	check(brand_new.buildings.is_empty() and brand_new.territory.buildings.is_empty() and initial_roads == 0, "Normal game construction creates no legacy plots or road grid")
	var previous_city := Simulation.new(true)
	previous_city.save_path = "user://empty_city_subsidy_test.json"
	previous_city.save_game()
	var city := Simulation.new(false)
	city.save_path = previous_city.save_path
	check(city.buildings.is_empty() and city.territory.buildings.is_empty(), "New Game starts from an empty state instead of the legacy test layout")
	city.start_empty_city()
	check(city.city_layout_version == 3 and city.territory.buildings.is_empty(), "New game uses the clean natural-grid layout")
	var only_forest := true
	var road_count := 0
	for row in range(TerritoryGrid.HEIGHT):
		for col in range(TerritoryGrid.WIDTH):
			if city.territory.state_at(col, row) != "forest":
				only_forest = false
			if city.territory.state_at(col, row) == "road":
				road_count += 1
	check(only_forest and road_count == 0 and city.territory.buildings.is_empty() and city.all_buildings().is_empty(), "Clean city has only natural terrain, with no inherited roads or buildings")
	check(city.incidents.is_empty() and city.job == "" and city.fire_assignments().is_empty() and city.police_job.is_empty() and city.construction_job.is_empty(), "Clean city has no incidents or active service/construction assignments")
	# The highlighted centre is reserved for City Hall, which creates the first street ring.
	for row in range(18, 24):
		for col in range(10, 16):
			city.territory.cells[row][col] = "free"
	check(city.territory.place_building(12, 19, "city_hall"), "The first city building is the reserved City Hall")
	var perimeter_is_road := true
	for row in range(18, 22):
		for col in range(11, 15):
			var inside_building := col in [12, 13] and row in [19, 20]
			if not inside_building and city.territory.state_at(col, row) != "road":
				perimeter_is_road = false
	check(perimeter_is_road, "City Hall placement forms roads around its entire footprint")
	city.start_empty_city()
	check(city.budget == 0 and city.income() == 0 and city.can_offer_subsidy(), "Empty city offers a subsidy only at zero budget and zero income")
	city.save_game()
	var restarted := Simulation.new()
	restarted.save_path = city.save_path
	check(restarted.load_game() and restarted.empty_city_mode and restarted.territory.buildings.is_empty() and restarted.all_buildings().is_empty(), "Restarting a New Game does not restore old legacy plots")
	var restart_is_natural := true
	for row in range(TerritoryGrid.HEIGHT):
		for col in range(TerritoryGrid.WIDTH):
			if restarted.territory.state_at(col, row) != "forest":
				restart_is_natural = false
	check(restart_is_natural, "Save/load never calls legacy sync for a clean city")
	check(city.take_subsidy(500), "Player can choose the 500 grant")
	check(city.budget == 500 and city.subsidy_debt == 500 and city.subsidy_threshold == 1000 and city.subsidy_installment == 100, "500 grant creates the correct repayment terms")
	check(not city.can_offer_subsidy() and not city.take_subsidy(1000), "A second grant is blocked while the first debt is outstanding")
	var resumed := Simulation.new(true)
	resumed.save_path = city.save_path
	check(resumed.load_game() and resumed.empty_city_mode and resumed.city_layout_version == 3 and resumed.subsidy_debt == 500 and resumed.subsidy_threshold == 1000, "Empty city layout and subsidy debt survive save/load")
	resumed.buildings[3] = "cafe"
	resumed.subsidy_income_accumulated = 994
	resumed.tick(12.0, false)
	resumed.save_game()
	check(resumed.subsidy_debt == 400 and resumed.subsidy_income_accumulated == 0, "The 1,000 income threshold withholds 100 and resets accrued income")
	check(not resumed.take_subsidy(500), "No repeat subsidy is issued before repayment")
	for _cycle in range(4):
		resumed.subsidy_income_accumulated = 994
		resumed.tick(12.0, false)
	check(resumed.subsidy_debt == 0 and resumed.subsidy_threshold == 0 and resumed.subsidy_income_accumulated == 0, "Installments continue until the original debt is fully paid")

	var larger := Simulation.new(true)
	larger.save_path = "user://empty_city_subsidy_1000_test.json"
	larger.start_empty_city()
	check(larger.take_subsidy(1000), "Player can choose the 1,000 grant")
	check(larger.subsidy_debt == 1000 and larger.subsidy_threshold == 2000 and larger.subsidy_installment == 200, "1,000 grant creates the correct repayment terms")
	larger.buildings[3] = "cafe"
	larger.subsidy_income_accumulated = 1994
	larger.tick(12.0, false)
	larger.save_game()
	check(larger.subsidy_debt == 800 and larger.subsidy_income_accumulated == 0, "The 2,000 income threshold withholds 200")

	var restored := Simulation.new(true)
	restored.save_path = larger.save_path
	check(restored.load_game() and restored.subsidy_debt == 800 and restored.subsidy_threshold == 2000 and restored.subsidy_installment == 200, "Partial 1,000 grant debt continues after restart")
	if failures > 0:
		quit(1)
	else:
		print("Все проверки чистого города и субсидии пройдены.")
		quit(0)
