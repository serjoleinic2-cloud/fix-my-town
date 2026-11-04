extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const Grid = preload("res://scripts/territory_grid.gd")
const ObjectScene = preload("res://scenes/objects/game_object.tscn")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var compact := Grid.new()
	compact.initialize_natural_terrain()
	compact.install_starting_city_hall()
	for row in range(19, 21):
		for col in range(9, 11):
			compact.cells[row][col] = "free"
	check(compact.place_building(9, 19, "elite_residence"), "Elite home uses one ordinary cleared lot")
	check(compact.building_at(9, 19).width == 2 and compact.building_at(9, 19).height == 2, "Elite footprint is 2x2")
	var restored_grid := Grid.new()
	check(restored_grid.restore(compact.data()), "Compact elite footprint survives reload")
	var old_city := compact.data()
	old_city.buildings.clear()
	old_city.buildings.append({"type_id": "elite_residence", "instance_id": "old_elite", "col": 3, "row": 3, "width": 4, "height": 4, "level": 1, "inspected": false})
	for row in range(3, 7):
		for col in range(3, 7):
			old_city.cells[row][col] = "occupied"
	check(restored_grid.restore(old_city) and restored_grid.building_by_id("old_elite").width == 4, "Existing 4x4 elite saves remain readable")
	var game := Simulation.new(false)
	game.save_path = "user://feature_transfer_neglect_test.json"
	game.start_empty_city()
	game.budget = 10000
	game.campaign_stage = 3
	for row in range(19, 21):
		for col in range(9, 11):
			game.territory.cells[row][col] = "free"
	check(game.territory.place_building(9, 19, "house"), "Neglect fixture house")
	var home := game.territory.building_at(9, 19)
	var identifier := str(home.instance_id)
	game.housing_neglect[identifier] = 76.0
	game.housing_neglect_clock = 17.0
	game.save_game()
	var loaded := Simulation.new(false)
	loaded.save_path = game.save_path
	check(loaded.load_game() and loaded.housing_neglect_percent(identifier) == 76 and loaded.housing_neglect_clock == 17.0, "Neglect and active-time clock survive reload with no offline decay")
	check(game.advance_housing_neglect(6), "Low quality gradually increases neglect")
	check(home.get("shanty", false) and home.width == 1 and home.height == 1, "Neglect eventually creates one-cell shanty")
	check(game.territory.state_at(10, 20) == "free" and game.territory.state_at(11, 19) == "road", "Shrinking home releases land but preserves roads")
	check(not game.start_grid_upgrade(identifier) and not game.upgrade_grid_house(identifier), "Shanty cannot be upgraded through UI or simulation")
	game.save_game()
	check(loaded.load_game() and loaded.territory.building_by_id(identifier).get("shanty", false), "Shanty survives restart")
	var object := ObjectScene.instantiate()
	root.add_child(object)
	object.setup("house", identifier)
	object.set_neglect_percent(76)
	check(object.visual_root.get_child(0).has_node("NeglectDetails"), "Neglect changes model through VisualRoot")
	object.set_shanty(true)
	check(object.visual_root.get_child(0).visual_type == "shanty", "Shanty wrapper replaces visual without changing identity")
	check(object.type_id == "house" and object.instance_id == identifier, "Shanty keeps gameplay identity")
	object.queue_free()
	var site := ObjectScene.instantiate()
	root.add_child(site)
	site.setup("construction_site", "feature_worksite")
	check(site.visual_root.get_child(0).get_node("TronFence").get_child_count() == 16, "Tall luminous curtain surrounds the material worksite under VisualRoot")
	var tall_panels := 0
	for panel in site.visual_root.get_child(0).get_node("TronFence").get_children():
		if panel.mesh.size.y >= 3.0:
			tall_panels += 1
	check(tall_panels == 8, "Four tall translucent curtains and four posts reach 3.2 metres")
	site.queue_free()
	await process_frame
	DirAccess.remove_absolute(game.save_path)
	print("FEATURE TRANSFER: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
