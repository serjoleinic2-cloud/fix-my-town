extends SceneTree

var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1080, 2400)
	viewport.size_2d_override = Vector2i(540, 1200)
	viewport.size_2d_override_stretch = true
	root.add_child(viewport)
	var scene = load("res://main.tscn").instantiate()
	viewport.add_child(scene)
	await process_frame
	await process_frame
	check(scene.stage_new_buildings(1).is_empty(), "Stage 1 has no announcement cards")
	var s17: Array = scene.stage_new_buildings(17)
	check("pizzeria" in s17 and "power_plant" in s17 and "fitness_club" in s17, "Stage 17 announces fitness, pizzeria, power plant")
	check(not ("lawn" in scene.stage_new_buildings(2)), "Landscaping is not announced")
	var game = scene.game
	game.campaign_stage = 17
	game.campaign_intro_acknowledged_stage = 16
	game.campaign_complete_pending = false
	game.campaign_finished = false
	if scene.campaign_intro_dialog != null and is_instance_valid(scene.campaign_intro_dialog):
		scene.campaign_intro_dialog.free()
	scene.campaign_intro_dialog = null
	game.empty_city_mode = true
	scene.update_campaign_intro()
	await process_frame
	var dialog = scene.campaign_intro_dialog
	check(dialog != null, "Intro dialog opens")
	if dialog != null:
		check(dialog.find_child("NewBuildingsBanner", true, false) != null, "Banner is shown")
		check(dialog.find_child("NewBuilding_pizzeria", true, false) != null, "Pizzeria card is shown")
	print("STAGE ANNOUNCEMENT CHECKS: ", "PASS" if failures.is_empty() else "FAIL")
	for f in failures:
		print(f)
	quit(0 if failures.is_empty() else 1)
