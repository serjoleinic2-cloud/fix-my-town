extends SceneTree

const ExternalLocations = preload("res://scripts/external_locations.gd")

func _init() -> void:
	var locations := ExternalLocations.new()
	assert(locations.entries.size() == 3)
	for location_id: String in ExternalLocations.DEFINITIONS:
		assert(locations.is_visible(location_id))
		assert(not locations.is_active(location_id))
		assert(locations.entries[location_id].module_levels.size() == 4)
		assert(int(ExternalLocations.DEFINITIONS[location_id].activation_level) >= 20)
	var saved := locations.data()
	locations.entries["rail_depot"].state = "active"
	locations.entries["rail_depot"].module_levels[0] = 2
	locations.load_data(saved)
	assert(not locations.is_active("rail_depot"))
	assert(int(locations.entries["rail_depot"].module_levels[0]) == 0)
	locations.load_data({})
	assert(not locations.is_active("energy_complex"))
	print("external_locations_test: PASS")
	quit()
