extends RefCounted

const Catalog = preload("res://scripts/asset_catalog.gd")

const WIDTH: int = 96
const HEIGHT: int = 96
const CELL_SIZE: float = 4.8
const ORIGIN := Vector3(-57.6, 0, -43.2) # world-space centre of cell (0, 0)
const EXPANSION_COLS := Vector2i(8, 17)
const EXPANSION_ROWS := Vector2i(19, 27)
const DISTRICT_ID := "pine_district"
const CITY_HALL_TYPE := "city_hall"
const CITY_HALL_SITE := Vector2i(12, 19)
const BUILDINGS = ["city_hall", "house", "cafe", "park", "depot", "fire_station", "police_station", "hospital", "elite_residence", "business_tower", "lawn", "flower_bed", "street_tree", "bush"]
var cells: Array = []
var buildings: Array = []
var revealed: Array = []
var expansion_cols: Vector2i = EXPANSION_COLS
var expansion_rows: Vector2i = EXPANSION_ROWS

func _init() -> void:
	reset()

func reset() -> void:
	expansion_cols = EXPANSION_COLS
	expansion_rows = EXPANSION_ROWS
	cells.clear()
	revealed.clear()
	for row in range(HEIGHT):
		var line: Array = []
		line.resize(WIDTH)
		line.fill("forest")
		cells.append(line)
		var visibility_line: Array = []
		visibility_line.resize(WIDTH)
		visibility_line.fill(true)
		revealed.append(visibility_line)
	buildings.clear()

func initialize_legacy_road_network() -> void:
	# Used by the old-save loader and explicit test fixtures only.
	for row in range(HEIGHT):
		for col in range(WIDTH):
			if (row <= 18 and row % 3 == 0) or (col <= 18 and col % 3 == 0 and row <= 18):
				cells[row][col] = "road"

func initialize_natural_terrain(start_col: int = 12, start_row: int = 20, visible_radius: int = 3) -> void:
	# A new city starts as uninterrupted forest. Legacy roads belong to the old
	# showcase layout and must never leak into a clean sandbox.
	reset()
	for row in range(HEIGHT):
		for col in range(WIDTH):
			cells[row][col] = "forest"
	reset_visibility()
	reveal_area(start_col, start_row, visible_radius)

func set_expansion_level(level: int) -> void:
	# Reveal new land as a frontier around the town centre and connected roads;
	# city level increases the reach without revealing an arbitrary rectangle.
	var radius := 3 + maxi(0, level - 1) * 3
	for entry: Dictionary in buildings:
		if entry.type_id == CITY_HALL_TYPE:
			reveal_area(entry.col, entry.row, radius + 1)
	for row in range(HEIGHT):
		for col in range(WIDTH):
			if cells[row][col] == "road" and connected_road(col, row):
				reveal_area(col, row, maxi(1, radius - 2))
	# Kept as compatibility metadata for old UI/save consumers only.
	var growth := maxi(0, level - 1) * 6
	expansion_cols = Vector2i(maxi(1, EXPANSION_COLS.x - growth), mini(WIDTH - 2, EXPANSION_COLS.y + growth))
	expansion_rows = Vector2i(maxi(1, EXPANSION_ROWS.x - growth), mini(HEIGHT - 2, EXPANSION_ROWS.y + growth))

func migrate_legacy(legacy_buildings: Array) -> void:
	for index in range(24):
		var kind: String = legacy_buildings[index]
		var logical := Vector3(-9 + (index % 4) * 6, 0, -7.5 + int(index / 4) * 3)
		var world := Vector3(logical.x * 2.4, 0, logical.z * 4.8)
		var col := floori((world.x - ORIGIN.x) / CELL_SIZE)
		var row := floori((world.z - ORIGIN.z) / CELL_SIZE)
		var cells_to_mark := "free" if kind == "empty" else "occupied"
		for dy in range(2):
			for dx in range(2):
				if in_bounds(col + dx, row + dy) and cells[row + dy][col + dx] != "road":
					cells[row + dy][col + dx] = cells_to_mark
		if kind != "empty":
			buildings.append({"type_id": kind, "instance_id": "pine_district_legacy_%d" % index, "col": col, "row": row, "width": 2, "height": 2, "legacy_plot": index})
			reveal_area(col, row, 3)

func reset_visibility() -> void:
	revealed.clear()
	for row in range(HEIGHT):
		var line: Array = []
		line.resize(WIDTH)
		line.fill(false)
		revealed.append(line)

func reveal_area(col: int, row: int, radius: int = 3) -> void:
	if revealed.size() != HEIGHT:
		reset_visibility()
	for current_row in range(row - radius, row + radius + 1):
		for current_col in range(col - radius, col + radius + 1):
			if in_bounds(current_col, current_row) and max(abs(current_col - col), abs(current_row - row)) <= radius:
				revealed[current_row][current_col] = true

func is_revealed(col: int, row: int) -> bool:
	return in_bounds(col, row) and revealed.size() == HEIGHT and bool(revealed[row][col])

func in_bounds(col: int, row: int) -> bool:
	return col >= 0 and col < WIDTH and row >= 0 and row < HEIGHT

func sync_legacy(legacy_buildings: Array) -> void:
	# Снос/застройка старого квартала должны обновлять и новую сетку.
	if legacy_buildings.size() != 24:
		return
	for building in buildings:
		if not building.has("legacy_plot"):
			continue
		for dy in range(2):
			for dx in range(2):
				var col: int = building.col + dx
				var row: int = building.row + dy
				if in_bounds(col, row) and cells[row][col] == "occupied":
					cells[row][col] = "free"
	buildings = buildings.filter(func(entry): return not entry.has("legacy_plot"))
	migrate_legacy(legacy_buildings)

func cell_world(col: int, row: int) -> Vector3:
	return ORIGIN + Vector3(col * CELL_SIZE, 0, row * CELL_SIZE)

func state_at(col: int, row: int) -> String:
	return cells[row][col] if in_bounds(col, row) else "outside"

func clear_cell(col: int, row: int) -> bool:
	if not in_bounds(col, row) or cells[row][col] != "forest":
		return false
	cells[row][col] = "free"
	reveal_area(col, row, 1)
	return true

func connected_road(col: int, row: int) -> bool:
	if not in_bounds(col, row) or cells[row][col] != "road":
		return false
	var queue: Array[Vector2i] = [Vector2i(col, row)]
	var visited: Dictionary = {Vector2i(col, row): true}
	var reaches_city := row <= 18 and ((row % 3 == 0) or (col <= 18 and col % 3 == 0))
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if current.y == 18 and current.x >= 0 and current.x < WIDTH or is_city_hall_access_cell(current):
			reaches_city = true
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = current + offset
			if in_bounds(next.x, next.y) and cells[next.y][next.x] == "road" and not visited.has(next):
				visited[next] = true
				queue.append(next)
	return reaches_city

func is_city_hall_access_cell(cell: Vector2i) -> bool:
	for entry: Dictionary in buildings:
		if entry.type_id != CITY_HALL_TYPE:
			continue
		var inside_x: bool = cell.x >= int(entry.col) and cell.x < int(entry.col) + int(entry.width)
		var inside_y: bool = cell.y >= int(entry.row) and cell.y < int(entry.row) + int(entry.height)
		if (inside_x and cell.y in [entry.row - 1, entry.row + entry.height]) or (inside_y and cell.x in [entry.col - 1, entry.col + entry.width]):
			return true
	return false

func road_orientation(col: int, row: int) -> String:
	# Остановка ориентируется вдоль оси улицы. На узлах выбираем ось с
	# горизонтальным продолжением, чтобы модель не вставала поперёк проезжей части.
	if state_at(col, row) != "road":
		return ""
	var links: Array[Vector2i] = []
	for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if state_at(col + offset.x, row + offset.y) == "road":
			links.append(offset)
	var has_horizontal := Vector2i.LEFT in links or Vector2i.RIGHT in links
	var has_vertical := Vector2i.UP in links or Vector2i.DOWN in links
	if has_horizontal:
		return "horizontal"
	if has_vertical:
		return "vertical"
	return ""

func place_road(col: int, row: int) -> bool:
	if not in_bounds(col, row) or cells[row][col] != "free":
		return false
	var adjacent := false
	for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var next: Vector2i = Vector2i(col, row) + offset
		if in_bounds(next.x, next.y) and cells[next.y][next.x] == "road" and connected_road(next.x, next.y):
			adjacent = true
	if not adjacent:
		return false
	cells[row][col] = "road"
	reveal_area(col, row, 1)
	return true

func build_house(col: int, row: int) -> bool:
	return place_building(col, row, "house")

func place_building(col: int, row: int, type_id: String) -> bool:
	if type_id not in BUILDINGS:
		return false
	if type_id == CITY_HALL_TYPE:
		for existing: Dictionary in buildings:
			if existing.type_id == CITY_HALL_TYPE:
				return false
		if Vector2i(col, row) != CITY_HALL_SITE:
			return false
	var footprint: Vector2i = Catalog.footprint_cells(type_id)
	if not in_bounds(col, row) or not in_bounds(col + footprint.x - 1, row + footprint.y - 1):
		return false
	var has_access := false
	for dy in range(footprint.y):
		for dx in range(footprint.x):
			if cells[row + dy][col + dx] != "free":
				return false
			for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var next: Vector2i = Vector2i(col + dx, row + dy) + offset
				if in_bounds(next.x, next.y) and cells[next.y][next.x] == "road" and connected_road(next.x, next.y):
					has_access = true
	if type_id not in ["lawn", "flower_bed", "street_tree", "bush"]:
		var entry_for_access := {"col": col, "row": row, "width": footprint.x, "height": footprint.y}
		var automatic_path := auto_access_path(entry_for_access)
		if not has_constructed_network():
			automatic_path = building_contour(entry_for_access)
		elif not has_access and automatic_path.is_empty():
			return false
		for path_cell: Vector2i in automatic_path:
			if state_at(path_cell.x, path_cell.y) in ["free", "forest"]:
				cells[path_cell.y][path_cell.x] = "road"
		# Every new building gets a continuous one-cell road contour. Free ground
		# and forest are converted as part of construction; existing roads join
		# the contour, while occupied building cells remain untouched.
		for contour_cell: Vector2i in building_contour(entry_for_access):
			if state_at(contour_cell.x, contour_cell.y) in ["free", "forest"]:
				cells[contour_cell.y][contour_cell.x] = "road"
	for dy in range(footprint.y):
		for dx in range(footprint.x):
			cells[row + dy][col + dx] = "occupied"
	var prefix := "pine_district_%s" % type_id
	var entry := {"type_id": type_id, "instance_id": "%s_%d_%d" % [prefix, col, row], "col": col, "row": row, "width": footprint.x, "height": footprint.y, "level": 1, "inspected": false}
	if type_id in ["depot", "fire_station", "police_station", "hospital"]:
		entry.service_building = true
	buildings.append(entry)
	reveal_area(col, row, 3)
	return true

func path_to_city(col: int, row: int) -> Array[Vector2i]:
	var start: Vector2i = Vector2i(col, row)
	if not connected_road(col, row):
		return []
	var queue: Array[Vector2i] = [start]
	var previous: Dictionary = {start: Vector2i(-1, -1)}
	var goal: Vector2i = Vector2i(-1, -1)
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if current.y == 18 or is_city_hall_access_cell(current):
			goal = current
			break
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = current + offset
			if in_bounds(next.x, next.y) and cells[next.y][next.x] == "road" and not previous.has(next):
				previous[next] = current
				queue.append(next)
	if goal.x < 0:
		return []
	var path: Array[Vector2i] = []
	var cursor := goal
	while cursor.x >= 0:
		path.push_front(cursor)
		cursor = previous[cursor]
	return path

func building_by_id(identifier: String) -> Dictionary:
	for entry: Dictionary in buildings:
		if entry.instance_id == identifier:
			return entry
	return {}

func building_center(entry: Dictionary) -> Vector3:
	return cell_world(entry.col, entry.row) + Vector3((entry.width - 1) * CELL_SIZE / 2, 0, (entry.height - 1) * CELL_SIZE / 2)

func building_at(col: int, row: int) -> Dictionary:
	for entry: Dictionary in buildings:
		if col >= entry.col and col < entry.col + entry.width and row >= entry.row and row < entry.row + entry.height:
			return entry
	return {}

func road_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	if state_at(start.x, start.y) != "road" or state_at(goal.x, goal.y) != "road":
		return []
	var queue: Array[Vector2i] = [start]
	var previous: Dictionary = {start: Vector2i(-1, -1)}
	var cursor := 0
	while cursor < queue.size():
		var current := queue[cursor]
		cursor += 1
		if current == goal:
			var result: Array[Vector2i] = []
			while current.x >= 0:
				result.push_front(current)
				current = previous[current]
			return result
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := current + offset
			if state_at(next.x, next.y) == "road" and not previous.has(next):
				previous[next] = current
				queue.append(next)
	return []

func nearest_road(point: Vector3) -> Vector2i:
	var nearest := Vector2i(-1, -1)
	var best := INF
	for row in range(HEIGHT):
		for col in range(WIDTH):
			if cells[row][col] == "road":
				var distance := cell_world(col, row).distance_squared_to(point)
				if distance < best:
					best = distance
					nearest = Vector2i(col, row)
	return nearest

func access_path(entry: Dictionary, start: Vector2i) -> Array[Vector2i]:
	var best: Array[Vector2i] = []
	for dy in range(entry.height):
		for dx in range(entry.width):
			for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var edge := Vector2i(entry.col + dx, entry.row + dy) + offset
				if state_at(edge.x, edge.y) != "road":
					continue
				var path := road_path(start, edge)
				if not path.is_empty() and (best.is_empty() or path.size() < best.size()):
					best = path
	return best

func has_constructed_network() -> bool:
	for row in cells:
		for state in row:
			if state == "road":
				return true
	for entry: Dictionary in buildings:
		if entry.type_id not in ["lawn", "flower_bed", "street_tree", "bush"]:
			return true
	return false

func building_contour(entry: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for row in range(entry.row - 1, entry.row + entry.height + 1):
		for col in range(entry.col - 1, entry.col + entry.width + 1):
			var inside: bool = col >= entry.col and col < entry.col + entry.width and row >= entry.row and row < entry.row + entry.height
			if inside or not in_bounds(col, row) or state_at(col, row) not in ["free", "forest"]:
				continue
			result.append(Vector2i(col, row))
	return result

func auto_access_path(entry: Dictionary) -> Array[Vector2i]:
	# Find a short cleared corridor from the building edge to the existing
	# connected network. The corridor becomes the building's automatic road
	# contour when placement is confirmed.
	var queue: Array[Vector2i] = []
	var previous: Dictionary = {}
	for dy in range(entry.height):
		for dx in range(entry.width):
			for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var edge := Vector2i(entry.col + dx, entry.row + dy) + offset
				var inside: bool = edge.x >= entry.col and edge.x < entry.col + entry.width and edge.y >= entry.row and edge.y < entry.row + entry.height
				if inside or not in_bounds(edge.x, edge.y):
					continue
				if state_at(edge.x, edge.y) == "road" and connected_road(edge.x, edge.y):
					return [edge]
				if state_at(edge.x, edge.y) == "free" and not previous.has(edge):
					queue.append(edge)
					previous[edge] = Vector2i(-1, -1)
	var cursor := 0
	while cursor < queue.size():
		var current := queue[cursor]
		cursor += 1
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := current + offset
			if not in_bounds(next.x, next.y) or previous.has(next):
				continue
			if state_at(next.x, next.y) == "road" and connected_road(next.x, next.y):
				var path: Array[Vector2i] = [current]
				var step := current
				while previous[step].x >= 0:
					step = previous[step]
					path.push_front(step)
				return path
			if state_at(next.x, next.y) == "free":
				previous[next] = current
				queue.append(next)
	return []

func placement_reason(col: int, row: int, tool: String) -> String:
	var footprint := Vector2i.ONE if tool in ["clear", "road", "landscaping"] else Catalog.footprint_cells(tool)
	if not in_bounds(col, row) or col + footprint.x > WIDTH or row + footprint.y > HEIGHT:
		return "outside"
	for dy in range(footprint.y):
		for dx in range(footprint.x):
			if not is_revealed(col + dx, row + dy):
				return "outside"
	if tool == "clear":
		return "" if state_at(col, row) == "forest" else "not_forest"
	for dy in range(footprint.y):
		for dx in range(footprint.x):
			if state_at(col + dx, row + dy) != "free":
				return "clear_first"
	if tool in ["landscaping", "lawn", "flower_bed", "street_tree", "bush"]:
		return ""
	var entry := {"col": col, "row": row, "width": footprint.x, "height": footprint.y}
	if not has_constructed_network():
		return "" if not building_contour(entry).is_empty() else "no_road"
	return "" if not auto_access_path(entry).is_empty() else "no_road"

func can_remove_road(col: int, row: int, transit: RefCounted = null) -> bool:
	if state_at(col, row) != "road":
		return false
	if transit != null:
		for stop in transit.stops:
			if transit.stop_cell(stop, self) == Vector2i(col, row):
				return false
	cells[row][col] = "free"
	var connected := true
	for entry: Dictionary in buildings:
		if entry.type_id in ["lawn", "flower_bed", "street_tree", "bush"]:
			continue
		if access_path(entry, Vector2i(12, 18)).is_empty():
			connected = false
			break
	cells[row][col] = "road"
	return connected

func data() -> Dictionary:
	return {"district_id": DISTRICT_ID, "width": WIDTH, "height": HEIGHT, "cells": cells.duplicate(true), "buildings": buildings.duplicate(true), "revealed": revealed.duplicate(true), "expansion_cols": [expansion_cols.x, expansion_cols.y], "expansion_rows": [expansion_rows.x, expansion_rows.y]}

func restore(value: Variant) -> bool:
	if not value is Dictionary or value.get("district_id", DISTRICT_ID) != DISTRICT_ID:
		return false
	var saved_width := int(value.get("width", 0))
	var saved_height := int(value.get("height", 0))
	# Upgrade saves from the original 28x30 prototype into the larger hidden
	# world without moving their buildings or roads.
	if saved_width == 28 and saved_height == 30 and value.get("cells") is Array:
		var old_cells: Array = value.get("cells")
		if old_cells.size() != saved_height:
			return false
		reset()
		for row in range(HEIGHT):
			cells[row].fill("forest")
		for row in range(saved_height):
			if not old_cells[row] is Array or old_cells[row].size() != saved_width:
				return false
			for col in range(saved_width):
				if old_cells[row][col] not in ["forest", "free", "road", "occupied"]:
					return false
				cells[row][col] = old_cells[row][col]
		value = value.duplicate(true)
		value["width"] = WIDTH
		value["height"] = HEIGHT
		value["cells"] = cells.duplicate(true)
		value["revealed"] = revealed.duplicate(true)
	elif saved_width != WIDTH or saved_height != HEIGHT:
		return false
	var new_cells: Variant = value.get("cells")
	var new_buildings: Variant = value.get("buildings")
	var new_revealed: Variant = value.get("revealed", null)
	if not new_cells is Array or new_cells.size() != HEIGHT or not new_buildings is Array:
		return false
	for row in new_cells:
		if not row is Array or row.size() != WIDTH:
			return false
		for state in row:
			if state not in ["forest", "free", "road", "occupied"]:
				return false
	var identifiers: Dictionary = {}
	for building in new_buildings:
		if not building is Dictionary or building.get("type_id") not in BUILDINGS or str(building.get("instance_id", "")) == "" or int(building.get("col", -1)) < 0 or int(building.get("row", -1)) < 0:
			return false
		var expected_footprint := Vector2i.ONE if building.type_id in ["lawn", "flower_bed", "street_tree", "bush"] else Vector2i(2, 2)
		if int(building.get("width", 0)) != expected_footprint.x or int(building.get("height", 0)) != expected_footprint.y or int(building.col) + expected_footprint.x > WIDTH or int(building.row) + expected_footprint.y > HEIGHT:
			return false
		var identifier: String = building.instance_id
		var level_value: Variant = building.get("level", 1)
		if not (level_value is int or level_value is float) or not is_finite(float(level_value)) or level_value != int(level_value) or level_value < 1 or level_value > 3:
			return false
		if typeof(building.get("inspected", false)) != TYPE_BOOL:
			return false
		if identifiers.has(identifier):
			return false
		identifiers[identifier] = true
		for dy in range(expected_footprint.y):
			for dx in range(expected_footprint.x):
				if new_cells[building.row + dy][building.col + dx] != "occupied":
					return false
	cells = new_cells.duplicate(true)
	buildings = new_buildings.duplicate(true)
	if new_revealed is Array and new_revealed.size() == HEIGHT and new_revealed.all(func(line): return line is Array and line.size() == WIDTH):
		revealed = new_revealed.duplicate(true)
	else:
		revealed.clear()
		for row in range(HEIGHT):
			var visibility_line: Array = []
			visibility_line.resize(WIDTH)
			visibility_line.fill(true)
			revealed.append(visibility_line)
	var saved_cols: Variant = value.get("expansion_cols", null)
	var saved_rows: Variant = value.get("expansion_rows", null)
	if saved_cols is Array and saved_cols.size() == 2 and saved_rows is Array and saved_rows.size() == 2:
		if int(saved_cols[0]) >= 0 and int(saved_cols[1]) < WIDTH and int(saved_cols[0]) <= int(saved_cols[1]) and int(saved_rows[0]) >= 0 and int(saved_rows[1]) < HEIGHT and int(saved_rows[0]) <= int(saved_rows[1]):
			expansion_cols = Vector2i(int(saved_cols[0]), int(saved_cols[1]))
			expansion_rows = Vector2i(int(saved_rows[0]), int(saved_rows[1]))
	return true
