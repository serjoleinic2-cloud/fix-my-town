extends RefCounted

const WIDTH: int = 28
const HEIGHT: int = 30
const CELL_SIZE: float = 4.8
const ORIGIN := Vector3(-57.6, 0, -43.2) # world-space centre of cell (0, 0)
const EXPANSION_COLS := Vector2i(8, 17)
const EXPANSION_ROWS := Vector2i(19, 27)
const DISTRICT_ID := "pine_district"
const BUILDINGS = ["house", "cafe", "park", "depot"]
var cells: Array = []
var buildings: Array = []

func _init(legacy_buildings: Array = []) -> void:
	reset()
	if legacy_buildings.size() == 24:
		migrate_legacy(legacy_buildings)

func reset() -> void:
	cells.clear()
	for row in range(HEIGHT):
		var line: Array = []
		line.resize(WIDTH)
		line.fill("forest")
		cells.append(line)
	buildings.clear()
	# The existing district is a connected orthogonal road grid.
	for row in range(HEIGHT):
		for col in range(WIDTH):
			if (row <= 18 and row % 3 == 0) or (col <= 18 and col % 3 == 0 and row <= 18):
				cells[row][col] = "road"

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
	return true

func connected_road(col: int, row: int) -> bool:
	if not in_bounds(col, row) or cells[row][col] != "road":
		return false
	var queue: Array[Vector2i] = [Vector2i(col, row)]
	var visited: Dictionary = {Vector2i(col, row): true}
	var reaches_city := row <= 18 and ((row % 3 == 0) or (col <= 18 and col % 3 == 0))
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if current.y == 18 and current.x >= 0 and current.x < WIDTH:
			reaches_city = true
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = current + offset
			if in_bounds(next.x, next.y) and cells[next.y][next.x] == "road" and not visited.has(next):
				visited[next] = true
				queue.append(next)
	return reaches_city

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
	return true

func build_house(col: int, row: int) -> bool:
	if not in_bounds(col, row) or not in_bounds(col + 1, row + 1):
		return false
	var has_access := false
	for dy in range(2):
		for dx in range(2):
			if cells[row + dy][col + dx] != "free":
				return false
			for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var next: Vector2i = Vector2i(col + dx, row + dy) + offset
				if in_bounds(next.x, next.y) and cells[next.y][next.x] == "road" and connected_road(next.x, next.y):
					has_access = true
	if not has_access:
		return false
	for dy in range(2):
		for dx in range(2):
			cells[row + dy][col + dx] = "occupied"
	buildings.append({"type_id": "house", "instance_id": "pine_district_house_%d_%d" % [col, row], "col": col, "row": row, "width": 2, "height": 2, "level": 1, "inspected": false})
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
		if current.y == 18:
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

func placement_reason(col: int, row: int, tool: String) -> String:
	var footprint := 2 if tool == "house" else 1
	if col < EXPANSION_COLS.x or col + footprint - 1 > EXPANSION_COLS.y or row < EXPANSION_ROWS.x or row + footprint - 1 > EXPANSION_ROWS.y:
		return "outside"
	if tool == "clear":
		return "" if state_at(col, row) == "forest" else "not_forest"
	for dy in range(footprint):
		for dx in range(footprint):
			if state_at(col + dx, row + dy) != "free":
				return "clear_first"
	var entry := {"col": col, "row": row, "width": footprint, "height": footprint}
	return "" if not access_path(entry, Vector2i(12, 18)).is_empty() else "no_road"

func data() -> Dictionary:
	return {"district_id": DISTRICT_ID, "width": WIDTH, "height": HEIGHT, "cells": cells.duplicate(true), "buildings": buildings.duplicate(true)}

func restore(value: Variant) -> bool:
	if not value is Dictionary or value.get("district_id", DISTRICT_ID) != DISTRICT_ID or int(value.get("width", 0)) != WIDTH or int(value.get("height", 0)) != HEIGHT:
		return false
	var new_cells: Variant = value.get("cells")
	var new_buildings: Variant = value.get("buildings")
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
		if not building is Dictionary or building.get("type_id") not in BUILDINGS or str(building.get("instance_id", "")) == "" or int(building.get("col", -1)) < 0 or int(building.get("row", -1)) < 0 or int(building.get("width", 0)) != 2 or int(building.get("height", 0)) != 2 or int(building.get("col", -1)) + 2 > WIDTH or int(building.get("row", -1)) + 2 > HEIGHT:
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
		for dy in range(2):
			for dx in range(2):
				if new_cells[building.row + dy][building.col + dx] != "occupied":
					return false
	cells = new_cells.duplicate(true)
	buildings = new_buildings.duplicate(true)
	return true
