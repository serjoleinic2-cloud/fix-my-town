extends SceneTree

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
		scene.safe_override = Vector4(20, 40, 20, 36)
		scene.update_layout()
		for i in range(3):
			await process_frame
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
		check(scene.game.buildings[9] == "cafe", "Actual touch/mouse build button works")
		check(scene.game.budget == 180, "Construction button charges once")
		scene.audio.shutdown()
		scene.queue_free()
		await process_frame
		viewport.queue_free()
		await create_timer(0.2).timeout
		DirAccess.remove_absolute("user://test_responsive.json")
		DirAccess.remove_absolute("user://test_graphics.json")
	print("RESPONSIVE UI CHECKS: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
