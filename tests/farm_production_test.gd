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
	game.campaign_stage = 12
	game.territory.set_expansion_level(12)
	var site: Vector2i = game.territory.bridge_site
	check(game.territory.place_bridge(site.x, site.y), "The bridge is built")
	var sites := game.territory.farm_start_sites()
	check(game.territory.place_building(sites[0].x, sites[0].y, "field"), "A field is built")
	check(game.territory.place_building(sites[1].x, sites[1].y, "barn"), "A barn is built")
	check(game.farm_production_per_minute() == 10.0, "One field grows 10 goods per minute")
	check(game.farm_storage_capacity() == 600.0, "Base 300 plus one barn of 300")
	game.advance_farm_stock(5)
	check(is_equal_approx(game.farm_stock, 50.0), "Five minutes of one field fill 50 goods")
	game.advance_farm_stock(1000)
	check(is_equal_approx(game.farm_stock, game.farm_storage_capacity()), "Stock never exceeds the storage limit")
	game.save_game()
	var reloaded := Simulation.new(false)
	reloaded.save_path = save_path
	check(reloaded.load_game(), "The saved city loads")
	check(is_equal_approx(reloaded.farm_stock, game.farm_stock), "Farm stock survives save and load")
	print("FARM PRODUCTION CHECKS: ", "PASS" if failures.is_empty() else "FAIL")
	for message in failures:
		push_error(message)
	quit(0 if failures.is_empty() else 1)
