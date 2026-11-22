extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")

var failures: Array[String] = []
const TEST_SAVE := "user://resident_happiness_test.json"
const HOME_ID := "happiness_test_home"

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func make_city() -> RefCounted:
	var game = Simulation.new()
	game.save_path = TEST_SAVE
	game.start_empty_city()
	game.campaign_stage = 10
	for cell in [Vector2i(14, 19), Vector2i(14, 18)]:
		game.territory.cells[cell.y][cell.x] = "road"
	for col in range(14, 25):
		game.territory.cells[18][col] = "road"
	for row in [16, 17]:
		for col in range(15, 17):
			game.territory.cells[row][col] = "free"
		for col in range(18, 20):
			game.territory.cells[row][col] = "free"
	check(game.territory.place_building(15, 16, "house"), "Test map has a home beside the road")
	var house: Dictionary = game.territory.building_at(15, 16)
	house.instance_id = HOME_ID
	return game

func home_record(game: RefCounted) -> Dictionary:
	for entry: Dictionary in game.all_buildings():
		if str(entry.get("instance_id", "")) == HOME_ID:
			return entry
	return {}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = make_city()
	var home := home_record(game)
	check(not home.is_empty(), "The home is found")
	var before: Dictionary = game.house_happiness(home)
	check(int(before.score) >= 0 and int(before.score) <= 100, "Happiness stays within 0-100")
	check(int(before.parts.base) == 20, "Every home has the base 20 points")
	check(int(before.parts.food) == 0, "A home without a shop has no food points")
	check("food" in game.happiness_issues(before, 3), "Missing food is named as a cause")
	check(game.happiness_label("food") != "", "Every cause has a readable label")
	check(game.territory.place_building(18, 16, "supermarket"), "A supermarket is built beside the road")
	var after: Dictionary = game.house_happiness(home_record(game))
	check(int(after.parts.food) > int(before.parts.food), "A stocked shop nearby raises food points")
	check(int(after.score) > int(before.score), "Food raises total happiness")
	var report: Dictionary = game.district_happiness_report(0)
	check(int(report.score) >= 0 and int(report.score) <= 100, "District happiness is an average between 0 and 100")
	check(int(report.residents) > 0, "The report counts residents")
	game.language = "en"
	check(game.happiness_label("food").begins_with("No food"), "English labels are available")
	print("RESIDENT HAPPINESS CHECKS: ", "PASS" if failures.is_empty() else "FAIL")
	for message in failures:
		push_error(message)
	quit(0 if failures.is_empty() else 1)
