extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1

func find_button(node: Node, caption: String) -> Button:
	if node is Button and (node as Button).text == caption:
		return node as Button
	for child in node.get_children():
		var found := find_button(child, caption)
		if found != null:
			return found
	return null

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var operating_city := Simulation.new(false)
	operating_city.start_empty_city()
	operating_city.territory.buildings.append({"type_id": "cafe", "instance_id": "test_income_cafe", "level": 1, "col": 10, "row": 20, "width": 2, "height": 2})
	operating_city.fires["test_fire_a"] = {}
	operating_city.fires["test_fire_b"] = {}
	check(operating_city.income() > 0 and operating_city.net_income() < 0 and operating_city.can_offer_subsidy(), "Rescue support is available when positive gross income is outweighed by city expenses")

	var save_path := "user://rewarded_placeholder_test.json"
	var reward_city := Simulation.new(false)
	reward_city.start_empty_city()
	reward_city.save_path = save_path
	check(reward_city.debug_rewarded_placeholder_amount() == 100, "Debug reward starts at 100 coins in the first campaign stage")
	check(reward_city.grant_debug_rewarded_placeholder() == 100 and reward_city.budget == 100, "Skipping the placeholder grants and saves its advertised reward")
	var first_reload := Simulation.new(false)
	first_reload.save_path = save_path
	check(first_reload.load_game() and first_reload.budget == 100, "Debug reward budget survives a simulated restart")
	first_reload.campaign_stage = 5
	check(first_reload.debug_rewarded_placeholder_amount() == 500, "Late campaign reward reaches the 500 coin cap")
	check(first_reload.grant_debug_rewarded_placeholder() == 500 and first_reload.budget == 600, "Rewards can be claimed repeatedly and accumulated")

	var scene = load("res://main.tscn").instantiate()
	scene.game.save_path = save_path
	root.add_child(scene)
	scene.set_process(false)
	scene.game.start_empty_city()
	scene.game.save_path = save_path
	scene.game.campaign_stage = 5
	scene.game.budget = 100
	scene.refresh()
	scene.select_grid_house("pine_district_city_hall_12_19")
	await process_frame
	var hall_reward := find_button(scene, "Тест рекламы · +500 монет")
	check(OS.is_debug_build() and hall_reward != null, "City Hall exposes the placeholder action only in debug builds")
	hall_reward.pressed.emit()
	await process_frame
	check(find_button(scene, "Пропустить · получить награду") != null and find_button(scene, "Закрыть без награды") != null, "Placeholder clearly labels itself and offers explicit reward/close actions")
	var balance_before_close: int = scene.game.budget
	find_button(scene, "Закрыть без награды").pressed.emit()
	await process_frame
	check(scene.game.budget == balance_before_close and (scene.rewarded_dialog == null or not is_instance_valid(scene.rewarded_dialog)), "Closing the placeholder does not award money")
	scene.show_rewarded_placeholder()
	await process_frame
	find_button(scene, "Пропустить · получить награду").pressed.emit()
	await process_frame
	check(scene.game.budget == balance_before_close + 500, "The skip action grants the displayed late-stage reward")
	scene.game.budget = 0
	scene.refresh()
	await process_frame
	check(find_button(scene, "Тест рекламы · награда 500") != null, "Zero-treasury support window also exposes the debug placeholder")
	var ui_reload := Simulation.new(false)
	ui_reload.save_path = save_path
	var ui_loaded: bool = ui_reload.load_game()
	check(ui_loaded and ui_reload.budget == balance_before_close + 500, "Reward from the City Hall UI persists after reload")
	scene.audio.shutdown()
	await create_timer(0.2).timeout
	scene.queue_free()
	await process_frame
	await process_frame
	DirAccess.remove_absolute(save_path)
	DirAccess.remove_absolute(save_path + ".tmp")
	if failures > 0:
		quit(1)
	else:
		print("Проверки субсидии и тестовой заглушки награды пройдены.")
		quit(0)
