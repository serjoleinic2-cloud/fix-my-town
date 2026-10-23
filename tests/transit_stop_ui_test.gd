extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(720, 1600)
	viewport.size_2d_override = Vector2i(540, 1200)
	viewport.size_2d_override_stretch = true
	root.add_child(viewport)
	var scene = load("res://main.tscn").instantiate()
	viewport.add_child(scene)
	scene.set_process(false)
	scene.game = Simulation.new()
	scene.game.save_path = "user://transit_stop_ui_test.json"
	scene.game.completed = true
	scene.game.budget = 1000
	scene.game.transit.stops = [0, 4]
	scene.game.transit.active = true
	scene.game.transit.coordinate = -20.0
	scene.game.transit.target_z = 21.6
	scene.game.save_game()
	for frame in range(12):
		await process_frame
	scene.set_camera_focus(scene.game.transit.stop_position(4) + Vector3(7, 0, 7))
	var old_stops: Array = scene.game.transit.stops.duplicate()
	var old_coverage: Dictionary = scene.game.transit_metrics().duplicate(true)
	var old_target: float = scene.game.transit.target_z
	var old_save: String = FileAccess.get_file_as_string(scene.game.save_path)
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.position = scene.camera.unproject_position(scene.game.transit.stop_position(4) + Vector3(0, 1.2, 0)) * scene.viewport_container.stretch_shrink
	scene.map_input(tap)
	check(scene.selection_kind == "stop" and scene.selected_stop_index == 1, "Tapping a stop opens its own card")
	check(scene.sheet.find_child("MoveStopButton", true, false) != null, "Stop card offers a clear Move button")
	scene.sheet.find_child("MoveStopButton", true, false).pressed.emit()
	await process_frame
	check(scene.placing_stop and scene.selection_kind == "stop_place", "Move enters an explicit location-picking mode")
	check(scene.sheet.find_child("MoveStopInstruction", true, false).text == "Выберите новое место у дороги", "Move prompt explains the next action")
	check(scene.game.transit.stops == old_stops and scene.game.transit_metrics() == old_coverage and scene.game.transit.target_z == old_target, "Before selection, stop, route and resident coverage do not change")
	check(FileAccess.get_file_as_string(scene.game.save_path) == old_save, "Entering move mode does not rewrite the save")
	check(scene.stop_candidate_visuals.get_child_count() == 4 and scene.highlights.get_child_count() == 0, "Only valid candidate bus-stop markers are shown; no unlabeled square outlines")
	var old_stop_tap := InputEventMouseButton.new()
	old_stop_tap.button_index = MOUSE_BUTTON_LEFT
	old_stop_tap.position = scene.camera.unproject_position(scene.game.transit.stop_position(4) + Vector3(0, 1.6, 0)) * scene.viewport_container.stretch_shrink
	scene.map_input(old_stop_tap)
	check(scene.placing_stop and scene.game.transit.stops == old_stops, "Tapping the old stop leaves it in place while choosing")
	var candidate_tap := InputEventMouseButton.new()
	candidate_tap.button_index = MOUSE_BUTTON_LEFT
	candidate_tap.position = scene.camera.unproject_position(scene.game.transit.stop_position(5) + Vector3(0, 1.6, 0)) * scene.viewport_container.stretch_shrink
	scene.map_input(candidate_tap)
	check(not scene.placing_stop and scene.game.transit.stops == [0, 5], "Tapping a marked valid road location commits the move")
	check(scene.game.transit_metrics() != old_coverage and scene.game.transit.target_z == old_target, "Coverage refreshes and the active bus safely finishes its current leg")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(scene.game.save_path))
	var saved_stops: Array = saved.get("transit", {}).get("stops", [])
	check(saved_stops.size() == 2 and int(saved_stops[0]) == 0 and int(saved_stops[1]) == 5, "The new route endpoints are saved immediately")
	scene.open_stop_card(1)
	scene.sheet.find_child("MoveStopButton", true, false).pressed.emit()
	await process_frame
	scene._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(not scene.placing_stop and scene.selection_kind == "stop", "System back cancels relocation and returns to the stop card")
	scene.sheet.find_child("MoveStopButton", true, false).pressed.emit()
	await process_frame
	scene.cancel_stop_placement()
	check(not scene.placing_stop and scene.game.transit.stops == [0, 5], "Cancel restores the old stop without changing the route")
	scene.audio.shutdown()
	var save_path: String = scene.game.save_path
	viewport.queue_free()
	await process_frame
	DirAccess.remove_absolute(save_path)
	await create_timer(0.2).timeout
	print("TRANSIT STOP UI CHECKS: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
