extends SceneTree

var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(540, 1200)
	root.add_child(viewport)
	var scene = load("res://main.tscn").instantiate()
	scene.game.save_path = "user://test_service_catalog_refresh.json"
	scene.settings_path = "user://test_service_catalog_graphics.json"
	scene.set_process(false)
	viewport.add_child(scene)
	# The scene tree keeps child nodes processing when only the main node is
	# paused. Disable ambience before yielding so teardown cannot restart audio.
	scene.audio.set_process(false)
	scene.audio.set_physics_process(false)
	for frame in range(3):
		await process_frame
	check(scene.game.empty_city_mode, "Service catalog test starts from an isolated empty-city fixture")
	var budget_before: int = scene.game.budget
	var stage_before: int = scene.game.campaign_stage
	var buildings_before: int = scene.game.all_buildings().size()
	var territory_before: String = JSON.stringify(scene.game.territory.data())
	var territory_visual_signature_before: String = scene.territory_signature
	var traffic_signature_before: String = scene.scenery.traffic_controller.grid_signature
	var territory_visual_count_before: int = scene.territory_visuals.get_child_count()
	scene.open_service_catalog("fire_station", Vector2i(17, 19))
	scene.refresh()
	for frame in range(2):
		await process_frame
	var baseline_profile: Dictionary = scene.service_refresh_profile.duplicate(true)
	check(scene.selection_kind == "catalog" and scene.catalog_category == "services" and scene.catalog_screen_mode == "items", "Free-cell service action opens the service list directly")
	check(scene.catalog_grid_target == Vector2i(17, 19), "Service list preserves the chosen target cell")
	var item_list := scene.sheet.find_child("CatalogItems", true, false) as VBoxContainer
	check(item_list != null and item_list.get_child_count() == 4, "The service list displays its four construction options")
	check(baseline_profile.get("mode", "") == "baseline_full", "The first debug service-list opening records the full-refresh baseline")
	check(baseline_profile.has("plots_and_territory") and baseline_profile.has("configure_city_traffic") and baseline_profile.has("build_sheet"), "Baseline profile separates map, traffic and sheet refresh work")
	check(baseline_profile.has("traffic_configure_grid_ms") and baseline_profile.has("territory_data_and_signature_ms"), "Baseline profile measures traffic-grid setup and territory serialization separately")
	check(scene.territory_signature == territory_visual_signature_before and scene.territory_visuals.get_child_count() == territory_visual_count_before, "Opening the service list leaves map visuals untouched")
	check(scene.scenery.traffic_controller.grid_signature == traffic_signature_before, "Opening the service list does not rebuild the traffic grid")
	check(scene.game.budget == budget_before and scene.game.campaign_stage == stage_before and scene.game.all_buildings().size() == buildings_before, "Opening the service list does not change the city state")
	check(JSON.stringify(scene.game.territory.data()) == territory_before, "Opening the service list leaves the saved territory unchanged")
	scene.open_service_catalog("fire_station", Vector2i(17, 19))
	scene.refresh()
	var optimized_profile: Dictionary = scene.service_refresh_profile.duplicate(true)
	check(optimized_profile.get("mode", "") == "ui_only", "Subsequent service-list openings use the UI-only refresh path")
	check(not optimized_profile.has("plots_and_territory") and not optimized_profile.has("configure_city_traffic"), "The optimized service path skips world, territory and traffic refresh work")
	scene.audio.shutdown()
	await create_timer(0.2).timeout
	scene.queue_free()
	await process_frame
	viewport.queue_free()
	await process_frame
	await process_frame
	DirAccess.remove_absolute("user://test_service_catalog_refresh.json")
	DirAccess.remove_absolute("user://test_service_catalog_graphics.json")
	if failures > 0:
		quit(1)
	else:
		print("Service catalog refresh checks passed.")
		quit(0)
