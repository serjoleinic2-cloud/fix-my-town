extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func write_payload(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()

func read_payload(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	var value: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return value if value is Dictionary else {}

func remove_test_file(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)
	if FileAccess.file_exists(absolute + ".tmp"):
		DirAccess.remove_absolute(absolute + ".tmp")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var suffix := str(Time.get_ticks_usec())
	var path := "user://budget_roundtrip_%s.json" % suffix
	var original := Simulation.new(false)
	original.save_path = path
	original.start_empty_city()
	original.budget = 1036122
	original.save_game()
	var loaded := Simulation.new(false)
	loaded.save_path = path
	check(loaded.load_game() and loaded.budget == 1036122, "A valid balance above one million loads without truncation")
	loaded.save_game()
	var loaded_again := Simulation.new(false)
	loaded_again.save_path = path
	check(loaded_again.load_game() and loaded_again.budget == 1036122, "A balance of 1,036,122 survives load-save-load unchanged")

	# Exercise the legacy pre-grid migration path on an isolated fixture.
	var legacy_source := Simulation.new(true)
	legacy_source.save_path = "user://budget_legacy_source_%s.json" % suffix
	legacy_source.budget = 1036122
	legacy_source.save_game()
	var legacy_payload := read_payload(legacy_source.save_path)
	legacy_payload.erase("districts")
	legacy_payload.erase("city_layout_version")
	legacy_payload.erase("empty_city_mode")
	legacy_payload.budget = 1036122
	var legacy_path := "user://budget_legacy_migration_%s.json" % suffix
	write_payload(legacy_path, legacy_payload)
	var legacy := Simulation.new(false)
	legacy.save_path = legacy_path
	check(legacy.load_game() and not legacy.territory.buildings.is_empty(), "Legacy pre-grid save still migrates through the production loader")
	check(legacy.budget == 1036122, "Legacy migration preserves a balance above one million")

	# Invalid values must reject the whole load instead of mutating the live city.
	for bad_balance in [-1, 1000000001, 12.5]:
		var invalid_payload := read_payload(path)
		invalid_payload.budget = bad_balance
		var invalid_path := "user://budget_invalid_%s_%s.json" % [suffix, str(bad_balance).replace(".", "_")]
		write_payload(invalid_path, invalid_payload)
		var guarded := Simulation.new(false)
		guarded.save_path = invalid_path
		guarded.budget = 777
		check(not guarded.load_game() and guarded.budget == 777, "Invalid balance %s rejects atomically" % str(bad_balance))
		remove_test_file(invalid_path)

	for test_path in [path, legacy_source.save_path, legacy_path]:
		remove_test_file(test_path)
	print("BUDGET PERSISTENCE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
