extends SceneTree

var failures: int = 0
func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	scene.game.save_path = "user://completion_test.json"
	DirAccess.remove_absolute(scene.game.save_path)
	root.add_child(scene)
	scene.set_process(false)
	scene.game = preload("res://scripts/simulation.gd").new()
	scene.game.save_path = "user://completion_test.json"
	scene.game.empty_city_mode = false
	scene.scenery.visible = true
	if scene.subsidy_dialog != null and is_instance_valid(scene.subsidy_dialog):
		scene.subsidy_dialog.hide()
		scene.subsidy_dialog.queue_free()
		scene.subsidy_dialog = null
	scene.refresh()
	scene.close_sheet()
	check(scene.mission.visible and scene.mission_icon.texture.resource_path.ends_with("ui_drop.svg"), "Leak task has water icon")
	scene.game.leak_fixed = true
	scene.refresh()
	check(not scene.mission_icon.texture.resource_path.ends_with("ui_drop.svg"), "Drop removed immediately after leak repair")
	scene.game.signal_fixed = true
	scene.game.budget = 1000
	scene.game.build(9, "park")
	scene.refresh()
	check(scene.game.completed and scene.mission.visible and is_equal_approx(scene.completion_left, 3.5), "Completion toast appears once for 3.5 sec")
	scene._process(3.0)
	check(scene.mission.visible, "Toast remains during brief celebration")
	scene._process(0.6)
	check(not scene.mission.visible, "Toast completely disappears after deadline")
	scene.refresh()
	check(not scene.mission.visible, "Income/UI refresh cannot resurrect old task")
	for intersection in scene.scenery.traffic_controller.intersections:
		for i in range(4):
			var pole = intersection.node.visual_root.get_child(0).get_node("SignalPole%d" % i)
			for lamp in scene.scenery.street_lamp_positions:
				check(pole.global_position.distance_to(lamp) > 3.0, "Street lamp must not look like second signal support")
	scene.game.save_game()
	scene.audio.shutdown()
	scene.queue_free()
	await create_timer(0.2).timeout
	var restored = load("res://main.tscn").instantiate()
	restored.game.save_path = "user://completion_test.json"
	root.add_child(restored)
	restored.set_process(false)
	check(restored.game.completed and not restored.mission.visible and restored.completion_left == 0, "Loading completed save leaves map free")
	check(not restored.world.get_node("LeakMarker").visible and not restored.leak_effect.visible, "Repaired leak marker never returns on load")
	restored.audio.shutdown()
	restored.queue_free()
	await create_timer(0.2).timeout
	DirAccess.remove_absolute("user://completion_test.json")
	if failures == 0:
		print("COMPLETION + SIGNAL VISUAL CHECKS: PASS")
	quit(0 if failures == 0 else 1)
