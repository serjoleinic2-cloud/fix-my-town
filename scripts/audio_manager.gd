extends Node

const DistrictWorld = preload("res://scripts/district_world.gd")

const MAX_VOICES = 12
const UI_RESERVE = 2
const SETTINGS_PATH = "user://audio_settings.json"
const CHANNELS = ["Ambience", "Effects", "Interface", "Music"]
var levels: Dictionary = {"Ambience": 0.45, "Effects": 0.65, "Interface": 0.6, "Music": 0.4}
var loops: Dictionary = {}
var voices: Array = []
var spatial_root: Node3D
var paused: bool = false
var zoom_gain: float = 1.0
var warning_clock: float = 0.0
var ambience_fade: float = 0.0
var last_job: String = ""
var last_leak: bool = false
var last_completed: bool = false
var last_signal: bool = false
var last_vehicle: Vector3 = Vector3.ZERO
var initialized: bool = false
var settings_path: String = SETTINGS_PATH
var streams: Dictionary = {}

func setup(root: Node3D) -> void:
	spatial_root = root
	for channel: String in CHANNELS:
		if AudioServer.get_bus_index(channel) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, channel)
	load_settings()
	for channel: String in CHANNELS:
		apply_level(channel)

func stream(sound: String, loop: bool = false) -> AudioStream:
	var key := sound + str(loop)
	if not streams.has(key):
		var resource := load("res://assets/audio/" + sound + ".wav").duplicate() as AudioStreamWAV
		if loop:
			resource.loop_mode = AudioStreamWAV.LOOP_FORWARD
			resource.loop_end = int(resource.get_length() * resource.mix_rate)
		streams[key] = resource
	return streams[key]

func play_ui(sound: String = "click") -> void:
	play(sound, "Interface")

func play_construction(position_value: Vector3, park: bool = false) -> void:
	play_ui("place")
	play("build", "Effects", position_value)
	if park:
		play("leaves", "Effects", position_value)

func play(sound: String, channel: String, position_value: Variant = null) -> void:
	clean_voices()
	if paused:
		return
	var limit := MAX_VOICES if channel == "Interface" else MAX_VOICES - UI_RESERVE
	if voices.size() + loops.size() >= limit:
		if channel != "Interface" or voices.is_empty():
			return
		# Подтверждение/тап не теряется за длинными эффектами.
		var oldest: Node = voices.pop_front()
		oldest.stop()
		oldest.stream = null
		oldest.queue_free()
	var player: Node
	if position_value is Vector3:
		player = AudioStreamPlayer3D.new()
		spatial_root.add_child(player)
		player.position = DistrictWorld.world_position(position_value)
		player.unit_size = 55
		player.max_distance = 300
		player.volume_db = linear_to_db(zoom_gain)
	else:
		player = AudioStreamPlayer.new()
		add_child(player)
	player.bus = channel
	player.stream = stream(sound)
	player.pitch_scale = randf_range(0.96, 1.04)
	voices.append(player)
	# Сначала отвязываем playback от дерева: мобильный микшер ещё может
	# завершать последний блок, когда очередь удаления уже обработана.
	player.finished.connect(func():
		player.stop()
		player.stream = null
		player.queue_free())
	player.play()

func clean_voices() -> void:
	voices = voices.filter(func(voice): return is_instance_valid(voice) and not voice.is_queued_for_deletion())

func set_loop(key: String, sound: String, channel: String, enabled: bool, position_value: Variant = null, gain: float = 1.0) -> void:
	if not enabled:
		if loops.has(key):
			loops[key].stop()
			loops[key].stream = null
			loops[key].queue_free()
			loops.erase(key)
		return
	if not loops.has(key):
		clean_voices()
		if voices.size() + loops.size() >= MAX_VOICES - UI_RESERVE:
			return
		var player: Node
		if position_value is Vector3:
			player = AudioStreamPlayer3D.new()
			spatial_root.add_child(player)
			player.unit_size = 55
			player.max_distance = 300
		else:
			player = AudioStreamPlayer.new()
			add_child(player)
		player.stream = stream(sound, true)
		player.bus = channel
		loops[key] = player
		player.play()
	var active: Node = loops[key]
	active.volume_db = linear_to_db(maxf(0.001, gain * (zoom_gain if position_value is Vector3 else 1.0)))
	if position_value is Vector3:
		active.position = DistrictWorld.world_position(position_value)
	active.stream_paused = paused

func sync(game: RefCounted, zoom: float, delta: float) -> void:
	zoom_gain = clampf(33.0 / zoom, 0.5, 1.4)
	if paused:
		return
	warning_clock += delta
	ambience_fade = minf(1, ambience_fade + delta / 2.0)
	if not initialized:
		last_signal = game.signal_fixed
		last_leak = game.leak_fixed
		last_completed = game.completed
		initialized = true
	if (not last_leak and game.leak_fixed) or (not last_signal and game.signal_fixed):
		play_ui("success")
		play("reaction", "Effects", last_vehicle)
	if not last_leak and game.leak_fixed:
		set_loop("water", "water", "Effects", false)
	if not last_completed and game.completed:
		play_ui("level_up")
	# В полевой записи уже есть птицы и редкий дальний транспорт.
	set_loop("city", "city", "Ambience", true, null, ambience_fade * 0.6)
	set_loop("water", "water", "Effects", not game.leak_fixed, Vector3(-9, 0.5, 6))
	var moving: bool = game.job != "" and game.route_index < game.route.size()
	set_loop("engine", "engine", "Effects", moving, game.vehicle)
	set_loop("repair", "repair", "Effects", game.job != "" and game.job_phase != "return" and not moving, game.vehicle)
	if warning_clock >= 45 and (not game.leak_fixed or not game.signal_fixed):
		play_ui("warning")
		warning_clock = 0
	last_job = game.job
	last_signal = game.signal_fixed
	last_vehicle = game.vehicle
	last_leak = game.leak_fixed
	last_completed = game.completed

func set_level(channel: String, value: float) -> void:
	levels[channel] = clampf(value, 0, 1)
	apply_level(channel)
	save_settings()

func apply_level(channel: String) -> void:
	var index := AudioServer.get_bus_index(channel)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(0.0001, levels[channel])))
	AudioServer.set_bus_mute(index, levels[channel] <= 0 or paused)

func set_paused(value: bool) -> void:
	paused = value
	for channel: String in CHANNELS:
		apply_level(channel)
	for player in loops.values() + voices:
		if is_instance_valid(player):
			player.stream_paused = value

func save_settings() -> void:
	var file := FileAccess.open(settings_path + ".tmp", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(levels))
		file.close()
		DirAccess.rename_absolute(settings_path + ".tmp", settings_path)

func load_settings() -> void:
	if not FileAccess.file_exists(settings_path):
		return
	var file := FileAccess.open(settings_path, FileAccess.READ)
	if not file:
		return
	var data = JSON.parse_string(file.get_as_text())
	if data is Dictionary:
		for channel: String in CHANNELS:
			var value = data.get(channel)
			if (value is float or value is int) and is_finite(float(value)):
				levels[channel] = clampf(float(value), 0, 1)

func shutdown() -> void:
	for player in loops.values() + voices:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	loops.clear()
	voices.clear()
	streams.clear()

func reset_state() -> void:
	shutdown()
	initialized = false
	last_job = ""
	warning_clock = 0
	ambience_fade = 0

func _exit_tree() -> void:
	shutdown()
