extends Node3D

const Art = preload("res://scripts/art.gd")
@export var visual_type: String = "house"
@export var alternate: bool = false
@export_range(1, 3) var visual_level: int = 1
var windows: Array[MeshInstance3D] = []
var signs: Array[Label3D] = []
var fountain_sprites: Array[Sprite3D] = []
var fountain_clock: float = 0

func _ready() -> void:
	var seed_value := absi(str(get_parent().get_parent().get("instance_id")).hash())
	if visual_type == "house":
		house(seed_value)
		rotation.y = (seed_value % 4) * PI / 2
	elif visual_type == "cafe":
		cafe()
	elif visual_type == "depot":
		depot()
	elif visual_type == "park":
		park()
	elif visual_type == "empty":
		for i in range(3):
			Art.hedge(self, Vector3(-3 + i * 2.5, 0.24, -3.6), Vector3(0.7, 0.45, 0.55))
	elif visual_type == "repair_van":
		van()
	elif visual_type == "traffic_signal":
		make_signals()
	elif visual_type == "bus_stop":
		bus_stop()
	elif visual_type in ["civilian_car", "city_bus"]:
		civilian_vehicle(visual_type == "city_bus", seed_value)
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

func _process(delta: float) -> void:
	fountain_clock += delta
	for i in range(fountain_sprites.size()):
		var sprite := fountain_sprites[i]
		var phase := fountain_clock * 5.0 + float(i) * 2.1
		sprite.position.y = 0.82 + sin(phase) * 0.12
		sprite.scale.y = 0.92 + sin(phase + 0.7) * 0.12
		sprite.modulate.a = 0.76 + sin(phase + 1.4) * 0.12

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
	signs.append(Art.sign_text(self, Vector3(0, 3.8, 1.34), "КАФЕ", 46))
	for x in [-1.7, 1.7]:
		Art.cylinder(self, Vector3(x, 0.6, 3.1), 0.07, 1.1, Color("726956"))
		Art.cylinder(self, Vector3(x, 1.2, 3.1), 0.67, 0.13, Color("f2eedc"))
		for dx in [-0.95, 0.95]:
			Art.box(self, Vector3(x + dx, 0.55, 3.1), Vector3(0.5, 0.1, 0.5), Color("927e60"))
			Art.box(self, Vector3(x + dx, 0.85, 3.35), Vector3(0.5, 0.6, 0.08), Color("927e60"))
		Art.cylinder(self, Vector3(x * 1.65, 0.4, 1.5), 0.3, 0.7, Color("a58b66"), 1.2)
		Art.tree(self, Vector3(x * 1.65, 0.4, 1.5), 0.35, false, 1)

func depot() -> void:
	Art.box(self, Vector3(0, 1.8, -0.6), Vector3(6.5, 3.6, 4.3), Color("c58f72"))
	Art.box(self, Vector3(0, 3.7, -0.6), Vector3(6.8, 0.3, 4.6), Color("999a88"))
	for x in [-1.6, 1.6]:
		Art.box(self, Vector3(x, 1.3, 1.6), Vector3(2.45, 2.65, 0.08), Color("56666a"))
		for y in [0.3, 0.7, 1.1, 1.5, 1.9, 2.3]:
			Art.box(self, Vector3(x, y, 1.66), Vector3(2.4, 0.04, 0.04), Color("758483"))
	Art.box(self, Vector3(0, 3.25, 1.68), Vector3(6.2, 0.8, 0.12), Color("9c5d49"))
	signs.append(Art.sign_text(self, Vector3(0, 3.3, 1.79), "СЛУЖБЫ", 42))
	for x in [-2.8, 0, 2.8]:
		Art.box(self, Vector3(x, 0.03, 3), Vector3(0.06, 0.025, 2.2), Color("e5dfc9"))
	Art.box(self, Vector3(2.3, 5, -1.5), Vector3(1.3, 3.3, 1.5), Color("b7896e"))
	Art.box(self, Vector3(2.3, 6.7, -1.5), Vector3(1.6, 0.2, 1.8), Color("e3d0ae"))

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
	Art.cylinder(self, Vector3(0, 0.52, 0), 1.4, 0.04, Color("7ab7c7"), 1, 20)
	make_fountain_sprites()
	for x in [-3, 3]:
		for z in [-3, 3]:
			if visual_level < 3 or x != 3 or z != -3:
				Art.tree(self, Vector3(x, 0, z), 1.0, false, int(x + z))
	for i in range(2):
		var x := -1.4 if i == 0 else 1.4
		var bench := Art.bench(self, Vector3(x, 0, 2.7), 0, 0.7)
		bench.name = "ParkBench%d" % i

func make_fountain_sprites() -> void:
	var image := Image.create(48, 96, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in range(7, 87):
		var progress := float(y - 7) / 80.0
		var center := 24.0 + sin(progress * PI * 1.4) * 5.0
		var half_width := maxf(1.0, 4.0 * (1.0 - progress * 0.72))
		for x in range(48):
			var distance := absf(float(x) - center)
			if distance <= half_width:
				var alpha := 0.88 if distance < half_width * 0.55 else 0.56
				image.set_pixel(x, y, Color(0.48, 0.83, 0.96, alpha))
	for point in [Vector2i(12, 32), Vector2i(35, 46), Vector2i(10, 58), Vector2i(38, 68), Vector2i(16, 76)]:
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				if dx * dx + dy * dy <= 4:
					image.set_pixel(point.x + dx, point.y + dy, Color(0.75, 0.94, 1.0, 0.9))
	var texture := ImageTexture.create_from_image(image)
	for i in range(3):
		var sprite := Sprite3D.new()
		sprite.name = "FountainWater%d" % i
		sprite.texture = texture
		sprite.pixel_size = 0.014
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.position = Vector3((i - 1) * 0.38, 0.82, 0)
		sprite.scale = Vector3(0.8 if i != 1 else 1.0, 0.9 + i * 0.06, 1)
		sprite.shaded = false
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		add_child(sprite)
		fountain_sprites.append(sprite)

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
	Art.cylinder(self, Vector3(0, 1.68, 0.7), 0.15, 0.24, Color("efb545"), 1, 10)

func set_serviced(value: bool) -> void:
	for item: MeshInstance3D in windows:
		item.material_override = Art.material(Color("7fbbb4") if value else Color("6a8790")) if visual_type != "traffic_signal" else Art.material(Color("6bad67") if value else Color("ef9b43"))

func set_language(language: String) -> void:
	for sign: Label3D in signs:
		sign.text = ("КАФЕ" if language == "ru" else "CAFE") if visual_type == "cafe" else ("СЛУЖБЫ" if language == "ru" else "SERVICE")

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
	for x in [-0.85 if bus else -0.73, 0.85 if bus else 0.73]:
		for z in [-1.5 if bus else -0.8, 1.5 if bus else 0.8]:
			var wheel := Art.cylinder(self, Vector3(x, 0.3, z), 0.3, 0.15, Color("3f4c4d"), 1, 10)
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
		Art.sign_text(platform, Vector3(0, 2, 2.18), "BUS", 30)
