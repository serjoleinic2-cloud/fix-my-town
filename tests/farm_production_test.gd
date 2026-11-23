extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")

var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var save_path := "user://farm_production_%s.json" % str(Time.get_ticks_usec())
	var game := Simulation.new(false)
	game.save_path = save_path
	game.start_empty_city()
	check(game.farm_storage_capacity() == 0.0 and game.farm_production_per_minute() == 0.0, "No farm buildings means no farm output or storage")
	game.campaign_stage = 15
	game.territory.set_expansion_level(15)
	var site: Vector2i = game.territory.bridge_site
	check(game.territory.place_bridge(site.x, site.y), "The bridge is built")
	var sites := game.territory.farm_start_sites()
	check(game.territory.place_building(sites[0].x, sites[0].y, "field"), "A field is built")
	check(game.territory.place_building(sites[1].x, sites[1].y, "barn"), "A barn is built")
	check(game.farm_production_per_minute() == 10.0, "One field grows 10 goods per minute")
	check(game.farm_storage_capacity() == 600.0, "Base 300 plus one barn of 300")
	var field: Dictionary = game.territory.buildings.filter(func(e: Dictionary) -> bool: return e.type_id == "field")[0]
	var barn: Dictionary = game.territory.buildings.filter(func(e: Dictionary) -> bool: return e.type_id == "barn")[0]
	game.advance_farm_stock(2)
	check(is_equal_approx(game.farm_ready_amount(field), 20.0) and not game.farm_is_ready(field), "Two minutes fill 20 of 60 and the field is not ready")
	check(game.farm_collect_all().count == 0, "Nothing is collected before half full")
	game.advance_farm_stock(1)
	check(game.farm_is_ready(field) and game.farm_ready_count() == 1, "Half full means ready")
	var partial: Dictionary = game.farm_collect(str(field.instance_id))
	check(is_equal_approx(float(partial.amount), 30.0) and is_equal_approx(game.farm_stock, 30.0), "Early collection pays no bonus and fills the warehouse")
	game.advance_farm_stock(6)
	check(is_equal_approx(game.farm_ready_amount(field), 60.0), "A field holds six minutes of output")
	var timely: Dictionary = game.farm_collect(str(field.instance_id))
	check(is_equal_approx(float(timely.amount), 72.0) and is_equal_approx(float(timely.bonus), 12.0), "Timely collection pays a 20 percent bonus")
	game.advance_farm_stock(6)
	game.advance_farm_stock(5)
	var late: Dictionary = game.farm_collect(str(field.instance_id))
	check(is_equal_approx(float(late.amount), 60.0) and is_equal_approx(float(late.bonus), 0.0), "Late collection has no bonus")
	game.farm_stock = game.farm_storage_capacity()
	game.advance_farm_stock(6)
	check(game.farm_building_issue(field) == "storage_full" and game.farm_collect(str(field.instance_id)).is_empty(), "Full storage blocks collection")
	game.farm_stock = 0.0
	check(not game.farm_collect(str(field.instance_id)).is_empty(), "Collection works again once there is room")
	# Mill: grain is held back for the mill and comes out as flour worth 1.5x.
	game.budget = 100000
	var mill_site: Vector2i = game.territory.farm_campaign_sites()[2]
	# Placement rules are covered by the river farm test; here only production matters.
	game.territory.buildings.append({"type_id": "mill", "instance_id": "pine_district_mill_test", "col": mill_site.x, "row": mill_site.y, "width": 2, "height": 2, "level": 1, "inspected": false})
	var mill: Dictionary = game.territory.buildings.filter(func(e: Dictionary) -> bool: return e.type_id == "mill")[0]
	check(game.farm_building_issue(mill) == "no_grain", "A mill without grain idles")
	game.farm_stock = 0.0
	game.advance_farm_stock(6)
	game.farm_collect(str(field.instance_id), false)
	check(is_equal_approx(game.farm_grain, 60.0) and is_equal_approx(game.farm_stock, 0.0), "With a mill, field grain waits for it")
	game.advance_farm_stock(1)
	check(is_equal_approx(game.farm_grain, 48.0) and is_equal_approx(game.farm_ready_amount(mill), 18.0), "The mill grinds 12 grain into 18 flour per minute")
	var flour: Dictionary = game.farm_collect(str(mill.instance_id), false)
	check(is_equal_approx(float(flour.amount), 18.0) and is_equal_approx(game.farm_stock, 18.0), "Flour goes to the warehouse")
	# Bakery: flour from the mill becomes bread worth 2x.
	game.territory.buildings.append({"type_id": "bakery", "instance_id": "pine_district_bakery_test", "col": mill_site.x, "row": mill_site.y + 3, "width": 2, "height": 2, "level": 1, "inspected": false})
	var bakery: Dictionary = game.territory.buildings.filter(func(e: Dictionary) -> bool: return e.type_id == "bakery")[0]
	check(game.farm_building_issue(bakery) == "no_flour", "A bakery without flour idles")
	game.farm_stock = 0.0
	game.farm_grain = 0.0
	mill["ready"] = 90.0
	game.farm_collect(str(mill.instance_id), false)
	check(is_equal_approx(game.farm_flour, 90.0) and is_equal_approx(game.farm_stock, 0.0), "With a bakery, mill flour waits for it")
	game.advance_farm_stock(1)
	check(is_equal_approx(game.farm_flour, 82.0) and is_equal_approx(game.farm_ready_amount(bakery), 16.0), "The bakery bakes 8 flour into 16 bread per minute")
	check(is_equal_approx(float(game.farm_collect(str(bakery.instance_id), false).amount), 16.0) and is_equal_approx(game.farm_stock, 16.0), "Bread goes to the warehouse")
	game.territory.buildings.erase(bakery)
	game.advance_farm_stock(1)
	check(is_equal_approx(game.farm_flour, 0.0) and game.farm_stock > 16.0, "Without a bakery leftover flour goes to the warehouse")
	# Auto collection starts with a level 2 barn.
	game.farm_stock = 0.0
	game.farm_grain = 0.0
	field["ready"] = 0.0
	game.advance_farm_stock(6)
	check(game.farm_ready_amount(field) >= 60.0 or game.farm_stock > 0.0, "Fields fill up before auto collection")
	barn["level"] = 2
	check(game.farm_auto_collect_enabled(), "A level 2 barn enables auto collection")
	game.advance_farm_stock(1)
	check(game.farm_ready_amount(field) < 60.0, "The crew collected the full field by itself")
	game.territory.buildings.erase(mill)
	game.farm_flour = 7.0
	game.farm_grain = 12.0
	game.save_game()
	var reloaded := Simulation.new(false)
	reloaded.save_path = save_path
	check(reloaded.load_game(), "The saved city loads")
	check(is_equal_approx(reloaded.farm_stock, game.farm_stock) and is_equal_approx(reloaded.farm_grain, game.farm_grain) and is_equal_approx(reloaded.farm_flour, game.farm_flour), "Farm stock survives save and load")
	print("FARM PRODUCTION CHECKS: ", "PASS" if failures.is_empty() else "FAIL")
	for message in failures:
		push_error(message)
	quit(0 if failures.is_empty() else 1)
