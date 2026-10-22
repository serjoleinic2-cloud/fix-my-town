extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var scene = load("res://main.tscn").instantiate()
	scene.game.save_path = "user://test_startup.json"
	root.add_child(scene)
	scene.game = preload("res://scripts/simulation.gd").new()
	scene.game.save_path = "user://visual_test.json"
	var args := OS.get_cmdline_user_args()
	var mode: String = args[1] if args.size() > 1 else "ru"
	if mode == "en":
		scene.game.language = "en"
		scene.selected = 3
		scene.selection_kind = "plot"
	if mode == "done":
		scene.game.leak_fixed = true
		scene.game.signal_fixed = true
		scene.game.buildings[9] = "park"
		scene.game.check_complete()
		scene.selected = 9
		scene.selection_kind = "plot"
	scene.refresh()
	if mode == "assets":
		scene.plots.get_node("plot_0").replace_visual(true)
		scene.car.replace_visual(true)
	if mode == "audio":
		root.gui_embed_subwindows = true
		scene.open_audio_settings()
	for i in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	var destination := args[0] if not args.is_empty() else "user://preview.png"
	root.get_texture().get_image().save_png(destination)
	print("CAPTURE: ", destination)
	scene.set_process(false)
	scene.audio.shutdown()
	await create_timer(0.2).timeout
	scene.queue_free()
	await process_frame
	quit()
