extends RefCounted

# Постоянные игровые типы и единственная точка выбора визуальных сцен.
const TYPES = {
	"city_hall": {"icon": "res://assets/icons/city_hall.svg", "scene": "res://scenes/visuals/city_hall.tscn", "cost": 180, "footprint": Vector2(9, 9)},
	"elite_residence": {"icon": "res://assets/icons/house.svg", "scene": "res://scenes/visuals/elite_residence.tscn", "cost": 1200, "income": 36, "residents": 30, "footprint": Vector2(19.2, 19.2)},
	"business_tower": {"icon": "res://assets/icons/hospital.svg", "scene": "res://scenes/visuals/business_tower.tscn", "cost": 2400, "income": 90, "residents": 80, "footprint": Vector2(19.2, 19.2)},
	"house": {"icon": "res://assets/icons/house.svg", "scene": "res://scenes/visuals/house.tscn", "cost": 80, "footprint": Vector2(9, 9)},
	"ruins": {"scene": "res://scenes/visuals/ruins.tscn", "cost": 0, "footprint": Vector2(9, 9)},
	"empty": {"scene": "res://scenes/visuals/empty.tscn", "cost": 0, "footprint": Vector2(9, 9)},
	"depot": {"icon": "res://assets/icons/depot.svg", "scene": "res://scenes/visuals/depot.tscn", "cost": 220, "footprint": Vector2(9, 9)},
	"logistics_center": {"icon": "res://assets/icons/depot.svg", "scene": "res://scenes/visuals/logistics_center.tscn", "cost": 900, "footprint": Vector2(14.4, 14.4)},
	"warehouse": {"icon": "res://assets/icons/house.svg", "scene": "res://scenes/visuals/warehouse.tscn", "cost": 380, "footprint": Vector2(9, 9)},
	"delivery_truck": {"scene": "res://scenes/visuals/delivery_truck.tscn", "footprint": Vector2(2.4, 4.4)},
	"fire_station": {"icon": "res://assets/icons/fire_station.svg", "scene": "res://scenes/visuals/fire_station.tscn", "cost": 260, "footprint": Vector2(9, 9)},
	"police_station": {"scene": "res://scenes/visuals/police_station.tscn", "cost": 240, "footprint": Vector2(9, 9)},
	"hospital": {"scene": "res://scenes/visuals/hospital.tscn", "cost": 300, "footprint": Vector2(9, 9)},
	"lawn": {"icon": "res://assets/icons/lawn.svg", "scene": "res://scenes/visuals/lawn.tscn", "cost": 10, "environment": 2, "footprint": Vector2(4.8, 4.8)},
	"flower_bed": {"icon": "res://assets/icons/flower_bed.svg", "scene": "res://scenes/visuals/flower_bed.tscn", "cost": 25, "environment": 4, "footprint": Vector2(4.8, 4.8)},
	"street_tree": {"icon": "res://assets/icons/street_tree.svg", "scene": "res://scenes/visuals/street_tree.tscn", "cost": 20, "environment": 3, "footprint": Vector2(4.8, 4.8)},
	"bush": {"icon": "res://assets/icons/bush.svg", "scene": "res://scenes/visuals/bush.tscn", "cost": 15, "environment": 2, "footprint": Vector2(4.8, 4.8)},
	"cafe": {"icon": "res://assets/icons/cafe.svg", "scene": "res://scenes/visuals/cafe.tscn", "cost": 120, "mood": 5, "footprint": Vector2(9, 9)},
	"park": {"icon": "res://assets/icons/park.svg", "scene": "res://scenes/visuals/park.tscn", "cost": 100, "mood": 5, "footprint": Vector2(9, 9)},
	"repair_van": {"scene": "res://scenes/visuals/repair_van.tscn", "footprint": Vector2(1.8, 3.0)},
	"work_vehicle": {"scene": "res://scenes/visuals/work_vehicle.tscn", "footprint": Vector2(2.4, 4.0)},
	"excavator": {"scene": "res://scenes/visuals/excavator.tscn", "footprint": Vector2(2.4, 4.0)},
	"dump_truck": {"scene": "res://scenes/visuals/dump_truck.tscn", "footprint": Vector2(2.4, 4.4)},
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
		{"scene": "res://scenes/visuals/park_level_3.tscn", "income": -4, "mood": 9, "environment": 18, "upgrade_cost": 0}],
	"logistics_center": [
		{"scene": "res://scenes/visuals/logistics_center.tscn", "income": 0, "warehouse_limit": 1, "delivery_range": 18, "upgrade_cost": 1200},
		{"scene": "res://scenes/visuals/logistics_center_level_2.tscn", "income": 0, "warehouse_limit": 2, "delivery_range": 26, "upgrade_cost": 2200},
		{"scene": "res://scenes/visuals/logistics_center_level_3.tscn", "income": 0, "warehouse_limit": 3, "delivery_range": 34, "upgrade_cost": 0}],
	"warehouse": [
		{"scene": "res://scenes/visuals/warehouse.tscn", "income": 0, "storage_capacity": 600, "delivery_range": 10, "upgrade_cost": 420},
		{"scene": "res://scenes/visuals/warehouse_level_2.tscn", "income": 0, "storage_capacity": 1400, "delivery_range": 15, "upgrade_cost": 800},
		{"scene": "res://scenes/visuals/warehouse_level_3.tscn", "income": 0, "storage_capacity": 2800, "delivery_range": 20, "upgrade_cost": 0}]
}
const ALTERNATIVES = {
	"house": "res://scenes/visuals/house_alternate.tscn",
	"repair_van": "res://scenes/visuals/repair_van_alternate.tscn"
}
const UNLOCK_LEVELS = {
	"city_hall": 1, "house": 1, "cafe": 1, "park": 1, "fire_station": 1, "depot": 1,
	"logistics_center": 6, "warehouse": 6,
	"elite_residence": 4, "business_tower": 5,
	"police_station": 2, "hospital": 3,
	"lawn": 1, "flower_bed": 1, "street_tree": 1, "bush": 1
}
const LANDSCAPING_TYPES = ["lawn", "flower_bed", "street_tree", "bush"]
const SERVICE_TYPES = ["fire_station", "police_station", "hospital", "depot"]

static func unlock_level(type_id: String) -> int:
	return int(UNLOCK_LEVELS.get(type_id, 1))

static func is_service(type_id: String) -> bool:
	return type_id in SERVICE_TYPES

static func is_landscaping(type_id: String) -> bool:
	return type_id in LANDSCAPING_TYPES

static func footprint_cells(type_id: String) -> Vector2i:
	if type_id == "logistics_center":
		return Vector2i(3, 3)
	if type_id in ["elite_residence", "business_tower"]:
		return Vector2i(4, 4)
	return Vector2i.ONE if is_landscaping(type_id) else Vector2i(2, 2)

static func icon_path(type_id: String) -> String:
	return str(TYPES.get(type_id, {}).get("icon", "res://assets/icons/ui_hammer.svg"))

static func cost(type_id: String) -> int:
	return TYPES[type_id].get("cost", 0)

static func level_data(type_id: String, level: int = 1) -> Dictionary:
	return LEVELS[type_id][clampi(level, 1, 3) - 1] if LEVELS.has(type_id) else TYPES[type_id]

static func scene_path(type_id: String, alternate: bool = false, level: int = 1) -> String:
	if alternate and level == 1 and ALTERNATIVES.has(type_id):
		return ALTERNATIVES[type_id]
	return level_data(type_id, level).scene
