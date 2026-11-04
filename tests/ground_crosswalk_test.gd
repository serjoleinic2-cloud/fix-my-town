extends SceneTree

const Visuals = preload("res://scripts/ground_road_visuals.gd")
const Art = preload("res://scripts/art.gd")
const Grid = preload("res://scripts/territory_grid.gd")
var failures := 0
var scene: Node

func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func has_cleared_surface(cell: Vector2i) -> bool:
	var center: Vector3 = scene.game.territory.cell_world(cell.x, cell.y)
	var material := Art.material(Visuals.cleared_color(cell.x, cell.y))
	for item in scene.territory_visuals.get_node("GridCells").get_children():
		if not item is MultiMeshInstance3D or item.material_override != material:
			continue
		# Dummy rendering does not retain GPU MultiMesh transform readback.
		# Check the material batch here; the GL run also checks exact tile positions.
		if DisplayServer.get_name() == "headless":
			return item.multimesh.instance_count > 0
		for index in range(item.multimesh.instance_count):
			var transform: Transform3D = item.multimesh.get_instance_transform(index)
			if Vector2(transform.origin.x, transform.origin.z).distance_to(Vector2(center.x, center.z)) < 0.01:
				return true
	return false

func capture(file_name: String) -> void:
	for frame in range(8):
		await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/screenshots/" + file_name + ".png")

func test_markings() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var parts := Visuals.junction_markings(holder, Vector3.ZERO, direction)
		check(parts.size() == 6, "Five zebra stripes and one STOP line per approach")
		var along := Vector3(direction.x, 0, direction.y)
		var across := Vector3(-direction.y, 0, direction.x)
		var previous_end := -INF
		var crossing_outer_edge := 0.0
		for index in range(5):
			var stripe := parts[index]
			var width_across := stripe.scale.z if direction.x != 0 else stripe.scale.x
			var length_along := stripe.scale.x if direction.x != 0 else stripe.scale.z
			var lateral := stripe.position.dot(across)
			check(length_along >= 0.8 and length_along > width_across * 2, "Stripe long edge follows vehicle travel: " + str(direction))
			check(is_equal_approx(stripe.position.dot(along), 1.72), "All zebra stripes share the same approach depth")
			check(lateral - width_across / 2 > previous_end + 0.10, "Side-by-side stripes have asphalt gaps and never overlap: " + str(direction))
			check(absf(lateral) + width_across / 2 < 1.4, "Stripes stay inside the 2.8m road")
			crossing_outer_edge = maxf(crossing_outer_edge, stripe.position.dot(along) + length_along / 2)
			previous_end = lateral + width_across / 2
		check(previous_end > 1.2, "Five stripes cover almost the entire road width")
		var stop := parts[5]
		check(stop.position.dot(along) - 0.05 > crossing_outer_edge + 0.08, "STOP line is outside the crossing with a visible gap")
		check(is_equal_approx(stop.position.dot(across), -0.70), "STOP line belongs to incoming right-hand traffic lane")
		check(stop.position.dot(along) + 0.05 < Grid.CELL_SIZE / 2, "STOP line stays inside its owning tile")
		for part in parts:
			part.free()
	holder.free()

func run() -> void:
	test_markings()
	root.size = Vector2i(1080, 2400)
	root.content_scale_size = Vector2i(540, 1200)
	scene = load("res://main.tscn").instantiate()
	scene.game.save_path = "user://ground_crosswalk_test.json"
	root.add_child(scene)
	scene.set_process(false)
	scene.game.start_empty_city()
	scene.game.budget = 5000
	scene.game.campaign_finished = true
	scene.close_subsidy_offer()
	# Reproduce the phone's site: three cleared tiles plus one treeless forest tile.
	for cell in [Vector2i(12, 16), Vector2i(13, 16), Vector2i(13, 17)]:
		check(scene.game.clear_grid_cell(cell.x, cell.y), "Clear test-only tile")
	scene.refresh()
	check(has_cleared_surface(Vector2i(12, 16)), "Free cell renders an actual sand surface after batching")
	check(not has_cleared_surface(Vector2i(12, 17)), "Untouched forest clearing does not render sand")
	var sand := Visuals.cleared_color(12, 16)
	var natural := Color("607e4c")
	check(sand.r > sand.g and sand.g > sand.b and Vector3(sand.r, sand.g, sand.b).distance_to(Vector3(natural.r, natural.g, natural.b)) > 0.25, "Sand is visibly distinct from green natural ground")
	check(sand != Visuals.cleared_color(13, 16) and sand == Visuals.cleared_color(12, 16), "Cell variation is small and deterministic")
	check(scene.game.territory.placement_reason(12, 16, "fire_station") == "clear_first", "Three cleared cells do not allow fire station placement")
	check(scene.game.clear_grid_cell(12, 17), "Fourth tile can be cleared in the isolated fixture")
	scene.refresh()
	check(scene.game.territory.placement_reason(12, 16, "fire_station") == "", "All four cleared tiles beside connected road permit fire station")
	for cell in [Vector2i(12, 16), Vector2i(13, 16), Vector2i(12, 17), Vector2i(13, 17)]:
		check(has_cleared_surface(cell), "Each cleared tile has sand: " + str(cell))
	scene.set_camera_focus(scene.game.territory.cell_world(12, 17) + Vector3(7, 0, 7))
	await capture("ground-cleared-2x2")
	scene.catalog_grid_target = Vector2i(12, 16)
	scene.begin_catalog_placement("fire_station")
	var budget_before: int = scene.game.budget
	check(scene.territory_reason() == "" and not scene.sheet.find_child("ConfirmTerritory", true, false).disabled, "Fire station preview is valid and confirmation enabled")
	await capture("ground-fire-station-valid")
	check(scene.game.budget == budget_before and scene.game.construction_job.is_empty(), "Preview never spends coins or starts construction")
	scene.cancel_catalog_placement()
	scene.close_sheet()
	for cell in [Vector2i(9, 19), Vector2i(10, 19), Vector2i(9, 20), Vector2i(10, 20)]:
		check(scene.game.clear_grid_cell(cell.x, cell.y), "Prepare test-only neighbouring house")
	check(scene.game.territory.place_building(9, 19, "house"), "Neighbouring building creates a T junction")
	scene.refresh()
	scene.set_camera_focus(scene.game.territory.cell_world(11, 18) + Vector3(7, 0, 7))
	await capture("ground-junction-zebra")
	scene.game.save_game()
	check(scene.game.load_game() and scene.game.territory.placement_reason(12, 16, "fire_station") == "", "Cleared footprint stays valid after save/load")
	scene.audio.shutdown()
	await create_timer(0.2).timeout
	scene.queue_free()
	await process_frame
	await process_frame
	DirAccess.remove_absolute("user://ground_crosswalk_test.json")
	print("GROUND AND CROSSWALKS: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
