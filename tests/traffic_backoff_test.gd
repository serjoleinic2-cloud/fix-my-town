extends SceneTree

const Traffic = preload("res://scripts/traffic_system.gd")
const TerritoryGrid = preload("res://scripts/territory_grid.gd")

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func add_road(grid: RefCounted, cells: Array) -> void:
	for value in cells:
		var cell: Vector2i = value
		grid.cells[cell.y][cell.x] = "road"

func _initialize() -> void:
	call_deferred("run")

# Straight road with a crossing road behind the queue:
#   row 20, columns 20..34; crossing column 25, rows 16..24.
func build_layout() -> RefCounted:
	var grid := TerritoryGrid.new()
	grid.reset()
	var cells: Array = []
	for col in range(20, 35):
		cells.append(Vector2i(col, 20))
	for row in range(16, 25):
		cells.append(Vector2i(25, row))
	add_road(grid, cells)
	return grid

func place(traffic: Node3D, vehicle: Dictionary, cell: Vector2i, previous: Vector2i) -> void:
	vehicle.node.show()
	vehicle.cell = cell
	vehicle.previous = previous
	vehicle.axis = "H"
	vehicle.direction = 1
	var center: Vector3 = traffic.grid.cell_world(cell.x, cell.y)
	vehicle.road = center.z
	vehicle.target = traffic.grid_lane_position(center, "H", 1)
	vehicle.node.position = vehicle.target
	vehicle.coordinate = vehicle.node.position.x
	vehicle.erase("waiting_next")
	vehicle.erase("turn_exit_cell")
	vehicle.erase("waiting_on")
	vehicle.stalled_time = 0.0

func run() -> void:
	var traffic := Traffic.new()
	root.add_child(traffic)
	var grid := build_layout()
	traffic.configure_grid(grid, 4, false, [])
	for vehicle: Dictionary in traffic.vehicles:
		vehicle.node.hide()
		vehicle.speed_factor = 1.0
	# Three cars queue behind a fixed obstacle on cell 32; the crossing at cell 25 is behind them.
	var cars: Array[Dictionary] = []
	for index in [0, 1, 3]:
		cars.append(traffic.vehicles[index])
	place(traffic, cars[0], Vector2i(31, 20), Vector2i(30, 20))
	place(traffic, cars[1], Vector2i(29, 20), Vector2i(28, 20))
	place(traffic, cars[2], Vector2i(27, 20), Vector2i(26, 20))
	var obstacle_center: Vector3 = grid.cell_world(32, 20)
	traffic.blocking_positions = [{"id": "fixed_obstacle", "position": obstacle_center + Vector3(0, 0.2, 0), "half_extents": Vector2(1.4, 1.4)}]
	for _frame in range(120):
		traffic.step(0.1)
	var tail: Dictionary = cars[2]
	print("STATE ", cars.map(func(c): return [c.id, c.cell, c.node.position, c.get("waiting_reason", ""), c.get("waiting_on", ""), c.get("stalled_time", 0.0)]))
	check(float(tail.get("stalled_time", 0.0)) > 2.0, "The queued tail car is stationary")
	check(traffic.manual_backoff_available(str(tail.id)), "The tail of an ordinary queue can be told to reverse")
	check(not traffic.manual_backoff_available(str(cars[1].id)), "A car with another car queued behind it cannot reverse")
	check(not traffic.manual_backoff_available(str(cars[0].id)), "The head of the queue cannot reverse")
	var tap_cell: Vector2i = tail.cell
	var requested: bool = traffic.request_manual_backoff(str(tail.id))
	check(requested, "Backing off the tail is accepted")
	var visited_junction := false
	var returned_to_tap := false
	for _frame in range(900):
		traffic.step(0.1)
		var current_cell: Vector2i = tail.get("cell", Vector2i(-1, -1))
		if current_cell.x == 25:
			visited_junction = true
		if _frame > 50 and current_cell == tap_cell:
			returned_to_tap = true
	print("TAIL after reverse ", tail.cell, " ", tail.node.position, " axis=", tail.axis, " dir=", tail.direction)
	check(visited_junction, "The tail reverses to the free junction behind it")
	check(not returned_to_tap, "The reversed car never returns to the tapped cell")
	print("TRAFFIC BACKOFF CHECKS: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
