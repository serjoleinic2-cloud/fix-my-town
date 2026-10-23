extends RefCounted

# Постоянные игровые типы и единственная точка выбора визуальных сцен.
const TYPES = {
	"house": {"icon": "res://assets/icons/house.svg", "scene": "res://scenes/visuals/house.tscn", "cost": 80, "footprint": Vector2(9, 9)},
	"ruins": {"scene": "res://scenes/visuals/ruins.tscn", "cost": 0, "footprint": Vector2(9, 9)},
	"empty": {"scene": "res://scenes/visuals/empty.tscn", "cost": 0, "footprint": Vector2(9, 9)},
	"depot": {"icon": "res://assets/icons/depot.svg", "scene": "res://scenes/visuals/depot.tscn", "cost": 220, "footprint": Vector2(9, 9)},
	"fire_station": {"icon": "res://assets/icons/fire_station.svg", "scene": "res://scenes/visuals/fire_station.tscn", "cost": 260, "footprint": Vector2(9, 9)},
	"police_station": {"scene": "res://scenes/visuals/police_station.tscn", "cost": 240, "footprint": Vector2(9, 9)},
	"hospital": {"scene": "res://scenes/visuals/hospital.tscn", "cost": 300, "footprint": Vector2(9, 9)},
	"cafe": {"icon": "res://assets/icons/cafe.svg", "scene": "res://scenes/visuals/cafe.tscn", "cost": 120, "mood": 5, "footprint": Vector2(9, 9)},
	"park": {"icon": "res://assets/icons/park.svg", "scene": "res://scenes/visuals/park.tscn", "cost": 100, "mood": 5, "footprint": Vector2(9, 9)},
	"repair_van": {"scene": "res://scenes/visuals/repair_van.tscn", "footprint": Vector2(1.8, 3.0)},
	"fire_engine": {"scene": "res://scenes/visuals/fire_engine.tscn", "footprint": Vector2(2.2, 4.2)},
	"police_car": {"scene": "res://scenes/visuals/police_car.tscn", "footprint": Vector2(1.8, 3.0)},
	"civilian_car": {"scene": "res://scenes/visuals/civilian_car.tscn", "footprint": Vector2(1.5, 2.6)},
	"bus_stop": {"scene": "res://scenes/visuals/bus_stop.tscn", "cost": 40, "footprint": Vector2(8, 5)},
	"city_bus": {"scene": "res://scenes/visuals/city_bus.tscn", "footprint": Vector2(1.8, 4.8)},
	"traffic_signal": {"scene": "res://scenes/visuals/traffic_signal.tscn", "cost": 70, "footprint": Vector2(0.6, 0.6)},
	"water_leak": {"scene": "res://scenes/visuals/water_leak.tscn", "cost": 90, "footprint": Vector2(1, 1)}
}
const LEVELS = {
	"house": [
		{"scene": "res://scenes/visuals/house.tscn", "residents": 8, "income": 1, "upgrade_cost": 90},
		{"scene": "res://scenes/visuals/house_level_2.tscn", "residents": 12, "income": 2, "upgrade_cost": 160},
		{"scene": "res://scenes/visuals/house_level_3.tscn", "residents": 16, "income": 3, "upgrade_cost": 0}],
	"cafe": [
		{"scene": "res://scenes/visuals/cafe.tscn", "income": 6, "mood": 5, "environment": 8, "upgrade_cost": 100},
		{"scene": "res://scenes/visuals/cafe_level_2.tscn", "income": 10, "mood": 7, "environment": 11, "upgrade_cost": 180},
		{"scene": "res://scenes/visuals/cafe_level_3.tscn", "income": 15, "mood": 9, "environment": 14, "upgrade_cost": 0}],
	"park": [
		{"scene": "res://scenes/visuals/park.tscn", "income": -2, "mood": 5, "environment": 10, "upgrade_cost": 80},
		{"scene": "res://scenes/visuals/park_level_2.tscn", "income": -3, "mood": 7, "environment": 14, "upgrade_cost": 140},
		{"scene": "res://scenes/visuals/park_level_3.tscn", "income": -4, "mood": 9, "environment": 18, "upgrade_cost": 0}]
}
const ALTERNATIVES = {
	"house": "res://scenes/visuals/house_alternate.tscn",
	"repair_van": "res://scenes/visuals/repair_van_alternate.tscn"
}

static func cost(type_id: String) -> int:
	return TYPES[type_id].get("cost", 0)

static func level_data(type_id: String, level: int = 1) -> Dictionary:
	return LEVELS[type_id][clampi(level, 1, 3) - 1] if LEVELS.has(type_id) else TYPES[type_id]

static func scene_path(type_id: String, alternate: bool = false, level: int = 1) -> String:
	if alternate and level == 1 and ALTERNATIVES.has(type_id):
		return ALTERNATIVES[type_id]
	return level_data(type_id, level).scene
