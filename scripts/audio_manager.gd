extends Node

const DistrictWorld = preload("res://scripts/district_world.gd")

const MAX_VOICES = 12
const UI_RESERVE = 2
const SETTINGS_PATH = "user://audio_settings.json"
const CHANNELS = ["Ambience", "Effects", "Interface", "Music"]
const BUILDING_SELECT_SOUNDS := {
	"city_hall": "success", "elite_residence": "level_up", "business_tower": "level_up",
	"house": "select", "ruins": "deny", "empty": "select", "depot": "repair",
	"logistics_center": "engine", "warehouse": "build", "fire_station": "siren",
	"police_station": "warning", "hospital": "radio_call", "lawn": "leaves",
	"flower_bed": "leaves", "street_tree": "leaves", "bush": "leaves",
	"cafe": "place", "park": "leaves", "bus_stop": "select", "traffic_signal": "click",
	"water_leak": "water", "construction_site": "build"
}
const BUILDING_AMBIENCE_SOUNDS := {
	"police_station": "warning",
	"hospital": "radio_call",
	"depot": "repair",
	"fire_station": "siren",
	"logistics_center": "engine"
}
const VEHICLE_SELECT_SOUNDS := {
	"delivery_truck": "engine", "repair_van": "repair", "work_vehicle": "build",
	"excavator": "build", "dump_truck": "engine", "fire_engine": "siren",
	"police_car": "warning", "civilian_car": "engine", "city_bus": "engine"
}
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
var building_sound_cooldowns: Dictionary = {}
var building_sound_rng := RandomNumberGenerator.new()

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

func play_ui(sound: String = "click", gain_db: float = 0.0) -> void:
	play(sound, "Interface", null, gain_db)

func cue_gain_db(sound: String) -> float:
	# Several original service samples were intentionally very quiet as spatial
	# loops. Selection feedback needs more mid-volume so it survives a phone speaker.
	return float({"engine": 8.0, "siren": 8.0, "warning": 8.0, "repair": 7.0, "build": 6.0, "radio_call": 4.0}.get(sound, 0.0))

func building_select_sound(type_id: String, ruined: bool = false) -> String:
	return "deny" if ruined else str(BUILDING_SELECT_SOUNDS.get(type_id, "select"))

func vehicle_select_sound(type_id: String) -> String:
	return str(VEHICLE_SELECT_SOUNDS.get(type_id, "engine"))

func play_building_select(type_id: String, ruined: bool = false) -> void:
	var sound := building_select_sound(type_id, ruined)
	play_ui(sound, cue_gain_db(sound))

func play_vehicle_select(type_id: String) -> void:
	var sound := vehicle_select_sound(type_id)
	play_ui(sound, cue_gain_db(sound))

func play_construction(position_value: Vector3, type_id: String = "house") -> void:
	play_ui(str({"road": "build", "clear": "repair"}.get(type_id, building_select_sound(type_id))))
	play("build", "Effects", position_value)
	if type_id in ["park", "lawn", "flower_bed", "street_tree", "bush"]:
		play("leaves", "Effects", position_value)

func sync_traffic_ambience(traffic_vehicles: Array, listener_position: Vector3) -> void:
	# Only two nearby engines are mixed at once; distant traffic remains in the
	# city field recording. Keys are stable so moving cars do not allocate voices.
	var candidates: Array[Dictionary] = []
	for vehicle: Dictionary in traffic_vehicles:
		var node: Node3D = vehicle.get("node") as Node3D
		if node == null or not is_instance_valid(node) or not node.visible:
			continue
		candidates.append({"node": node, "distance": node.global_position.distance_squared_to(listener_position)})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.distance) < float(b.distance))
	var active_keys: Array[String] = []
	for index in range(mini(2, candidates.size())):
		var key := "traffic_engine_%d" % index
		active_keys.append(key)
		var node: Node3D = candidates[index].node
		set_loop(key, "engine", "Effects", true, DistrictWorld.logical_position(node.global_position), 0.48 if index == 0 else 0.34)
	for index in range(2):
		var key := "traffic_engine_%d" % index
		if key not in active_keys:
			stop_loop(key)

func sync_building_sounds(buildings: Array, listener_position: Vector3, delta: float) -> void:
	if paused or buildings.is_empty():
		return
	var candidates: Array[Dictionary] = []
	var active_ids: Dictionary = {}
	for entry: Dictionary in buildings:
		var type_id := str(entry.get("type_id", ""))
		if not BUILDING_AMBIENCE_SOUNDS.has(type_id):
			continue
		var identifier := str(entry.get("instance_id", type_id))
		active_ids[identifier] = true
		if not building_sound_cooldowns.has(identifier):
			building_sound_rng.randomize()
			building_sound_cooldowns[identifier] = building_sound_rng.randf_range(8.0, 24.0)
		else:
			building_sound_cooldowns[identifier] = maxf(0.0, float(building_sound_cooldowns[identifier]) - delta)
		var position_value: Vector3 = entry.get("position", Vector3.ZERO)
		var distance_squared := position_value.distance_squared_to(listener_position)
		if float(building_sound_cooldowns[identifier]) <= 0.0 and distance_squared <= 32.0 * 32.0:
			candidates.append({"id": identifier, "type_id": type_id, "position": position_value, "distance": distance_squared})
	for identifier in building_sound_cooldowns.keys():
		if not active_ids.has(identifier):
			building_sound_cooldowns.erase(identifier)
	if candidates.is_empty():
		return
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.distance) < float(b.distance))
	var candidate: Dictionary = candidates[0]
	var type_id := str(candidate.type_id)
	# Simulation building positions are already world-space; `play()` accepts
	# logical district coordinates and converts them back to world space. Convert
	# before calling it, otherwise special-building sounds are placed far away.
	play(str(BUILDING_AMBIENCE_SOUNDS[type_id]), "Effects", DistrictWorld.logical_position(candidate.position), -5.0)
	building_sound_cooldowns[str(candidate.id)] = building_sound_rng.randf_range(24.0, 42.0)

func play(sound: String, channel: String, position_value: Variant = null, gain_db: float = 0.0) -> void:
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
		player.volume_db = linear_to_db(zoom_gain) + gain_db
	else:
		player = AudioStreamPlayer.new()
		add_child(player)
		player.volume_db = gain_db
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

func stop_loop(key: String) -> void:
	set_loop(key, "", "Effects", false)

func sync(game: RefCounted, zoom: float, delta: float) -> void:
	zoom_gain = clampf(33.0 / zoom, 0.5, 1.4)
	if paused:
		return
	warning_clock += delta
	ambience_fade = minf(1, ambience_fade + delta / 2.0)
	var leak_active: bool = game.legacy_problem_available("leak")
	var signal_active: bool = game.legacy_problem_available("signal")
	if not initialized:
		last_signal = game.signal_fixed
		last_leak = game.leak_fixed
		last_completed = game.completed
		initialized = true
	if (not last_leak and game.leak_fixed) or (not last_signal and game.signal_fixed):
		play_ui("success")
		play("reaction", "Effects", last_vehicle)
	if not leak_active:
		stop_loop("water")
	if not last_completed and game.completed:
		play_ui("level_up")
	# В полевой записи уже есть птицы и редкий дальний транспорт.
	set_loop("city", "city", "Ambience", true, null, ambience_fade * 0.6)
	set_loop("water", "water", "Effects", leak_active, Vector3(-9, 0.5, 6))
	var moving: bool = game.job != "" and game.route_index < game.route.size()
	set_loop("engine", "engine", "Effects", moving, game.vehicle)
	set_loop("repair", "repair", "Effects", game.job != "" and game.job_phase != "return" and not moving, game.vehicle)
	if warning_clock >= 24 and (leak_active or signal_active or not game.fires.is_empty()):
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
	stop_loop("water")
	shutdown()
	initialized = false
	last_job = ""
	warning_clock = 0
	ambience_fade = 0

func _exit_tree() -> void:
	shutdown()
