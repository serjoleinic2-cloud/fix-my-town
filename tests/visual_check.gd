extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var args := OS.get_cmdline_user_args()
	var mode: String = args[1] if args.size() > 1 else "ru"
	var width: int = int(args[2]) if args.size() > 2 else 840
	var height: int = int(args[3]) if args.size() > 3 else 1870
	var capture_viewport := SubViewport.new()
	capture_viewport.size = Vector2i(width, height)
	capture_viewport.size_2d_override = Vector2i(540, roundi(540.0 * height / width))
	capture_viewport.size_2d_override_stretch = true
	capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(capture_viewport)
	var scene = load("res://main.tscn").instantiate()
	scene.game.save_path = "user://test_startup.json"
	capture_viewport.add_child(scene)
	scene.set_process(false)
	scene.game = preload("res://scripts/simulation.gd").new()
	scene.game.save_path = "user://visual_test.json"
	scene.elapsed = 8
	scene.scenery.animate(8)
	scene.quality = "high"
	scene.apply_quality()
	if mode == "en":
		scene.game.language = "en"
	if mode == "done":
		scene.game.leak_fixed = true
		scene.game.signal_fixed = true
		scene.game.buildings[9] = "park"
		scene.game.check_complete()
	if mode in ["leak", "signal"]:
		scene.select_problem(mode)
	if mode in ["build", "en", "park"]:
		scene.preview_kind = "park" if mode == "park" else "cafe"
		scene.selected = 9
		scene.selection_kind = "plot"
		scene.active_tab = "build_tab"
		scene.set_camera_focus(scene.map_position(scene.game.plot_position(9)) + Vector3(7, 0, 7))
	if mode == "low":
		scene.quality = "low"
		scene.apply_quality()
	if mode in ["house", "condition"]:
		scene.selected = 16
		scene.selection_kind = "plot"
		scene.quality_mode = mode == "condition"
		scene.set_camera_focus(scene.map_position(scene.game.plot_position(16)) + Vector3(7, 0, 7))
	if mode in ["transit", "stop", "transit_en"]:
		scene.game.leak_fixed = true
		scene.game.signal_fixed = true
		scene.game.buildings[9] = "cafe"
		scene.game.check_complete()
		scene.game.budget = 500
		scene.game.place_stop(0)
		scene.selection_kind = "transit"
		if mode == "stop":
			scene.placing_stop = true
			scene.stop_candidate = 4
		else:
			scene.game.place_stop(4)
			scene.game.start_transit()
			scene.game.transit.tick(0.1, scene.scenery.traffic_controller)
		if mode == "transit_en":
			scene.game.language = "en"
		scene.set_camera_focus(scene.game.transit.stop_position(4) + Vector3(7, 0, 7))
	if mode == "safe":
		scene.safe_override = Vector4(0, 36, 0, 38)
	scene.refresh()
	if mode == "assets":
		scene.plots.get_node("plot_0").replace_visual(true)
		scene.car.replace_visual(true)
	if mode == "audio":
		capture_viewport.gui_embed_subwindows = true
		scene.open_audio_settings()
	for i in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	var destination := args[0] if not args.is_empty() else "user://preview.png"
	capture_viewport.get_texture().get_image().save_png(destination)
	print("CAPTURE: ", destination)
	scene.set_process(false)
	scene.audio.shutdown()
	await create_timer(0.2).timeout
	scene.queue_free()
	await process_frame
	quit()
