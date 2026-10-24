extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const Catalog = preload("res://scripts/asset_catalog.gd")
var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	scene.game.save_path = "user://test_startup.json"
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	scene.game = Simulation.new(true)
	scene.game.save_path = "user://asset_test.json"
	scene.audio.settings_path = "user://audio_test.json"
	scene.refresh()
	check(scene.game.dispatch("leak"), "Dispatch before replacement")
	scene.refresh()
	scene.game.tick(1)
	scene.car.position = scene.map_position(scene.game.vehicle)
	var before_budget: int = scene.game.budget
	var before_vehicle: Vector3 = scene.game.vehicle
	var before_route: Array = scene.game.route.duplicate()
	var house = scene.plots.get_node("plot_0")
	var old_house_visual = house.visual_root.get_child(0)
	var old_car_visual = scene.car.visual_root.get_child(0)
	var house_collision = house.interaction_area
	var car_collision = scene.car.interaction_area
	var car_mounts = scene.car.mounts
	house.replace_visual(true)
	scene.car.replace_visual(true)
	check(house.visual_root.get_child(0) != old_house_visual, "House visual must change")
	check(scene.car.visual_root.get_child(0) != old_car_visual, "Vehicle visual must change")
	check(house.visual_root.get_child(0).has_node("Model"), "House must load GLB through wrapper")
	check(scene.car.visual_root.get_child(0).has_node("Model"), "Vehicle must load GLB through wrapper")
	check(house.type_id == "house" and house.instance_id == "plot_0", "House identity preserved")
	check(scene.car.type_id == "repair_van" and scene.car.instance_id == "crew_0", "Vehicle identity preserved")
	check(house.interaction_area == house_collision and scene.car.interaction_area == car_collision, "Collisions preserved")
	check(scene.car.mounts == car_mounts and car_mounts.has_node("WheelFrontLeft"), "Mounts preserved")
	var alternate_visual = scene.car.visual_root.get_child(0)
	scene.refresh()
	check(scene.car.visual_root.get_child(0) == alternate_visual, "UI refresh must not reset model")
	check(scene.game.budget == before_budget and scene.game.vehicle == before_vehicle and scene.game.route == before_route, "Replacement must not change gameplay")
	scene.game.save_game()
	var loaded = Simulation.new(true)
	loaded.save_path = scene.game.save_path
	check(loaded.load_game(), "Load after GLB replacement")
	check(loaded.job == "leak" and loaded.target_type_id() == "water_leak", "Permanent job target")
	check(loaded.route == before_route and loaded.vehicle == before_vehicle, "Route survives save/load")
	for i in range(600):
		loaded.tick(0.1)
	check(loaded.leak_fixed, "Task completes after replacement and load")
	var audio = scene.audio
	var city: AudioStreamWAV = audio.stream("city", true)
	check(city.get_length() >= 60 and city.stereo, "Ambience is a long stereo field-recording loop")
	audio.set_paused(false)
	audio.sync(scene.game, 33, 0.1)
	check(audio.loops.has("city") and not audio.loops.has("birds"), "Real city recording replaces the repetitive synthetic birds layer")
	check(audio.loops.has("water") and audio.loops.has("engine"), "Leak and moving engine loops")
	check(audio.loops["engine"].get_parent() == scene.world, "Spatial audio belongs to gameplay world")
	scene.game.route_index = scene.game.route.size()
	audio.sync(scene.game, 33, 0.1)
	check(audio.loops.has("repair") and not audio.loops.has("engine"), "Tools replace engine on arrival")
	for i in range(50):
		scene.game.tick(0.1)
	audio.sync(scene.game, 33, 0.1)
	check(not audio.loops.has("water") and not audio.loops.has("repair"), "Water and tools stop after repair")
	audio.set_level("Effects", 0.23)
	audio.levels["Effects"] = 0.9
	audio.load_settings()
	check(is_equal_approx(audio.levels["Effects"], 0.23), "Audio settings persist")
	audio.set_paused(true)
	for channel: String in audio.CHANNELS:
		check(AudioServer.is_bus_mute(AudioServer.get_bus_index(channel)), "Pause mutes " + channel)
	audio.set_paused(false)
	for i in range(30):
		audio.play_ui("click")
	check(audio.voices.size() + audio.loops.size() <= audio.MAX_VOICES, "Voice budget")
	audio.play_ui("select")
	check(audio.voices[-1].bus == "Interface" and audio.voices[-1].stream == audio.stream("select"), "House tap remains audible when effects occupy the voice budget")
	check(audio.stream("place").get_length() < 1.1, "Construction feedback is a brief original musical accent")
	check(audio.stream("tesla").get_length() < 0.3, "Tesla-like selection feedback is a short cue")
	for type_id: String in Catalog.TYPES:
		check(ResourceLoader.exists(Catalog.scene_path(type_id)), "Catalog resource exists: " + type_id)
	DirAccess.remove_absolute(scene.game.save_path)
	DirAccess.remove_absolute(audio.settings_path)
	scene.audio.shutdown()
	await create_timer(0.2).timeout
	scene.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	print("ASSET + AUDIO CHECKS: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
