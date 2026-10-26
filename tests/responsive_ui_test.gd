extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")

var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func click(viewport: Viewport, point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.pressed = true
	viewport.push_input(event, true)
	event.pressed = false
	viewport.push_input(event, true)

func run() -> void:
	for resolution: Vector2i in [Vector2i(360, 800), Vector2i(1080, 2400), Vector2i(540, 960)]:
		var viewport := SubViewport.new()
		viewport.size = resolution
		viewport.size_2d_override = Vector2i(540, roundi(540.0 * resolution.y / resolution.x))
		viewport.size_2d_override_stretch = true
		root.add_child(viewport)
		var scene = load("res://main.tscn").instantiate()
		scene.game.save_path = "user://test_responsive.json"
		scene.settings_path = "user://test_graphics.json"
		viewport.add_child(scene)
		scene.set_process(false)
		# The layout suite covers legacy service/building panels. Main now starts
		# new installs in an empty-city mode, so explicitly install this fixture.
		scene.game = Simulation.new(true)
		scene.game.save_path = "user://test_responsive.json"
		scene.game.empty_city_mode = false
		scene.scenery.visible = true
		scene.scenery.traffic_controller.set_active_count(0)
		if scene.subsidy_dialog != null and is_instance_valid(scene.subsidy_dialog):
			scene.subsidy_dialog.hide()
			scene.subsidy_dialog.queue_free()
			scene.subsidy_dialog = null
		scene.refresh()
		scene.safe_override = Vector4(20, 40, 20, 36)
		scene.update_layout()
		for i in range(3):
			await process_frame
		check(scene.district_label.text == "Сосновый район" and not scene.district_label.clip_text, "District name remains complete in the top bar")
		var map_tools: Control = scene.screen.get_node("MapTools")
		check(map_tools.size.y <= 140 and map_tools.get_global_rect().end.y < scene.navbar.position.y, "Compact map actions leave the map visible")
		var settings_rect: Rect2 = scene.audio_button.get_global_rect()
		var condition_rect: Rect2 = scene.state_button.get_global_rect()
		var bus_rect: Rect2 = scene.transit_button.get_global_rect()
		check(map_tools.position.y >= scene.hud.get_global_rect().end.y and settings_rect.position.y == condition_rect.position.y and bus_rect.position.y > condition_rect.position.y,
			"BUS is placed on the third line below the condition button")
		check(absf(condition_rect.position.x - bus_rect.position.x) <= 1 and bus_rect.end.x <= scene.screen.size.x - scene.safe_right + 1,
			"BUS aligns beneath Condition and remains within the safe area")
		scene.open_territory()
		scene.set_territory_tool("service")
		check(not scene.mode_switcher.get_global_rect().intersects(map_tools.get_global_rect()), "Four land-mode buttons never overlap floating map controls")
		check(scene.mode_switcher.get_global_rect().position.x >= 0 and scene.mode_switcher.get_global_rect().end.x <= scene.screen.size.x + 1, "Land-mode row stays inside safe screen width")
		check(scene.hud.position.y >= 40, "HUD respects top safe area")
		check(scene.hud.get_global_rect().end.x <= scene.screen.size.x - 20.0 + 1, "HUD respects right safe area")
		var map_before: Vector3 = scene.focus_point
		scene.set_camera_focus(map_before + Vector3(5, 0, 2))
		check(scene.focus_point != map_before, "Map can pan")
		for quality: String in ["high", "medium", "low"]:
			scene.set_quality(quality)
			scene.close_sheet()
			scene.focus_problem()
			for i in range(3):
				await process_frame
			click(viewport, scene.viewport_point(scene.world.get_node("LeakMarker").position))
			await process_frame
			check(scene.selection_kind == "leak", "Map picking after render scaling: " + quality)
			check(scene.sheet.get_global_rect().end.y <= scene.screen.size.y + 1, "Service panel stays inside screen")
			var dispatch_button = scene.action_box.get_child(0)
			check(dispatch_button.size.y >= 72, "Dispatch has 48dp target at 360dp width")
			scene.close_sheet()
			scene.selected = 9
			scene.selection_kind = "plot"
			scene.preview_kind = "cafe"
			scene.refresh()
			for i in range(3):
				await process_frame
			check(scene.preview != null, "Construction has 3D preview")
			var cancel_button = scene.action_box.get_child(1)
			check(cancel_button.size.y >= 72, "Cancel target remains usable")
			check(cancel_button.get_global_rect().end.y <= scene.navbar.position.y, "Cancel is not hidden behind navigation")
			check(scene.action_box.get_child(0).size.y >= 72, "Build target remains usable")
			var before: int = scene.game.budget
			scene.close_sheet()
			check(scene.game.budget == before and scene.game.buildings[9] == "empty", "Preview cancellation never spends money")
		scene.quality = "high"
		scene.load_graphics()
		check(scene.quality == "low", "Graphics profile persists")
		scene.safe_override = Vector4.ZERO
		scene.set_quality("high")
		scene.selected = 9
		scene.selection_kind = "plot"
		scene.refresh()
		for i in range(3):
			await process_frame
		# Настоящее касание карты проверяется отдельно от эмулированной мыши.
		scene.close_sheet()
		scene.focus_problem()
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = scene.camera.unproject_position(scene.world.get_node("LeakMarker").position) * scene.viewport_container.stretch_shrink
		touch.pressed = true
		scene.handle_map_gesture(touch)
		touch.pressed = false
		scene.handle_map_gesture(touch)
		check(scene.selection_kind == "leak", "Raw touch selects marker once")
		scene.selected = 9
		scene.selection_kind = "plot"
		scene.refresh()
		for i in range(3):
			await process_frame
		var build_button = scene.action_box.get_child(0)
		click(viewport, build_button.get_global_transform_with_canvas() * (build_button.size / 2))
		await process_frame
		check(scene.game.buildings[9] == "empty" and scene.game.construction_job.kind == "build_legacy", "Actual touch/mouse build button starts a saved worksite")
		var construction_task: Dictionary = scene.game.construction_job.duplicate(true)
		scene.game.tick(6.1)
		scene.handle_construction_finish(construction_task)
		scene.refresh()
		check(scene.game.buildings[9] == "cafe", "Building appears when the work bar completes")
		check(scene.game.budget == 180, "Construction button charges once")
		scene.game.fire_triggered = true
		scene.game.fires[Simulation.FIRST_FIRE_TARGET] = {"phase": "warning", "warning_left": 18.0, "elapsed": 0.0, "danger": 1}
		scene.select_problem("fire")
		check(not scene.navbar.visible and scene.sheet.get_global_rect().end.y <= scene.screen.size.y, "Fire call card fits within the safe screen")
		check(scene.sheet.find_child("DispatchFirefighters", true, false) != null, "Fire card offers a direct dispatch action")
		scene.game.fires.clear()
		scene.game.fire_damage[Simulation.FIRST_FIRE_TARGET] = 24.0
		scene.select_plot(0)
		var damage_card: Control = scene.sheet
		var repair_button = damage_card.find_children("*", "Button", true, false).filter(func(item): return item.text.begins_with("Пожар потушен"))
		var restore_button = damage_card.find_children("*", "Button", true, false).filter(func(item): return item.text.begins_with("Восстановить дом"))
		check(not restore_button.is_empty(), "Damaged home card offers a compact restoration action")
		check(damage_card.get_global_rect().end.y <= scene.navbar.position.y + 1 and damage_card.position.y >= scene.hud.get_global_rect().end.y, "Damaged home card remains above bottom navigation")
		check(damage_card.position.x >= 0 and damage_card.get_global_rect().end.x <= scene.screen.size.x + 1, "Damaged home card stays inside narrow/wide screen bounds")
		var close_button: Button = damage_card.find_children("*", "Button", true, false).filter(func(item): return item.text == "×")[0]
		check(close_button.visible and close_button.get_global_rect().position.x >= 0 and close_button.get_global_rect().end.x <= scene.screen.size.x + 1, "House card close button remains visible and tappable")
		scene.set_camera_focus(scene.map_position(scene.game.plot_position(1)) + Vector3(7, 0, 7))
		var other_house_tap := InputEventMouseButton.new()
		other_house_tap.button_index = MOUSE_BUTTON_LEFT
		other_house_tap.pressed = true
		other_house_tap.position = scene.camera.unproject_position(scene.map_position(scene.game.plot_position(1)) + Vector3(0, 0.2, 0)) * scene.viewport_container.stretch_shrink
		scene.map_input(other_house_tap)
		check(scene.selection_kind == "plot" and scene.selected == 1, "Tapping another house replaces the previous house card")
		var outside_tap := InputEventMouseButton.new()
		outside_tap.button_index = MOUSE_BUTTON_LEFT
		outside_tap.pressed = true
		scene.set_camera_focus(Vector3(40, 0, 75))
		var landscape_point: Vector3 = scene.game.territory.cell_world(14, 21)
		outside_tap.position = scene.camera.unproject_position(landscape_point) * scene.viewport_container.stretch_shrink
		scene.map_input(outside_tap)
		check(scene.selection_kind == "land_cell" and scene.sheet.visible, "Tapping an unoccupied landscape cell opens its available actions")
		scene.select_plot(0)
		for i in range(2):
			await process_frame
		var header_close: Button = scene.sheet.find_children("*", "Button", true, false).filter(func(item): return item.text == "×")[0]
		click(viewport, header_close.get_global_transform_with_canvas() * (header_close.size / 2))
		await process_frame
		check(scene.selection_kind == "" and not scene.sheet.visible, "Tapping the visible close button dismisses the card")
		scene.game = Simulation.new(false)
		scene.game.save_path = "user://test_responsive.json"
		scene.game.start_empty_city()
		scene.refresh()
		scene.select_grid_house("pine_district_city_hall_12_19")
		for i in range(3):
			await process_frame
		var civic_close_buttons: Array = scene.sheet.find_children("*", "Button", true, false).filter(func(item): return item.text == "×")
		check(scene.sheet_scroll.get_parent() == scene.sheet and scene.sheet_scroll.get_global_rect().end.y <= scene.screen.size.y + 1, "City Hall card uses an in-screen, vertically scrollable panel")
		check(not civic_close_buttons.is_empty() and civic_close_buttons[0].get_global_rect().end.y <= scene.sheet_scroll.get_global_rect().end.y + 1, "City Hall card close button stays inside its visible panel")
		check(scene.sheet_column.find_child("MoreButton", true, false) == null, "Permanent City Hall has no unusable demolition action")
		scene.audio.shutdown()
		scene.queue_free()
		await process_frame
		viewport.queue_free()
		await create_timer(0.2).timeout
		DirAccess.remove_absolute("user://test_responsive.json")
		DirAccess.remove_absolute("user://test_graphics.json")
	print("RESPONSIVE UI CHECKS: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
