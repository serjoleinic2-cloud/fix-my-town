extends RefCounted

# Постоянные игровые типы и единственная точка выбора визуальных сцен.
const TYPES = {
	"construction_site": {"scene": "res://scenes/visuals/construction_site.tscn", "footprint": Vector2(9.6, 9.6)},
	"city_hall": {"icon": "res://assets/icons/city_hall.svg", "scene": "res://scenes/visuals/city_hall.tscn", "cost": 180, "footprint": Vector2(9, 9)},
	"elite_residence": {"icon": "res://assets/icons/house.svg", "scene": "res://scenes/visuals/elite_residence.tscn", "cost": 1200, "income": 36, "residents": 30, "footprint": Vector2(9.6, 9.6)},
	"business_tower": {"icon": "res://assets/icons/hospital.svg", "scene": "res://scenes/visuals/business_tower.tscn", "cost": 2400, "income": 90, "residents": 80, "footprint": Vector2(9.6, 9.6)},
	"house": {"icon": "res://assets/icons/house.svg", "scene": "res://scenes/visuals/house.tscn", "cost": 80, "footprint": Vector2(9, 9)},
	"ruins": {"scene": "res://scenes/visuals/ruins.tscn", "cost": 0, "footprint": Vector2(9, 9)},
	"empty": {"scene": "res://scenes/visuals/empty.tscn", "cost": 0, "footprint": Vector2(9, 9)},
	"depot": {"icon": "res://assets/icons/depot.svg", "scene": "res://scenes/visuals/depot.tscn", "cost": 220, "footprint": Vector2(9, 9)},
	"logistics_center": {"icon": "res://assets/icons/depot.svg", "scene": "res://scenes/visuals/logistics_center.tscn", "cost": 900, "footprint": Vector2(9.6, 9.6)},
	"warehouse": {"icon": "res://assets/icons/house.svg", "scene": "res://scenes/visuals/warehouse.tscn", "cost": 380, "footprint": Vector2(9, 9)},
	"bridge": {"icon": "res://assets/icons/catalog_road.svg", "scene": "res://scenes/visuals/bridge.tscn", "cost": 3200, "footprint": Vector2(9.6, 9.6)},
	"field": {"icon": "res://assets/icons/lawn.svg", "scene": "res://scenes/visuals/field.tscn", "cost": 180, "income": 8, "footprint": Vector2(9.6, 9.6)},
	"barn": {"icon": "res://assets/icons/house.svg", "scene": "res://scenes/visuals/barn.tscn", "cost": 420, "income": 14, "footprint": Vector2(9.6, 9.6)},
	"mill": {"icon": "res://assets/icons/depot.svg", "scene": "res://scenes/visuals/mill.tscn", "cost": 680, "income": 22, "footprint": Vector2(9.6, 9.6)},
	"pasture": {"icon": "res://assets/icons/park.svg", "scene": "res://scenes/visuals/pasture.tscn", "cost": 240, "income": 9, "footprint": Vector2(9.6, 9.6)},
	"bakery": {"icon": "res://assets/icons/cafe.svg", "scene": "res://scenes/visuals/bakery.tscn", "cost": 720, "income": 24, "footprint": Vector2(9.6, 9.6)},
	"livestock_yard": {"icon": "res://assets/icons/house.svg", "scene": "res://scenes/visuals/livestock_yard.tscn", "cost": 760, "income": 25, "footprint": Vector2(9.6, 9.6)},
	"farm_warehouse": {"icon": "res://assets/icons/house.svg", "scene": "res://scenes/visuals/farm_warehouse.tscn", "cost": 520, "income": 12, "footprint": Vector2(9.6, 9.6)},
	"supermarket": {"icon": "res://assets/icons/cafe.svg", "scene": "res://scenes/visuals/supermarket.tscn", "cost": 220, "income": 12, "footprint": Vector2(9, 9)},
	"delivery_truck": {"scene": "res://scenes/visuals/delivery_truck.tscn", "footprint": Vector2(2.4, 4.4)},
	"fire_station": {"icon": "res://assets/icons/fire_station.svg", "scene": "res://scenes/visuals/fire_station.tscn", "cost": 260, "footprint": Vector2(9, 9)},
	"police_station": {"scene": "res://scenes/visuals/police_station.tscn", "cost": 240, "footprint": Vector2(9, 9)},
	"hospital": {"scene": "res://scenes/visuals/hospital.tscn", "cost": 300, "footprint": Vector2(9, 9)},
	"lawn": {"icon": "res://assets/icons/lawn.svg", "scene": "res://scenes/visuals/lawn.tscn", "cost": 10, "environment": 2, "footprint": Vector2(4.8, 4.8)},
	"flower_bed": {"icon": "res://assets/icons/flower_bed.svg", "scene": "res://scenes/visuals/flower_bed.tscn", "cost": 25, "environment": 4, "footprint": Vector2(4.8, 4.8)},
	"street_tree": {"icon": "res://assets/icons/street_tree.svg", "scene": "res://scenes/visuals/street_tree.tscn", "cost": 20, "environment": 3, "footprint": Vector2(4.8, 4.8)},
	"bush": {"icon": "res://assets/icons/bush.svg", "scene": "res://scenes/visuals/bush.tscn", "cost": 15, "environment": 2, "footprint": Vector2(4.8, 4.8)},
	"street_lamp": {"icon": "res://assets/icons/park.svg", "scene": "res://scenes/visuals/street_lamp.tscn", "cost": 30, "environment": 2, "footprint": Vector2(4.8, 4.8)},
	"wind_turbine": {"icon": "res://assets/icons/depot.svg", "scene": "res://scenes/visuals/wind_turbine.tscn", "cost": 400, "income": 0, "footprint": Vector2(9.6, 9.6)},
	"solar_panel": {"icon": "res://assets/icons/depot.svg", "scene": "res://scenes/visuals/solar_panel.tscn", "cost": 520, "income": 0, "footprint": Vector2(9.6, 9.6)},
	"power_plant": {"icon": "res://assets/icons/depot.svg", "scene": "res://scenes/visuals/power_plant.tscn", "cost": 1500, "income": 0, "footprint": Vector2(9.6, 9.6)},
	"heat_plant": {"icon": "res://assets/icons/depot.svg", "scene": "res://scenes/visuals/heat_plant.tscn", "cost": 1400, "income": 0, "footprint": Vector2(9.6, 9.6)},
	"battery": {"icon": "res://assets/icons/depot.svg", "scene": "res://scenes/visuals/battery.tscn", "cost": 700, "income": 0, "footprint": Vector2(9.6, 9.6)},
	"fitness_club": {"icon": "res://assets/icons/cafe.svg", "scene": "res://scenes/visuals/fitness_club.tscn", "cost": 260, "income": 14, "footprint": Vector2(9.6, 9.6)},
	"pizzeria": {"icon": "res://assets/icons/cafe.svg", "scene": "res://scenes/visuals/pizzeria.tscn", "cost": 300, "income": 18, "footprint": Vector2(9.6, 9.6)},
	"theatre": {"icon": "res://assets/icons/cafe.svg", "scene": "res://scenes/visuals/theatre.tscn", "cost": 900, "income": 30, "footprint": Vector2(9.6, 9.6)},
	"aquapark": {"icon": "res://assets/icons/park.svg", "scene": "res://scenes/visuals/aquapark.tscn", "cost": 1400, "income": 48, "footprint": Vector2(9.6, 9.6)},
	"amusement_park": {"icon": "res://assets/icons/park.svg", "scene": "res://scenes/visuals/amusement_park.tscn", "cost": 2200, "income": 70, "footprint": Vector2(9.6, 9.6)},
	"cafe": {"icon": "res://assets/icons/cafe.svg", "scene": "res://scenes/visuals/cafe.tscn", "cost": 120, "mood": 5, "footprint": Vector2(9, 9)},
	"park": {"icon": "res://assets/icons/park.svg", "scene": "res://scenes/visuals/park.tscn", "cost": 100, "mood": 5, "footprint": Vector2(9, 9)},
	"repair_van": {"scene": "res://scenes/visuals/repair_van.tscn", "footprint": Vector2(1.8, 3.0)},
	"work_vehicle": {"scene": "res://scenes/visuals/work_vehicle.tscn", "footprint": Vector2(2.4, 4.0)},
	"excavator": {"scene": "res://scenes/visuals/excavator.tscn", "footprint": Vector2(2.4, 4.0)},
	"dump_truck": {"scene": "res://scenes/visuals/dump_truck.tscn", "footprint": Vector2(2.4, 4.4)},
	"fire_engine": {"scene": "res://scenes/visuals/fire_engine.tscn", "footprint": Vector2(2.2, 4.2)},
	"police_car": {"scene": "res://scenes/visuals/police_car.tscn", "footprint": Vector2(1.8, 3.0)},
	"ambulance": {"scene": "res://scenes/visuals/ambulance.tscn", "footprint": Vector2(2.0, 3.0)},
	"civilian_car": {"scene": "res://scenes/visuals/civilian_car.tscn", "footprint": Vector2(1.5, 2.6)},
	"bus_stop": {"scene": "res://scenes/visuals/bus_stop.tscn", "cost": 40, "footprint": Vector2(8, 5)},
	"city_bus": {"scene": "res://scenes/visuals/city_bus.tscn", "footprint": Vector2(1.8, 4.8)},
	"traffic_signal": {"scene": "res://scenes/visuals/traffic_signal.tscn", "cost": 70, "footprint": Vector2(0.6, 0.6)},
	"water_leak": {"scene": "res://scenes/visuals/water_leak.tscn", "cost": 90, "footprint": Vector2(1, 1)}
}
const LEVELS = {
	"elite_residence": [
		{"scene": "res://scenes/visuals/elite_residence.tscn", "residents": 30, "income": 36, "upgrade_cost": 900},
		{"scene": "res://scenes/visuals/elite_residence_level_2.tscn", "residents": 38, "income": 52, "upgrade_cost": 1700},
		{"scene": "res://scenes/visuals/elite_residence_level_3.tscn", "residents": 48, "income": 70, "upgrade_cost": 0}],
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
		{"scene": "res://scenes/visuals/warehouse_level_3.tscn", "income": 0, "storage_capacity": 2800, "delivery_range": 20, "upgrade_cost": 0}],
	"field": [
		{"scene": "res://scenes/visuals/field.tscn", "income": 8, "upgrade_cost": 110},
		{"scene": "res://scenes/visuals/field.tscn", "income": 13, "upgrade_cost": 220},
		{"scene": "res://scenes/visuals/field.tscn", "income": 18, "upgrade_cost": 0}],
	"barn": [
		{"scene": "res://scenes/visuals/barn.tscn", "income": 14, "upgrade_cost": 250},
		{"scene": "res://scenes/visuals/barn.tscn", "income": 22, "upgrade_cost": 500},
		{"scene": "res://scenes/visuals/barn.tscn", "income": 32, "upgrade_cost": 0}],
	"mill": [
		{"scene": "res://scenes/visuals/mill.tscn", "income": 22, "upgrade_cost": 410},
		{"scene": "res://scenes/visuals/mill.tscn", "income": 35, "upgrade_cost": 820},
		{"scene": "res://scenes/visuals/mill.tscn", "income": 51, "upgrade_cost": 0}],
	"pasture": [
		{"scene": "res://scenes/visuals/pasture.tscn", "income": 9, "upgrade_cost": 140},
		{"scene": "res://scenes/visuals/pasture.tscn", "income": 14, "upgrade_cost": 290},
		{"scene": "res://scenes/visuals/pasture.tscn", "income": 21, "upgrade_cost": 0}],
	"bakery": [
		{"scene": "res://scenes/visuals/bakery.tscn", "income": 24, "upgrade_cost": 430},
		{"scene": "res://scenes/visuals/bakery.tscn", "income": 38, "upgrade_cost": 860},
		{"scene": "res://scenes/visuals/bakery.tscn", "income": 55, "upgrade_cost": 0}],
	"livestock_yard": [
		{"scene": "res://scenes/visuals/livestock_yard.tscn", "income": 25, "upgrade_cost": 460},
		{"scene": "res://scenes/visuals/livestock_yard.tscn", "income": 40, "upgrade_cost": 910},
		{"scene": "res://scenes/visuals/livestock_yard.tscn", "income": 57, "upgrade_cost": 0}],
	"farm_warehouse": [
		{"scene": "res://scenes/visuals/farm_warehouse.tscn", "income": 12, "upgrade_cost": 310},
		{"scene": "res://scenes/visuals/farm_warehouse.tscn", "income": 19, "upgrade_cost": 620},
		{"scene": "res://scenes/visuals/farm_warehouse.tscn", "income": 28, "upgrade_cost": 0}]
}
const ALTERNATIVES = {
	"house": "res://scenes/visuals/house_alternate.tscn",
	"repair_van": "res://scenes/visuals/repair_van_alternate.tscn"
}
const UNLOCK_LEVELS = {
	"city_hall": 1, "house": 1, "cafe": 1, "park": 1, "fire_station": 1, "depot": 1, "supermarket": 2,
	"logistics_center": 6, "warehouse": 6,
	"elite_residence": 4, "business_tower": 5,
	"bridge": 11, "field": 12, "barn": 12, "mill": 13, "pasture": 13, "livestock_yard": 14, "farm_warehouse": 15, "bakery": 15,
	"police_station": 2, "hospital": 3,
	"lawn": 1, "flower_bed": 1, "street_tree": 1, "bush": 1,
	"street_lamp": 16, "wind_turbine": 16, "solar_panel": 16, "fitness_club": 17, "pizzeria": 17, "power_plant": 17, "theatre": 18, "battery": 18, "aquapark": 19, "amusement_park": 19, "heat_plant": 20
}
const LANDSCAPING_TYPES = ["lawn", "flower_bed", "street_tree", "bush", "street_lamp"]
const LEISURE_TYPES = ["fitness_club", "pizzeria", "theatre", "aquapark", "amusement_park"]
const ENERGY_TYPES = ["street_lamp", "wind_turbine", "solar_panel", "power_plant", "battery", "heat_plant"]
const SERVICE_TYPES = ["fire_station", "police_station", "hospital", "depot"]
const FARM_TYPES = ["field", "barn", "mill", "bakery", "pasture", "livestock_yard", "farm_warehouse"]

static func unlock_level(type_id: String) -> int:
	return int(UNLOCK_LEVELS.get(type_id, 1))

static func is_service(type_id: String) -> bool:
	return type_id in SERVICE_TYPES

static func is_landscaping(type_id: String) -> bool:
	return type_id in LANDSCAPING_TYPES

static func is_farm(type_id: String) -> bool:
	return type_id in FARM_TYPES

static func footprint_cells(type_id: String) -> Vector2i:
	return Vector2i.ONE if is_landscaping(type_id) else Vector2i(2, 2)

static func icon_path(type_id: String) -> String:
	return str(TYPES.get(type_id, {}).get("icon", "res://assets/icons/ui_hammer.svg"))

static func cost(type_id: String) -> int:
	return TYPES[type_id].get("cost", 0)

static func level_data(type_id: String, level: int = 1) -> Dictionary:
	return LEVELS[type_id][clampi(level, 1, 3) - 1] if LEVELS.has(type_id) else TYPES[type_id]

static func scene_path(type_id: String, alternate: bool = false, level: int = 1) -> String:
	if type_id == "shanty":
		return "res://scenes/visuals/shanty.tscn"
	if alternate and level == 1 and ALTERNATIVES.has(type_id):
		return ALTERNATIVES[type_id]
	return level_data(type_id, level).scene
