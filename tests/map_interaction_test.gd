extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const Grid = preload("res://scripts/territory_grid.gd")
var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func tap_at(scene: Node, position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position * scene.viewport_container.stretch_shrink
	scene.map_input(event)

func check_polygon_pick(scene: Node, center: Vector3, half_x: float, half_z: float, expected_legacy: int, expected_grid: String) -> void:
	scene.set_camera_focus(center + Vector3(7, 0, 7))
	for offset in [Vector2.ZERO, Vector2(-half_x + 0.25, -half_z + 0.25), Vector2(half_x - 0.25, -half_z + 0.25), Vector2(half_x - 0.25, half_z - 0.25), Vector2(-half_x + 0.25, half_z - 0.25)]:
		var point: Vector2 = scene.camera.unproject_position(center + Vector3(offset.x, 0.2, offset.y))
		if point.x < 0 or point.x >= scene.screen.size.x or point.y < 0 or point.y >= scene.screen.size.y:
			continue
		var overlay_distance: float = minf(scene.camera.unproject_position(scene.world.get_node("LeakMarker").position).distance_to(point), scene.camera.unproject_position(scene.world.get_node("SignalMarker").position).distance_to(point))
		if overlay_distance < 36.0 * scene.render_scale / scene.viewport_container.stretch_shrink:
			continue
		tap_at(scene, point)
		if expected_legacy >= 0:
			check(scene.selection_kind == "plot" and scene.selected == expected_legacy, "Visible roof edge " + str(offset) + " selects legacy building " + str(expected_legacy) + "; got " + str(scene.selected))
		else:
			check(scene.selection_kind == "grid_house" and scene.grid_selected_id == expected_grid, "Visible roof edge selects expansion building " + expected_grid)

func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1080, 2400)
	viewport.size_2d_override = Vector2i(540, 1200)
	viewport.size_2d_override_stretch = true
	root.add_child(viewport)
	var scene = load("res://main.tscn").instantiate()
	viewport.add_child(scene)
	scene.set_process(false)
	scene.game = Simulation.new()
	scene.game.save_path = "user://map_interaction_test.json"
	scene.game.empty_city_mode = false
	scene.scenery.visible = true
	scene.scenery.traffic_controller.set_active_count(0)
	scene.refresh()
	for frame in range(12):
		await process_frame
	var original_zoom: float = scene.camera.size
	var pinch_start := InputEventScreenTouch.new()
	var pinch_second := InputEventScreenTouch.new()
	var pinch_move := InputEventScreenDrag.new()
	pinch_start.index = 0
	pinch_start.position = Vector2(200, 400)
	pinch_start.pressed = true
	scene.handle_map_gesture(pinch_start)
	pinch_second.index = 1
	pinch_second.position = Vector2(400, 400)
	pinch_second.pressed = true
	scene.handle_map_gesture(pinch_second)
	var zoom_before_pinch: float = scene.camera.size
	pinch_move.index = 1
	pinch_move.position = Vector2(600, 400)
	scene.handle_map_gesture(pinch_move)
	check(scene.camera.size < zoom_before_pinch, "Moving two fingers apart zooms the camera in")
	pinch_move.position = Vector2(300, 400)
	scene.handle_map_gesture(pinch_move)
	check(scene.camera.size > 45.0, "Moving two fingers together zooms the camera back out")
	pinch_second.pressed = false
	scene.handle_map_gesture(pinch_second)
	pinch_start.pressed = false
	scene.handle_map_gesture(pinch_start)
	check(scene.selection_kind == "", "A pinch gesture does not tap-select a map object")
	scene.camera.size = original_zoom
	var checked := 0
	for index in range(scene.game.buildings.size()):
		if scene.game.buildings[index] == "empty":
			continue
		var object: Node = scene.plots.get_node("plot_%d" % index)
		object.interaction_area.collision_layer = 0
		var center: Vector3 = scene.map_position(scene.game.plot_position(index))
		check_polygon_pick(scene, center, 4.5, 4.5, index, "")
		checked += 1
	check(checked >= 18, "The test covers old buildings at each map edge")
	for cell in [Vector2i(12, 19), Vector2i(12, 20), Vector2i(12, 21), Vector2i(13, 21), Vector2i(14, 21), Vector2i(14, 22)]:
		check(scene.game.clear_grid_cell(cell.x, cell.y), "Clear test footprint for a mapped expansion home")
	for cell in [Vector2i(12, 19), Vector2i(12, 20), Vector2i(12, 21), Vector2i(13, 21), Vector2i(14, 21), Vector2i(14, 22)]:
		check(scene.game.build_grid_road(cell.x, cell.y), "Build a connected road and turn for map hit testing")
	for cell in [Vector2i(15, 21), Vector2i(16, 21), Vector2i(15, 22), Vector2i(16, 22)]:
		check(scene.game.clear_grid_cell(cell.x, cell.y), "Clear the home footprint")
	check(scene.game.build_grid_house(15, 21), "Build the expansion home before selecting it")
	scene.territory_signature = ""
	scene.refresh()
	var entry: Dictionary = scene.game.territory.building_at(15, 21)
	var grid_object: Node = scene.territory_visuals.get_node(entry.instance_id)
	grid_object.interaction_area.collision_layer = 0
	check_polygon_pick(scene, scene.game.territory.building_center(entry), 4.5, 4.5, -1, entry.instance_id)
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	var probe_cell := Vector2i(17, 25)
	scene.open_territory()
	scene.set_camera_focus(scene.game.territory.cell_world(probe_cell.x, probe_cell.y) + Vector3(7, 0, 7))
	tap.position = scene.camera.unproject_position(scene.game.territory.cell_world(probe_cell.x, probe_cell.y))
	scene.map_input(tap)
	check(scene.territory_cell == probe_cell, "Forest selection uses the center of the visible cell")
	var road_cell := Vector2i(12, 21)
	scene.set_camera_focus(scene.game.territory.cell_world(road_cell.x, road_cell.y) + Vector3(7, 0, 7))
	tap.position = scene.camera.unproject_position(scene.game.territory.cell_world(road_cell.x, road_cell.y))
	scene.map_input(tap)
	check(scene.territory_cell == road_cell, "Road selection uses the same visible grid cell as forest placement")
	scene.car.position = Vector3(35, 0.18, 72)
	scene.car.visible = true
	scene.set_camera_focus(scene.car.position)
	tap.position = scene.camera.unproject_position(scene.car.position + Vector3(0, 0.9, 0))
	scene.close_sheet()
	scene.map_input(tap)
	check(scene.selection_kind == "vehicle" and scene.selected_vehicle_type == "repair_van", "A tap on an unobstructed service vehicle opens its status card")
	var save_path: String = scene.game.save_path
	scene.audio.shutdown()
	viewport.queue_free()
	await process_frame
	DirAccess.remove_absolute(save_path)
	await create_timer(0.2).timeout
	print("MAP INTERACTION CHECKS: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
