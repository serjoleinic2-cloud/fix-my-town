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
	if mode.begins_with("expansion"):
		scene.game.budget = 5000
		scene.game.leak_fixed = true
		scene.game.signal_fixed = true
		for cell in [Vector2i(12, 19), Vector2i(12, 20), Vector2i(12, 21), Vector2i(13, 21), Vector2i(14, 21), Vector2i(14, 22), Vector2i(15, 21), Vector2i(16, 21), Vector2i(15, 22), Vector2i(16, 22)]:
			scene.game.clear_grid_cell(cell.x, cell.y)
		for cell in [Vector2i(12, 19), Vector2i(12, 20), Vector2i(12, 21), Vector2i(13, 21), Vector2i(14, 21), Vector2i(14, 22)]:
			scene.game.build_grid_road(cell.x, cell.y)
		scene.open_territory()
		scene.territory_tool = "house"
		scene.select_territory_cell(Vector2i(15, 21))
		if mode in ["expansion_house", "expansion_condition", "expansion_upgrade"]:
			scene.game.build_grid_house(15, 21)
			scene.select_grid_house(scene.game.territory.building_at(15, 21).instance_id)
			scene.quality_mode = mode == "expansion_condition"
			if mode == "expansion_upgrade":
				scene.selection_kind = "grid_upgrade"
		if mode == "expansion_en":
			scene.game.language = "en"
	if mode == "done":
		scene.game.leak_fixed = true
		scene.game.signal_fixed = true
		scene.game.buildings[9] = "park"
		scene.game.check_complete()
	if mode in ["fire_before", "fire_during"]:
		scene.game.leak_fixed = true
		scene.game.signal_fixed = true
		scene.game.buildings[9] = "cafe"
		scene.game.check_complete()
		scene.game.completed = true
		scene.game.fire_triggered = true
		scene.completion_observed = true
		scene.completion_left = 0
		var target_id: String = scene.game.FIRST_FIRE_TARGET
		if mode == "fire_during":
			scene.game.fires[target_id] = {"phase": "burning", "warning_left": 0.0, "elapsed": 26.0, "danger": 2}
			scene.game.fires[scene.game.FIRST_FIRE_NEIGHBOR] = {"phase": "warning", "warning_left": 11.0, "elapsed": 0.0, "danger": 1}
			scene.game.fire_damage[target_id] = 14.0
			scene.select_problem("fire")
		else:
			scene.selection_kind = ""
		scene.set_camera_focus(scene.game.building_world_for_id(target_id) + Vector3(7, 0, 7))
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
	if mode in ["house", "condition", "damaged_house"]:
		scene.selected = 16
		scene.selection_kind = "plot"
		scene.quality_mode = mode == "condition"
		if mode == "damaged_house":
			scene.game.fire_damage["pine_district_legacy_16"] = 24.0
		scene.set_camera_focus(scene.map_position(scene.game.plot_position(16)) + Vector3(7, 0, 7))
	if mode in ["transit", "stop", "stop_move", "transit_en"]:
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
		elif mode == "stop_move":
			scene.game.place_stop(4)
			scene.open_stop_card(1)
			scene.begin_move_stop(1)
		else:
			scene.game.place_stop(4)
			if mode == "transit":
				scene.game.transit.stops = [{"col": 6, "row": 14}, {"col": 9, "row": 8}]
			scene.game.start_transit()
			scene.game.transit.tick(0.1, scene.scenery.traffic_controller, scene.game.territory)
		if mode == "transit_en":
			scene.game.language = "en"
		scene.set_camera_focus(scene.game.transit.stop_position(4) + Vector3(7, 0, 7))
		if mode == "transit":
			var route: Array[Vector3] = scene.game.transit.route_for(scene.game.territory, 0, 1)
			if not route.is_empty():
				scene.set_camera_focus((route.front() + route.back()) / 2 + Vector3(7, 0, 7))
	if mode in ["upgrade", "upgrade_en", "levels", "demolition"]:
		scene.game.budget = 5000
		scene.game.buildings[9] = "cafe"
		scene.game.buildings[14] = "park"
		scene.selected = 16
		scene.selection_kind = "plot"
		if mode == "upgrade_en":
			scene.game.language = "en"
		if mode == "levels":
			for i in range(24):
				if scene.game.buildings[i] in ["house", "cafe", "park"]:
					scene.game.levels[i] = (i % 3) + 1
		scene.set_camera_focus(scene.game.building_world(16) + Vector3(7, 0, 7))
	if mode == "traffic_stop":
		scene.game.signal_fixed = true
		var controller = scene.scenery.traffic_controller
		controller.signal_fixed = true
		controller.set_active_count(3)
		for i in range(3):
			var vehicle: Dictionary = controller.vehicles[i]
			vehicle.axis = "H" if i < 2 else "V"
			vehicle.direction = 1 if i != 1 else -1
			vehicle.road = 0.0 if i < 2 else -14.4
			var center := -14.4 if i < 2 else 0.0
			vehicle.coordinate = center - vehicle.direction * (controller.stop_distance_for(vehicle.node.type_id) + 0.4)
		controller.clock = 8.7
		controller.step(0.1)
		scene.car.position = Vector3(-13.4, 0.18, 5.5)
		scene.car.rotation.y = PI
		scene.camera.size = 45
		scene.set_camera_focus(Vector3(-14.4, 0, 0))
	if mode == "safe":
		scene.safe_override = Vector4(0, 36, 0, 38)
	scene.refresh()
	if mode in ["upgrade", "upgrade_en"]:
		scene.begin_upgrade()
	if mode == "demolition":
		capture_viewport.gui_embed_subwindows = true
		scene.request_demolition(16)
	if mode == "assets":
		scene.plots.get_node("plot_0").replace_visual(true)
		scene.car.replace_visual(true)
	if mode == "audio":
		capture_viewport.gui_embed_subwindows = true
		scene.open_audio_settings()
	for i in range(12):
		await process_frame
	await process_frame
	var destination := args[0] if not args.is_empty() else "user://preview.png"
	capture_viewport.get_texture().get_image().save_png(destination)
	print("CAPTURE: ", destination)
	scene.set_process(false)
	scene.audio.shutdown()
	await create_timer(0.2).timeout
	scene.queue_free()
	await process_frame
	quit()
