extends SceneTree

const ExternalLocations = preload("res://scripts/external_locations.gd")
const Simulation = preload("res://scripts/simulation.gd")

var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var locations := ExternalLocations.new()
	check(locations.entries.size() == ExternalLocations.DEFINITIONS.size() and locations.entries.size() == 4, "Four regional campuses")
	for location_id: String in ExternalLocations.DEFINITIONS:
		check(locations.is_visible(location_id), location_id + " is visible")
		check(not locations.is_active(location_id), location_id + " is inactive by default")
		check(locations.entries[location_id].module_levels.size() == 4, location_id + " has four modules")
	var saved := locations.data()
	locations.entries["rail_depot"].state = "active"
	locations.entries["rail_depot"].module_levels[0] = 2
	locations.load_data(saved)
	check(not locations.is_active("rail_depot"), "Loading resets an active depot to the saved state")
	check(int(locations.entries["rail_depot"].module_levels[0]) == 0, "Module levels are restored")
	# Regression: saves written before the campuses existed, and partial entries,
	# must load without a script error.
	locations.load_data({})
	check(not locations.is_active("energy_complex"), "Empty data keeps campuses inactive")
	locations.load_data({"airport": {}})
	check(not locations.is_active("airport"), "An empty campus entry is accepted")
	locations.load_data({"airport": {"state": "active", "module_levels": [1, 2], "energy_factor": 0.5}})
	check(locations.is_active("airport") and float(locations.entries["airport"].energy_factor) == 0.5, "A partial entry loads what it has")
	# A real save without the external_locations key still loads end to end.
	var game := Simulation.new(false)
	game.save_path = "user://external_locations_%s.json" % str(Time.get_ticks_usec())
	game.start_empty_city()
	game.save_game()
	var raw := FileAccess.open(game.save_path, FileAccess.READ)
	var parsed: Dictionary = JSON.parse_string(raw.get_as_text())
	raw.close()
	parsed.erase("external_locations")
	var rewrite := FileAccess.open(game.save_path, FileAccess.WRITE)
	rewrite.store_string(JSON.stringify(parsed))
	rewrite.close()
	var loaded := Simulation.new(false)
	loaded.save_path = game.save_path
	check(loaded.load_game() == true, "An old save without external_locations loads")
	print("EXTERNAL LOCATIONS CHECKS: ", "PASS" if failures.is_empty() else "FAIL")
	for f in failures:
		print(f)
	quit(0 if failures.is_empty() else 1)
