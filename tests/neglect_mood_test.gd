extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")

var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := Simulation.new(false)
	check(is_equal_approx(game.neglect_after(10.0, 80, 50, 1, false), 7.0), "Good quality and average mood relax 3 per minute")
	check(is_equal_approx(game.neglect_after(10.0, 80, 80, 1, false), 5.5), "Happy residents recover faster")
	check(is_equal_approx(game.neglect_after(10.0, 80, 20, 1, false), 8.5), "Unhappy residents recover slower")
	check(is_equal_approx(game.neglect_after(10.0, 60, 50, 1, false), 9.0) and is_equal_approx(game.neglect_after(10.0, 60, 80, 1, false), 8.0), "Mid quality: happier homes heal faster")
	check(is_equal_approx(game.neglect_after(0.0, 60, 20, 3, false), 3.0), "Mid quality with unhappy residents decays 1 per minute")
	check(is_equal_approx(game.neglect_after(19.0, 60, 20, 5, false), 20.0), "Mood decay stops at the 20 percent warning line")
	check(is_equal_approx(game.neglect_after(0.0, 40, 50, 1, false), 4.0) and is_equal_approx(game.neglect_after(0.0, 40, 20, 1, false), 6.0), "Poor quality decays faster when residents are unhappy")
	check(is_equal_approx(game.neglect_after(20.0, 40, 20, 3, true), 20.0), "An open maintenance problem freezes the meter")
	check(is_equal_approx(game.neglect_after(50.0, 40, 50, 1, false), 20.0), "The meter never jumps past the warning line without a crew")
	if failures.is_empty():
		print("NEGLECT MOOD CHECKS: PASS")
		quit(0)
	else:
		print("NEGLECT MOOD CHECKS: FAIL")
		for failure in failures:
			push_error(failure)
		quit(1)
