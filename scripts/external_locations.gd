extends RefCounted

## Data-only foundation for the future regional campuses. They are
## deliberately inactive until their campaign level is enabled.
class_name ExternalLocations

const DEFINITIONS := {
	"energy_complex": {
		"title_ru": "Энергетический комплекс",
		"title_en": "Energy complex",
		"side": "top",
		"activation_level": 7,
		"modules": ["generation", "storage", "grid_control", "safety"],
		"position": Vector3(0, 0, -112),
		"footprint": Vector2(43.2, 43.2)
	},
	"rail_depot": {
		"title_ru": "Железнодорожное депо",
		"title_en": "Rail depot",
		"side": "right",
		"activation_level": 9,
		"modules": ["platform", "freight", "signals", "maintenance"],
		"position": Vector3(100, 0, -28),
		"footprint": Vector2(43.2, 43.2)
	},
	"airport": {
		"title_ru": "Аэропорт",
		"title_en": "Airport",
		"side": "left",
		"activation_level": 10,
		"modules": ["terminal", "runway", "cargo", "control_tower"],
		"position": Vector3(-105, 0, 0),
		"footprint": Vector2(57.6, 43.2)
	},
	"farm_campus": {
		"title_ru": "Фермерский кампус",
		"title_en": "Farm campus",
		"side": "bottom",
		"activation_level": 12,
		"modules": ["fields", "storage", "animals", "processing"],
		"position": Vector3(95, 0, 112),
		"footprint": Vector2(57.6, 43.2)
	}
}

var entries: Dictionary = {}

func _init() -> void:
	reset()

func reset() -> void:
	entries.clear()
	for location_id: String in DEFINITIONS:
		entries[location_id] = {
			"id": location_id,
			"state": "inactive",
			"activation_level": int(DEFINITIONS[location_id].activation_level),
			"module_levels": [0, 0, 0, 0],
			"visual_level": 0,
			"animation_enabled": false,
			"energy_factor": 0.0,
			"materials_factor": 0.0,
			"orders_factor": 0.0,
			"rating_factor": 0.0,
			"failure_clock": 0.0
		}

func data() -> Dictionary:
	return entries.duplicate(true)

func load_data(raw: Variant) -> void:
	reset()
	if not raw is Dictionary:
		return
	for location_id: String in DEFINITIONS:
		var stored: Variant = raw.get(location_id, {})
		if not stored is Dictionary:
			continue
		var target: Dictionary = entries[location_id]
		var state := str(stored.get("state", "inactive"))
		target.state = state if state in ["inactive", "active", "failed"] else "inactive"
		var levels: Array = stored.get("module_levels", []) if stored.get("module_levels", []) is Array else []
		for index in range(mini(4, levels.size())):
			if levels[index] is int or levels[index] is float:
				target.module_levels[index] = clampi(int(levels[index]), 0, 3)
		target.visual_level = clampi(int(stored.get("visual_level", 0)), 0, 3)
		target.animation_enabled = bool(stored.get("animation_enabled", false)) and target.state == "active"
		for key in ["energy_factor", "materials_factor", "orders_factor", "rating_factor", "failure_clock"]:
			var value: Variant = stored.get(key, 0.0)
			if value is int or value is float:
				target[key] = maxf(0.0, float(value))

func is_visible(location_id: String) -> bool:
	return DEFINITIONS.has(location_id)

func is_active(location_id: String) -> bool:
	return bool(entries.get(location_id, {}).get("state", "inactive") == "active")
