extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var city := Simulation.new()
	city.save_path = "user://empty_city_subsidy_test.json"
	city.start_empty_city()
	check(city.city_layout_version == 2 and city.territory.buildings.is_empty(), "New game uses the clean natural-grid layout")
	# The first building of a fresh town creates its own connected street ring.
	for row in range(18, 24):
		for col in range(10, 16):
			city.territory.cells[row][col] = "free"
	check(city.territory.place_building(12, 20, "house"), "The first building can be placed on cleared natural land")
	var perimeter_is_road := true
	for row in range(19, 23):
		for col in range(11, 15):
			var inside_building := col in [12, 13] and row in [20, 21]
			if not inside_building and city.territory.state_at(col, row) != "road":
				perimeter_is_road = false
	check(perimeter_is_road, "Building placement forms roads around the entire footprint")
	city.start_empty_city()
	check(city.budget == 0 and city.income() == 0 and city.can_offer_subsidy(), "Empty city offers a subsidy only at zero budget and zero income")
	check(city.take_subsidy(500), "Player can choose the 500 grant")
	check(city.budget == 500 and city.subsidy_debt == 500 and city.subsidy_threshold == 1000 and city.subsidy_installment == 100, "500 grant creates the correct repayment terms")
	check(not city.can_offer_subsidy() and not city.take_subsidy(1000), "A second grant is blocked while the first debt is outstanding")
	var resumed := Simulation.new()
	resumed.save_path = city.save_path
	check(resumed.load_game() and resumed.empty_city_mode and resumed.city_layout_version == 2 and resumed.subsidy_debt == 500 and resumed.subsidy_threshold == 1000, "Empty city layout and subsidy debt survive save/load")
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

	var larger := Simulation.new()
	larger.save_path = "user://empty_city_subsidy_1000_test.json"
	larger.start_empty_city()
	check(larger.take_subsidy(1000), "Player can choose the 1,000 grant")
	check(larger.subsidy_debt == 1000 and larger.subsidy_threshold == 2000 and larger.subsidy_installment == 200, "1,000 grant creates the correct repayment terms")
	larger.buildings[3] = "cafe"
	larger.subsidy_income_accumulated = 1994
	larger.tick(12.0, false)
	larger.save_game()
	check(larger.subsidy_debt == 800 and larger.subsidy_income_accumulated == 0, "The 2,000 income threshold withholds 200")

	var restored := Simulation.new()
	restored.save_path = larger.save_path
	check(restored.load_game() and restored.subsidy_debt == 800 and restored.subsidy_threshold == 2000 and restored.subsidy_installment == 200, "Partial 1,000 grant debt continues after restart")
	if failures > 0:
		quit(1)
	else:
		print("Все проверки чистого города и субсидии пройдены.")
		quit(0)
