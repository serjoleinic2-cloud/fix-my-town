extends SceneTree

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	scene.game.save_path = "user://territory_redraw_signature_test.json"
	DirAccess.remove_absolute(scene.game.save_path)
	root.add_child(scene)
	await process_frame
	var initial_redraws: int = scene.territory_full_redraw_count
	check(initial_redraws >= 1, "Initial map construction performs one full redraw")
	var hall: Dictionary = scene.game.territory.building_by_id("pine_district_city_hall_12_19")
	check(not hall.is_empty(), "Test city has a visual building")
	hall["diagnostic_nonvisual_value"] = 42
	scene.redraw_territory()
	check(scene.territory_full_redraw_count == initial_redraws, "Non-visual building data does not rebuild the territory")
	scene.game.budget += 500
	scene.game.income_clock += 1.0
	scene.game.subsidy_income_accumulated += 25
	scene.redraw_territory()
	check(scene.territory_full_redraw_count == initial_redraws, "Budget and accrued income data do not rebuild the territory")
	var state_updates_before: int = scene.territory_state_update_count
	scene.game.fire_ruins[str(hall.instance_id)] = true
	scene.redraw_territory()
	check(scene.territory_full_redraw_count == initial_redraws, "A ruin updates its existing building without rebuilding roads and terrain")
	check(scene.territory_state_update_count == state_updates_before + 1, "A ruin still updates the visible building state")
	var map_redraws_before: int = scene.territory_full_redraw_count
	scene.game.territory.cells[0][0] = "road"
	scene.redraw_territory()
	check(scene.territory_full_redraw_count == map_redraws_before + 1, "A road change rebuilds the territory")
	map_redraws_before = scene.territory_full_redraw_count
	scene.game.territory.cells[2][2] = "occupied"
	scene.game.territory.buildings.append({"instance_id": "redraw_test_lawn", "type_id": "lawn", "col": 2, "row": 2, "width": 1, "height": 1, "level": 1})
	scene.redraw_territory()
	check(scene.territory_full_redraw_count == map_redraws_before + 1, "A building placement rebuilds the territory")
	map_redraws_before = scene.territory_full_redraw_count
	scene.game.territory.revealed[0][1] = not bool(scene.game.territory.revealed[0][1])
	scene.redraw_territory()
	check(scene.territory_full_redraw_count == map_redraws_before + 1, "A fog visibility change rebuilds the territory")
	map_redraws_before = scene.territory_full_redraw_count
	scene.game.territory.set_expansion_level(2)
	scene.redraw_territory()
	check(scene.territory_full_redraw_count == map_redraws_before + 1, "An expansion level change rebuilds the territory")
	root.remove_child(scene)
	scene.free()
	DirAccess.remove_absolute("user://territory_redraw_signature_test.json")
	DirAccess.remove_absolute("user://territory_redraw_signature_test.json.tmp")
	print("Territory redraw signature checks passed.")
	quit(1 if failures > 0 else 0)
