extends Node3D

const Art = preload("res://scripts/art.gd")
const TrafficSystem = preload("res://scripts/traffic_system.gd")
var traffic_controller: Node3D
var traffic: Array[Node3D] = []
var animation_time: float = 0
var street_lamp_positions: Array[Vector3] = []

static func world_position(point: Vector3) -> Vector3:
	var x := point.x * 2.4
	if point.x >= -9 and point.x <= -7:
		x = lerpf(-21.6, -14.4, (point.x + 9) / 2)
	elif point.x > -7 and point.x <= -3:
		x = lerpf(-14.4, -7.2, (point.x + 7) / 4)
	return Vector3(x, point.y, point.z * 4.8)

static func logical_position(point: Vector3) -> Vector3:
	var x := point.x / 2.4
	if point.x >= -21.6 and point.x <= -14.4:
		x = -9 + (point.x + 21.6) / 3.6
	elif point.x > -14.4 and point.x <= -7.2:
		x = -7 + (point.x + 14.4) / 1.8
	return Vector3(x, point.y, point.z / 4.8)

func build() -> void:
	Art.box(self, Vector3(0, -0.5, 0), Vector3(150, 0.9, 170), Color("8eaa69"))
	# Р’РѕРґР° Рё РЅР°Р±РµСЂРµР¶РЅР°СЏ РЅР° РїСЂР°РІРѕР№ РіСЂР°РЅРёС†Рµ СЂР°Р№РѕРЅР°.
	Art.box(self, Vector3(43, -0.8, 0), Vector3(17, 0.25, 160), Color("62a8c2"))
	Art.box(self, Vector3(34.5, -0.1, 0), Vector3(1, 1.3, 152), Color("b8b7a6"))
	Art.box(self, Vector3(33.2, 0.03, 0), Vector3(1.8, 0.15, 152), Color("d4cfb9"))
	for z in range(-72, 73, 3):
		Art.box(self, Vector3(34, 0.8, z), Vector3(0.12, 1.3, 0.12), Color("687776"))
	Art.box(self, Vector3(34, 1.3, 0), Vector3(0.09, 0.09, 148), Color("687776"))
	for z in [-43.2, -28.8, -14.4, 0, 14.4, 28.8, 43.2]:
		# Keep the legacy district on the same compact profile as expansion
		# streets: 2.8 m asphalt with two 0.9 m sidewalks.
		Art.box(self, Vector3(-17, 0.14, z), Vector3(98, 0.08, 2.8), Color("777d80"))
		for side in [-1.0, 1.0]:
			Art.box(self, Vector3(-17, 0.16, z + side * 1.85), Vector3(98, 0.1, 0.9), Color("b6b2a3"))
	for x in [-57.6, -43.2, -28.8, -14.4, 0, 14.4, 28.8]:
		Art.box(self, Vector3(x, 0.14, 0), Vector3(2.8, 0.08, 96), Color("777d80"))
		for side in [-1.0, 1.0]:
			Art.box(self, Vector3(x + side * 1.85, 0.16, 0), Vector3(0.9, 0.1, 96), Color("b6b2a3"))
	# Broken centre markings use the same short dashes as expansion roads.
	for z in [-43.2, -28.8, -14.4, 0, 14.4, 28.8, 43.2]:
		for x in [-50.4, -36.0, -21.6, -7.2, 7.2, 21.6]:
			Art.box(self, Vector3(x, 0.205, z), Vector3(0.62, 0.018, 0.055), Color("e4e1d0"))
	for x in [-57.6, -43.2, -28.8, -14.4, 0, 14.4, 28.8]:
		for z in [-36.0, -21.6, -7.2, 7.2, 21.6, 36.0]:
			Art.box(self, Vector3(x, 0.205, z), Vector3(0.055, 0.018, 0.62), Color("e4e1d0"))
	# Р Р°Р·РјРµС‚РєР° РЅРµ РїСЂРѕС…РѕРґРёС‚ С‡РµСЂРµР· РїРµСЂРµРєСЂС‘СЃС‚РєРё.
	for z in [-43.2, -28.8, -14.4, 0, 14.4, 28.8, 43.2]:
		for x in [-50.4, -36, -21.6, -7.2, 7.2, 21.6]:
			for dx in [-2.1, 0, 2.1]:
				Art.box(self, Vector3(x + dx, 0.2, z), Vector3(1.05, 0.012, 0.07), Color("d4d5c8"))
			var lamp_position := Vector3(x, 0, z + 2.5)
			street_lamp_positions.append(lamp_position)
			Art.lamp(self, lamp_position)
		for x in [-57.6, -43.2, -28.8, -14.4, 0, 14.4, 28.8]:
			for side in [-1, 1]:
				for i in range(6):
					Art.box(self, Vector3(x - 1.7 + i * 0.68, 0.21, z + side * 2.9), Vector3(0.32, 0.015, 0.8), Color("e4e1d0"))
					Art.box(self, Vector3(x + side * 2.9, 0.21, z - 1.7 + i * 0.68), Vector3(0.8, 0.015, 0.32), Color("e4e1d0"))
				Art.box(self, Vector3(x + side * 1.05, 0.21, z + side * 3.9), Vector3(1.95, 0.015, 0.13), Color("e4e1d0"))
				Art.box(self, Vector3(x - side * 3.9, 0.21, z + side * 1.05), Vector3(0.13, 0.015, 1.95), Color("e4e1d0"))
	for x in [-57.6, -43.2, -28.8, -14.4, 0, 14.4, 28.8]:
		for z in [-36, -21.6, -7.2, 7.2, 21.6, 36]:
			for dz in [-2, 0, 2]:
				Art.box(self, Vector3(x, 0.21, z + dz), Vector3(0.07, 0.012, 1), Color("d4d5c8"))
	# Р”Р°Р»СЊРЅРёР№ РїР»Р°РЅ Р·Р°СЃР°Р¶РµРЅ РґРµСЂРµРІСЊСЏРјРё, РіСЂР°РЅРёС†С‹ РєРІР°РґСЂР°С‚РЅРѕР№ РїР»Р°С‚С„РѕСЂРјС‹ РЅРµ РІРёРґРЅС‹.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1842
	for i in range(170):
		var x := rng.randf_range(-65, 32)
		var z := rng.randf_range(-78, 78)
		# Северная кромка отдана расширяемой сетке территории.
		if x >= -21.6 and x <= 26.4 and z >= 45.6 and z <= 88.8:
			continue
		if x > -64 and absf(z) < 49:
			continue
		Art.tree(self, Vector3(x, 0, z), rng.randf_range(1.1, 1.9), true, i)
	for z in range(-46, 47, 4):
		Art.tree(self, Vector3(31.5, 0, z), 0.9, false, z)
	# Р”РµРєРѕСЂР°С‚РёРІРЅС‹Р№ РѕР±С‰РµСЃС‚РІРµРЅРЅС‹Р№ СЃРєРІРµСЂ Р·Р° СЃРµРІРµСЂРЅРѕР№ РіСЂР°РЅРёС†РµР№ РёРіСЂРѕРІС‹С… СѓС‡Р°СЃС‚РєРѕРІ.
	for i in range(15):
		Art.tree(self, Vector3(-24 + (i % 5) * 7, 0, -52 - (i / 5) * 5), 1.2, false, i)
	Art.box(self, Vector3(-7, 0.04, -57), Vector3(30, 0.1, 1.2), Color("d7ccaa"))
	for x in [-19, -10, 0, 8]:
		Art.bench(self, Vector3(x, 0, -55))
	Art.batch(self)
	traffic_controller = TrafficSystem.new()
	add_child(traffic_controller)
	traffic_controller.build()
	traffic = traffic_controller.cars

func animate(time: float) -> void:
	var remaining := maxf(0, time - animation_time)
	animation_time = time
	while remaining > 0.00001:
		var delta := minf(0.05, remaining)
		traffic_controller.step(delta)
		remaining -= delta
