extends Node3D

const GameObjectScene = preload("res://scenes/objects/game_object.tscn")
const Catalog = preload("res://scripts/asset_catalog.gd")
const AudioManager = preload("res://scripts/audio_manager.gd")
const Simulation = preload("res://scripts/simulation.gd")
const DistrictWorld = preload("res://scripts/district_world.gd")
const Art = preload("res://scripts/art.gd")
const INK = Color("252c38")
const BLUE = Color("258ed2")
const PAPER = Color("fbf9f4")
const SETTINGS_PATH = "user://graphics_settings.json"
var game = Simulation.new()
var audio: Node
var camera: Camera3D
var world: Node3D
var scenery: Node3D
var plots: Node3D
var car: Node3D
var signal_object: Node3D
var leak_effect: Node3D
var sunlight: DirectionalLight3D
var viewport_container: SubViewportContainer
var screen: Control
var hud: MarginContainer
var navbar: PanelContainer
var sheet: PanelContainer
var sheet_column: VBoxContainer
var mission: PanelContainer
var completion_left: float = 0
var completion_observed: bool = false
var mission_icon: TextureRect
var objective: Label
var stats: Label
var details: Label
var status: Label
var action_box: VBoxContainer
var budget_label: Label
var rating_label: Label
var district_label: Label
var language_button: Button
var audio_button: Button
var reset_button: Button
var signal_button: Button
var leak_button: Button
var progress_bar: ProgressBar
var ui_theme: Theme
var nav_buttons: Dictionary = {}
var selected: int = -1
var selection_kind: String = ""
var preview_kind: String = "cafe"
var active_tab: String = "district"
var preview: Node3D
var highlights: Node3D
var quality: String = "high"
var settings_path: String = SETTINGS_PATH
var focus_point := Vector3(-15, 0, 27)
var save_clock: float = 0
var elapsed: float = 0
var drag_start := Vector2.ZERO
var drag_previous := Vector2.ZERO
var dragging: bool = false
var drag_moved: bool = false
var safe_override := Vector4.ZERO
var safe_top: float = 16
var safe_bottom: float = 12
var action_height: float = 390
var updating_layout: bool = false
var mode_switcher: HBoxContainer
var render_scale: float = 1.0
var diagnostic_clock: float = 0.0
var quality_mode: bool = false
var quality_legend: PanelContainer
var state_button: Button
var transit_button: Button
var transit_visuals: Node3D
var transit_signature: String = ""
var transit_stats: Label
var stop_candidate: int = 0
var placing_stop: bool = false
var last_quality: float = -1
var quality_trend: String = "→"
const QUALITY_COLORS = [Color("df6356"), Color("e9994f"), Color("d8bd57"), Color("9fc76e"), Color("59a675")]
const QUALITY_NAMES = [["Критическое", "Неблагополучное", "Удовлетворительное", "Благополучное", "Отличное"], ["Critical", "Struggling", "Satisfactory", "Good", "Excellent"]]
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
	"occupied": ["%s • участок %d", "%s • plot %d"],
	"reset": ["Заново", "Restart"], "confirm": ["Начать новый район?", "Start a new district?"],
	"reset_info": ["Текущий прогресс будет заменён.", "Your current progress will be replaced."],
	"ok": ["Начать", "Start"], "cancel": ["Отмена", "Cancel"],
	"zoom": ["Масштаб", "Zoom"], "saving": ["Автосохранение", "Autosave"],
	"audio_done": ["Готово", "Done"], "audio": ["Звук", "Sound"], "Ambience": ["Окружение", "Ambience"],
	"Effects": ["Эффекты", "Effects"], "Interface": ["Интерфейс", "Interface"], "Music": ["Музыка", "Music"],
	"music_note": ["Музыка пока не добавлена. Можно играть без звука.", "Music is not added yet. All cues are also visual."]
,
 "district": ["Район", "District"], "district_name": ["Сосновый район", "Pine District"],
 "build_tab": ["Строить", "Build"], "services": ["Службы", "Services"], "rating": ["Рейтинг %d", "Rating %d"],
 "leak_title": ["Прорыв трубы", "Burst water pipe"], "signal_title": ["Сломан светофор", "Broken traffic signal"],
 "leak_subtitle": ["Без воды: 3 дома", "3 homes without water"], "signal_subtitle": ["Перекрёсток задерживает службы", "Intersection delays service vehicles"],
 "permanent_repair": ["Восстановить обслуживание", "Restore the service"], "cost": ["Стоимость", "Cost"],
 "comfort": ["Комфорт", "Comfort"], "preview_title": ["Построить %s", "Build a %s"],
 "dispatch": ["Отправить бригаду", "Dispatch crew"], "crew_available": ["Свободно бригад: 1", "Crews available: 1"],
 "crew_unavailable": ["Бригада выполняет поручение", "Crew is on an assignment"],
 "mission_water": ["Верните воду в 3 дома", "Restore water to 3 homes"],
 "mission_signal": ["Восстановите перекрёсток", "Restore the intersection"],
 "mission_build": ["Постройте кафе или парк", "Build a café or a park"],
 "mission_done": ["Квартал снова живёт!", "The district is thriving!"],
 "build_confirm": ["Построить", "Build"], "nearby_bonus": ["Влияние на соседние дома", "Nearby homes benefit"],
 "residents": ["Жители: %d   •   Доход: +%d", "Residents: %d   •   Income: +%d"],
 "construction_mode": ["Строительство", "Construction"],
 "route_title": ["Маршрут службы", "Service route"],
 "route_delayed": ["Сломанный светофор задерживает машину", "The broken signal delays the vehicle"],
 "route_clear": ["Перекрёсток исправен: путь свободен", "Signal repaired: the route is clear"],
 "repair_duration": ["Работы на месте: 4 сек.", "On-site work: 4 sec"]
}

func t(key: String) -> String:
	return TEXT[key][0 if game.language == "ru" else 1]

func _ready() -> void:
	game.load_game()
	completion_observed = game.completed
	load_graphics()
	build_ui()
	build_world()
	audio = AudioManager.new()
	add_child(audio)
	audio.setup(world)
	apply_quality()
	refresh()
	get_tree().auto_accept_quit = false

func style(color: Color, radius: int = 14, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var value := StyleBoxFlat.new()
	value.bg_color = color
	value.set_corner_radius_all(radius)
	value.set_border_width_all(1 if border.a > 0 else 0)
	value.border_color = border
	value.content_margin_left = 16
	value.content_margin_right = 16
	value.content_margin_top = 12
	value.content_margin_bottom = 12
	return value

func label(size_value: int, parent: Node, text_value: String = "", bold: bool = false) -> Label:
	var item := Label.new()
	if parent == sheet_column and sheet_column != null:
		item.size.x = maxf(100, screen.size.x - 64)
		item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.text = text_value
	item.add_theme_font_size_override("font_size", size_value)
	item.add_theme_color_override("font_color", INK)
	if bold:
		var font := FontVariation.new()
		font.base_font = ThemeDB.fallback_font
		font.variation_embolden = 0.5
		item.add_theme_font_override("font", font)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item)
	return item

func button(parent: Node, text_value: String, callback: Callable, primary: bool = false) -> Button:
	var item := Button.new()
	item.text = text_value
	item.custom_minimum_size.y = 72
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.add_theme_font_size_override("font_size", 26)
	var font := FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	font.variation_embolden = 0.35
	item.add_theme_font_override("font", font)
	item.add_theme_stylebox_override("normal", style(BLUE if primary else Color("f2f2ee"), 12, Color.TRANSPARENT if primary else Color("dddcd6")))
	item.add_theme_stylebox_override("hover", style(Color("3c9cda") if primary else Color("e3eff7")))
	item.add_theme_stylebox_override("pressed", style(Color("187bb9") if primary else Color("d5e8f5")))
	item.add_theme_stylebox_override("disabled", style(Color("dbddd9")))
	for property_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		item.add_theme_color_override(property_name, Color.WHITE if primary else INK)
	item.add_theme_color_override("font_disabled_color", Color("89949b"))
	item.pressed.connect(func():
		if audio != null:
			audio.play_ui())
	item.pressed.connect(callback)
	parent.add_child(item)
	return item

func icon(parent: Node, key: String, size_value: int = 32) -> TextureRect:
	var item := TextureRect.new()
	item.texture = load("res://assets/icons/ui_" + key + ".svg")
	item.custom_minimum_size = Vector2(size_value, size_value)
	item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item)
	return item

func hbox(parent: Node, separation: int = 12) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", separation)
	parent.add_child(row)
	return row

func card(parent: Node, color: Color = PAPER) -> PanelContainer:
	var item := PanelContainer.new()
	item.add_theme_stylebox_override("panel", style(color))
	parent.add_child(item)
	return item

func build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(screen)
	ui_theme = Theme.new()
	ui_theme.default_font_size = 22
	for dialog_type in ["AcceptDialog", "ConfirmationDialog"]:
		ui_theme.set_constant("buttons_min_height", dialog_type, 72)
		ui_theme.set_constant("buttons_min_width", dialog_type, 140)
	ui_theme.set_color("font_color", "Label", INK)
	ui_theme.set_color("font_color", "Button", INK)
	ui_theme.set_stylebox("panel", "AcceptDialog", style(PAPER))
	ui_theme.set_stylebox("panel", "ConfirmationDialog", style(PAPER))
	screen.theme = ui_theme
	viewport_container = SubViewportContainer.new()
	viewport_container.stretch = true
	viewport_container.position = Vector2.ZERO
	screen.add_child(viewport_container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(540, 1200)
	viewport.audio_listener_enable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(viewport)
	world = Node3D.new()
	viewport.add_child(world)
	viewport_container.gui_input.connect(handle_map_gesture)
	mode_switcher = HBoxContainer.new()
	mode_switcher.add_theme_constant_override("separation", 8)
	screen.add_child(mode_switcher)
	hud = MarginContainer.new()
	screen.add_child(hud)
	var top_row := hbox(hud, 8)
	var name_card := card(top_row)
	name_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	district_label = label(20, name_card, "", true)
	district_label.clip_text = true
	district_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var budget_card := card(top_row)
	var budget_row := hbox(budget_card, 5)
	icon(budget_row, "coin", 25)
	budget_label = label(22, budget_row, "", true)
	var rating_card := card(top_row)
	var rating_row := hbox(rating_card, 5)
	icon(rating_row, "star", 26)
	rating_label = label(18, rating_row, "", true)
	var tools := VBoxContainer.new()
	tools.name = "MapTools"
	tools.add_theme_constant_override("separation", 4)
	screen.add_child(tools)
	language_button = button(tools, "EN", switch_language)
	language_button.hide()
	audio_button = button(tools, "☷", open_settings)
	state_button = button(tools, "", toggle_quality)
	state_button.add_theme_font_size_override("font_size", 18)
	transit_button = button(tools, "BUS", open_transit)
	quality_legend = card(screen)
	var legend_column := VBoxContainer.new()
	quality_legend.add_child(legend_column)
	for i in range(5):
		var item := label(18, legend_column)
		item.name = "Band%d" % i
		item.add_theme_color_override("font_color", QUALITY_COLORS[i])
	quality_legend.hide()
	button(tools, "+", change_zoom.bind(-7.0)).hide()
	button(tools, "−", change_zoom.bind(7.0)).hide()
	button(tools, "⌖", focus_problem).hide()
	for child in tools.get_children():
		child.custom_minimum_size = Vector2(72, 72)
		child.add_theme_font_size_override("font_size", 25)
		child.add_theme_stylebox_override("normal", style(Color(0.98, 0.97, 0.94, 0.93), 14))
	state_button.add_theme_font_size_override("font_size", 18)
	mission = card(screen)
	var mission_row := hbox(mission, 14)
	var tile := card(mission_row, Color("dceefa"))
	mission_icon = icon(tile, "drop", 38)
	var mission_column := VBoxContainer.new()
	mission_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mission_row.add_child(mission_column)
	var goal_row := hbox(mission_column)
	objective = label(23, goal_row, "", true)
	objective.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var counter := label(21, goal_row, "", true)
	counter.name = "MissionCounter"
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size.y = 12
	progress_bar.show_percentage = false
	progress_bar.max_value = 3
	progress_bar.add_theme_stylebox_override("background", style(Color("dbddd9"), 6))
	progress_bar.add_theme_stylebox_override("fill", style(Color("3c9ed8"), 6))
	mission_column.add_child(progress_bar)
	sheet = card(screen)
	sheet.resized.connect(func():
		if not updating_layout:
			call_deferred("update_layout"))
	sheet.minimum_size_changed.connect(func():
		if not updating_layout:
			call_deferred("update_layout"))
	sheet_column = VBoxContainer.new()
	sheet_column.add_theme_constant_override("separation", 10)
	sheet.add_child(sheet_column)
	navbar = card(screen)
	var navigation := hbox(navbar, 8)
	for key in ["district", "build_tab", "services"]:
		var item := button(navigation, "", select_tab.bind(key))
		item.custom_minimum_size.y = 90
		var content := VBoxContainer.new()
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_top = 7
		content.offset_bottom = -7
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(content)
		icon(content, {"district": "pin", "build_tab": "hammer", "services": "people"}[key], 32)
		var caption := label(24, content, "", true)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.name = "Caption"
		nav_buttons[key] = item
	stats = label(20, screen)
	stats.hide()
	screen.resized.connect(update_layout)
	update_layout()

func update_layout() -> void:
	if updating_layout or navbar == null:
		return
	updating_layout = true
	var size_value := screen.size
	var physical_width: float = get_viewport().get_texture().get_width()
	render_scale = clampf(physical_width / maxf(1, size_value.x), 1.0, 2.0) if quality == "high" else 1.0
	viewport_container.scale = Vector2.ONE / render_scale
	viewport_container.size = size_value * render_scale
	safe_top = maxf(16, safe_override.y)
	safe_bottom = maxf(12, safe_override.w)
	var safe_left := maxf(16, safe_override.x)
	var safe_right := maxf(16, safe_override.z)
	if OS.has_feature("android") or OS.has_feature("ios"):
		var safe := DisplayServer.get_display_safe_area()
		var physical := DisplayServer.window_get_size()
		if safe.size.x > 0 and physical.x > 0:
			var ratio := size_value.x / physical.x
			safe_top = maxf(safe_top, safe.position.y * ratio + 8)
			safe_bottom = maxf(safe_bottom, (physical.y - safe.end.y) * ratio + 8)
			safe_left = maxf(safe_left, safe.position.x * ratio + 8)
			safe_right = maxf(safe_right, (physical.x - safe.end.x) * ratio + 8)
	hud.position = Vector2(safe_left, safe_top + 10)
	hud.size = Vector2(size_value.x - safe_left - safe_right, 56)
	var tools := screen.get_node("MapTools") as Control
	var tools_width := maxf(105, tools.get_combined_minimum_size().x)
	tools.position = Vector2(size_value.x - safe_right - tools_width, safe_top + 84)
	tools.custom_minimum_size.x = 105
	tools.size.x = tools_width
	quality_legend.position = Vector2(safe_left, safe_top + 84)
	quality_legend.size = Vector2(size_value.x - safe_left - safe_right - tools_width - 16, 150)
	navbar.position = Vector2(0, size_value.y - safe_bottom - 114)
	navbar.size = Vector2(size_value.x, 114 + safe_bottom)
	var nav_style := style(PAPER, 0)
	nav_style.content_margin_left = safe_left
	nav_style.content_margin_right = safe_right
	nav_style.content_margin_bottom = safe_bottom
	navbar.add_theme_stylebox_override("panel", nav_style)
	mission.position = Vector2(safe_left, navbar.position.y - 108)
	mission.size = Vector2(size_value.x - safe_left - safe_right, 88)
	var service_mode: bool = selection_kind in ["signal", "leak"]
	navbar.visible = not service_mode
	if service_mode:
		sheet.position = Vector2(0, size_value.y - safe_bottom - action_height)
		sheet.size = Vector2(size_value.x, action_height + safe_bottom)
		var service_style := style(PAPER, 22)
		service_style.content_margin_left = safe_left
		service_style.content_margin_right = safe_right
		service_style.content_margin_bottom = safe_bottom
		sheet.add_theme_stylebox_override("panel", service_style)
		var required := maxf(action_height + safe_bottom, sheet.get_combined_minimum_size().y)
		sheet.size.y = required
		sheet.position.y = size_value.y - required
	else:
		sheet.position = Vector2(safe_left, navbar.position.y - action_height - 12)
		sheet.size = Vector2(size_value.x - safe_left - safe_right, maxf(action_height, sheet.get_combined_minimum_size().y))
		sheet.position.y = navbar.position.y - sheet.size.y - 12
	mode_switcher.position = Vector2(safe_left, safe_top + 92)
	mode_switcher.size = Vector2(minf(360, size_value.x - 150), 72)
	updating_layout = false

func map_position(point: Vector3) -> Vector3:
	return DistrictWorld.world_position(point)

func build_world() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 76
	camera.far = 400
	world.add_child(camera)
	set_camera_focus(focus_point)
	sunlight = DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-48, -33, 0)
	sunlight.light_color = Color("fff9ec")
	sunlight.light_energy = 0.65
	sunlight.shadow_enabled = true
	sunlight.shadow_opacity = 0.65
	sunlight.directional_shadow_max_distance = 190
	world.add_child(sunlight)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("8eaa69")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("d9e4e2")
	environment.environment.ambient_light_energy = 0.8
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.add_child(environment)
	scenery = DistrictWorld.new()
	world.add_child(scenery)
	scenery.build()
	var backdrop := Node3D.new()
	backdrop.name = "NeighborhoodBackdrop"
	world.add_child(backdrop)
	for x in [-50.4, -36]:
		for z in [-36, -21.6, -7.2, 7.2, 21.6, 36]:
			var kind := "park" if x == -36 and z == -7.2 else "house"
			var object := create_object(backdrop, kind, "backdrop_%s_%s" % [x, z], Vector3(x, 0, z))
			object.interaction_area.collision_layer = 0
			object.set_serviced(true)
			Art.box(object, Vector3(0, 0.02, 0), Vector3(9, 0.12, 9), Color("91a66f"))
	plots = Node3D.new()
	world.add_child(plots)
	signal_object = scenery.traffic_controller.get_problem_signal()
	leak_effect = create_object(world, "water_leak", "leak_0", map_position(Vector3(-9, 0.24, 6)))
	car = create_object(world, "repair_van", "crew_0", map_position(game.vehicle))
	make_marker("SignalMarker", Vector3(-14.4, 5, 0))
	make_marker("LeakMarker", map_position(Vector3(-9, 5, 6)))
	transit_visuals = Node3D.new()
	world.add_child(transit_visuals)
	highlights = Node3D.new()
	world.add_child(highlights)

func create_object(parent: Node3D, type_id: String, persistent_id: String, point: Vector3) -> Node3D:
	var object := GameObjectScene.instantiate()
	object.name = persistent_id
	parent.add_child(object)
	object.setup(type_id, persistent_id)
	object.position = point
	return object

func make_marker(marker_name: String, point: Vector3) -> void:
	var marker := Sprite3D.new()
	marker.name = marker_name
	marker.texture = load("res://assets/icons/problem_marker.svg")
	marker.pixel_size = 0.035
	marker.position = point
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.no_depth_test = true
	world.add_child(marker)

func redraw_plots() -> void:
	for i in range(24):
		var kind: String = game.buildings[i]
		var object = plots.get_node_or_null("plot_" + str(i))
		if object != null and object.type_id != kind:
			plots.remove_child(object)
			object.queue_free()
			object = null
		if object == null:
			object = create_object(plots, kind, "plot_" + str(i), map_position(game.plot_position(i)))
			var base := Art.box(object, Vector3(0, 0.02, 0), Vector3(9, 0.12, 9), Color("91a66f") if kind != "empty" else Color("9cab7a"))
			base.name = "PlotBase"
		object.set_level(game.building_level(i))
		object.visual_root.visible = true
		object.set_serviced(game.has_water(i) if kind == "house" else true)
		var base := object.get_node("PlotBase") as MeshInstance3D
		base.material_override = Art.material(quality_color(game.house_quality(i).score) if quality_mode and kind == "house" else (Color("91a66f") if kind != "empty" else Color("9cab7a")))
		object.set_language(game.language)

func set_camera_focus(point: Vector3) -> void:
	focus_point = Vector3(clampf(point.x, -35, 32), 0, clampf(point.z, -52, 52))
	camera.position = focus_point + Vector3(70, 88, 70)
	camera.look_at(focus_point)

func focus_problem() -> void:
	var point := map_position(Vector3(-9, 0, 6)) if not game.leak_fixed else Vector3(-14.4, 0, 0)
	set_camera_focus(point + Vector3(5, 0, 5))

func change_zoom(amount: float) -> void:
	camera.size = clampf(camera.size + amount, 45, 110)

func handle_map_gesture(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.index != 0:
			drag_moved = true
			return
		if event.pressed:
			dragging = true
			drag_moved = false
			drag_start = event.position
			drag_previous = event.position
		else:
			if dragging and not drag_moved:
				map_input(event)
			dragging = false
		return
	if event is InputEventScreenDrag:
		var motion := InputEventMouseMotion.new()
		motion.position = event.position
		_handle_mouse_gesture(motion)
		return
	# Android присылает исходное касание и эмулированную мышь. Карта обрабатывает один поток.
	if OS.has_feature("android"):
		return
	_handle_mouse_gesture(event)

func _handle_mouse_gesture(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			change_zoom(-5 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 5)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				drag_moved = false
				drag_start = event.position
				drag_previous = event.position
			else:
				if dragging and not drag_moved:
					map_input(event)
				dragging = false
	elif event is InputEventMouseMotion and dragging:
		if event.position.distance_to(drag_start) > 9 * render_scale:
			drag_moved = true
		if drag_moved:
			var plane := Plane(Vector3.UP, 0)
			var previous = plane.intersects_ray(camera.project_ray_origin(drag_previous / viewport_container.stretch_shrink), camera.project_ray_normal(drag_previous / viewport_container.stretch_shrink))
			var current = plane.intersects_ray(camera.project_ray_origin(event.position / viewport_container.stretch_shrink), camera.project_ray_normal(event.position / viewport_container.stretch_shrink))
			if previous != null and current != null:
				set_camera_focus(focus_point + previous - current)
		drag_previous = event.position
	elif event is InputEventMagnifyGesture:
		camera.size = clampf(camera.size / event.factor, 45, 110)

func map_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton and not event is InputEventScreenTouch:
		return
	var point: Vector2 = event.position / viewport_container.stretch_shrink
	for kind in ["leak", "signal"]:
		var fixed: bool = game.leak_fixed if kind == "leak" else game.signal_fixed
		var marker := world.get_node("LeakMarker" if kind == "leak" else "SignalMarker") as Node3D
		if not fixed and camera.unproject_position(marker.position).distance_to(point) < 36.0 * render_scale / viewport_container.stretch_shrink:
			select_problem(kind)
			return
	var hit = Plane(Vector3.UP, 0).intersects_ray(camera.project_ray_origin(point), camera.project_ray_normal(point))
	if hit == null:
		return
	if placing_stop:
		var nearest := INF
		for row in range(6):
			var distance: float = game.transit.stop_position(row).distance_to(hit)
			if distance < nearest:
				stop_candidate = row
				nearest = distance
		refresh()
		return
	for kind in ["leak", "signal"]:
		var location := map_position(Vector3(-9, 0, 6)) if kind == "leak" else Vector3(-14.4, 0, 0)
		if location.distance_to(hit) < 2.2:
			select_problem(kind)
			return
	for i in range(24):
		var location := map_position(game.plot_position(i))
		if absf(location.x - hit.x) <= 4.6 and absf(location.z - hit.z) <= 4.6:
			selected = i
			selection_kind = "plot"
			active_tab = "build_tab" if game.buildings[i] == "empty" else "district"
			audio.play_ui("select")
			refresh()
			return

func select_problem(kind: String) -> void:
	selection_kind = kind
	selected = -1
	active_tab = "services"
	if audio != null:
		audio.play_ui("select")
	var point := map_position(Vector3(-9, 0, 6)) if kind == "leak" else Vector3(-14.4, 0, 0)
	set_camera_focus(point + Vector3(7, 0, 7))
	refresh()

func select_tab(key: String) -> void:
	active_tab = key
	if key == "services":
		select_problem("leak" if not game.leak_fixed else "signal")
		return
	if key == "build_tab":
		if selected < 0 or game.buildings[selected] != "empty":
			var nearest := INF
			for i in range(24):
				var distance: float = map_position(game.plot_position(i)).distance_to(focus_point)
				if game.buildings[i] == "empty" and distance < nearest:
					selected = i
					nearest = distance
		if selected >= 0:
			selection_kind = "plot"
			set_camera_focus(map_position(game.plot_position(selected)) + Vector3(6, 0, 6))
	else:
		selection_kind = "district_status"
		selected = -1
	refresh()

func close_sheet() -> void:
	placing_stop = false
	selection_kind = ""
	selected = -1
	active_tab = "district"
	refresh()

func switch_language() -> void:
	game.language = "en" if game.language == "ru" else "ru"
	game.save_game()
	refresh()

func clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func refresh() -> void:
	if world == null or camera == null:
		return
	var current_quality: float = game.district_quality()
	if last_quality >= 0 and not is_equal_approx(current_quality, last_quality):
		quality_trend = "↑" if current_quality > last_quality else "↓"
	last_quality = current_quality
	state_button.text = tr_text("Состояние", "Condition")
	state_button.add_theme_stylebox_override("normal", style(Color("d6eafa") if quality_mode else PAPER))
	quality_legend.visible = quality_mode
	for i in range(5):
		quality_legend.find_child("Band%d" % i, true, false).text = "● " + QUALITY_NAMES[0 if game.language == "ru" else 1][i]
	redraw_transit()
	stats.text = t("stats") % [game.budget, game.population(), game.happiness(), game.income()]
	district_label.text = t("district_name")
	budget_label.text = str(game.budget)
	rating_label.text = t("rating") % game.happiness()
	language_button.text = "EN" if game.language == "ru" else "RU"
	for key in nav_buttons:
		var item: Button = nav_buttons[key]
		item.find_child("Caption", true, false).text = t(key)
		item.add_theme_stylebox_override("normal", style(Color("d6eafa") if active_tab == key else PAPER, 12, Color("aad2ee") if active_tab == key else Color("e6e1d7")))
	if game.completed and not completion_observed:
		completion_left = 3.5
	completion_observed = game.completed
	if not game.completed:
		completion_left = 0
	var mission_symbol := "star" if game.completed else ("drop" if not game.leak_fixed else ("hammer" if not game.signal_fixed else "pin"))
	mission_icon.texture = load("res://assets/icons/ui_" + mission_symbol + ".svg")
	var completed_steps := int(game.leak_fixed) + int(game.signal_fixed) + int(game.buildings.has("cafe") or game.buildings.has("park"))
	objective.text = t("mission_done") if game.completed else (t("mission_water") if not game.leak_fixed else (t("mission_signal") if not game.signal_fixed else t("mission_build")))
	objective.get_parent().get_node("MissionCounter").text = "%d / 3" % completed_steps
	progress_bar.value = completed_steps
	redraw_plots()
	scenery.traffic_controller.signal_fixed = game.signal_fixed
	scenery.traffic_controller.update_lights()
	leak_effect.visible = not game.leak_fixed
	world.get_node("LeakMarker").visible = not game.leak_fixed
	world.get_node("SignalMarker").visible = not game.signal_fixed
	build_sheet()
	update_preview()
	update_layout()

func header(title_value: String, icon_key: String = "") -> void:
	var row := hbox(sheet_column)
	if icon_key != "":
		var tile := card(row, Color("e68a3c"))
		icon(tile, icon_key, 42)
	var title := label(30, row, title_value, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var close := button(row, "×", close_sheet)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.custom_minimum_size = Vector2(72, 72)
	close.add_theme_stylebox_override("normal", style(PAPER))

func build_sheet() -> void:
	clear_children(sheet_column)
	clear_children(mode_switcher)
	sheet.add_theme_stylebox_override("panel", style(PAPER, 22))
	sheet.visible = selection_kind != ""
	update_mission_visibility()
	status = null
	transit_stats = null
	if not sheet.visible:
		return
	if selection_kind == "upgrade":
		build_upgrade_sheet()
	elif selection_kind == "district_status":
		build_district_sheet()
	elif selection_kind == "transit":
		build_transit_sheet()
	elif selection_kind in ["signal", "leak"]:
		action_height = 500
		header(t("leak_title") if selection_kind == "leak" else t("signal_title"), "pipe_white")
		var sub := hbox(sheet_column)
		details = label(23, sub, t("leak_subtitle") if selection_kind == "leak" else t("signal_subtitle"))
		details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var chips := mode_switcher
		leak_button = button(chips, t("leak"), select_problem.bind("leak"))
		signal_button = button(chips, t("signal"), select_problem.bind("signal"))
		for chip in [leak_button, signal_button]:
			chip.custom_minimum_size.y = 72
			chip.add_theme_font_size_override("font_size", 22)
		var fixed: bool = game.leak_fixed if selection_kind == "leak" else game.signal_fixed
		var repair_card := card(sheet_column, Color("ebf3fa"))
		var row := hbox(repair_card)
		icon(row, "hammer", 30)
		var content := VBoxContainer.new()
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(content)
		label(23, content, t("fixed") if fixed else t("permanent_repair"), true)
		label(21, content, t("cost") + ": " + str(Catalog.cost("water_leak" if selection_kind == "leak" else "traffic_signal")))
		var route_card := card(sheet_column, Color("f0f0ed"))
		var route_row := hbox(route_card)
		icon(route_row, "pin", 32)
		var route_column := VBoxContainer.new()
		route_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		route_row.add_child(route_column)
		label(23, route_column, t("route_title"), true)
		var route_description := label(20, route_column, t("route_clear") if game.signal_fixed else t("route_delayed"))
		route_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label(19, route_column, t("repair_duration"))
		action_box = VBoxContainer.new()
		sheet_column.add_child(action_box)
		var dispatch_button := button(action_box, t("fixed") if fixed else t("dispatch"), dispatch, true)
		dispatch_button.disabled = fixed or game.job != "" or game.budget < Catalog.cost("water_leak" if selection_kind == "leak" else "traffic_signal")
		status = label(19, sheet_column)
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		update_crew_status()
	elif selected >= 0 and game.buildings[selected] == "empty":
		action_height = 410
		header(t("preview_title") % t(preview_kind).to_lower())
		var choices := mode_switcher
		for kind in ["house", "cafe", "park"]:
			var choose := button(choices, tr_text("Дом", "House") if kind == "house" else t(kind), choose_preview.bind(kind))
			choose.custom_minimum_size.y = 72
			choose.add_theme_font_size_override("font_size", 22)
			if kind == preview_kind:
				choose.add_theme_stylebox_override("normal", style(Color("d6eafa"), 12, Color("aad2ee")))
		var cost_row := hbox(card(sheet_column, Color("eeefec")))
		icon(cost_row, "coin", 26)
		var cost_name := label(23, cost_row, t("cost"), true)
		cost_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label(24, cost_row, str(Catalog.cost(preview_kind)), true)
		var effect_row := hbox(card(sheet_column, Color("eeefec")))
		icon(effect_row, "people", 26)
		var effect_name := label(23, effect_row, tr_text("Вместимость", "Capacity") if preview_kind == "house" else t("comfort"), true)
		effect_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var bonus: int = 8 if preview_kind == "house" else mini(Catalog.level_data(preview_kind).mood + game.placement_bonus(selected, preview_kind), 100 - game.happiness())
		var benefit := label(24, effect_row, "+%d" % bonus, true)
		benefit.add_theme_color_override("font_color", Color("58a56b"))
		action_box = VBoxContainer.new()
		action_box.add_theme_constant_override("separation", 8)
		sheet_column.add_child(action_box)
		var build_button := button(action_box, t("build_confirm"), construct.bind(preview_kind), true)
		build_button.disabled = game.budget < Catalog.cost(preview_kind)
		var cancel := button(action_box, t("cancel"), close_sheet)
		cancel.custom_minimum_size.y = 72
	elif selected >= 0 and Catalog.LEVELS.has(game.buildings[selected]):
		build_building_sheet()
	elif selected >= 0:
		action_height = 190
		header(t(game.buildings[selected]))
		details = label(23, sheet_column, t("occupied") % [t(game.buildings[selected]), selected + 1])
		details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func choose_preview(kind: String) -> void:
	preview_kind = kind
	refresh()

func outline(point: Vector3, color: Color) -> void:
	for z in [-4.5, 4.5]:
		Art.box(highlights, point + Vector3(0, 0.26, z), Vector3(9.1, 0.08, 0.13), color)
	for x in [-4.5, 4.5]:
		Art.box(highlights, point + Vector3(x, 0.26, 0), Vector3(0.13, 0.08, 9.1), color)

func update_preview() -> void:
	if preview != null:
		world.remove_child(preview)
		preview.queue_free()
		preview = null
	clear_children(highlights)
	if placing_stop:
		var point: Vector3 = game.transit.stop_position(stop_candidate)
		for i in range(4):
			var first: Vector3 = point + Vector3(cos(PI * i / 2) * game.Transit.WALK_RADIUS, 0.3, sin(PI * i / 2) * game.Transit.WALK_RADIUS)
			var second: Vector3 = point + Vector3(cos(PI * (i + 1) / 2) * game.Transit.WALK_RADIUS, 0.3, sin(PI * (i + 1) / 2) * game.Transit.WALK_RADIUS)
			var length := first.distance_to(second)
			var edge := Art.box(highlights, (first + second) / 2, Vector3(0.18, 0.08, length), Color("8ed6f8"))
			edge.rotation.y = atan2(second.x - first.x, second.z - first.z)
		for i in range(24):
			if game.buildings[i] == "house" and game.transit.in_range(map_position(game.plot_position(i)), stop_candidate):
				outline(map_position(game.plot_position(i)), Color("a7f384"))
		preview = create_object(world, "bus_stop", "stop_preview", point)
		preview.interaction_area.collision_layer = 0
		return
	if selection_kind == "upgrade" and selected >= 0:
		var point := map_position(game.plot_position(selected))
		outline(point, Color("8ed6f8"))
		preview = create_object(world, game.buildings[selected], "plot_%d" % selected, point)
		preview.set_level(game.building_level(selected) + 1)
		preview.set_serviced(game.has_water(selected) if game.buildings[selected] == "house" else true)
		preview.set_language(game.language)
		preview.interaction_area.collision_layer = 0
		plots.get_node("plot_%d" % selected).visual_root.hide()
		return
	if selection_kind != "plot" or selected < 0:
		return
	var point := map_position(game.plot_position(selected))
	outline(point, Color("8ed6f8"))
	if game.buildings[selected] != "empty":
		return
	preview = create_object(world, preview_kind, "construction_preview", point)
	preview.interaction_area.collision_layer = 0
	preview.set_language(game.language)
	var ghost := StandardMaterial3D.new()
	ghost.albedo_color = Color(0.48, 0.79, 1, 0.48)
	ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost.cull_mode = BaseMaterial3D.CULL_DISABLED
	for item in preview.visual_root.find_children("*", "GeometryInstance3D", true, false):
		item.material_override = ghost
		item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in range(24):
		if i != selected and (game.buildings[i] in ["cafe", "park"] if preview_kind == "house" else game.buildings[i] == "house") and game.building_world(i).distance_to(game.building_world(selected)) < Simulation.AMENITY_RADIUS:
			outline(map_position(game.plot_position(i)), Color("a7f384"))

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
		close_sheet()
	else:
		audio.play_ui("deny")

func update_crew_status() -> void:
	if status == null or not is_instance_valid(status):
		return
	if game.job == "":
		status.text = t("crew_available")
	else:
		var phase_text: String = t("return") if game.job_phase == "return" else (t("travel") if game.route_index < game.route.size() else t("repairing") % ceili(game.repair_left))
		status.text = t("busy") % [t(game.job), phase_text]

func _process(delta: float) -> void:
	if car == null:
		return
	elapsed += delta
	completion_left = maxf(0, completion_left - delta)
	update_mission_visibility()
	if OS.is_debug_build() and OS.has_feature("android"):
		diagnostic_clock += delta
		if diagnostic_clock >= 5:
			diagnostic_clock = 0
			print("FMT_METRICS ", JSON.stringify({"quality": quality, "fps": Engine.get_frames_per_second(), "map_size": str(viewport_container.get_child(0).size), "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "safe_top": safe_top, "safe_bottom": safe_bottom, "selection": selection_kind, "job": game.job, "leak_fixed": game.leak_fixed, "signal_fixed": game.signal_fixed}))
	scenery.traffic_controller.signal_fixed = game.signal_fixed
	scenery.traffic_controller.service_position = car.position
	scenery.traffic_controller.service_active = game.job != ""
	scenery.traffic_controller.vehicles[2].managed = game.transit.active
	scenery.animate(elapsed)
	game.transit.tick(delta, scenery.traffic_controller)
	update_transit_stats()
	var movement_fraction := 1.0
	if game.job != "" and game.route_index < game.route.size():
		var current := map_position(game.vehicle)
		var proposed := map_position(game.proposed_vehicle(delta))
		var intended := current.distance_to(proposed)
		if intended > 0.0001:
			movement_fraction = scenery.traffic_controller.service_travel_distance(current, proposed, delta) / intended
	if game.tick(delta, true, movement_fraction):
		refresh()
	audio.sync(game, camera.size / 2.2, delta)
	update_crew_status()
	car.position = map_position(game.vehicle) + Vector3(0, 0.18, 0)
	if game.job != "" and game.route_index < game.route.size():
		var direction: Vector3 = map_position(game.route[game.route_index]) - car.position
		if direction.length() > 0.01:
			car.rotation.y = atan2(direction.x, direction.z)
			if absf(direction.x) > absf(direction.z):
				car.position.z += signf(direction.x)
			else:
				car.position.x -= signf(direction.z)
	leak_effect.visual_root.position.y = sin(elapsed * 6) * 0.12
	for marker_name in ["LeakMarker", "SignalMarker"]:
		var marker := world.get_node(marker_name) as Node3D
		marker.position.y = 5.2 + sin(elapsed * 2) * 0.15
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

func load_graphics() -> void:
	if OS.has_feature("mobile"):
		quality = "medium"
	if FileAccess.file_exists(settings_path):
		var data = JSON.parse_string(FileAccess.get_file_as_string(settings_path))
		if data is Dictionary and data.get("quality") in ["low", "medium", "high"]:
			quality = data.quality

func set_quality(value: String) -> void:
	if value not in ["low", "medium", "high"]:
		return
	quality = value
	apply_quality()
	var file := FileAccess.open(settings_path + ".tmp", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"quality": quality}))
		file.close()
		DirAccess.rename_absolute(settings_path + ".tmp", settings_path)

func apply_quality() -> void:
	viewport_container.stretch_shrink = {"high": 1, "medium": 2, "low": 3}[quality]
	sunlight.shadow_enabled = quality != "low"
	var viewport := viewport_container.get_child(0) as SubViewport
	viewport.msaa_3d = Viewport.MSAA_DISABLED if quality == "low" else (Viewport.MSAA_2X if quality == "medium" else Viewport.MSAA_4X)
	scenery.traffic_controller.set_active_count(8 if quality == "low" else (16 if quality == "medium" else 24))
	Engine.max_fps = 30 if quality == "low" else 60
	update_layout()

func open_settings() -> void:
	var dialog := AcceptDialog.new()
	dialog.theme = ui_theme
	dialog.title = "Настройки" if game.language == "ru" else "Settings"
	dialog.ok_button_text = t("audio_done")
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	dialog.add_child(column)
	var quality_label := label(24, column, "Качество 3D" if game.language == "ru" else "3D quality", true)
	quality_label.custom_minimum_size.x = 400
	var quality_buttons := VBoxContainer.new()
	quality_buttons.add_theme_constant_override("separation", 8)
	column.add_child(quality_buttons)
	for value in ["low", "medium", "high"]:
		var caption: String = ({"low": "Экономное · A22", "medium": "Сбалансированное", "high": "Высокое · S21+"} if game.language == "ru" else {"low": "Low · A22", "medium": "Balanced", "high": "High · S21+"})[value]
		var choice := button(quality_buttons, caption, set_quality_from_menu.bind(value, dialog))
		choice.name = "Quality_" + value
		choice.set_meta("quality", value)
		choice.add_theme_font_size_override("font_size", 24)
		if value == quality:
			choice.add_theme_stylebox_override("normal", style(Color("d6eafa"), 12, Color("aad2ee")))
	var language_choice := button(column, "English / Русский", switch_language)
	language_choice.custom_minimum_size.y = 72
	var zoom_row := hbox(column)
	button(zoom_row, "−", change_zoom.bind(7.0))
	button(zoom_row, "+", change_zoom.bind(-7.0))
	button(column, t("audio"), open_audio_settings)
	reset_button = button(column, t("reset"), confirm_reset)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	add_child(dialog)
	decorate_dialog(dialog)
	dialog.popup_centered(Vector2i(450, 770))
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
	dialog.get_ok_button().custom_minimum_size.y = 72
	dialog.get_cancel_button().custom_minimum_size.y = 72
	decorate_dialog(dialog)
	dialog.popup_centered()


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
		slider.custom_minimum_size = Vector2(180, 72)
		row.add_child(slider)
		slider.value_changed.connect(func(value: float): audio.set_level(channel, value / 100.0))
	var note := label(14, column)
	note.text = t("music_note")
	note.custom_minimum_size = Vector2(390, 50)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog.confirmed.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	add_child(dialog)
	dialog.get_ok_button().custom_minimum_size.y = 72
	decorate_dialog(dialog)
	dialog.popup_centered(Vector2i(450, 470))


func _exit_tree() -> void:
	if audio != null and is_instance_valid(audio):
		audio.shutdown()

func viewport_point(world_point: Vector3) -> Vector2:
	return viewport_container.get_global_transform_with_canvas() * (camera.unproject_position(world_point) * viewport_container.stretch_shrink)

func set_quality_from_menu(value: String, dialog: Window) -> void:
	set_quality(value)
	for item in dialog.find_children("Quality_*", "Button", true, false):
		var active: bool = item.get_meta("quality") == quality
		item.add_theme_stylebox_override("normal", style(Color("d6eafa") if active else Color("f2f2ee"), 12, Color("aad2ee") if active else Color("dddcd6")))

func decorate_dialog(dialog: AcceptDialog) -> void:
	var buttons: Array[Button] = [dialog.get_ok_button()]
	if dialog is ConfirmationDialog:
		buttons.append(dialog.get_cancel_button())
	for item in buttons:
		item.custom_minimum_size = Vector2(140, 72)
		item.add_theme_font_size_override("font_size", 24)
		item.add_theme_stylebox_override("normal", style(Color("eef1ee"), 12, Color("d6d9d4")))
		item.add_theme_stylebox_override("hover", style(Color("dceafa")))
		item.add_theme_stylebox_override("pressed", style(Color("c5e2f5")))
		for property_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			item.add_theme_color_override(property_name, INK)

func tr_text(ru: String, en: String) -> String:
	return ru if game.language == "ru" else en

func quality_name(score: float) -> String:
	if score < 0:
		return tr_text("Нет данных", "No data")
	return QUALITY_NAMES[0 if game.language == "ru" else 1][Simulation.quality_band(score)]

func quality_color(score: float) -> Color:
	return QUALITY_COLORS[Simulation.quality_band(score)]

func toggle_quality() -> void:
	quality_mode = not quality_mode
	refresh()

func build_district_sheet() -> void:
	action_height = 300
	header(t("district_name"))
	var score: float = game.district_quality()
	var condition := label(24, sheet_column, "● " + quality_name(score) + "  " + quality_trend, true)
	condition.add_theme_color_override("font_color", quality_color(score) if score >= 0 else INK)
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = 12
	bar.show_percentage = false
	bar.value = maxf(0, score)
	bar.add_theme_stylebox_override("fill", style(quality_color(score) if score >= 0 else Color("a5acb0"), 6))
	sheet_column.add_child(bar)
	label(21, sheet_column, t("residents") % [game.population(), game.income()])
	var row := hbox(sheet_column)
	button(row, tr_text("Состояние", "Condition"), toggle_quality)
	button(row, tr_text("Транспорт", "Transit"), open_transit)

func house_problems(index: int) -> Array:
	var data: Dictionary = game.house_quality(index)
	var issues: Array = []
	if not data.water:
		issues.append([tr_text("Нет воды — устраните протечку", "No water — repair the leak"), "leak"])
	if not data.services:
		issues.append([tr_text("Службы задерживаются — почините светофор", "Services delayed — repair the signal"), "signal"])
	if not data.transport:
		issues.append([tr_text("Нет транспорта — подключите остановку к маршруту", "No transit — connect a stop to a route"), "transit"])
	if data.environment < 20:
		issues.append([tr_text("Мало удобств — постройте парк или кафе", "Few amenities — build a park or café"), "build_tab"])
	return issues

func build_house_sheet() -> void:
	build_building_sheet()

func build_building_sheet() -> void:
	action_height = 430
	var kind: String = game.buildings[selected]
	var level_value: int = game.building_level(selected)
	header(t(kind) + " · %d/3" % level_value)
	var issues: Array = []
	if kind == "house":
		var data: Dictionary = game.house_quality(selected)
		var condition := label(25, sheet_column, "● " + quality_name(data.score), true)
		condition.add_theme_color_override("font_color", quality_color(data.score))
		issues = house_problems(selected)
		for i in range(mini(2, issues.size())):
			var issue := label(20, sheet_column, issues[i][0])
			issue.set_meta("house_problem", true)
	else:
		label(22, sheet_column, building_effect(kind, level_value))
	if level_value < 3:
		label(20, sheet_column, tr_text("Следующий: ", "Next: ") + building_effect(kind, level_value + 1))
	else:
		label(20, sheet_column, tr_text("Достигнут третий уровень", "Level three reached"))
	var row := hbox(sheet_column)
	var improve := button(row, tr_text("Улучшить · %d", "Upgrade · %d") % game.upgrade_cost(selected) if level_value < 3 else tr_text("Максимум", "Maximum"), begin_upgrade, true)
	improve.name = "UpgradeButton"
	improve.disabled = level_value >= 3
	var more := button(row, tr_text("Ещё", "More"), open_building_more)
	more.size_flags_horizontal = Control.SIZE_SHRINK_END
	more.custom_minimum_size.x = 100
	more.name = "MoreButton"
	if not issues.is_empty():
		var key: String = issues[0][1]
		var caption: String = (tr_text("Устранить протечку", "Fix the leak") if key == "leak" else tr_text("Починить светофор", "Fix the signal")) if key in ["leak", "signal"] else tr_text("Открыть транспорт", "Open transit") if key == "transit" else t("build_tab")
		button(sheet_column, caption, house_action.bind(key))

func house_action(key: String) -> void:
	if key in ["leak", "signal"]:
		select_problem(key)
	elif key == "transit":
		open_transit()
	else:
		select_tab("build_tab")

func house_details() -> void:
	if selected < 0:
		return
	var data: Dictionary = game.house_quality(selected)
	var dialog := AcceptDialog.new()
	dialog.theme = ui_theme
	dialog.title = t("house")
	dialog.ok_button_text = t("audio_done")
	dialog.dialog_text = tr_text("Качество жизни", "Quality of life") + ": %d/100 · %s\n" % [data.score, quality_name(data.score)]
	dialog.dialog_text += tr_text("Уровень здания: %d/3", "Building level: %d/3") % game.building_level(selected) + "\n"
	dialog.dialog_text += tr_text("Вода: ", "Water: ") + (tr_text("есть", "available") if data.water else tr_text("нет — устраните протечку", "none — repair the leak")) + "\n"
	dialog.dialog_text += tr_text("Службы: ", "Services: ") + (tr_text("доступны", "available") if data.services else tr_text("задержка — почините светофор", "delayed — repair the signal")) + "\n"
	dialog.dialog_text += tr_text("Транспорт: ", "Transit: ") + (tr_text("маршрут соединяет нужные точки", "route connects useful destinations") if data.transport else tr_text("нужны остановки и маршрут", "stops and a route are needed")) + "\n"
	dialog.dialog_text += tr_text("Окружение: ", "Amenities: ") + str(data.environment) + "/30"
	add_child(dialog)
	decorate_dialog(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(490, 390))

func open_transit() -> void:
	selection_kind = "transit"
	selected = -1
	placing_stop = false
	refresh()

func build_transit_sheet() -> void:
	action_height = 420
	header(tr_text("Транспорт", "Transit"))
	transit_stats = label(22, sheet_column)
	transit_stats.visible = not placing_stop
	transit_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	update_transit_stats()
	if not game.completed:
		var locked := label(22, sheet_column, tr_text("Сначала завершите ремонт и постройте кафе или парк.", "Complete the repairs and build a café or park first."))
		locked.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		return
	if game.transit.stops.size() < 2:
		if placing_stop:
			var explanation := label(21, sheet_column, tr_text("Нажмите у дороги на карте. Контур — пешая доступность, зелёные рамки — охваченные дома.", "Tap near the road. The outline shows walking range; green borders mark covered homes."))
			explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			var row := hbox(sheet_column)
			button(row, "‹", change_stop_candidate.bind(-1))
			label(22, row, tr_text("Место ", "Site ") + str(stop_candidate + 1))
			button(row, "›", change_stop_candidate.bind(1))
			var confirm := button(sheet_column, tr_text("Поставить остановку · 40", "Place stop · 40"), confirm_stop, true)
			confirm.disabled = stop_candidate in game.transit.stops or game.budget < 40
			button(sheet_column, t("cancel"), open_transit)
		else:
			button(sheet_column, tr_text("Разместить остановку · 40", "Place a stop · 40"), begin_stop_placement, true)
	else:
		var launch := button(sheet_column, tr_text("Маршрут работает", "Route running") if game.transit.active else tr_text("Запустить автобус · 60", "Start bus · 60"), launch_transit, true)
		launch.disabled = game.transit.active or game.budget < 60
	if placing_stop:
		return
	var note := label(20, sheet_column, tr_text("Один маршрут по западной улице. Остановки парные; автобус делает рейсы между ними. Полезна связь жилья с депо (работа) или кафе.", "One route on the western street, with paired stops and a shuttle bus. Connect homes to the depot (jobs) or a café."))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func begin_stop_placement() -> void:
	placing_stop = true
	stop_candidate = 0 if game.transit.stops.is_empty() else 4
	set_camera_focus(game.transit.stop_position(stop_candidate) + Vector3(7, 0, 7))
	refresh()

func change_stop_candidate(delta: int) -> void:
	stop_candidate = posmod(stop_candidate + delta, 6)
	set_camera_focus(game.transit.stop_position(stop_candidate) + Vector3(7, 0, 7))
	refresh()

func confirm_stop() -> void:
	if game.place_stop(stop_candidate):
		placing_stop = false
		audio.play_ui("success")
	else:
		audio.play_ui("deny")
	refresh()

func launch_transit() -> void:
	if game.start_transit():
		audio.play_ui("success")
	refresh()

func update_transit_stats() -> void:
	if transit_stats == null or not is_instance_valid(transit_stats):
		return
	var metrics: Dictionary = game.transit_metrics()
	transit_stats.text = tr_text("Остановки: %d/2 · Охват: %d жителей\nПолезное сообщение: %d · Загрузка ≈ %d/%d\nЗадержка рейса: %.0f сек. · Расход: 3/12 сек.", "Stops: %d/2 · Coverage: %d residents\nUseful connections: %d · Load ≈ %d/%d\nTrip delay: %.0f sec · Cost: 3/12 sec") % [game.transit.stops.size(), metrics.covered, metrics.served, metrics.load, metrics.capacity, maxf(game.transit.delay, game.transit.last_delay)]
	if game.transit.active and not game.transit.funded:
		transit_stats.text += tr_text("\nНет средств на обслуживание", "\nMaintenance is not funded")

func redraw_transit() -> void:
	var signature := str(game.transit.stops)
	if signature == transit_signature:
		return
	transit_signature = signature
	clear_children(transit_visuals)
	for row in game.transit.stops:
		var stop := create_object(transit_visuals, "bus_stop", "bus_stop_%d" % row, game.transit.stop_position(row))
		stop.interaction_area.collision_layer = 0

func building_effect(kind: String, level_value: int) -> String:
	var data := Catalog.level_data(kind, level_value)
	if kind == "house":
		return tr_text("До %d жителей · доход %d/12 сек. при воде", "Up to %d residents · income %d/12 sec with water") % [data.residents, data.income]
	if kind == "cafe":
		return tr_text("Доход +%d · окружение +%d", "Income +%d · amenities +%d") % [data.income, data.environment]
	return tr_text("Окружение +%d · расход %d/12 сек.", "Amenities +%d · cost %d/12 sec") % [data.environment, -data.income]

func begin_upgrade() -> void:
	if selected < 0 or game.upgrade_cost(selected) <= 0:
		return
	selection_kind = "upgrade"
	set_camera_focus(game.building_world(selected) + Vector3(7, 0, 7))
	refresh()

func cancel_upgrade() -> void:
	selection_kind = "plot"
	refresh()

func build_upgrade_sheet() -> void:
	action_height = 360
	var kind: String = game.buildings[selected]
	var level_value: int = game.building_level(selected)
	header(tr_text("Предпросмотр · %d/3", "Preview · %d/3") % mini(3, level_value + 1))
	label(22, sheet_column, building_effect(kind, mini(3, level_value + 1)))
	var changes: Dictionary = game.project_change(selected)
	label(20, sheet_column, change_summary(changes))
	var confirm := button(sheet_column, tr_text("Улучшить · %d", "Upgrade · %d") % game.upgrade_cost(selected), confirm_upgrade.bind(selected, kind, level_value), true)
	confirm.name = "ConfirmUpgrade"
	confirm.disabled = game.upgrade_cost(selected) <= 0 or game.budget < game.upgrade_cost(selected)
	button(sheet_column, t("cancel"), cancel_upgrade).name = "CancelUpgrade"

func confirm_upgrade(index: int, kind: String, expected_level: int) -> void:
	if game.buildings[index] == kind and game.building_level(index) == expected_level and game.upgrade(index):
		audio.play_ui("success")
		audio.play("build", "Effects", game.plot_position(index))
		selection_kind = "plot"
	else:
		audio.play_ui("deny")
	refresh()

func change_summary(after: Dictionary) -> String:
	var before: Dictionary = game.metrics()
	return tr_text("Жители: %+d · доход: %+d/12 сек.\nРейтинг: %+d · спрос на автобус: %+d", "Residents: %+d · income: %+d/12 sec\nRating: %+d · bus demand: %+d") % [after.population - before.population, after.income - before.income, after.rating - before.rating, after.demand - before.demand]

func open_building_more() -> void:
	if selected < 0:
		return
	var index := selected
	var dialog := AcceptDialog.new()
	dialog.theme = ui_theme
	dialog.title = tr_text("Ещё", "More")
	dialog.ok_button_text = t("cancel")
	var column := VBoxContainer.new()
	dialog.add_child(column)
	if game.buildings[index] == "house":
		button(column, tr_text("Подробнее", "Details"), func():
			dialog.queue_free()
			house_details())
	button(column, tr_text("Снести…", "Demolish…"), func():
		dialog.queue_free()
		request_demolition(index))
	add_child(dialog)
	decorate_dialog(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(420, 250))

func request_demolition(index: int) -> void:
	if not Catalog.LEVELS.has(game.buildings[index]):
		return
	var kind: String = game.buildings[index]
	var level_value: int = game.building_level(index)
	var after: Dictionary = game.project_change(index, true)
	var dialog := ConfirmationDialog.new()
	dialog.name = "DemolitionConfirmation"
	dialog.theme = ui_theme
	dialog.title = tr_text("Подтвердите снос", "Confirm demolition")
	dialog.ok_button_text = tr_text("Снести", "Demolish")
	dialog.cancel_button_text = t("cancel")
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 420
	dialog.add_child(column)
	var message := label(22, column)
	message.custom_minimum_size.x = 420
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.text = t(kind) + tr_text(" · уровень %d\n", " · level %d\n") % level_value
	message.text += tr_text("Здание исчезнет, участок освободится.\n", "The building will be removed, freeing the plot.\n")
	message.text += change_summary(after)
	message.text += tr_text("\nОхват жителей: %d → %d\nПолезное сообщение: %d → %d", "\nResidents covered: %d → %d\nUseful connections: %d → %d") % [game.transit_metrics().covered, after.covered, game.transit_metrics().served, after.served]
	message.text += tr_text("\nСостояние района: %s → %s", "\nDistrict condition: %s → %s") % [quality_name(game.district_quality()), quality_name(after.quality)]
	message.text += tr_text("\nВозврат средств: %d\nБонус соседства и окружение пересчитаются. Отменить снос после подтверждения нельзя.", "\nRefund: %d\nNeighbor bonuses and amenities will be recalculated. Demolition cannot be undone after confirmation.") % game.demolition_refund(index)
	add_child(dialog)
	decorate_dialog(dialog)
	dialog.confirmed.connect(func():
		if game.buildings[index] == kind and game.building_level(index) == level_value and game.demolish(index):
			audio.play_ui("success")
			close_sheet()
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(480, 570))

func update_mission_visibility() -> void:
	mission.visible = not sheet.visible and (not game.completed or completion_left > 0)
