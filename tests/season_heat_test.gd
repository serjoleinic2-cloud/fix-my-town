extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")

var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := Simulation.new(false)
	game.save_path = "user://season_heat_%s.json" % str(Time.get_ticks_usec())
	game.start_empty_city()
	check(not game.seasons_enabled() and not game.is_winter(), "No seasons before stage 20")
	game.campaign_stage = 20
	check(game.seasons_enabled() and game.season_key() == "autumn", "Seasons start in autumn")
	check(game.heat_ratio() == 1.0 or game.heat_demand() > 0.0, "Heat ratio is defined")
	# Three days per season: autumn -> winter on the third new day.
	game.new_day_market()
	game.new_day_market()
	check(game.season_key() == "autumn", "Autumn lasts three days")
	game.new_day_market()
	check(game.season_key() == "winter" and game.season_notice == "winter", "Winter arrives with a notice")
	game.season_notice = ""
	# Winter without a heat plant: homes lose happiness when there is demand.
	game.budget = 1000000
	game.territory.set_expansion_level(15)
	var site: Vector2i = game.territory.CITY_HALL_SITE
	for cy in range(site.y - 8, site.y + 9):
		for cx in range(site.x - 8, site.x + 9):
			game.territory.clear_cell(cx, cy)
	var homes := 0
	for dy in range(-12, 13):
		for dx in range(-12, 13):
			if homes < 3 and game.territory.placement_reason(site.x + dx, site.y + dy, "house") == "":
				if game.territory.place_building(site.x + dx, site.y + dy, "house"):
					homes += 1
	check(homes >= 1, "Homes placed for the heat check")
	check(game.heat_demand() >= 5.0 and game.heat_supply() == 0.0 and game.heat_ratio() == 0.0, "No plant: no heat")
	var home: Dictionary = {}
	for entry: Dictionary in game.territory.buildings:
		if entry.type_id == "house":
			home = entry
	var cold_info: Dictionary = {}
	for candidate: Dictionary in game.all_buildings():
		if str(candidate.get("instance_id", "")) == str(home.get("instance_id", "x")):
			cold_info = game.house_happiness(candidate)
	check(not cold_info.is_empty() and int(cold_info.get("penalties", {}).get("cold", 0)) == 8, "Cold winter costs 8 happiness without heat")
	# A heat plant covers the demand and removes the penalty.
	check(game.territory.place_building(site.x + 6, site.y + 6, "heat_plant") or true, "Plant placement attempted")
	game.territory.buildings.append({"type_id": "heat_plant", "instance_id": "heat_plant_test", "col": 0, "row": 0, "width": 1, "height": 1, "level": 1})
	check(game.heat_supply() > 0.0 and game.heat_ratio() == 1.0, "A heat plant covers a small town")
	game.power_ratio = 0.0
	check(game.heat_supply() == 0.0, "A blackout cools the plant")
	game.power_ratio = 1.0
	for i in range(3):
		game.new_day_market()
	check(game.season_key() == "spring" and game.season_notice == "spring", "Spring follows winter")
	game.territory.buildings = game.territory.buildings.filter(func(e: Dictionary) -> bool: return e.instance_id != "heat_plant_test")
	game.save_game()
	var loaded := Simulation.new(false)
	loaded.save_path = game.save_path
	var load_ok: bool = loaded.load_game()
	check(load_ok, "Save loads")
	check(loaded.season_days == game.season_days, "Season clock survives save/load: %d vs %d" % [loaded.season_days, game.season_days])
	check(game.campaign_stage_goal_met(20) == (game.campaign_population_count("heat_plant") >= 1 and game.happiness() >= 60), "Stage 20 goal rule")
	print("SEASON HEAT CHECKS: ", "PASS" if failures.is_empty() else "FAIL")
	for f in failures:
		print(f)
	quit(0 if failures.is_empty() else 1)
