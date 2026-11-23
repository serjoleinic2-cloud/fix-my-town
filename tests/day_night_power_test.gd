extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const Catalog = preload("res://scripts/asset_catalog.gd")

var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := Simulation.new(false)
	game.save_path = "user://day_night_%s.json" % str(Time.get_ticks_usec())
	game.start_empty_city()
	game.day_time = 0.5
	check(game.daylight() > 0.9 and not game.is_night(), "Noon is bright")
	game.day_time = 0.0
	check(game.daylight() == 0.0 and game.is_night(), "Midnight is dark")
	game.day_time = 0.99
	game.tick(DAY_FIX(game), true)
	check(game.day_time < 0.1, "The day clock wraps around midnight")
	check(not game.power_enabled(), "Power rules stay off before stage 16 and without energy buildings")
	game.campaign_stage = 16
	check(game.power_enabled(), "Stage 16 turns power rules on")
	for type_id in ["street_lamp", "wind_turbine", "solar_panel", "power_plant", "battery", "fitness_club", "pizzeria", "theatre", "aquapark", "amusement_park"]:
		check(Catalog.TYPES.has(type_id) and Catalog.unlock_level(type_id) >= 16, "%s is a catalog type unlocked at stage 16 or later" % type_id)
	# Supply follows the sun and the wind.
	game.territory.buildings.append({"type_id": "solar_panel", "instance_id": "t_solar", "col": 1, "row": 1, "width": 2, "height": 2, "level": 1})
	game.territory.buildings.append({"type_id": "wind_turbine", "instance_id": "t_wind", "col": 4, "row": 1, "width": 2, "height": 2, "level": 1})
	game.day_time = 0.5
	var noon_supply := game.power_supply()
	game.day_time = 0.0
	var night_supply := game.power_supply()
	check(noon_supply > night_supply and night_supply > 0.0 and night_supply <= 60.0, "Solar works by day, wind keeps blowing at night")
	game.territory.buildings.append({"type_id": "power_plant", "instance_id": "t_plant", "col": 8, "row": 1, "width": 2, "height": 2, "level": 1})
	check(game.power_supply() >= night_supply + 180.0 - 0.01, "A power plant adds a steady 180")
	# Demand beyond supply drops the ratio; a battery covers the gap.
	game.territory.buildings.clear()
	for index in range(4):
		game.territory.buildings.append({"type_id": "aquapark", "instance_id": "t_aqua_%d" % index, "col": index * 3, "row": 1, "width": 2, "height": 2, "level": 1})
	game.day_time = 0.5
	game.advance_power(1.0)
	check(game.power_ratio < 0.2, "No stations: the ratio collapses")
	game.territory.buildings.append({"type_id": "power_plant", "instance_id": "t_plant2", "col": 20, "row": 1, "width": 2, "height": 2, "level": 1})
	game.territory.buildings.append({"type_id": "battery", "instance_id": "t_battery", "col": 24, "row": 1, "width": 2, "height": 2, "level": 1})
	game.territory.buildings.erase(game.territory.buildings[0])
	game.territory.buildings.erase(game.territory.buildings[0])
	game.advance_power(10.0)
	check(game.power_ratio >= 0.99 and game.battery_charge > 0.0, "Surplus power charges the battery")
	var charge := game.battery_charge
	game.territory.buildings.append({"type_id": "amusement_park", "instance_id": "t_ride", "col": 30, "row": 1, "width": 2, "height": 2, "level": 1})
	for extra in range(3):
		game.territory.buildings.append({"type_id": "amusement_park", "instance_id": "t_ride_x%d" % extra, "col": 36 + extra * 3, "row": 1, "width": 2, "height": 2, "level": 1})
	game.advance_power(1.0)
	check(game.battery_charge < charge and game.power_ratio >= 0.99, "The battery covers a short deficit")
	game.battery_charge = 0.0
	game.advance_power(1.0)
	check(game.power_ratio < 1.0, "An empty battery cannot cover the deficit")
	# Leisure buildings need power.
	var theatre := {"type_id": "theatre", "position": Vector3.ZERO}
	game.power_ratio = 1.0
	game.day_time = 0.0
	check(game.leisure_environment(theatre) == 6, "A theatre gives its full bonus at night")
	game.day_time = 0.5
	check(game.leisure_environment(theatre) == 3, "A theatre gives half the bonus in daytime")
	game.power_ratio = 0.2
	check(game.leisure_environment(theatre) == 0, "Without power leisure buildings give nothing")
	# Stages continue to 19 and persist.
	check(Simulation.MAX_CAMPAIGN_STAGE == 19 and game.campaign_stage_title(19) != "", "The campaign now reaches stage 19")
	game.campaign_stage = 18
	game.day_time = 0.77
	game.battery_charge = 123.0
	game.territory.buildings.clear()
	game.save_game()
	var loaded := Simulation.new(false)
	loaded.save_path = game.save_path
	check(loaded.load_game() and is_equal_approx(loaded.day_time, 0.77) and is_equal_approx(loaded.battery_charge, 123.0), "Clock and battery survive save and load")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path))
	if failures.is_empty():
		print("DAY NIGHT POWER CHECKS: PASS")
		quit(0)
	else:
		print("DAY NIGHT POWER CHECKS: FAIL")
		for failure in failures:
			push_error(failure)
		quit(1)

func DAY_FIX(game: Simulation) -> float:
	return Simulation.DAY_LENGTH_SECONDS * 0.02
