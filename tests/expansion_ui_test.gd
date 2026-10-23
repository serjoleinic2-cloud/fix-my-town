extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
var failures: int = 0

func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for resolution in [Vector2i(360, 800), Vector2i(720, 1600), Vector2i(1080, 2400)]:
		var viewport := SubViewport.new()
		viewport.size = resolution
		viewport.size_2d_override = Vector2i(540, 1200)
		viewport.size_2d_override_stretch = true
		root.add_child(viewport)
		var scene = load("res://main.tscn").instantiate()
		scene.game.save_path = "user://test_startup.json"
		viewport.add_child(scene)
		scene.set_process(false)
		scene.game = Simulation.new()
		scene.game.save_path = "user://expansion_ui_test.json"
		scene.game.budget = 5000
		scene.game.clear_grid_cell(9, 19)
		scene.game.build_grid_road(9, 19)
		for dy in range(2):
			for dx in range(2):
				scene.game.clear_grid_cell(10 + dx, 19 + dy)
		for language in ["ru", "en"]:
			scene.game.language = language
			scene.open_territory()
			scene.set_territory_tool("house")
			scene.territory_cell = Vector2i(17, 27)
			scene.refresh()
			check(scene.territory_reason() == "outside" and scene.sheet.find_child("ConfirmTerritory", true, false).disabled, "An invalid footprint is explained and cannot be purchased")
			var budget: int = scene.game.budget
			var tap := InputEventMouseButton.new()
			tap.button_index = MOUSE_BUTTON_LEFT
			tap.position = scene.camera.unproject_position(scene.game.territory.cell_world(10, 19)) * scene.viewport_container.stretch_shrink
			scene.map_input(tap)
			check(scene.territory_cell == Vector2i(10, 19) and scene.game.budget == budget, "Map taps select a footprint without spending money")
			for frame in range(10):
				await process_frame
			check(scene.preview != null and scene.preview.type_id == "house", "The next building is visible as a 3D preview")
			check(scene.sheet.position.y > scene.hud.get_global_rect().end.y and scene.sheet.get_global_rect().end.y <= scene.navbar.position.y, "Expansion controls fit between HUD and navigation")
		# Подтверждение добавляет дом и открывает его собственную карточку.
		scene.sheet.find_child("ConfirmTerritory", true, false).pressed.emit()
		check(scene.selection_kind == "grid_house", "Construction opens the new home's card")
		for frame in range(3):
			await physics_frame
		var entry: Dictionary = scene.selected_grid_record()
		var tap := InputEventMouseButton.new()
		tap.button_index = MOUSE_BUTTON_LEFT
		tap.position = scene.camera.unproject_position(entry.position + Vector3(0, 4.7, 0)) * scene.viewport_container.stretch_shrink
		scene.close_sheet()
		scene.map_input(tap)
		check(scene.selection_kind == "grid_house" and scene.grid_selected_id == entry.instance_id, "Tapping the new home's roof selects its own state")
		scene.sheet.find_child("UpgradeButton", true, false).pressed.emit()
		check(scene.selection_kind == "grid_upgrade" and scene.preview.level == 2, "New homes use the same swappable upgrade preview")
		scene.sheet.find_child("ConfirmGridUpgrade", true, false).pressed.emit()
		check(scene.selected_grid_record().level == 2, "Confirmed upgrade changes the expansion level")
		scene.toggle_quality()
		check(scene.quality_mode and scene.quality_legend.visible, "Condition mode also covers expansion homes")
		scene.audio.shutdown()
		viewport.queue_free()
		await process_frame
	DirAccess.remove_absolute("user://expansion_ui_test.json")
	await create_timer(0.2).timeout
	print("EXPANSION UI: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
