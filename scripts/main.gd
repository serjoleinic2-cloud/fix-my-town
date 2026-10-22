extends Node3D

const GameObjectScene = preload("res://scenes/objects/game_object.tscn")
const Catalog = preload("res://scripts/asset_catalog.gd")
const AudioManager = preload("res://scripts/audio_manager.gd")
var audio: Node
var audio_button: Button
var ui_theme: Theme
var signal_object: Node3D

const Simulation = preload("res://scripts/simulation.gd")
var game = Simulation.new()
var camera: Camera3D
var world: Node3D
var plots: Node3D
var car: Node3D
var leak_effect: Node3D
var stats: Label
var objective: Label
var details: Label
var status: Label
var action_box: HBoxContainer
var language_button: Button
var signal_button: Button
var leak_button: Button
var reset_button: Button
var viewport_container: SubViewportContainer
var selected: int = -1
var selection_kind: String = "signal"
var save_clock: float = 0.0
var elapsed: float = 0.0


const TEXT = {
	"title": ["FIX MY TOWN · Мэрия", "FIX MY TOWN · City Hall"],
	"goal": ["1. Почините светофор и протечку\n2. Постройте кафе или парк", "1. Repair the signal and water leak\n2. Build a café or park"],
	"done": ["Квартал ожил! Сценарий завершён.\nПродолжайте обустраивать район.", "The neighborhood is thriving! Scenario complete.\nKeep improving your district."],
	"stats": ["Бюджет  %d   •   Жители  %d\nНастроение  %d%%   •   Доход  +%d / 12 сек.", "Budget  %d   •   Residents  %d\nHappiness  %d%%   •   Income  +%d / 12 sec"],
	"signal": ["Светофор", "Traffic signal"], "leak": ["Протечка", "Water leak"],
	"signal_info": ["Сломанный перекрёсток\nЗадерживает машину. Ремонт: %d монет.", "Broken intersection\nSlows the service van. Repair: %d coins."],
	"leak_info": ["Протечка у жилого дома\nСнижает заселение и доход. Ремонт: %d монет.", "Leak near a residential building\nReduces occupancy and income. Repair: %d coins."],
	"repair": ["Отправить бригаду", "Dispatch crew"], "fixed": ["Обслуживание восстановлено", "Service restored"],
	"busy": ["Бригада: %s • %s", "Crew: %s • %s"], "travel": ["в пути", "on the way"], "repairing": ["ремонт %d сек.", "repair %d sec"], "return": ["возвращается", "returning"], "idle": ["Бригада свободна • выбор участка на карте", "Crew ready • select a plot on the map"],
	"empty": ["Участок %d • доступ к дороге\nБонус зависит от соседних домов и объектов.", "Plot %d • road access\nBonus depends on nearby homes and amenities."],
	"cafe": ["Кафе", "Café"], "park": ["Парк", "Park"], "house": ["Жилой дом", "Residential home"], "depot": ["Ремонтная служба", "Repair depot"],
	"build": ["%s · %d\nНастроение +%d", "%s · %d\nHappiness +%d"],
	"occupied": ["%s • участок %d\nПодключён к дороге и службам.", "%s • plot %d\nConnected to roads and services."],
	"reset": ["Заново", "Restart"], "confirm": ["Начать новый район?", "Start a new district?"],
	"reset_info": ["Текущий прогресс будет заменён.", "Your current progress will be replaced."],
	"ok": ["Начать", "Start"], "cancel": ["Отмена", "Cancel"],
	"zoom": ["Масштаб", "Zoom"], "saving": ["Автосохранение", "Autosave"],
	"audio_done": ["Готово", "Done"], "audio": ["Звук", "Sound"], "Ambience": ["Окружение", "Ambience"],
	"Effects": ["Эффекты", "Effects"], "Interface": ["Интерфейс", "Interface"], "Music": ["Музыка", "Music"],
	"music_note": ["Музыка пока не добавлена. Можно играть без звука.", "Music is not added yet. All cues are also visual."]
}

func t(key: String) -> String:
	return TEXT[key][0 if game.language == "ru" else 1]

func _ready() -> void:
	game.load_game()
	build_ui()
	build_world()
	audio = AudioManager.new()
	add_child(audio)
	audio.setup(world)
	refresh()
	get_tree().auto_accept_quit = false

func label(size: int, parent: Node) -> Label:
	var item := Label.new()
	item.add_theme_font_size_override("font_size", size)
	item.add_theme_color_override("font_color", Color("243d44"))
	parent.add_child(item)
	return item

func button(parent: Node, text_value: String, callback: Callable) -> Button:
	var item := Button.new()
	item.text = text_value
	item.custom_minimum_size.y = 50
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.pressed.connect(func():
		if audio != null:
			audio.play_ui("click"))
	item.gui_input.connect(func(event: InputEvent):
		if item.disabled and event is InputEventMouseButton and event.pressed and audio != null:
			audio.play_ui("deny"))
	item.pressed.connect(callback)
	parent.add_child(item)
	return item

func build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var background := ColorRect.new()
	background.color = Color("edf2eb")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	layer.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var theme := Theme.new()
	ui_theme = theme
	theme.default_font_size = 19
	theme.set_color("font_color", "Label", Color("243d44"))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("d6e5d9")
	style.set_corner_radius_all(12)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	theme.set_stylebox("normal", "Button", style)
	var panel_style := style.duplicate() as StyleBoxFlat
	panel_style.bg_color = Color("edf2eb")
	theme.set_stylebox("panel", "AcceptDialog", panel_style)
	theme.set_stylebox("panel", "ConfirmationDialog", panel_style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color("b8d5c2")
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", hover)
	for property_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(property_name, "Button", Color("243d44"))
	column.theme = theme
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var title := label(23, heading)
	title.name = "Title"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	language_button = button(heading, "EN", switch_language)
	language_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	stats = label(22, column)
	objective = label(18, column)
	viewport_container = SubViewportContainer.new()
	viewport_container.stretch = true
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_container.custom_minimum_size.y = 300
	column.add_child(viewport_container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(508, 450)
	viewport.audio_listener_enable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(viewport)
	world = Node3D.new()
	viewport.add_child(world)
	viewport_container.gui_input.connect(map_input)
	var zoom_row := HBoxContainer.new()
	column.add_child(zoom_row)
	var zoom_label := label(16, zoom_row)
	zoom_label.name = "ZoomLabel"
	var zoom := HSlider.new()
	zoom.min_value = 25
	zoom.max_value = 39
	zoom.value = 33
	zoom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zoom_row.add_child(zoom)
	zoom.value_changed.connect(func(value: float): camera.size = value)
	var problems := HBoxContainer.new()
	column.add_child(problems)
	signal_button = button(problems, "", select_problem.bind("signal"))
	leak_button = button(problems, "", select_problem.bind("leak"))
	details = label(18, column)
	details.custom_minimum_size.y = 56
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_box = HBoxContainer.new()
	action_box.custom_minimum_size.y = 62
	column.add_child(action_box)
	status = label(17, column)
	var footer := HBoxContainer.new()
	column.add_child(footer)
	var save_label := label(12, footer)
	save_label.name = "SaveLabel"
	save_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	audio_button = button(footer, "", open_audio_settings)
	audio_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	audio_button.custom_minimum_size.y = 36
	reset_button = button(footer, "", confirm_reset)
	reset_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	reset_button.custom_minimum_size.y = 36

func box(parent: Node3D, position_value: Vector3, size_value: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size_value
	mesh.mesh = shape
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	mesh.material_override = material
	mesh.position = position_value
	parent.add_child(mesh)
	return mesh

func marker(parent: Node3D, pos: Vector3, text_value: String, color: Color) -> void:
	var item := Label3D.new()
	item.text = text_value
	item.position = pos
	item.font_size = 64
	item.pixel_size = 0.02
	item.outline_size = 2
	item.no_depth_test = true
	item.modulate = color
	item.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(item)

func build_world() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 33
	camera.position = Vector3(21, 29, 27)
	world.add_child(camera)
	camera.look_at(Vector3.ZERO)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -30, 0)
	light.light_energy = 1.15
	world.add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("cdded9")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("ffffff")
	environment.environment.ambient_light_energy = 0.65
	world.add_child(environment)
	box(world, Vector3(0, -0.35, 0), Vector3(26, 0.6, 21), Color("8fb69a"))
	for z in [-9, -6, -3, 0, 3, 6, 9]:
		box(world, Vector3(0, 0, z), Vector3(25, 0.08, 1.15), Color("647578"))
		for x in range(-11, 12, 3):
			box(world, Vector3(x, 0.055, z), Vector3(0.8, 0.02, 0.07), Color("c8cebc"))
	box(world, Vector3(-7, 0.015, 0), Vector3(1.1, 0.1, 19), Color("647578"))
	signal_object = create_object(world, "traffic_signal", "intersection_0", Vector3(-6.3, 0, 0))
	marker(world, Vector3(-6.3, 3.2, 0), "!", Color("ffe6a6"))
	world.get_child(world.get_child_count() - 1).name = "SignalMarker"
	plots = Node3D.new()
	world.add_child(plots)
	car = create_object(world, "repair_van", "crew_0", game.vehicle)
	marker(world, Vector3(-9, 3.0, 6), "!", Color("63d8ff"))
	world.get_child(world.get_child_count() - 1).name = "LeakMarker"
	leak_effect = create_object(world, "water_leak", "leak_0", Vector3(-9, 0, 6))

func create_object(parent: Node3D, type_id: String, persistent_id: String, pos: Vector3) -> Node3D:
	var object := GameObjectScene.instantiate()
	object.name = persistent_id
	parent.add_child(object)
	object.setup(type_id, persistent_id)
	object.position = pos
	return object

func redraw_plots() -> void:
	for i in range(24):
		var kind: String = game.buildings[i]
		var object = plots.get_node_or_null("plot_" + str(i))
		if object != null and object.type_id != kind:
			plots.remove_child(object)
			object.queue_free()
			object = null
		if object == null:
			object = create_object(plots, kind, "plot_" + str(i), game.plot_position(i))
			var base := box(object, Vector3(0, 0.05, 0), Vector3(4.5, 0.12, 1.65), Color("a9c7a1"))
			base.name = "PlotBase"
			if kind == "empty":
				marker(object, Vector3(0, 0.4, 0), "+", Color("eef4df"))
			elif Catalog.TYPES[kind].has("icon"):
				var icon := Sprite3D.new()
				icon.texture = load(Catalog.TYPES[kind].icon)
				icon.position = Vector3(0, 2.8, 0)
				icon.pixel_size = 0.014
				icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				icon.no_depth_test = true
				object.add_child(icon)
		object.get_node("PlotBase").material_override.albedo_color = Color("f3d59b") if selected == i else Color("a9c7a1")
		object.set_serviced(game.leak_fixed)

func map_input(event: InputEvent) -> void:
	var click: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var touch: bool = event is InputEventScreenTouch and event.pressed
	if not click and not touch:
		return
	var point: Vector2 = event.position
	for kind in ["signal", "leak"]:
		var fixed: bool = game.signal_fixed if kind == "signal" else game.leak_fixed
		var marker_position := Vector3(-6.3, 3.2, 0) if kind == "signal" else Vector3(-9, 3, 6)
		if not fixed and camera.unproject_position(marker_position).distance_to(point) < 22:
			select_problem(kind)
			return
	var hit = Plane(Vector3.UP, 0).intersects_ray(camera.project_ray_origin(point), camera.project_ray_normal(point))
	if hit == null:
		return
	if Vector2(hit.x + 6.3, hit.z).length() < 1.5:
		select_problem("signal")
		return
	if Vector2(hit.x + 9, hit.z - 6).length() < 1.2:
		select_problem("leak")
		return
	var closest := -1
	var distance := 2.8
	for i in range(24):
		var current: float = game.plot_position(i).distance_to(hit)
		if current < distance:
			distance = current
			closest = i
	if closest >= 0:
		audio.play_ui("select")
		selected = closest
		selection_kind = "plot"
		refresh()

func select_problem(kind: String) -> void:
	selection_kind = kind
	selected = -1
	if audio != null:
		audio.play_ui("select")
	refresh()

func switch_language() -> void:
	game.language = "en" if game.language == "ru" else "ru"
	game.save_game()
	refresh()

func refresh() -> void:
	find_child("Title", true, false).text = t("title")
	find_child("ZoomLabel", true, false).text = t("zoom")
	find_child("SaveLabel", true, false).text = t("saving")
	language_button.text = "EN" if game.language == "ru" else "RU"
	stats.text = t("stats") % [game.budget, game.population(), game.happiness(), game.income()]
	objective.text = t("done") if game.completed else t("goal")
	signal_button.text = ("✓ " if game.signal_fixed else "! ") + t("signal")
	leak_button.text = ("✓ " if game.leak_fixed else "! ") + t("leak")
	reset_button.text = t("reset")
	audio_button.text = t("audio")
	update_crew_status()
	for child in action_box.get_children():
		action_box.remove_child(child)
		child.queue_free()
	if selection_kind in ["signal", "leak"]:
		var fixed: bool = game.signal_fixed if selection_kind == "signal" else game.leak_fixed
		details.text = t("fixed") if fixed else t(selection_kind + "_info") % Catalog.cost("traffic_signal" if selection_kind == "signal" else "water_leak")
		if not fixed:
			var dispatch_button := button(action_box, t("repair"), dispatch)
			dispatch_button.disabled = game.job != "" or game.budget < Catalog.cost("traffic_signal" if selection_kind == "signal" else "water_leak")
	elif selected >= 0:
		var kind: String = game.buildings[selected]
		if kind == "empty":
			details.text = t("empty") % (selected + 1)
			for build_kind in ["cafe", "park"]:
				var cost := Catalog.cost(build_kind)
				var build_button := button(action_box, t("build") % [t(build_kind), cost, Catalog.TYPES[build_kind].mood + game.placement_bonus(selected, build_kind)], construct.bind(build_kind))
				build_button.disabled = game.budget < cost
		else:
			details.text = t("occupied") % [t(kind), selected + 1]
	redraw_plots()
	signal_object.set_serviced(game.signal_fixed)
	leak_effect.visible = not game.leak_fixed
	world.get_node("LeakMarker").visible = not game.leak_fixed
	world.get_node("SignalMarker").visible = not game.signal_fixed

func dispatch() -> void:
	if game.dispatch(selection_kind):
		audio.play("siren", "Effects", game.vehicle)
	else:
		audio.play_ui("deny")
	refresh()

func construct(kind: String) -> void:
	if game.build(selected, kind):
		audio.play_ui("success")
		audio.play("build", "Effects", game.plot_position(selected))
		if kind == "park":
			audio.play("leaves", "Effects", game.plot_position(selected))
	else:
		audio.play_ui("deny")
	refresh()

func confirm_reset() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.theme = ui_theme
	dialog.title = t("confirm")
	dialog.dialog_text = t("reset_info")
	dialog.ok_button_text = t("ok")
	dialog.cancel_button_text = t("cancel")
	add_child(dialog)
	dialog.confirmed.connect(func():
		var previous_language: String = game.language
		audio.reset_state()
		game = Simulation.new()
		game.language = previous_language
		game.save_game()
		selection_kind = "signal"
		selected = -1
		refresh())
	dialog.close_requested.connect(dialog.queue_free)
	dialog.canceled.connect(func():
		audio.play_ui("cancel")
		dialog.queue_free())
	dialog.popup_centered()

func _process(delta: float) -> void:
	if car == null:
		return
	elapsed += delta
	if game.tick(delta):
		refresh()
	audio.sync(game, camera.size, delta)
	update_crew_status()
	car.position = game.vehicle
	if game.job != "" and game.route_index < game.route.size():
		var direction: Vector3 = game.route[game.route_index] - game.vehicle
		if direction.length() > 0.01:
			car.rotation.y = atan2(direction.x, direction.z)
	leak_effect.visual_root.position.y = sin(elapsed * 6) * 0.12
	save_clock += delta
	if save_clock > 2:
		game.save_game()
		save_clock = 0

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		game.save_game()
		if audio != null:
			audio.shutdown()
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		game.save_game()
		set_process(false)
		if audio != null:
			audio.set_paused(true)
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		set_process(true)
		if audio != null:
			audio.set_paused(false)



func open_audio_settings() -> void:
	var dialog := AcceptDialog.new()
	dialog.theme = ui_theme
	dialog.title = t("audio")
	dialog.ok_button_text = t("audio_done")
	dialog.min_size = Vector2i(420, 320)
	var column := VBoxContainer.new()
	dialog.add_child(column)
	for channel: String in AudioManager.CHANNELS:
		var row := HBoxContainer.new()
		column.add_child(row)
		var name_label := label(18, row)
		name_label.text = t(channel)
		name_label.custom_minimum_size.x = 140
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 100
		slider.value = audio.levels[channel] * 100
		slider.custom_minimum_size = Vector2(180, 44)
		row.add_child(slider)
		slider.value_changed.connect(func(value: float): audio.set_level(channel, value / 100.0))
	var note := label(14, column)
	note.text = t("music_note")
	note.custom_minimum_size = Vector2(390, 50)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog.confirmed.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(440, 360))

func update_crew_status() -> void:
	if game.job == "":
		status.text = t("idle")
		return
	var phase_text: String = t("return") if game.job_phase == "return" else (t("travel") if game.route_index < game.route.size() else t("repairing") % ceili(game.repair_left))
	status.text = t("busy") % [t(game.job), phase_text]
