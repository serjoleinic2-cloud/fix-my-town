extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
var failures := 0
var scene: Node

func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func test_dialog(method: String, arguments: Array = []) -> void:
	if method in ["house_details", "open_building_more", "request_demolition"]:
		scene.selected = 16
	if method in ["open_audio_settings", "confirm_reset"]:
		scene.open_settings()
		for frame in range(4):
			await process_frame
	scene.callv(method, arguments)
	for frame in range(6):
		await process_frame
	var dialogs: Array = scene.get_children().filter(func(item): return item is AcceptDialog and item.visible)
	check(dialogs.size() == 1, "Dialog opens: " + method)
	if dialogs.is_empty():
		return
	var dialog: AcceptDialog = dialogs[0]
	var safe_rect := Rect2(Vector2(scene.safe_left + 8, scene.safe_top + 28), scene.screen.size - Vector2(scene.safe_left + scene.safe_right + 16, scene.safe_top + scene.safe_bottom + 36))
	var bounds := Rect2(Vector2(dialog.position), Vector2(dialog.size))
	check(safe_rect.encloses(bounds), "Dialog and title stay in safe screen: %s %s %s %s" % [method, scene.game.language, bounds, safe_rect])
	var scroll: ScrollContainer = dialog.get_node("DialogContentScroll")
	check(scroll.size.x <= dialog.size.x and scroll.size.y > 0, "Content has a bounded scroll area: " + method)
	for button: Button in [dialog.get_ok_button(), dialog.get_cancel_button() if dialog is ConfirmationDialog else null]:
		if button == null:
			continue
		var button_rect := button.get_global_rect()
		check(Rect2(Vector2.ZERO, Vector2(dialog.size)).encloses(button_rect), "Dialog action stays visible: %s %s" % [method, button_rect])
		check(not scroll.get_global_rect().intersects(button_rect), "Scrolling content never covers confirmation/cancel: " + method)
		if button.text in ["Снести", "Отмена", "Demolish", "Cancel"]:
			var text_width: float = button.get_theme_font("font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size")).x
			check(text_width + 32 <= button.size.x + 1, "Short dialog action fits on one line: " + button.text)
	if DisplayServer.get_name() != "headless" and scene.game.language == "ru" and method == "open_grid_more":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/screenshots/dialog-demolition-%d.png" % int(scene.screen.size.x))
	dialog.hide()
	dialog.queue_free()
	await process_frame
	await process_frame

func run() -> void:
	root.gui_embed_subwindows = true
	scene = load("res://main.tscn").instantiate()
	scene.game.save_path = "user://dialog_bounds_test.json"
	scene.settings_path = "user://dialog_bounds_graphics.json"
	root.add_child(scene)
	scene.set_process(false)
	scene.close_subsidy_offer()
	for size_value in [Vector2i(360, 640), Vector2i(540, 760), Vector2i(540, 1200)]:
		root.size = size_value * 2
		root.content_scale_size = size_value
		for language in ["ru", "en"]:
			scene.game = Simulation.new(true)
			scene.game.save_path = "user://dialog_bounds_test.json"
			scene.game.budget = 5000
			scene.game.language = language
			scene.selected = 16
			scene.safe_override = Vector4(12, 30, 12, 20)
			scene.refresh()
			for frame in range(4):
				await process_frame
			for method in ["open_settings", "open_audio_settings", "confirm_reset", "house_details", "open_building_more"]:
				await test_dialog(method)
			await test_dialog("request_demolition", [16])
			scene.road_selected_cell = Vector2i(0, 0)
			check(scene.game.can_demolish_road(0, 0), "Test road can be removed without isolating buildings")
			await test_dialog("request_road_demolition")
			scene.game.start_empty_city()
			scene.game.budget = 5000
			scene.game.campaign_finished = true
			for row in [19, 20]:
				for col in [9, 10]:
					scene.game.clear_grid_cell(col, row)
			check(scene.game.territory.place_building(9, 19, "house"), "Prepare isolated test house")
			scene.grid_selected_id = str(scene.game.territory.building_at(9, 19).instance_id)
			scene.refresh()
			await test_dialog("open_grid_more")
	scene.audio.shutdown()
	await create_timer(0.2).timeout
	scene.queue_free()
	await process_frame
	await process_frame
	DirAccess.remove_absolute("user://dialog_bounds_test.json")
	DirAccess.remove_absolute("user://dialog_bounds_graphics.json")
	print("DIALOG BOUNDS: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
