extends Node3D

const Art = preload("res://scripts/art.gd")
@export var visual_type: String = "house"
@export var alternate: bool = false
@export_range(1, 3) var visual_level: int = 1
var windows: Array[MeshInstance3D] = []
var signs: Array[Label3D] = []
var helicopter_rng := RandomNumberGenerator.new()
var police_helicopter: Node3D
var helicopter_rotor: Node3D
var helicopter_state: String = "waiting"
var helicopter_timer: float = 0.0
var helicopter_elapsed: float = 0.0
var helicopter_departure_target := Vector3.ZERO
var helicopter_pad := Vector3(-0.9, 3.95, -0.7)
var delivery_cargo_height: float = 0.0
var delivery_cab_height: float = 0.0

func _ready() -> void:
	var seed_value := absi(str(get_parent().get_parent().get("instance_id")).hash())
	if visual_type == "house":
		house(seed_value)
		rotation.y = (seed_value % 4) * PI / 2
	elif visual_type == "ruins":
		ruins(seed_value)
	elif visual_type == "shanty":
		shanty(seed_value)
	elif visual_type == "cafe":
		cafe()
	elif visual_type == "depot":
		depot()
		parked_service_vehicle("work_vehicle")
	elif visual_type == "logistics_center":
		logistics_center()
	elif visual_type == "warehouse":
		warehouse()
	elif visual_type == "city_hall":
		city_hall()
	elif visual_type == "elite_residence":
		elite_residence()
	elif visual_type == "business_tower":
		business_tower()
	elif visual_type == "fire_station":
		fire_station()
		parked_service_vehicle("fire_engine")
	elif visual_type == "police_station":
		service_station(Color("54768c"), Color("d9e5e6"), "ПОЛИЦИЯ")
		police_helipad()
		parked_service_vehicle("police_car")
	elif visual_type == "hospital":
		service_station(Color("e6e5dc"), Color("62a9a0"), "БОЛЬНИЦА")
		medical_roof_emblem()
		parked_service_vehicle("ambulance")
	elif visual_type == "park":
		park()
	elif visual_type == "lawn":
		Art.box(self, Vector3(0, 0.05, 0), Vector3(4.25, 0.1, 4.25), Color("83ad62"))
	elif visual_type == "flower_bed":
		Art.box(self, Vector3(0, 0.08, 0), Vector3(4.2, 0.16, 3.6), Color("5c7550"))
		for x in [-1.4, -0.7, 0, 0.7, 1.4]:
			for z in [-0.9, 0, 0.9]:
				Art.cylinder(self, Vector3(x, 0.42, z), 0.12, 0.56, Color("4f8652"))
				var flower_colors := [Color("edc75b"), Color("d97f78"), Color("c58bc0")]
				var color_index := posmod(roundi(absf(x * 3 + z)), flower_colors.size())
				Art.sphere(self, Vector3(x, 0.77, z), 0.23, flower_colors[color_index])
	elif visual_type == "street_tree":
		Art.box(self, Vector3(0, 0.08, 0), Vector3(2.5, 0.16, 2.5), Color("879d66"))
		Art.tree(self, Vector3.ZERO, 0.85, false, seed_value % 4)
	elif visual_type == "bush":
		Art.box(self, Vector3(0, 0.06, 0), Vector3(3.9, 0.12, 3.9), Color("879d66"))
		for x in [-0.9, 0, 0.9]:
			for z in [-0.65, 0.45]:
				Art.hedge(self, Vector3(x, 0.45, z), Vector3(0.68, 0.62, 0.7))
	elif visual_type == "empty":
		for i in range(3):
			Art.hedge(self, Vector3(-3 + i * 2.5, 0.24, -3.6), Vector3(0.7, 0.45, 0.55))
	elif visual_type in ["excavator", "dump_truck", "work_vehicle"]:
		construction_vehicle()
	elif visual_type == "repair_van":
		van()
	elif visual_type == "fire_engine":
		fire_engine()
	elif visual_type == "police_car":
		civilian_vehicle(false, seed_value)
		Art.box(self, Vector3(0, 1.34, -0.25), Vector3(1.6, 0.14, 1.9), Color("315b88"))
		var beacon_red := Art.box(self, Vector3(-0.23, 1.92, 0.2), Vector3(0.2, 0.12, 0.12), Color("dc4242"))
		beacon_red.name = "BeaconRed"
		beacon_red.set_meta("dynamic", true)
		var beacon_blue := Art.box(self, Vector3(0.23, 1.92, 0.2), Vector3(0.2, 0.12, 0.12), Color("438ee8"))
		beacon_blue.name = "BeaconBlue"
		beacon_blue.set_meta("dynamic", true)
	elif visual_type == "traffic_signal":
		make_signals()
	elif visual_type == "bus_stop":
		bus_stop()
	elif visual_type in ["civilian_car", "city_bus"]:
		civilian_vehicle(visual_type == "city_bus", seed_value)
	elif visual_type == "delivery_truck":
		delivery_truck()
	elif visual_type == "water_leak":
		for i in range(5):
			var puddle := Art.cylinder(self, Vector3(sin(i * 1.7) * 0.9, 0.07, cos(i * 2.3) * 0.7), 0.8 + i * 0.1, 0.035, Color("63b5d4"))
			puddle.scale.x *= 1.25
		for i in range(9):
			var angle := TAU * i / 9
			var jet := Art.cylinder(self, Vector3(sin(angle) * 0.45, 0.75 + (i % 3) * 0.26, cos(angle) * 0.45), 0.065, 1.4, Color("83d2e5"), 0.45, 7)
			jet.rotation.z = sin(angle) * 0.45
			jet.rotation.x = cos(angle) * 0.45
		Art.cylinder(self, Vector3(1.45, 0.06, 0), 0.48, 0.1, Color("776d58"))
	Art.batch(self)
	set_process(visual_type == "police_station")

func _process(delta: float) -> void:
	if police_helicopter == null or helicopter_rotor == null:
		return
	helicopter_rotor.rotation.y += delta * 16.0
	match helicopter_state:
		"waiting":
			helicopter_timer -= delta
			if helicopter_timer <= 0.0:
				helicopter_state = "landing"
				helicopter_elapsed = 0.0
				police_helicopter.visible = true
				police_helicopter.position = helicopter_pad + Vector3(0, 11, 0)
		"landing":
			helicopter_elapsed += delta
			var landing_progress := clampf(helicopter_elapsed / 4.0, 0.0, 1.0)
			police_helicopter.position = helicopter_pad + Vector3(0, lerpf(11.0, 0.48, landing_progress), 0)
			if landing_progress >= 1.0:
				helicopter_state = "landed"
				helicopter_timer = helicopter_rng.randf_range(7.0, 14.0)
		"landed":
			helicopter_timer -= delta
			if helicopter_timer <= 0.0:
				var angle := helicopter_rng.randf_range(0.0, TAU)
				var flight_direction := Vector3(sin(angle), 0, cos(angle))
				police_helicopter.rotation.y = angle
				helicopter_departure_target = helicopter_pad + flight_direction * 18.0 + Vector3(0, 12.0, 0)
				helicopter_state = "departing"
				helicopter_elapsed = 0.0
		"departing":
			helicopter_elapsed += delta
			var departure_progress := clampf(helicopter_elapsed / 5.0, 0.0, 1.0)
			police_helicopter.position = helicopter_pad + Vector3(0, 0.48, 0).lerp(helicopter_departure_target - helicopter_pad, departure_progress)
			if departure_progress >= 1.0:
				police_helicopter.visible = false
				helicopter_state = "waiting"
				helicopter_timer = helicopter_rng.randf_range(25.0, 55.0)

func house(seed_value: int) -> void:
	var lift := (visual_level - 1) * 1.5
	var creams := [Color("eee5ce"), Color("e6dfc7"), Color("e8dcc0"), Color("d9e1d2")]
	var color: Color = creams[seed_value % creams.size()]
	Art.box(self, Vector3(0, 0.27, 0), Vector3(5.1, 0.5, 3.9), Color("d2cbb5"))
	Art.box(self, Vector3(0, 1.92 + lift / 2, 0), Vector3(4.8, 3.3 + lift, 3.5), color)
	roof(2.7, 2.0, 3.52 + lift, 4.9 + lift, Color("e9a389"))
	Art.box(self, Vector3(1.3, 4.65 + lift, -0.75), Vector3(0.47, 1.6, 0.55), Color("c68d72"))
	Art.box(self, Vector3(1.3, 5.47 + lift, -0.75), Vector3(0.62, 0.18, 0.7), Color("e2c1a0"))
	Art.box(self, Vector3(0.5, 0.07, 3), Vector3(1.05, 0.12, 2.8), Color("d8d2bc"))
	Art.box(self, Vector3(0.5, 0.23, 2), Vector3(1.3, 0.3, 0.7), Color("d3cdb8"))
	Art.box(self, Vector3(0.5, 1.25, 1.78), Vector3(0.9, 2.2, 0.1), Color("797e6b"))
	Art.box(self, Vector3(0.78, 1.2, 1.86), Vector3(0.07, 0.07, 0.08), Color("d7bd83"))
	for x in [-1.5, 1.55]:
		window(Vector3(x, 2, 1.79), false)
	for z in [-0.85, 0.85]:
		window(Vector3(-2.42, 2, z), true)
	for floor_index in range(1, visual_level):
		for x in [-1.5, 1.55]:
			window(Vector3(x, 2 + floor_index * 1.5, 1.79), false)
		window(Vector3(-2.42, 2 + floor_index * 1.5, 0), true)
	if visual_level >= 2:
		Art.box(self, Vector3(0.5, 2.6, 2), Vector3(1.8, 0.15, 0.8), Color("d7ceb3"))
	if visual_level == 3:
		Art.box(self, Vector3(0.5, 3.15, 2.2), Vector3(1.8, 0.08, 0.08), Color("6a8984"))
		for x in [-0.3, 0.5, 1.3]:
			Art.box(self, Vector3(x, 2.9, 2.2), Vector3(0.06, 0.5, 0.06), Color("6a8984"))
	Art.fence(self, Vector3(0, 0, -4.3), 8.6)
	Art.fence(self, Vector3(-4.3, 0, 0), 8.6, PI / 2)
	Art.fence(self, Vector3(4.3, 0, 0), 8.6, PI / 2)
	Art.fence(self, Vector3(-2.4, 0, 4.3), 3.8)
	Art.fence(self, Vector3(3.0, 0, 4.3), 2.6)
	for i in range(5):
		Art.hedge(self, Vector3(-3.5 + i * 1.65, 0.4, -3.5), Vector3(1.05, 0.8, 0.8))
	Art.tree(self, Vector3(-3.25, 0, 2.15), 1.2, false, seed_value)
	Art.tree(self, Vector3(3.2, 0, -2.4), 1.05, false, seed_value + 1)
	for i in range(4):
		Art.hedge(self, Vector3(2.1 + (i % 2) * 1.1, 0.35, 2.6 + (i / 2) * 0.9), Vector3(0.8, 0.7, 0.7))

func shanty(seed_value: int) -> void:
	var wall_colors := [Color("82715c"), Color("746c5e"), Color("87745e"), Color("6c7164")]
	var wall: Color = wall_colors[seed_value % wall_colors.size()]
	Art.box(self, Vector3(0, 0.1, 0), Vector3(4.05, 0.2, 4.05), Color("b9a77e"))
	Art.box(self, Vector3(0, 0.95, -0.25), Vector3(3.2, 1.65, 2.8), wall)
	Art.box(self, Vector3(0.15, 1.82, -0.25), Vector3(3.55, 0.16, 3.05), Color("514e48"))
	for index in range(5):
		var panel := Art.box(self, Vector3(-1.25 + index * 0.62, 1.98, -0.25), Vector3(0.67, 0.08, 3.18), Color("79766b") if index % 2 == 0 else Color("8a7357"))
		panel.rotation.z = 0.03 if index % 2 == 0 else -0.04
	Art.box(self, Vector3(0, 0.68, 1.18), Vector3(0.68, 1.16, 0.12), Color("493b30"))
	Art.box(self, Vector3(-0.95, 1.15, 1.2), Vector3(0.62, 0.42, 0.12), Color("59686a"))
	Art.box(self, Vector3(-0.95, 1.15, 1.27), Vector3(0.07, 0.52, 0.08), Color("d0b98a"))
	# Small, low-detail protesters read clearly at district scale without adding
	# animated characters or expensive skeletal rigs.
	for index in range(3):
		var x := -1.35 + index * 1.12
		var shirt: Color = [Color("b56c55"), Color("647d86"), Color("827a58")][index]
		Art.cylinder(self, Vector3(x, 0.58, 2.15), 0.18, 0.68, shirt, 0.72, 7)
		Art.sphere(self, Vector3(x, 1.05, 2.15), 0.16, Color("c99f78"))
		Art.cylinder(self, Vector3(x - 0.1, 0.28, 2.15), 0.055, 0.5, Color("3c4140"), 0.8, 6)
		Art.cylinder(self, Vector3(x + 0.1, 0.28, 2.15), 0.055, 0.5, Color("3c4140"), 0.8, 6)
		Art.box(self, Vector3(x, 1.34, 2.15), Vector3(0.76, 0.5, 0.08), Color("e4ddc8"))
		Art.box(self, Vector3(x, 1.34, 2.21), Vector3(0.025, 0.4, 0.025), Color("847d6c"))

func window(pos: Vector3, side: bool) -> void:
	var trim := Vector3(0.12, 1.42, 0.98) if side else Vector3(1.02, 1.42, 0.12)
	Art.box(self, pos, trim, Color("faf1d9"))
	var glass := Art.box(self, pos + Vector3(-0.07 if side else 0, 0, 0 if side else 0.07), trim * Vector3(0.55 if side else 0.75, 0.75, 0.75 if side else 0.55), Color("698b95"))
	glass.set_meta("dynamic", true)
	windows.append(glass)

func roof(x: float, z: float, low: float, high: float, color: Color) -> void:
	var a := Vector3(-x, low, -z)
	var b := Vector3(x, low, -z)
	var c := Vector3(-x, low, z)
	var d := Vector3(x, low, z)
	var e := Vector3(0, high, -z)
	var f := Vector3(0, high, z)
	Art.triangles(self, PackedVector3Array([a, c, f, a, f, e, b, e, f, b, f, d]), color)
	Art.triangles(self, PackedVector3Array([a, e, b, c, d, f]), Color("eee5ce"))
	Art.box(self, Vector3(0, high, 0), Vector3(0.14, 0.12, z * 2.05), color.lightened(0.12))

func cafe() -> void:
	if visual_level >= 2:
		var height_value := 1.7 if visual_level == 2 else 2.7
		Art.box(self, Vector3(0, 3.9 + height_value / 2, -0.8), Vector3(5.1, height_value, 3.6), Color("e7d7b6"))
		Art.box(self, Vector3(0, 4 + height_value, -0.8), Vector3(5.6, 0.22, 4.1), Color("bd8066"))
		for x in [-1.6, 0, 1.6]:
			Art.box(self, Vector3(x, 4.7, 1.04), Vector3(1.1, 1.05, 0.05), Color("638e9b"))
	if visual_level == 3:
		for x in [-2.4, 2.4]:
			Art.box(self, Vector3(x, 1.2, 2.5), Vector3(0.13, 2.4, 0.13), Color("719295"))
		Art.box(self, Vector3(0, 2.4, 3.8), Vector3(5.4, 0.16, 0.7), Color("bba782"))
	Art.box(self, Vector3(0, 0.14, 0.5), Vector3(7, 0.25, 7.5), Color("d9d4c2"))
	Art.box(self, Vector3(0, 1.95, -0.8), Vector3(5.3, 3.7, 3.8), Color("ebe3cb"))
	Art.box(self, Vector3(0, 3.9, -0.8), Vector3(5.6, 0.3, 4.1), Color("c47d62"))
	Art.box(self, Vector3(1.4, 4.2, -1.3), Vector3(0.45, 0.7, 0.45), Color("dfc5a4"))
	for x in [-1.6, 0, 1.6]:
		Art.box(self, Vector3(x, 1.5, 1.15), Vector3(1.4, 2.6, 0.09), Color("567f8a"))
		Art.box(self, Vector3(x - 0.72, 1.5, 1.22), Vector3(0.08, 2.7, 0.13), Color("555e58"))
	for i in range(10):
		var awning := Art.box(self, Vector3(-2.4 + i * 0.53, 2.9, 1.9), Vector3(0.53, 0.14, 1.6), Color("498faa") if i % 2 == 0 else Color("f8f3dd"))
		awning.rotation.x = 0.16
		Art.box(self, Vector3(-2.4 + i * 0.53, 2.65, 2.65), Vector3(0.53, 0.35, 0.1), Color("498faa") if i % 2 == 0 else Color("f8f3dd"))
	Art.box(self, Vector3(0, 3.8, 1.23), Vector3(3.8, 1, 0.16), Color("3f5860"))

	for x in [-1.7, 1.7]:
		Art.cylinder(self, Vector3(x, 0.6, 3.1), 0.07, 1.1, Color("726956"))
		Art.cylinder(self, Vector3(x, 1.2, 3.1), 0.67, 0.13, Color("f2eedc"))
		for dx in [-0.95, 0.95]:
			Art.box(self, Vector3(x + dx, 0.55, 3.1), Vector3(0.5, 0.1, 0.5), Color("927e60"))
			Art.box(self, Vector3(x + dx, 0.85, 3.35), Vector3(0.5, 0.6, 0.08), Color("927e60"))
		Art.cylinder(self, Vector3(x * 1.65, 0.4, 1.5), 0.3, 0.7, Color("a58b66"), 1.2)
		Art.tree(self, Vector3(x * 1.65, 0.4, 1.5), 0.35, false, 1)

func service_building_shell(wall: Color, roof: Color, foundation: Color) -> void:
	# L-shaped plan leaves the front-right corner open as a real vehicle court.
	Art.box(self, Vector3(-0.9, 0.16, -0.7), Vector3(5.4, 0.24, 6.0), foundation)
	Art.box(self, Vector3(2.7, 0.16, -1.7), Vector3(1.8, 0.24, 4.0), foundation)
	Art.box(self, Vector3(-0.9, 1.8, -0.7), Vector3(5.4, 3.6, 6.0), wall)
	Art.box(self, Vector3(2.7, 1.8, -1.7), Vector3(1.8, 3.6, 4.0), wall)
	Art.box(self, Vector3(-0.9, 3.7, -0.7), Vector3(5.65, 0.3, 6.25), roof)
	Art.box(self, Vector3(2.7, 3.7, -1.7), Vector3(2.05, 0.3, 4.25), roof)
	var corner := Node3D.new()
	corner.name = "ServiceVehicleCornerCutout"
	corner.set_meta("vehicle_court_open", true)
	add_child(corner)
	Art.box(corner, Vector3(2.0, 0.13, 0.52), Vector3(1.1, 0.12, 0.12), Color("d7c6a2"))
	corner.rotation.y = -0.55

func depot() -> void:
	service_building_shell(Color("c58f72"), Color("999a88"), Color("8f8170"))
	for x in [-2.45, -0.15]:
		Art.box(self, Vector3(x, 1.3, 2.34), Vector3(2.0, 2.65, 0.08), Color("56666a"))
		for y in [0.3, 0.7, 1.1, 1.5, 1.9, 2.3]:
			Art.box(self, Vector3(x, y, 2.40), Vector3(1.94, 0.04, 0.04), Color("758483"))
	Art.box(self, Vector3(-1.3, 3.25, 2.42), Vector3(4.6, 0.8, 0.12), Color("9c5d49"))
	for x in [-2.8, -0.9, 1.0]:
		Art.box(self, Vector3(x, 0.03, 3.0), Vector3(0.06, 0.025, 2.2), Color("e5dfc9"))
	Art.box(self, Vector3(2.7, 5, -1.8), Vector3(1.3, 3.3, 1.3), Color("b7896e"))
	Art.box(self, Vector3(2.7, 6.7, -1.8), Vector3(1.6, 0.2, 1.6), Color("e3d0ae"))
	var repair_roof_badge := Art.cylinder(self, Vector3(2.7, 6.86, -1.8), 0.62, 0.08, Color("f5f2e9"), 1.0, 16)
	repair_roof_badge.set_meta("batch_feature", "RepairServiceRoofBadge")
	Art.box(self, Vector3(2.7, 6.92, -1.8), Vector3(0.13, 0.035, 0.68), Color("d99c34"))
	Art.box(self, Vector3(2.7, 6.92, -1.8), Vector3(0.5, 0.035, 0.13), Color("d99c34"))
	var wrench_grip := Art.box(self, Vector3(2.7, 6.92, -1.8), Vector3(0.13, 0.035, 0.28), Color("54768c"))
	wrench_grip.rotation.y = 0.7

func logistics_center() -> void:
	# Keep the campus model inside the shared 2x2 building footprint.
	scale = Vector3(0.68, 1.0, 0.68)
	# Higher levels visibly add operating capacity.
	Art.box(self, Vector3(0, 0.12, 0), Vector3(13.4, 0.22, 13.4), Color("9a9c91"))
	Art.box(self, Vector3(0, 1.7, -1.15), Vector3(8.6, 3.25, 7.0), Color("d5d4c7"))
	Art.box(self, Vector3(0, 3.4, -1.15), Vector3(8.95, 0.22, 7.25), Color("405c70"))
	Art.box(self, Vector3(0, 1.15, 2.42), Vector3(8.0, 2.3, 0.16), Color("e5e2d6"))
	for x in [-2.6, 0.0, 2.6]:
		Art.box(self, Vector3(x, 1.15, 2.53), Vector3(1.95, 2.0, 0.12), Color("566b73"))
		Art.box(self, Vector3(x, 2.22, 2.62), Vector3(2.0, 0.18, 0.1), Color("dea84e"))
	Art.box(self, Vector3(0, 3.05, 2.72), Vector3(6.6, 0.68, 0.18), Color("3e6d78"))

	Art.box(self, Vector3(-4.35, 0.42, -1.6), Vector3(0.5, 0.7, 5.6), Color("d7c78e"))
	Art.box(self, Vector3(4.35, 0.42, -1.6), Vector3(0.5, 0.7, 5.6), Color("d7c78e"))
	if visual_level >= 2:
		Art.box(self, Vector3(-5.1, 1.55, -1.15), Vector3(2.25, 2.95, 6.35), Color("b9c6bf"))
		Art.box(self, Vector3(-5.1, 3.08, -1.15), Vector3(2.45, 0.18, 6.55), Color("587588"))
		Art.box(self, Vector3(-5.1, 1.18, 2.1), Vector3(1.5, 1.8, 0.1), Color("667f88"))
	if visual_level >= 3:
		Art.box(self, Vector3(3.0, 4.35, -2.25), Vector3(2.6, 2.15, 2.5), Color("7ea0a2"))
		Art.box(self, Vector3(3.0, 5.5, -2.25), Vector3(2.85, 0.2, 2.75), Color("405c70"))
		for x in [1.95, 3.0, 4.05]:
			Art.box(self, Vector3(x, 4.35, -0.96), Vector3(0.08, 1.3, 0.05), Color("dce8dd"))

func warehouse() -> void:
	# Compact 2x2 storage building with readable level upgrades.
	Art.box(self, Vector3(0, 0.12, 0), Vector3(8.7, 0.24, 8.7), Color("a4a08e"))
	Art.box(self, Vector3(0, 1.8, -0.2), Vector3(7.8, 3.35, 6.65), Color("c7c9bd"))
	Art.box(self, Vector3(0, 3.52, -0.2), Vector3(8.05, 0.22, 6.9), Color("587486"))
	Art.box(self, Vector3(0, 1.05, 3.14), Vector3(6.5, 1.95, 0.13), Color("596a70"))
	for x in [-2.15, 0.0, 2.15]:
		Art.box(self, Vector3(x, 1.05, 3.24), Vector3(1.7, 1.72, 0.1), Color("71858a"))
		Art.box(self, Vector3(x, 2.0, 3.31), Vector3(1.78, 0.13, 0.08), Color("e3ba62"))
	Art.box(self, Vector3(0, 2.95, 3.38), Vector3(4.5, 0.55, 0.15), Color("465f68"))

	for x in [-3.35, 3.35]:
		Art.box(self, Vector3(x, 0.32, 3.6), Vector3(0.08, 0.04, 0.65), Color("f0ead8"))
	if visual_level >= 2:
		Art.box(self, Vector3(-0.9, 4.15, -1.2), Vector3(3.0, 0.8, 2.6), Color("e0e3d9"))
		for x in [-1.75, -0.9, -0.05]:
			Art.box(self, Vector3(x, 4.58, -1.2), Vector3(0.42, 0.08, 0.42), Color("9faaa1"))
	if visual_level >= 3:
		Art.cylinder(self, Vector3(2.55, 2.0, -2.1), 1.05, 4.1, Color("d6d9cf"), 0.92, 12)
		Art.cylinder(self, Vector3(2.55, 4.25, -2.1), 1.12, 0.72, Color("718b91"), 0.08, 12)

func fire_station() -> void:
	service_building_shell(Color("c96b52"), Color("6d7070"), Color("8f8170"))
	Art.box(self, Vector3(-0.9, 1.3, 2.34), Vector3(3.5, 2.6, 0.08), Color("48565a"))
	for y in [0.35, 0.75, 1.15, 1.55, 1.95, 2.35]:
		Art.box(self, Vector3(-0.9, y, 2.40), Vector3(3.42, 0.045, 0.04), Color("99a5a0"))
	Art.box(self, Vector3(-0.9, 3.15, 2.42), Vector3(4.6, 0.75, 0.13), Color("a9503e"))
	for x in [-2.55, 0.75]:
		Art.box(self, Vector3(x, 1.15, 2.48), Vector3(0.12, 2.3, 0.12), Color("d7c6a2"))
	var fire_badge := Art.cylinder(self, Vector3(-0.9, 3.99, -0.7), 0.82, 0.08, Color("f7f5ef"), 1.0, 20)
	fire_badge.set_meta("batch_feature", "FireStation911Badge")
	var emergency_911 := Label3D.new()
	emergency_911.name = "FireStation911"
	emergency_911.text = "911"
	emergency_911.font_size = 86
	emergency_911.modulate = Color("d83b34")
	emergency_911.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emergency_911.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	emergency_911.position = Vector3(-0.9, 4.045, -0.7)
	emergency_911.rotation.x = -PI / 2.0
	add_child(emergency_911)

func medical_roof_emblem() -> void:
	var medical_badge := Art.cylinder(self, Vector3(-0.9, 3.99, -0.7), 0.76, 0.08, Color("fbfaf6"), 1.0, 20)
	medical_badge.set_meta("batch_feature", "HospitalRoofBadge")
	Art.box(self, Vector3(-0.9, 4.07, -0.7), Vector3(0.18, 0.045, 0.68), Color("d44343"))
	Art.box(self, Vector3(-0.9, 4.07, -0.7), Vector3(0.56, 0.045, 0.18), Color("d44343"))

func add_vehicle_lights(half_width: float, front_z: float, y: float, rear_z: float) -> void:
	for side in [-1.0, 1.0]:
		Art.box(self, Vector3(side * half_width, y, front_z), Vector3(0.22, 0.14, 0.08), Color("fff1bf"))
		Art.box(self, Vector3(side * half_width, y * 0.78, rear_z), Vector3(0.18, 0.12, 0.08), Color("e45e4f"))

func parked_service_vehicle(kind: String) -> void:
	# Dedicated parking pad and one vehicle for this service, kept inside its 2x2 lot.
	Art.box(self, Vector3(3.1, 0.19, 3.35), Vector3(2.8, 0.12, 2.75), Color("697276"))
	var vehicle := Node3D.new()
	vehicle.name = "ParkedServiceVehicle"
	vehicle.position = Vector3(3.1, 0.27, 3.25)
	vehicle.scale = Vector3.ONE * 0.68
	add_child(vehicle)
	var body_color := Color("d64f3e") if kind == "fire_engine" else (Color("f4f0df") if kind in ["police_car", "ambulance"] else Color("e5a932"))
	var ambulance := kind == "ambulance"
	var body_size := Vector3(1.95, 1.1, 2.75) if ambulance else Vector3(1.85, 0.62, 2.6)
	var body_y := 0.9 if ambulance else 0.72
	var cabin_size := Vector3(1.8, 0.82, 1.18) if ambulance else Vector3(1.68, 0.86, 1.0)
	var cabin_y := 1.72 if ambulance else 1.24
	Art.box(vehicle, Vector3(0, body_y, -0.15), body_size, body_color)
	Art.box(vehicle, Vector3(0, cabin_y, 0.68), cabin_size, body_color.darkened(0.04))
	Art.box(vehicle, Vector3(0, cabin_y + (0.14 if ambulance else 0.10), 1.2), Vector3(1.42, 0.58, 0.06), Color("8bb6c0"))
	if kind == "ambulance":
		# Red cross on white roof circle and on both sides of the minibus body.
		Art.box(vehicle, Vector3(0, 1.0, -0.18), Vector3(0.18, 0.44, 0.06), Color("d95046"))
		Art.box(vehicle, Vector3(0, 1.0, -0.18), Vector3(0.52, 0.16, 0.06), Color("d95046"))
		Art.box(vehicle, Vector3(0, 0.7, 0), Vector3(1.9, 0.12, 2.5), Color("4aa4a0"))
		var ambulance_roof_badge := Art.cylinder(vehicle, Vector3(0, 2.20, -0.28), 0.34, 0.06, Color("fffdf8"), 1.0, 16)
		ambulance_roof_badge.set_meta("batch_feature", "AmbulanceRoofBadge")
		Art.box(vehicle, Vector3(0, 2.25, -0.28), Vector3(0.13, 0.04, 0.46), Color("d44343"))
		Art.box(vehicle, Vector3(0, 2.25, -0.28), Vector3(0.40, 0.04, 0.13), Color("d44343"))
		for side in [-1.0, 1.0]:
			var side_disc := Art.cylinder(vehicle, Vector3(side * 0.99, 1.08, -0.2), 0.31, 0.06, Color("fffdf8"), 1.0, 16)
			side_disc.set_meta("batch_feature", "AmbulanceSideBadge")
			side_disc.rotation.z = PI / 2
			Art.box(vehicle, Vector3(side * 1.03, 1.08, -0.2), Vector3(0.04, 0.10, 0.42), Color("d44343"))
			Art.box(vehicle, Vector3(side * 1.03, 1.08, -0.2), Vector3(0.04, 0.36, 0.10), Color("d44343"))
	elif kind == "police_car":
		Art.box(vehicle, Vector3(0, 1.57, 0.15), Vector3(1.54, 0.12, 1.9), Color("315b88"))
		for side in [-1.0, 1.0]:
			var police_door := Art.box(vehicle, Vector3(side * 0.94, 0.95, 0.0), Vector3(0.06, 0.42, 1.05), Color("315b88"))
			police_door.name = "PoliceLiveryDoor"
			Art.sphere(vehicle, Vector3(side * 0.98, 0.97, 0.0), 0.12, Color("d7c884"))
	elif kind == "fire_engine":
		Art.box(vehicle, Vector3(0, 0.96, -0.3), Vector3(0.16, 0.18, 1.6), Color("f3d463"))
		var fire_vehicle_badge := Art.cylinder(vehicle, Vector3(0, 1.94, -0.58), 0.34, 0.06, Color("fffdf8"), 1.0, 16)
		fire_vehicle_badge.set_meta("batch_feature", "FireEngineRoofBadge")
		for side in [-1.0, 1.0]:
			Art.box(vehicle, Vector3(side * 0.18, 1.99, -0.58), Vector3(0.12, 0.04, 0.44), Color("d44343"))
			Art.box(vehicle, Vector3(0, 1.99, -0.58), Vector3(0.38, 0.04, 0.12), Color("d44343"))
	else:
		Art.box(vehicle, Vector3(0, 1.18, -0.64), Vector3(1.35, 0.42, 1.15), Color("d79626"))
		var repair_vehicle_badge := Art.cylinder(vehicle, Vector3(0, 1.48, -0.64), 0.31, 0.06, Color("fffdf8"), 1.0, 16)
		repair_vehicle_badge.set_meta("batch_feature", "RepairVehicleRoofBadge")
		Art.box(vehicle, Vector3(0, 1.53, -0.64), Vector3(0.10, 0.04, 0.38), Color("d99c34"))
		Art.box(vehicle, Vector3(0, 1.53, -0.64), Vector3(0.34, 0.04, 0.10), Color("d99c34"))
	for side in [-1.0, 1.0]:
		for z in [-0.88, 0.88]:
			var wheel := Art.cylinder(vehicle, Vector3(side * 0.9, 0.39, z), 0.34, 0.2, Color("343a3b"), 0.0, 10)
			wheel.rotation.z = PI / 2
	for side in [-1.0, 1.0]:
		Art.box(vehicle, Vector3(side * 0.55, 0.75, 1.34), Vector3(0.2, 0.14, 0.07), Color("fff1bf"))
	if kind == "work_vehicle":
		var amber := Art.cylinder(vehicle, Vector3(0, 1.72, 0.18), 0.2, 0.14, Color("ff9b24"), 0.0, 10)
		amber.name = "BeaconLamp"
		amber.set_meta("dynamic", true)
		amber.material_override = Art.material(Color("755827"))
	if kind in ["fire_engine", "police_car", "ambulance"]:
		var red := Art.box(vehicle, Vector3(-0.22, 1.76, 0.25), Vector3(0.2, 0.12, 0.13), Color("dc4242"))
		red.name = "BeaconRed"
		red.set_meta("dynamic", true)
		var blue := Art.box(vehicle, Vector3(0.22, 1.76, 0.25), Vector3(0.2, 0.12, 0.13), Color("438ee8"))
		blue.name = "BeaconBlue"
		blue.set_meta("dynamic", true)
		red.material_override = Art.material(Color("7f3838"))
		blue.material_override = Art.material(Color("344d75"))
	# Keep the vehicle's geometry grouped under this node so dispatch can hide it
	# while the matching service vehicle is out on a call.
	Art.batch(vehicle)

func set_parked_service_vehicle_visible(value: bool) -> void:
	var vehicle := find_child("ParkedServiceVehicle", false, false) as Node3D
	if vehicle != null:
		vehicle.visible = value

func police_helipad() -> void:
	# Roof pad stays within the police station's standard 2x2 lot.
	Art.cylinder(self, helicopter_pad, 1.25, 0.08, Color("53646a"), 1.0, 20)
	for side in [-1.0, 1.0]:
		var rim := Art.box(self, helicopter_pad + Vector3(side * 1.12, 0.055, 0), Vector3(0.06, 0.025, 0.92), Color("e5e5d8"))
		rim.rotation.y = 0.5
		var cross_rim := Art.box(self, helicopter_pad + Vector3(0, 0.055, side * 1.12), Vector3(0.92, 0.025, 0.06), Color("e5e5d8"))
		cross_rim.rotation.y = 0.5
	for x in [-0.28, 0.28]:
		var stem := Art.box(self, helicopter_pad + Vector3(x, 0.075, 0), Vector3(0.16, 0.035, 0.9), Color("fff4d8"))
		stem.set_meta("batch_feature", "HelipadH")
	var bar := Art.box(self, helicopter_pad + Vector3(0, 0.075, 0), Vector3(0.56, 0.035, 0.16), Color("fff4d8"))
	bar.set_meta("batch_feature", "HelipadH")

	police_helicopter = Node3D.new()
	police_helicopter.name = "PoliceHelicopter"
	police_helicopter.position = helicopter_pad + Vector3(0, 11, 0)
	police_helicopter.visible = false
	add_child(police_helicopter)
	var fuselage := Art.box(police_helicopter, Vector3(0, 0, 0), Vector3(0.78, 0.42, 1.55), Color("354b57"))
	fuselage.set_meta("dynamic", true)
	var cabin := Art.box(police_helicopter, Vector3(0, 0.12, 0.3), Vector3(0.76, 0.48, 0.7), Color("78aebe"))
	cabin.set_meta("dynamic", true)
	var tail := Art.box(police_helicopter, Vector3(0, 0.06, -1.35), Vector3(0.14, 0.14, 1.35), Color("354b57"))
	tail.set_meta("dynamic", true)
	for side in [-1.0, 1.0]:
		var skid := Art.box(police_helicopter, Vector3(side * 0.38, -0.34, 0), Vector3(0.08, 0.08, 1.65), Color("aebcc0"))
		skid.set_meta("dynamic", true)
		var strut := Art.box(police_helicopter, Vector3(side * 0.3, -0.2, 0), Vector3(0.06, 0.3, 0.06), Color("aebcc0"))
		strut.set_meta("dynamic", true)
	helicopter_rotor = Node3D.new()
	helicopter_rotor.name = "MainRotor"
	helicopter_rotor.position = Vector3(0, 0.38, 0)
	police_helicopter.add_child(helicopter_rotor)
	var blade_a := Art.box(helicopter_rotor, Vector3.ZERO, Vector3(2.6, 0.035, 0.1), Color("202c32"))
	blade_a.set_meta("dynamic", true)
	var blade_b := Art.box(helicopter_rotor, Vector3.ZERO, Vector3(0.1, 0.035, 2.6), Color("202c32"))
	blade_b.set_meta("dynamic", true)
	helicopter_rng.seed = absi(str(get_parent().get_parent().get("instance_id")).hash()) + 9271
	helicopter_timer = helicopter_rng.randf_range(20.0, 45.0)

func service_station(wall: Color, accent: Color, sign_text: String) -> void:
	service_building_shell(wall, Color("70787a"), Color("8f8170"))
	Art.box(self, Vector3(-0.9, 1.25, 2.34), Vector3(3.2, 2.5, 0.08), Color("56666a"))
	Art.box(self, Vector3(-0.9, 3.1, 2.42), Vector3(4.5, 0.72, 0.13), accent)
	for x in [-2.4, -0.9, 0.6]:
		Art.box(self, Vector3(x, 1.6, 2.40), Vector3(0.72, 1.0, 0.08), Color("9bc7d0"))

func fire_engine() -> void:
	Art.box(self, Vector3(0, 0.72, -0.35), Vector3(1.9, 1.15, 2.8), Color("d64f3e"))
	Art.box(self, Vector3(0, 1.32, 0.58), Vector3(1.82, 1.15, 1.0), Color("c94334"))
	Art.box(self, Vector3(0, 1.38, 1.11), Vector3(1.5, 0.62, 0.06), Color("9bc7d0"))
	Art.box(self, Vector3(0, 1.31, -1.78), Vector3(1.52, 0.9, 0.08), Color("dce2db"))
	Art.box(self, Vector3(0, 1.38, -0.4), Vector3(0.15, 0.18, 1.65), Color("f3d463"))
	Art.cylinder(self, Vector3(0, 2.02, 0.25), 0.13, 0.12, Color("4c9de0"), 1, 8)
	var beacon_left := Art.box(self, Vector3(-0.28, 2.02, 0.25), Vector3(0.22, 0.12, 0.14), Color("dc4242"))
	beacon_left.name = "BeaconRed"
	beacon_left.set_meta("dynamic", true)
	var beacon_right := Art.box(self, Vector3(0.28, 2.02, 0.25), Vector3(0.22, 0.12, 0.14), Color("438ee8"))
	beacon_right.name = "BeaconBlue"
	beacon_right.set_meta("dynamic", true)
	add_vehicle_lights(0.5, 1.14, 1.35, -1.8)
	for x in [-0.78, 0.78]:
		for z in [-1.15, 0.95]:
			var wheel := Art.cylinder(self, Vector3(x, 0.43, z), 0.4, 0.24, Color("3a3b3a"), 0.8, 12)
			wheel.rotation.z = PI / 2

func ruins(seed_value: int) -> void:
	Art.box(self, Vector3(0, 0.12, 0), Vector3(7.8, 0.22, 7.8), Color("827b70"))
	for i in range(12):
		var x := float((i * 17 + seed_value) % 65) / 10.0 - 3.2
		var z := float((i * 23 + seed_value / 3) % 65) / 10.0 - 3.2
		var height := 0.28 + float(i % 4) * 0.16
		var rubble := Art.box(self, Vector3(x, 0.24 + height / 2, z), Vector3(0.6 + float(i % 3) * 0.2, height, 0.45 + float(i % 2) * 0.24), Color("9a8978") if i % 2 == 0 else Color("6e716d"))
		rubble.rotation.y = float(i * 11 % 40) * PI / 180.0

func set_emergency_lights(enabled: bool, time_value: float = 0.0) -> void:
	var red := get_node_or_null("BeaconRed") as MeshInstance3D
	var blue := get_node_or_null("BeaconBlue") as MeshInstance3D
	var red_flash := enabled and int(time_value * 8.0) % 2 == 0
	var blue_flash := enabled and not red_flash
	if red != null:
		red.visible = true
		red.material_override = Art.material(Color("ff3e35") if red_flash else (Color("7f3838") if not enabled else Color("362a2b")))
	if blue != null:
		blue.visible = true
		blue.material_override = Art.material(Color("398bff") if blue_flash else (Color("344d75") if not enabled else Color("29313b")))
	var amber := get_node_or_null("BeaconLamp") as MeshInstance3D
	if amber != null:
		amber.visible = true
		amber.material_override = Art.material(Color("ff9b24") if enabled and int(time_value * 6.0) % 2 == 0 else Color("755827"))

func park() -> void:
	if visual_level >= 2:
		for x in [-2.7, 2.7]:
			for z in [-1.8, 1.8]:
				Art.box(self, Vector3(x, 0.25, z), Vector3(1.2, 0.4, 0.9), Color("c8b68d"))
				for i in range(3):
					Art.cylinder(self, Vector3(x - 0.35 + i * 0.35, 0.5, z), 0.14, 0.2, Color("d6868e"), 1, 8)
	if visual_level == 3:
		Art.cylinder(self, Vector3(2.6, 0.25, -2.6), 1.4, 0.45, Color("d4c6a6"), 1, 6)
		for x in [1.7, 3.5]:
			for z in [-3.5, -1.7]:
				Art.box(self, Vector3(x, 1.2, z), Vector3(0.12, 2, 0.12), Color("c9c2a7"))
		Art.cylinder(self, Vector3(2.6, 2.5, -2.6), 1.6, 0.8, Color("709e95"), 0, 6)
	Art.box(self, Vector3(0, 0.02, 0), Vector3(8.6, 0.08, 8.6), Color("a6b879"))
	Art.box(self, Vector3(0, 0.09, 0), Vector3(1.1, 0.06, 8.6), Color("d9d2ab"))
	Art.box(self, Vector3(0, 0.09, 0), Vector3(8.6, 0.06, 1.1), Color("d9d2ab"))
	Art.cylinder(self, Vector3(0, 0.25, 0), 1.7, 0.5, Color("cecbb7"), 1, 20)
	var fountain_water := Art.cylinder(self, Vector3(0, 0.52, 0), 1.4, 0.04, Color("7ab7c7"), 1, 20)
	fountain_water.name = "FountainWaterSurface"
	for x in [-3, 3]:
		for z in [-3, 3]:
			if visual_level < 3 or x != 3 or z != -3:
				Art.tree(self, Vector3(x, 0, z), 1.0, false, int(x + z))
	for i in range(2):
		var x := -1.4 if i == 0 else 1.4
		var bench := Art.bench(self, Vector3(x, 0, 2.7), 0, 0.7)
		bench.name = "ParkBench%d" % i

func van() -> void:
	Art.box(self, Vector3(0, 0.87, -0.35), Vector3(1.65, 1.35, 1.85), Color("218fb9"))
	Art.box(self, Vector3(0, 0.8, 0.85), Vector3(1.55, 1.2, 0.8), Color("389fca"))
	Art.box(self, Vector3(0, 1.42, 0.72), Vector3(1.52, 0.12, 1.03), Color("6bbde0"))
	Art.box(self, Vector3(0, 1.15, 1.29), Vector3(1.27, 0.53, 0.04), Color("a2ccd3"))
	for x in [-0.85, 0.85]:
		Art.box(self, Vector3(x, 0.9, -0.4), Vector3(0.025, 0.14, 1.6), Color("e8eee1"))
		for z in [-0.85, 0.9]:
			var wheel := Art.cylinder(self, Vector3(x, 0.37, z), 0.36, 0.21, Color("35454a"), 1, 12)
			wheel.rotation.z = PI / 2
			var hub := Art.cylinder(self, Vector3(x * 1.12, 0.37, z), 0.16, 0.03, Color("aeb5b0"), 1, 10)
			hub.rotation.z = PI / 2
	for x in [-0.56, 0.56]:
		Art.box(self, Vector3(x, 0.7, 1.29), Vector3(0.28, 0.23, 0.06), Color("fff0be"))
	Art.box(self, Vector3(0, 0.37, 1.35), Vector3(1.65, 0.18, 0.13), Color("566971"))
	add_vehicle_lights(0.58, 1.3, 0.78, -1.25)
	var beacon_red := Art.box(self, Vector3(-0.18, 1.7, 0.7), Vector3(0.16, 0.12, 0.14), Color("dc4242"))
	beacon_red.name = "BeaconRed"
	beacon_red.set_meta("dynamic", true)
	var beacon_blue := Art.box(self, Vector3(0.18, 1.7, 0.7), Vector3(0.16, 0.12, 0.14), Color("438ee8"))
	beacon_blue.name = "BeaconBlue"
	beacon_blue.set_meta("dynamic", true)

func construction_vehicle() -> void:
	var yellow := Color("e5a932")
	var work_car := visual_type == "work_vehicle"
	Art.box(self, Vector3(0, 0.72, 0), Vector3(2.0, 0.52, 3.7), yellow)
	Art.box(self, Vector3(0, 1.35, 0.45), Vector3(1.75, 1.1, 1.65), yellow)
	Art.box(self, Vector3(0, 1.48, 1.28), Vector3(1.36, 0.62, 0.08), Color("91b6bf"))
	Art.box(self, Vector3(0, 1.13, -0.85), Vector3(1.5, 0.35, 1.55), Color("d79626"))
	if not work_car:
		Art.box(self, Vector3(0, 1.48, -1.45), Vector3(1.85, 0.65, 1.8), Color("efb83f"))
		Art.box(self, Vector3(0, 1.84, -1.45), Vector3(1.92, 0.08, 1.88), Color("f4c852"))
	for side in [-1, 1]:
		for z in [-1.15, 1.05]:
			var wheel := Art.cylinder(self, Vector3(float(side) * 1.0, 0.46, z), 0.42, 0.22, Color("343a3b"), 0.0, 12)
			wheel.rotation.z = PI / 2
			var hub := Art.cylinder(self, Vector3(float(side) * 1.13, 0.46, z), 0.2, 0.04, Color("a5a8a6"), 0.0, 10)
			hub.rotation.z = PI / 2
	add_vehicle_lights(0.72, 1.3, 0.78, -1.8)
	if work_car:
		var beacon := Art.cylinder(self, Vector3(0, 2.03, 0.5), 0.23, 0.2, Color("ff8c24"), 0.0, 10)
		beacon.name = "BeaconLamp"
		beacon.set_meta("dynamic", true)
		beacon.material_override = Art.material(Color("ff8c24"))

func set_serviced(value: bool) -> void:
	for item: MeshInstance3D in windows:
		item.material_override = Art.material(Color("7fbbb4") if value else Color("6a8790")) if visual_type != "traffic_signal" else Art.material(Color("6bad67") if value else Color("ef9b43"))

func set_language(language: String) -> void:
	for sign: Label3D in signs:
		if visual_type == "cafe":
			sign.text = "КАФЕ" if language == "ru" else "CAFE"
		elif visual_type == "city_hall":
			sign.text = "МЭРИЯ" if language == "ru" else "CITY HALL"
		elif visual_type == "fire_station":
			sign.text = "ПОЖАРНЫЕ" if language == "ru" else "FIRE"
		elif visual_type == "logistics_center":
			sign.text = "ЛОГИСТИКА" if language == "ru" else "LOGISTICS"
		elif visual_type == "warehouse":
			sign.text = "СКЛАД" if language == "ru" else "WAREHOUSE"
		else:
			sign.text = "СЛУЖБЫ" if language == "ru" else "SERVICE"

func city_hall() -> void:
	# Monumental low-poly civic hall: stone forecourt, broad wings and a clear
	# classical silhouette that reads from the fixed isometric camera.
	Art.box(self, Vector3(0, 0.18, 0), Vector3(9.1, 0.28, 9.1), Color("b8b49f"))
	Art.box(self, Vector3(0, 0.38, -0.15), Vector3(8.35, 0.36, 7.7), Color("e6dfcc"))
	Art.box(self, Vector3(0, 2.98, -0.55), Vector3(5.15, 5.05, 5.65), Color("e8e1d1"))
	Art.box(self, Vector3(-3.18, 2.55, -0.68), Vector3(1.25, 4.15, 5.15), Color("d7d2c3"))
	Art.box(self, Vector3(3.18, 2.55, -0.68), Vector3(1.25, 4.15, 5.15), Color("d7d2c3"))
	# Deep blue rooflines distinguish the civic building from ordinary houses.
	Art.box(self, Vector3(0, 5.62, -0.52), Vector3(5.65, 0.34, 6.15), Color("455f78"))
	Art.box(self, Vector3(-3.18, 4.72, -0.68), Vector3(1.55, 0.28, 5.45), Color("637b8c"))
	Art.box(self, Vector3(3.18, 4.72, -0.68), Vector3(1.55, 0.28, 5.45), Color("637b8c"))
	# Grand portico, repeated stone columns, and a broad public staircase.
	Art.box(self, Vector3(0, 5.1, 2.48), Vector3(6.6, 0.42, 1.55), Color("e9e3d4"))
	for x in [-2.55, -1.53, -0.51, 0.51, 1.53, 2.55]:
		Art.cylinder(self, Vector3(x, 2.72, 3.12), 0.19, 4.35, Color("f2ecdc"), 0.82, 10)
		Art.cylinder(self, Vector3(x, 0.58, 3.12), 0.29, 0.22, Color("c4bba5"), 0.94, 10)
	for step in range(3):
		Art.box(self, Vector3(0, 0.26 + step * 0.19, 3.64 + step * 0.43), Vector3(4.4 + step * 0.75, 0.24, 0.72), Color("c9c3b3"))
	# Pediment with an inset blue clock medallion.
	Art.triangles(self, PackedVector3Array([
		Vector3(-3.35, 5.25, 3.02), Vector3(3.35, 5.25, 3.02), Vector3(0, 7.15, 3.02)
	]), Color("eee7d8"))
	var clock := Art.cylinder(self, Vector3(0, 5.93, 3.105), 0.43, 0.12, Color("b49b62"), 1.0, 20)
	clock.rotation.x = PI / 2
	var clock_face := Art.cylinder(self, Vector3(0, 5.93, 3.19), 0.33, 0.035, Color("344d64"), 1.0, 20)
	clock_face.rotation.x = PI / 2
	Art.box(self, Vector3(0, 6.02, 3.22), Vector3(0.045, 0.19, 0.035), Color("f2e9cd"))
	Art.box(self, Vector3(0.07, 5.91, 3.22), Vector3(0.17, 0.045, 0.035), Color("f2e9cd"))
	# A blue-green dome and flag form the city-centre landmark.
	Art.cylinder(self, Vector3(0, 6.0, -0.58), 1.6, 0.62, Color("b6ad98"), 1.0, 16)
	var dome := Art.sphere(self, Vector3(0, 6.78, -0.58), 1.42, Color("527b87"))
	dome.scale = Vector3(1.0, 0.68, 1.0)
	Art.cylinder(self, Vector3(0, 7.9, -0.58), 0.13, 1.45, Color("b89d5c"), 0.8, 8)
	Art.box(self, Vector3(0.55, 8.2, -0.58), Vector3(1.0, 0.48, 0.055), Color("3f7e81"))
	Art.box(self, Vector3(0.55, 8.2, -0.545), Vector3(0.16, 0.16, 0.025), Color("e4c675"))
	# Tall blue entrance doors and front-facing windows make the facade legible.
	Art.box(self, Vector3(0, 1.56, 3.2), Vector3(1.25, 2.3, 0.16), Color("3c596d"))
	Art.box(self, Vector3(0, 1.52, 3.3), Vector3(0.05, 2.0, 0.035), Color("b6a56f"))
	for x in [-3.16, -2.12, 2.12, 3.16]:
		Art.box(self, Vector3(x, 3.05, 1.94), Vector3(0.58, 1.35, 0.12), Color("7fabb4"))
		Art.box(self, Vector3(x, 3.05, 2.02), Vector3(0.66, 0.09, 0.07), Color("f0e7d6"))
	Art.box(self, Vector3(0, 0.34, -3.8), Vector3(5.7, 0.12, 0.36), Color("71915f"))
	for x in [-2.0, 2.0]:
		Art.tree(self, Vector3(x, 0.38, -3.8), 0.42, false, 2)

func set_elite_arch_axis(axis: String, lane_offset: int = 0) -> void:
	if visual_type != "elite_residence" or axis not in ["horizontal", "vertical"]:
		return
	for child in get_children():
		remove_child(child)
		child.queue_free()
	elite_residence(axis, lane_offset)
	Art.batch(self)

func set_neglect_stage(stage: int) -> void:
	if visual_type != "house":
		return
	var old_details := get_node_or_null("NeglectDetails")
	if old_details != null:
		remove_child(old_details)
		old_details.queue_free()
	if stage <= 0:
		return
	var details := Node3D.new()
	details.name = "NeglectDetails"
	add_child(details)
	for index in range(mini(stage, 3)):
		var x: float = [-1.5, 1.55, -1.5][index]
		var y: float = [2.0, 2.0, 3.5][index]
		var z := 1.87 if index < 2 else 1.8
		Art.box(details, Vector3(x, y, z), Vector3(0.9, 0.12, 0.1), Color("736756"))
		if index < 2:
			Art.box(details, Vector3(x, y - 0.34, z), Vector3(0.12, 0.68, 0.1), Color("736756"))
	Art.batch(details)

func elite_residence(arch_axis: String = "", lane_offset: int = 0) -> void:
	scale = Vector3(0.48, 1.0, 0.48) if arch_axis == "" else Vector3.ONE
	if arch_axis != "":
		elite_residence_arch(arch_axis, lane_offset)
		return
	# A compact 2x2 luxury lot. Each upgrade adds a richer silhouette.
	var stone := Color("e8e1d3")
	var trim := Color("a88757")
	var glass := Color("79b7c5")
	var dark_glass := Color("355766")
	Art.box(self, Vector3(0, 0.12, 0), Vector3(18.4, 0.18, 18.4), Color("79956b"))
	Art.box(self, Vector3(-6.9, 0.22, -3.6), Vector3(3.2, 0.12, 7.8), Color("626d72"))
	for x in [-7.7, -6.9, -6.1]:
		Art.box(self, Vector3(x, 0.30, -3.6), Vector3(0.06, 0.025, 7.2), Color("eee6d5"))
	Art.box(self, Vector3(0, 0.34, 0.2), Vector3(14.2, 0.34, 12.2), Color("d1c5ae"))
	Art.box(self, Vector3(0, 1.78, -0.15), Vector3(13.2, 2.55, 10.8), stone)
	Art.box(self, Vector3(0, 3.85, -0.35), Vector3(11.7, 2.0, 9.6), Color("eee9df"))
	Art.box(self, Vector3(0, 4.93, -0.35), Vector3(12.1, 0.24, 10.0), dark_glass)
	for x in [-4.5, -2.7, 2.7, 4.5]:
		Art.box(self, Vector3(x, 1.9, 5.28), Vector3(1.18, 1.38, 0.10), glass)
		Art.box(self, Vector3(x, 4.0, 4.46), Vector3(1.35, 1.05, 0.10), glass)
		Art.box(self, Vector3(x - 0.7, 1.9, 5.35), Vector3(0.08, 1.52, 0.08), trim)
		Art.box(self, Vector3(x + 0.7, 1.9, 5.35), Vector3(0.08, 1.52, 0.08), trim)
	Art.box(self, Vector3(0, 1.55, 5.38), Vector3(1.42, 2.12, 0.14), Color("354653"))
	Art.box(self, Vector3(0.42, 1.6, 5.48), Vector3(0.12, 0.12, 0.04), Color("e9c779"))
	Art.box(self, Vector3(0, 2.74, 5.95), Vector3(3.7, 0.18, 1.72), trim)
	for x in [-1.48, 1.48]:
		Art.box(self, Vector3(x, 1.72, 5.95), Vector3(0.2, 2.1, 0.2), stone)
	Art.box(self, Vector3(0, 0.50, 6.28), Vector3(4.3, 0.18, 2.5), Color("c8baa0"))
	# Formal Roman cypress allee beside the entrance; the arrival path stays clear.
	for index in range(4):
		var tree_x := -5.8 + index * 1.45 if index < 2 else 4.35 + (index - 2) * 1.45
		Art.cylinder(self, Vector3(tree_x, 3.05, 5.7), 0.58, 6.1, Color("315743"), 0.055, 8)
		Art.cylinder(self, Vector3(tree_x, 0.62, 5.7), 0.14, 1.15, Color("78634b"), 0.10, 8)
	for x in [-3.2, 3.2]:
		Art.box(self, Vector3(x, 3.05, 5.18), Vector3(3.25, 0.16, 1.32), Color("cfc5b4"))
		Art.box(self, Vector3(x, 3.48, 5.78), Vector3(3.25, 0.08, 0.07), glass)
		for post in [-1.5, 1.5]:
			Art.box(self, Vector3(x + post, 3.27, 5.78), Vector3(0.07, 0.48, 0.07), glass)
	if visual_level >= 2:
		Art.box(self, Vector3(0, 6.15, -0.55), Vector3(9.3, 2.25, 7.2), Color("e8e4dc"))
		Art.box(self, Vector3(0, 7.32, -0.55), Vector3(9.7, 0.22, 7.6), Color("7c8581"))
		for x in [-3.15, -1.05, 1.05, 3.15]:
			Art.box(self, Vector3(x, 6.22, 3.12), Vector3(1.3, 1.1, 0.10), glass)
		Art.box(self, Vector3(0, 5.22, -3.2), Vector3(8.0, 0.12, 3.1), Color("a99878"))
		for x in [-3.8, 3.8]:
			Art.box(self, Vector3(x, 5.55, -3.2), Vector3(0.07, 0.7, 2.9), glass)
		for x in [-4.5, -2.25, 0.0, 2.25, 4.5]:
			Art.box(self, Vector3(x, 4.0, -5.22), Vector3(0.14, 4.0, 0.12), trim)
		Art.tree(self, Vector3(-3.15, 7.45, -2.8), 0.28, false, 13)
		Art.tree(self, Vector3(3.15, 7.45, -2.8), 0.28, false, 29)
	if visual_level >= 3:
		Art.box(self, Vector3(0, 8.7, -0.7), Vector3(7.8, 2.3, 6.1), dark_glass)
		Art.box(self, Vector3(0, 9.95, -0.7), Vector3(8.25, 0.24, 6.5), trim)
		for x in [-3.0, -1.0, 1.0, 3.0]:
			Art.box(self, Vector3(x, 8.7, 2.42), Vector3(0.92, 1.48, 0.10), Color("b4d9d7"))
		Art.box(self, Vector3(0, 10.18, -0.7), Vector3(10.1, 0.12, 8.0), Color("637e6d"))
		Art.box(self, Vector3(0, 10.68, -0.7), Vector3(6.8, 0.14, 5.2), Color("b8aa8c"))
		for x in [-2.85, 2.85]:
			Art.box(self, Vector3(x, 10.42, -0.7), Vector3(0.08, 0.55, 5.0), glass)
		Art.box(self, Vector3(0, 10.31, -0.7), Vector3(3.2, 0.08, 1.3), Color("4ca4b9"))
		for x in [-3.3, 3.3]:
			Art.box(self, Vector3(x, 11.02, -0.7), Vector3(0.10, 1.4, 0.10), trim)
		Art.box(self, Vector3(0, 11.68, -0.7), Vector3(6.7, 0.12, 0.12), trim)
	for x in [-8.0, 8.0]:
		Art.tree(self, Vector3(x, 0.1, -7.7), 0.42, false, absi(roundi(x * 10)))

func elite_residence_arch(axis: String, lane_offset: int) -> void:
	# Two private halves frame a public road; the elevated connector forms a visible arch.
	var lane_shift := float(lane_offset) * 2.4
	if axis == "horizontal":
		for side in [-1.0, 1.0]:
			var z: float = lane_shift + side * 7.0
			Art.box(self, Vector3(0, 0.12, z), Vector3(18.5, 0.18, 4.2), Color("8e9f78"))
			Art.box(self, Vector3(0, 2.35, z), Vector3(12.8, 4.3, 4.1), Color("f2eee2"))
			Art.box(self, Vector3(0, 4.6, z), Vector3(13.2, 0.25, 4.35), Color("39586a"))
			for window_x in [-4.4, -1.5, 1.5, 4.4]:
				Art.box(self, Vector3(window_x, 2.35, z + side * 2.08), Vector3(1.0, 1.25, 0.08), Color("7fabb4"))
		# Four edge piers leave the 2.8 m roadway clear; the bridge deck crosses overhead.
		for x in [-8.45, 8.45]:
			for side in [-1.0, 1.0]:
				Art.box(self, Vector3(x, 2.0, lane_shift + side * 2.25), Vector3(0.62, 4.0, 0.62), Color("d7d7cd"))
		Art.box(self, Vector3(0, 4.15, lane_shift), Vector3(18.3, 0.9, 4.45), Color("d8d5c8"))
		Art.box(self, Vector3(0, 4.64, lane_shift), Vector3(18.4, 0.18, 4.55), Color("39586a"))
		Art.box(self, Vector3(-5.7, 0.24, lane_shift - 7.1), Vector3(4.8, 0.22, 4.2), Color("666f72"))
		Art.box(self, Vector3(5.6, 0.22, lane_shift + 7.1), Vector3(4.5, 0.2, 3.5), Color("72b5c4"))
	else:
		for side in [-1.0, 1.0]:
			var x: float = lane_shift + side * 7.0
			Art.box(self, Vector3(x, 0.12, 0), Vector3(4.2, 0.18, 18.5), Color("8e9f78"))
			Art.box(self, Vector3(x, 2.35, 0), Vector3(4.1, 4.3, 12.8), Color("f2eee2"))
			Art.box(self, Vector3(x, 4.6, 0), Vector3(4.35, 0.25, 13.2), Color("39586a"))
			for window_z in [-4.4, -1.5, 1.5, 4.4]:
				Art.box(self, Vector3(x + side * 2.08, 2.35, window_z), Vector3(0.08, 1.25, 1.0), Color("7fabb4"))
		for z in [-8.45, 8.45]:
			for side in [-1.0, 1.0]:
				Art.box(self, Vector3(lane_shift + side * 2.25, 2.0, z), Vector3(0.62, 4.0, 0.62), Color("d7d7cd"))
		Art.box(self, Vector3(lane_shift, 4.15, 0), Vector3(4.45, 0.9, 18.3), Color("d8d5c8"))
		Art.box(self, Vector3(lane_shift, 4.64, 0), Vector3(4.55, 0.18, 18.4), Color("39586a"))
		Art.box(self, Vector3(lane_shift - 7.1, 0.24, -5.7), Vector3(4.2, 0.22, 4.8), Color("666f72"))
		Art.box(self, Vector3(lane_shift + 7.1, 0.22, 5.6), Vector3(3.5, 0.2, 4.5), Color("72b5c4"))

func business_tower() -> void:
	# Keep the 12-floor silhouette while fitting on a standard 2x2 lot.
	scale = Vector3(0.48, 1.0, 0.48)
	Art.box(self, Vector3(0, 0.12, 0), Vector3(18.6, 0.18, 18.6), Color("a6a88f"))
	Art.box(self, Vector3(0, 0.55, 0), Vector3(13.4, 0.8, 13.4), Color("d5d0c0"))
	for floor_index in range(12):
		var y := 1.25 + floor_index * 1.16
		var taper := 1.0 - float(floor_index) * 0.018
		Art.box(self, Vector3(0, y, 0), Vector3(10.2 * taper, 1.08, 10.2 * taper), Color("527f91") if floor_index % 3 else Color("8eb7bd"))
		for side in [-1.0, 1.0]:
			Art.box(self, Vector3(side * 5.15 * taper, y, 0), Vector3(0.12, 0.85, 9.8 * taper), Color("c9e3df"))
	Art.box(self, Vector3(0, 15.4, 0), Vector3(5.8, 1.2, 5.8), Color("37566c"))
	for x in [-7.0, 7.0]:
		for z in [-7.0, 7.0]:
			Art.tree(self, Vector3(x, 0.1, z), 0.42, false, absi(roundi(x * 13 + z)))

var signal_bulbs: MultiMesh

func make_signals() -> void:
	signal_bulbs = MultiMesh.new()
	signal_bulbs.transform_format = MultiMesh.TRANSFORM_3D
	signal_bulbs.use_colors = true
	var sphere := SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	sphere.radial_segments = 8
	sphere.rings = 4
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	sphere.material = material
	signal_bulbs.mesh = sphere
	signal_bulbs.instance_count = 12
	var positions := [Vector3(-2.65, 0, 2.65), Vector3(2.65, 0, -2.65), Vector3(2.65, 0, 2.65), Vector3(-2.65, 0, -2.65)]
	var rotations := [-PI / 2, PI / 2, 0.0, PI]
	for i in range(4):
		var pole := Node3D.new()
		pole.name = "SignalPole%d" % i
		add_child(pole)
		pole.position = positions[i]
		pole.rotation.y = rotations[i]
		Art.cylinder(pole, Vector3(0, 1.8, 0), 0.08, 3.6, Color("93999d"))
		Art.box(pole, Vector3(0, 3.6, 0), Vector3(0.48, 1.2, 0.36), Color("858b90"))
		for lamp in range(3):
			var point: Vector3 = pole.transform * Vector3(0, 3.94 - lamp * 0.34, 0.22)
			signal_bulbs.set_instance_transform(i * 3 + lamp, Transform3D(Basis(), point))
	var display := MultiMeshInstance3D.new()
	display.multimesh = signal_bulbs
	add_child(display)
	set_signal_states("red", "red")

func set_signal_states(horizontal: String, vertical: String) -> void:
	if signal_bulbs == null:
		return
	var colors := [Color("f34c41"), Color("ffbd3e"), Color("5eec78")]
	var names := ["red", "yellow", "green"]
	for i in range(12):
		var active := horizontal if i < 6 else vertical
		signal_bulbs.set_instance_color(i, colors[i % 3] if active == names[i % 3] else Color("253335"))

func civilian_vehicle(bus: bool, seed_value: int) -> void:
	var colors := [Color("76a5bc"), Color("d37952"), Color("e4dfc7"), Color("dfb458"), Color("839aa0")]
	var color: Color = Color("e4b455") if bus else colors[seed_value % colors.size()]
	if bus:
		Art.box(self, Vector3(0, 1.1, 0), Vector3(1.7, 1.7, 4.6), color)
		Art.box(self, Vector3(0, 1.9, 0), Vector3(1.74, 0.18, 4.65), Color("f1e9d3"))
		Art.box(self, Vector3(0, 1.45, 2.33), Vector3(1.5, 0.7, 0.04), Color("557d8a"))
		for x in [-0.86, 0.86]:
			for z in [-1.7, -0.8, 0.1, 1.0]:
				Art.box(self, Vector3(x, 1.45, z), Vector3(0.03, 0.65, 0.75), Color("557d8a"))
		Art.box(self, Vector3(-0.87, 0.85, 1.8), Vector3(0.03, 1.5, 0.55), Color("486d79"))
		Art.box(self, Vector3(0, 1.95, 0.4), Vector3(1.1, 0.22, 1.4), Color("d4d7ca"))
	else:
		Art.box(self, Vector3(0, 0.55, 0), Vector3(1.4, 0.6, 2.5), color)
		Art.box(self, Vector3(0, 1, -0.2), Vector3(1.25, 0.55, 1.35), color.lightened(0.1))
		Art.box(self, Vector3(0, 1.02, 0.5), Vector3(1.05, 0.37, 0.03), Color("aac4c5"))
	add_vehicle_lights(0.58 if bus else 0.48, 2.3 if bus else 1.22, 0.66 if bus else 0.62, -2.28 if bus else -1.22)
	for x in [-0.85 if bus else -0.73, 0.85 if bus else 0.73]:
		for z in [-1.5 if bus else -0.8, 1.5 if bus else 0.8]:
			var wheel := Art.cylinder(self, Vector3(x, 0.3, z), 0.3, 0.15, Color("3f4c4d"), 1, 10)
			wheel.rotation.z = PI / 2

func delivery_truck() -> void:
	# Closed cargo box is taller than the cab, with distinct roof and side panels.
	Art.box(self, Vector3(0, 0.62, -0.48), Vector3(1.62, 0.9, 2.65), Color("3f555a"))
	var cargo_box := Art.box(self, Vector3(0, 1.55, -0.55), Vector3(1.72, 1.75, 2.55), Color("d9e0d8"))
	cargo_box.set_meta("batch_feature", "DeliveryCargoBox")
	delivery_cargo_height = 1.75
	Art.box(self, Vector3(0, 2.44, -0.55), Vector3(1.76, 0.09, 2.60), Color("bcc9c5"))
	Art.box(self, Vector3(-0.87, 1.55, -0.55), Vector3(0.06, 1.62, 2.43), Color("bfcac4"))
	Art.box(self, Vector3(0.87, 1.55, -0.55), Vector3(0.06, 1.62, 2.43), Color("bfcac4"))
	Art.box(self, Vector3(0, 1.55, -1.84), Vector3(1.62, 1.62, 0.06), Color("aebcb7"))
	var cab := Art.box(self, Vector3(0, 1.02, 0.92), Vector3(1.48, 1.15, 1.0), Color("4a7c86"))
	cab.set_meta("batch_feature", "DeliveryCab")
	delivery_cab_height = 1.15
	Art.box(self, Vector3(0, 1.22, 1.46), Vector3(1.18, 0.62, 0.06), Color("9fc7ca"))
	add_vehicle_lights(0.52, 1.49, 0.72, -1.8)
	for x in [-0.78, 0.78]:
		for z in [-1.38, 1.12]:
			var wheel := Art.cylinder(self, Vector3(x, 0.34, z), 0.34, 0.18, Color("374345"), 1, 10)
			wheel.rotation.z = PI / 2

func bus_stop() -> void:
	# Парные платформы для обоих направлений, за пределами проезжей части.
	for side in [-1, 1]:
		var platform := Node3D.new()
		add_child(platform)
		platform.position.x = side * 2.48
		Art.box(platform, Vector3(0, 0.06, 0), Vector3(0.65, 0.12, 4.8), Color("e3d9be"))
		for z in [-1.6, 1.6]:
			Art.box(platform, Vector3(side * 0.15, 1.25, z), Vector3(0.08, 2.5, 0.08), Color("677f84"))
		Art.box(platform, Vector3(0, 2.5, 0), Vector3(0.9, 0.16, 4), Color("6c9ca8"))
		Art.box(platform, Vector3(0, 0.7, 0), Vector3(0.45, 0.12, 2.4), Color("ad9978"))
		Art.box(platform, Vector3(0, 2, 2.1), Vector3(0.65, 0.8, 0.12), Color("328cb8"))
