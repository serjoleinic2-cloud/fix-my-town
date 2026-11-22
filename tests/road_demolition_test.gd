extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")

var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = Simulation.new()
	game.save_path = "user://road_demolition_test.json"
	game.start_empty_city()
	game.campaign_stage = 10
	for cell in [Vector2i(14, 19), Vector2i(14, 18)]:
		game.territory.cells[cell.y][cell.x] = "road"
	for col in range(14, 25):
		game.territory.cells[18][col] = "road"
	for row in [16, 17]:
		for col in range(15, 17):
			game.territory.cells[row][col] = "free"
	check(game.territory.place_building(15, 16, "house"), "A home stands beside the road")
	check(game.road_demolition_block_reason(24, 18) == "", "A free dead-end road cell can be demolished")
	check(game.road_demolition_block_reason(14, 18) != "", "A road that connects the home to the hall cannot be demolished")
	check(game.road_demolition_block_reason(5, 5) == "not_road", "A non-road cell is reported as such")
	print("ROAD DEMOLITION CHECKS: ", "PASS" if failures.is_empty() else "FAIL")
	for message in failures:
		push_error(message)
	quit(0 if failures.is_empty() else 1)
