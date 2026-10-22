extends RefCounted

# Постоянные игровые типы и единственная точка выбора визуальных сцен.
const TYPES = {
	"house": {"icon": "res://assets/icons/house.svg", "scene": "res://scenes/visuals/house.tscn", "cost": 0, "footprint": Vector2(4.5, 1.65)},
	"empty": {"scene": "res://scenes/visuals/empty.tscn", "cost": 0, "footprint": Vector2(4.5, 1.65)},
	"depot": {"icon": "res://assets/icons/depot.svg", "scene": "res://scenes/visuals/depot.tscn", "cost": 0, "footprint": Vector2(4.5, 1.65)},
	"cafe": {"icon": "res://assets/icons/cafe.svg", "scene": "res://scenes/visuals/cafe.tscn", "cost": 120, "mood": 5, "footprint": Vector2(4.5, 1.65)},
	"park": {"icon": "res://assets/icons/park.svg", "scene": "res://scenes/visuals/park.tscn", "cost": 100, "mood": 5, "footprint": Vector2(4.5, 1.65)},
	"repair_van": {"scene": "res://scenes/visuals/repair_van.tscn", "footprint": Vector2(1, 1.5)},
	"traffic_signal": {"scene": "res://scenes/visuals/traffic_signal.tscn", "cost": 70, "footprint": Vector2(0.6, 0.6)},
	"water_leak": {"scene": "res://scenes/visuals/water_leak.tscn", "cost": 90, "footprint": Vector2(1, 1)}
}
const ALTERNATIVES = {
	"house": "res://scenes/visuals/house_alternate.tscn",
	"repair_van": "res://scenes/visuals/repair_van_alternate.tscn"
}

static func cost(type_id: String) -> int:
	return TYPES[type_id].get("cost", 0)

static func scene_path(type_id: String, alternate: bool = false) -> String:
	return ALTERNATIVES[type_id] if alternate and ALTERNATIVES.has(type_id) else TYPES[type_id].scene
