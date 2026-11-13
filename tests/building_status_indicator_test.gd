extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const Indicators = preload("res://scripts/world_status_indicators.gd")

var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func spec_of(specs: Array[Dictionary], kind: String) -> Dictionary:
	for spec: Dictionary in specs:
		if str(spec.get("kind", "")) == kind:
			return spec
	return {}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	check("FlameAnimation" in main_source and "ProblemPerimeter" in main_source, "Fire visuals use animated 2D flame and a world-space problem perimeter")
	check("AnimatedSmoke" not in main_source and "DangerLevel" not in main_source, "Fire visuals do not recreate smoke or the old overhead danger sign")
	var game = Simulation.new(true)
	var target := Simulation.FIRST_FIRE_TARGET
	check(game.start_fire(target), "Test fire starts on a concrete building")
	game.fire_damage[target] = 35.0
	var fire_spec := spec_of(Indicators.specs_for(game), "fire")
	check(not fire_spec.is_empty() and is_equal_approx(float(fire_spec.progress), 0.35), "Active fire exposes a red realtime damage bar")
	check((fire_spec.position as Vector3).distance_to(game.building_world_for_id(target) + Vector3(0, 6.3, 0)) < 0.01, "Status bar is anchored in world space above its building")

	game.job = "fire"
	game.target_instance_id = target
	game.job_vehicle_id = "test_station_engine_1"
	game.job_phase = "repair"
	game.repair_left = 2.0
	var repair_spec := spec_of(Indicators.specs_for(game), "repair")
	check(not repair_spec.is_empty() and is_equal_approx(float(repair_spec.progress), 0.5), "On-site firefighting changes the bar to yellow repair progress")

	game.fires.clear()
	game.job = ""
	game.construction_job = {"kind": "upgrade_legacy", "identifier": target, "index": 0, "total": 6.0, "remaining": 3.0}
	var construction_spec := spec_of(Indicators.specs_for(game), "construction")
	check(not construction_spec.is_empty() and is_equal_approx(float(construction_spec.progress), 0.5), "Construction and upgrades expose a blue progress bar")

	var indicators := Indicators.new()
	root.add_child(indicators)
	indicators.sync([construction_spec])
	var sprite := indicators.indicators.values()[0] as Sprite3D
	check(sprite.billboard == BaseMaterial3D.BILLBOARD_ENABLED, "The compact bar faces the camera while remaining world anchored")
	check(str(sprite.get_meta("kind", "")) == "construction", "Indicator colour state is attached to the specific worksite")
	game.construction_job.clear()
	indicators.sync(Indicators.specs_for(game))
	await process_frame
	check(indicators.indicators.is_empty(), "Finished events remove their status bar")
	indicators.queue_free()

	if failures.is_empty():
		print("BUILDING STATUS INDICATOR CHECKS: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
