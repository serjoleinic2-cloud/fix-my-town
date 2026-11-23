extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")

var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var save_path := "user://farm_guidance_%s.json" % str(Time.get_ticks_usec())
	var game := Simulation.new(false)
	game.save_path = save_path
	game.start_empty_city()
	check(game.farm_next_suggestion().is_empty(), "No farm advice before the bridge exists")
	game.campaign_stage = 15
	game.territory.set_expansion_level(15)
	var bridge_site: Vector2i = game.territory.bridge_site
	check(game.territory.place_bridge(bridge_site.x, bridge_site.y), "The bridge is built")
	game.budget = 100000
	var first := game.farm_next_suggestion()
	check(first.type_id == "field" and first.reason == "start" and first.site != Vector2i(-1, -1), "A farm starts with a field on a free lot")
	check(game.farm_build_suggestion() and game.farm_type_count("field") == 1, "The suggested field is built")
	var second := game.farm_next_suggestion()
	check(second.type_id == "barn" and second.reason == "storage", "The barn comes second because the harvest needs room")
	check(game.farm_build_suggestion() and game.farm_type_count("barn") == 1, "The suggested barn is built")
	check(game.farm_next_suggestion().type_id == "mill" and game.farm_next_suggestion().reason == "chain", "The mill follows to turn grain into flour")
	game.budget = 5
	check(not game.farm_next_suggestion().affordable and not game.farm_build_suggestion(), "An unaffordable suggestion is not built")
	game.budget = 100000
	# Demolishing remembers the building and it can be restored in place.
	var field: Dictionary = game.territory.buildings.filter(func(e: Dictionary) -> bool: return e.type_id == "field")[0]
	var field_cell := Vector2i(int(field.col), int(field.row))
	check(game.demolish_grid_building(str(field.instance_id)), "The field is demolished")
	check(game.farm_blueprint.size() == 1 and game.farm_restorable().size() == 1 and game.farm_restore_cost() == game.Catalog.cost("field"), "The demolished field is remembered and can be restored")
	check(game.farm_next_suggestion().type_id == "field", "Advice returns to the missing field")
	var loaded := Simulation.new(false)
	loaded.save_path = save_path
	check(loaded.load_game() and loaded.farm_blueprint.size() == 1, "The blueprint survives save and load")
	check(game.farm_restore_all() == 1 and game.farm_blueprint.is_empty(), "Restoring rebuilds the field and clears the blueprint")
	var restored := game.territory.building_at(field_cell.x, field_cell.y)
	check(not restored.is_empty() and restored.type_id == "field", "The field stands on its old lot")
	# Building the same type on a different lot also settles the memory.
	game.demolish_grid_building(str(restored.instance_id))
	check(game.farm_blueprint.size() == 1, "A second demolition is remembered")
	game.farm_blueprint[0]["col"] = field_cell.x + 100
	check(game.build_grid_building(field_cell.x, field_cell.y, "field") and game.farm_blueprint.is_empty(), "A manual rebuild on any lot clears the blueprint entry")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	if failures.is_empty():
		print("FARM GUIDANCE CHECKS: PASS")
		quit(0)
	else:
		print("FARM GUIDANCE CHECKS: FAIL")
		for failure in failures:
			push_error(failure)
		quit(1)
