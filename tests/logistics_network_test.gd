extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const Catalog = preload("res://scripts/asset_catalog.gd")
const GameObjectScene = preload("res://scenes/objects/game_object.tscn")
const MainScript = preload("res://scripts/main.gd")

var failures := 0

func has_batched_feature(model: Node, feature: StringName) -> bool:
	for batch in model.find_children("*", "MultiMeshInstance3D", true, false):
		if batch.has_meta(feature):
			return true
	return false

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func prepare_footprint(game: RefCounted, col: int, row: int, size: Vector2i) -> void:
	for dy in range(size.y):
		for dx in range(size.x):
			if game.territory.state_at(col + dx, row + dy) == "forest":
				game.territory.cells[row + dy][col + dx] = "free"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var motion_routes: Array = [
		[Vector3.ZERO, Vector3(10, 0, 0)],
		[Vector3(10, 0, 0), Vector3(20, 0, 0)]
	]
	var halted_progress := MainScript.logistics_progress_after_motion(motion_routes, 0, 3.0, 2.0, 0.0)
	check(int(halted_progress.route_index) == 0 and is_equal_approx(float(halted_progress.progress), 3.0), "A logistics vehicle stopped at a signal does not consume route progress")
	var partial_progress := MainScript.logistics_progress_after_motion(motion_routes, 0, 3.0, 2.0, 0.5)
	check(int(partial_progress.route_index) == 0 and is_equal_approx(float(partial_progress.progress), 4.0), "A logistics vehicle commits only its allowed movement distance")
	var resumed_progress := MainScript.logistics_progress_after_motion(motion_routes, 0, 9.5, 1.0, 1.0)
	check(int(resumed_progress.route_index) == 1 and is_equal_approx(float(resumed_progress.progress), 0.5), "A logistics vehicle advances to the next delivery leg only after reaching the route end")
	var turn_route: Array = MainScript.logistics_driving_route([Vector3.ZERO, Vector3(6, 0, 0), Vector3(6, 0, 6)])
	var shortest_turn_segment := INF
	for turn_index in range(1, turn_route.size()):
		shortest_turn_segment = minf(shortest_turn_segment, (turn_route[turn_index] as Vector3).distance_to(turn_route[turn_index - 1]))
	check(turn_route.size() == 5 and shortest_turn_segment < 0.7, "A logistics truck transitions between lane offsets through the junction center rather than jumping across the corner")
	var spawn_route: Array = [Vector3(0, 0.32, 0), Vector3(0, 0.32, -20)]
	var occupied_start: Array = [{"position": Vector3(0, 0.32, 0), "half_extents": Vector2(1.8, 0.6)}]
	var safe_spawn_progress := MainScript.logistics_spawn_progress(spawn_route, 0.0, occupied_start)
	var safe_spawn_pose := MainScript.logistics_route_pose(spawn_route, safe_spawn_progress)
	check(safe_spawn_progress > 0.0 and safe_spawn_pose.position.distance_to(Vector3.ZERO) > 2.5, "A logistics truck does not spawn on top of an occupied bus or car")
	var game := Simulation.new(false)
	game.save_path = "user://logistics_network_test.json"
	game.start_empty_city()
	game.campaign_stage = 6
	game.budget = 20000
	check(Catalog.footprint_cells("logistics_center") == Vector2i(2, 2) and Catalog.footprint_cells("warehouse") == Vector2i(2, 2), "Logistics center and warehouse both fit standard 2x2 lots")
	check(game.can_build_logistics_center() and not game.can_build_warehouse(), "Stage six unlocks one logistics center before warehouses")
	prepare_footprint(game, 9, 19, Vector2i(2, 2))
	check(game.build_grid_building(9, 19, "logistics_center"), "Connected city can build its aligned logistics center")
	var center: Dictionary = game.territory.building_by_id("pine_district_logistics_center_9_19")
	check(not center.is_empty() and game.logistics_warehouse_limit() == 1, "Level-one center authorizes one warehouse")
	if center.is_empty():
		quit(1)
		return
	prepare_footprint(game, 15, 19, Vector2i(2, 2))
	check(game.can_build_warehouse() and game.build_grid_building(15, 19, "warehouse"), "A warehouse can be built on a connected 2x2 site")
	var warehouse: Dictionary = game.territory.building_by_id("pine_district_warehouse_15_19")
	if warehouse.is_empty():
		quit(1)
		return
	check(not warehouse.is_empty() and game.territory.road_distance_between_buildings(center, warehouse, game.logistics_center_range()) >= 0, "Warehouse is connected to the dispatch center within its road range")
	check(not game.logistics_vehicle_routes(str(center.instance_id)).is_empty(), "Center dispatch trucks receive a road route to the warehouse")
	check(not game.can_build_warehouse() and not game.logistics_upgrade_allowed(warehouse), "Center level one blocks extra warehouses and warehouse upgrades")
	prepare_footprint(game, 12, 16, Vector2i(2, 2))
	check(game.build_grid_building(12, 16, "house"), "A home can be built beside the local road network")
	check(game.logistics_covered_buildings(warehouse.instance_id).any(func(entry: Dictionary): return entry.instance_id == "pine_district_house_12_16"), "Warehouse coverage follows connected roads and reaches nearby homes")
	check(not game.logistics_vehicle_routes(str(warehouse.instance_id)).is_empty(), "Warehouse delivery trucks receive local road routes")
	var police := GameObjectScene.instantiate()
	root.add_child(police)
	police.setup("police_station", "police_visual_test")
	var police_model: Variant = police.visual_root.get_child(0)
	var heli: Node3D = police_model.find_child("PoliceHelicopter", true, false)
	check(has_batched_feature(police_model, "HelipadH") and heli != null, "Police station displays an H helipad and its procedural helicopter")
	police_model._process(100.0)
	check(heli.visible and police_model.helicopter_state == "landing", "Helicopter periodically approaches the helipad")
	police_model._process(10.0)
	check(police_model.helicopter_state == "landed", "Helicopter lands and waits at the police station")
	police_model._process(30.0)
	check(police_model.helicopter_state == "departing" and Vector2(police_model.helicopter_departure_target.x - police_model.helicopter_pad.x, police_model.helicopter_departure_target.z - police_model.helicopter_pad.z).length() > 15.0, "Helicopter departs in a randomized direction")
	police_model._process(10.0)
	check(police_model.helicopter_state == "waiting" and not heli.visible, "Helicopter leaves the scene and returns after a delay")
	police.queue_free()
	await process_frame
	var fire_station := GameObjectScene.instantiate()
	root.add_child(fire_station)
	fire_station.setup("fire_station", "fire_visual_test")
	var fire_model: Variant = fire_station.visual_root.get_child(0)
	var fire_sign: Label3D = fire_model.find_child("FireStation911", true, false) as Label3D
	check(fire_sign != null and fire_sign.text == "911" and has_batched_feature(fire_model, "FireStation911Badge") and has_batched_feature(fire_model, "FireEngineRoofBadge"), "Fire station has a 911 roof badge and fire engine roof insignia")
	fire_station.queue_free()
	await process_frame
	var hospital := GameObjectScene.instantiate()
	root.add_child(hospital)
	hospital.setup("hospital", "hospital_visual_test")
	var hospital_model: Variant = hospital.visual_root.get_child(0)
	check(has_batched_feature(hospital_model, "HospitalRoofBadge") and has_batched_feature(hospital_model, "AmbulanceRoofBadge") and has_batched_feature(hospital_model, "AmbulanceSideBadge"), "Hospital and ambulance carry visible medical emblems")
	hospital.queue_free()
	await process_frame
	var depot := GameObjectScene.instantiate()
	root.add_child(depot)
	depot.setup("depot", "repair_visual_test")
	var depot_model: Variant = depot.visual_root.get_child(0)
	check(has_batched_feature(depot_model, "RepairServiceRoofBadge") and has_batched_feature(depot_model, "RepairVehicleRoofBadge"), "Repair depot and work van have matching roof emblems")
	depot.queue_free()
	await process_frame
	var truck := GameObjectScene.instantiate()
	root.add_child(truck)
	truck.setup("delivery_truck", "delivery_shape_test")
	var truck_model: Variant = truck.visual_root.get_child(0)
	check(has_batched_feature(truck_model, "DeliveryCargoBox") and has_batched_feature(truck_model, "DeliveryCab"), "Logistics truck has a distinct enclosed cargo box and cab")
	check(float(truck_model.delivery_cargo_height) > float(truck_model.delivery_cab_height), "Closed cargo box stands higher than the cab roof")
	truck.queue_free()
	await process_frame
	check(not game.can_demolish_grid_building(center.instance_id), "A logistics center with active warehouses cannot be removed")
	check(game.upgrade_grid_house(center.instance_id, true), "The logistics center can be upgraded")
	check(game.logistics_warehouse_limit() == 2 and game.can_build_warehouse() and game.logistics_upgrade_allowed(warehouse), "Center level two permits a second warehouse and level-two warehouse upgrades")
	check(game.upgrade_grid_house(warehouse.instance_id, true) and int(game.territory.building_by_id(warehouse.instance_id).level) == 2, "Warehouse upgrade changes its stored level")
	var ui_script: Script = load("res://scripts/main.gd")
	var ui: Node = ui_script.new()
	ui.game = game
	check(ui.catalog_items_for("infrastructure").has("logistics_center") and ui.catalog_items_for("infrastructure").has("warehouse"), "Construction menu exposes logistics buildings")
	ui.free()
	game.save_game()
	var restored := Simulation.new(false)
	restored.save_path = game.save_path
	check(restored.load_game() and restored.logistics_warehouse_limit() == 2 and int(restored.territory.building_by_id(warehouse.instance_id).level) == 2, "Center and warehouse progression survive saving")
	DirAccess.remove_absolute(game.save_path)
	DirAccess.remove_absolute(game.save_path + ".tmp")
	print("LOGISTICS NETWORK CHECKS: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
