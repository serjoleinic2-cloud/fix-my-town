extends Node3D

const GameObjectScene = preload("res://scenes/objects/game_object.tscn")
const Catalog = preload("res://scripts/asset_catalog.gd")
const AudioManager = preload("res://scripts/audio_manager.gd")
const Simulation = preload("res://scripts/simulation.gd")
const DistrictWorld = preload("res://scripts/district_world.gd")
const TerritoryGrid = preload("res://scripts/territory_grid.gd")
const Art = preload("res://scripts/art.gd")
const CitizenPool = preload("res://scripts/citizen_pool.gd")
const INK = Color("252c38")
const BLUE = Color("258ed2")
const PAPER = Color("fbf9f4")
const SETTINGS_PATH = "user://graphics_settings.json"
var game = Simulation.new(false)
var audio: Node
var camera: Camera3D
var world: Node3D
var scenery: Node3D
var plots: Node3D
var territory_visuals: Node3D
var clean_start_visual: bool = false
var fog_visuals: MultiMeshInstance3D
var car: Node3D
var fire_car: Node3D
var fire_engine_nodes: Dictionary = {}
var selected_fire_id: String = ""
var fire_markers: Dictionary = {}
var notified_fire_ids: Dictionary = {}
var fire_notice: PanelContainer
var fire_notice_label: Label
var fire_notice_left: float = 0.0
var subsidy_dialog: Control
var campaign_dialog: Control
var jam_notice_cooldown: float = 0.0
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
var touch_points: Dictionary = {}
var pinch_distance: float = 0.0
var pinching: bool = false
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
var logistics_visuals: Node3D
var logistics_vehicles: Array[Dictionary] = []
var logistics_visual_signature: String = ""
var stop_candidate_visuals: Node3D
var transit_signature: String = ""
var transit_stats: Label
var citizen_pool: Node3D
var stop_candidate: int = 0
var placing_stop: bool = false
var moving_stop_index: int = -1
var selected_stop_index: int = -1
var safe_left: float = 16.0
var safe_right: float = 16.0
var territory_tool: String = "clear"
var service_type: String = "fire_station"
var catalog_category: String = "residential"
var catalog_screen_mode: String = "categories"
var selected_catalog_type: String = ""
var catalog_target_plot: int = -1
var catalog_grid_target := Vector2i(-1, -1)
var road_selected_cell := Vector2i(-1, -1)
var road_piece_type := "auto"
var construction_root: Node3D
var construction_objects: Dictionary = {}
var construction_bar_fill: MeshInstance3D
var catalog_target_road := Vector2i(-1, -1)
var catalog_scroll: ScrollContainer
var catalog_scroll_dragging: bool = false
var catalog_drag_start := Vector2.ZERO
var catalog_drag_last := Vector2.ZERO
var catalog_drag_moved: bool = false
var selected_vehicle_type: String = ""
var territory_cell := Vector2i(-1, -1)
var territory_signature: String = ""
var grid_selected_id: String = ""
var last_quality: float = -1
var quality_trend: String = "→"
const QUALITY_COLORS = [Color("df6356"), Color("e9994f"), Color("d8bd57"), Color("9fc76e"), Color("59a675")]
const QUALITY_NAMES = [["Критическое", "Неблагополучное", "Удовлетворительное", "Благополучное", "Отличное"], ["Critical", "Struggling", "Satisfactory", "Good", "Excellent"]]
const CATALOG_CATEGORIES := ["residential", "commercial", "infrastructure", "services", "landscaping"]
const CATALOG_ITEMS := {
	"residential": ["house", "elite_residence"],
	"commercial": ["cafe", "park", "business_tower"],
	"infrastructure": ["clear", "logistics_center", "warehouse"],
	"services": ["fire_station", "police_station", "hospital", "depot"],
	"landscaping": ["lawn", "flower_bed", "street_tree", "bush"]
}
const TEXT = {
	"title": ["FIX MY TOWN · Мэрия", "FIX MY TOWN · City Hall"],
	"goal": ["1. Почините светофор и протечку\n2. Постройте кафе или парк", "1. Repair the signal and water leak\n2. Build a café or park"],
	"done": ["Квартал ожил! Сценарий завершён.\nПродолжайте обустраивать район.", "The neighborhood is thriving! Scenario complete.\nKeep improving your district."],
	"stats": ["Бюджет  %d   •   Жители  %d\nНастроение  %d%%   •   Доход  +%d / 12 сек.", "Budget  %d   •   Residents  %d\nHappiness  %d%%   •   Income  +%d / 12 sec"],
	"signal": ["Светофор", "Traffic signal"], "leak": ["Протечка", "Water leak"],
	"inspection": ["Проверка обслуживания", "Service inspection"],
	"fire": ["Пожар", "Fire"],
	"signal_info": ["Сломанный перекрёсток\nЗадерживает машину. Ремонт: %d монет.", "Broken intersection\nSlows the service van. Repair: %d coins."],
	"leak_info": ["Протечка у жилого дома\nСнижает заселение и доход. Ремонт: %d монет.", "Leak near a residential building\nReduces occupancy and income. Repair: %d coins."],
	"repair": ["Отправить бригаду", "Dispatch crew"], "fixed": ["Обслуживание восстановлено", "Service restored"],
	"busy": ["Бригада: %s • %s", "Crew: %s • %s"], "travel": ["в пути", "on the way"], "repairing": ["ремонт %d сек.", "repair %d sec"], "return": ["возвращается", "returning"], "idle": ["Бригада свободна • выбор участка на карте", "Crew ready • select a plot on the map"],
	"empty": ["Участок %d • доступ к дороге\nБонус зависит от соседних домов и объектов.", "Plot %d • road access\nBonus depends on nearby homes and amenities."],
	"cafe": ["Кафе", "Café"], "park": ["Парк", "Park"], "house": ["Жилой дом", "Residential home"], "depot": ["Дом рабочих", "Workers depot"],
	"city_hall": ["Городской центр", "City Hall"],
	"logistics_center": ["Логистический центр", "Logistics center"],
	"warehouse": ["Склад", "Warehouse"],
	"elite_residence": ["Элитная резиденция", "Elite residence"], "business_tower": ["Деловая башня", "Business tower"],
	"repair_van": ["Ремонтная машина", "Repair van"], "fire_engine": ["Пожарная машина", "Fire engine"],
	"build": ["%s · %d\nНастроение +%d", "%s · %d\nHappiness +%d"],
	"occupied": ["%s • участок %d", "%s • plot %d"],
	"reset": ["Новый город", "New city"], "confirm": ["Начать новый город?", "Start a new city?"],
	"reset_info": ["Текущий прогресс будет удалён. Вы начнёте с начального проблемного квартала.", "Current progress will be deleted. You will start with the initial problem district."],
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
 "next_goal_clear": ["Следующая цель: расчистить лес и подготовить место для новой дороги.", "Next goal: clear the forest and prepare a place for a new road."],
 "next_goal_road": ["Следующая цель: проложить соединённую дорогу с поворотом.", "Next goal: build a connected road with a turn."],
 "next_goal_house": ["Следующая цель: построить дом у новой дороги.", "Next goal: build a home beside the new road."],
 "next_goal_expand": ["Следующая цель: развивайте город и выбирайте следующий участок.", "Next goal: keep expanding the city and choose the next plot."],
 "build_confirm": ["Построить", "Build"], "nearby_bonus": ["Влияние на соседние дома", "Nearby homes benefit"],
 "residents": ["Жители: %d   •   Доход: +%d", "Residents: %d   •   Income: +%d"],
 "construction_mode": ["Строительство", "Construction"],
 "route_title": ["Маршрут службы", "Service route"],
 "route_delayed": ["Сломанный светофор задерживает машину", "The broken signal delays the vehicle"],
 "route_clear": ["Перекрёсток исправен: путь свободен", "Signal repaired: the route is clear"],
	 "repair_duration": ["Работы на месте: 4 сек.", "On-site work: 4 sec"],
		"fire_title": ["Пожар в здании", "Building fire"],
	 "fire_call": ["Вызвать пожарных", "Call firefighters"],
	 "fire_engine_available": ["Пожарная машина доступна", "Fire engine available"],
	 "fire_engine_unavailable": ["Нет свободной машины или дорожного пути", "No available engine or connected road route"],
	 "fire_warning": ["Предупреждение · возгорание через %d сек.", "Warning · fire starts in %d sec"],
	 "fire_burning": ["Опасность %d/3 · огонь повреждает дом", "Danger %d/3 · fire is damaging the home"],
	 "fire_neighbor": ["Соседний дом под угрозой · %d сек.", "Nearby home at risk · %d sec"],
	 "fire_spread": ["Огонь перекинулся на соседний дом", "The fire has spread to the neighboring home"],
	 "fire_damaged": ["Повреждения здания: %d%%", "Building damage: %d%%"],
	 "fire_extinguished": ["Пожар потушен · восстановить дом за %d", "Fire extinguished · restore home for %d"],
	 "fire_station": ["Пожарная часть", "Fire station"],
	 "police_station": ["Полицейский участок", "Police station"],
	 "hospital": ["Больница", "Hospital"],
	"service_depot": ["Дом рабочих", "Workers depot"],
	"clear": ["Расчистка леса", "Clear forest"],
	"road": ["Дорога", "Road"],
	"lawn": ["Газон", "Lawn"],
	"flower_bed": ["Клумба", "Flower bed"],
	"street_tree": ["Дерево", "Tree"],
	"bush": ["Кустарники", "Bushes"],
	"catalog_title": ["Строительство", "Construction catalog"],
	"close": ["Скрыть", "Hide"],
	"construction_build": ["Идут строительные работы", "Construction in progress"],
	"construction_demolish": ["Идёт снос", "Demolition in progress"],
	"construction_upgrade": ["Идёт модернизация здания", "Building upgrade in progress"],
	"construction_duration": ["Рабочая техника выполняет короткую задачу. Прогресс сохраняется; вне игры время остановлено.", "The work crew completes a short task. Progress is saved and pauses while the game is closed."],
	"construction_status": ["Идут работы", "Work in progress"],
	"service": ["Службы", "Services"],
	"forest": ["Лес", "Forest"],
	"free": ["Свободно", "Free"],
	"road_state": ["Дорога", "Road"],
	"occupied_state": ["Занято", "Occupied"],
	"work_signs": ["Дорожные работы", "Road works"],
	"catalog_level": ["Уровень города: %d", "City level: %d"],
	"catalog_locked": ["Откроется на уровне %d", "Unlocks at level %d"],
	"catalog_size": ["Участок: %s", "Lot: %s"],
	"catalog_requires": ["Требования: %s", "Requirements: %s"],
	"catalog_price": ["Цена: %d", "Cost: %d"],
	"catalog_requirement_house": ["Расчищенные клетки 2×2 и связь с дорогой города", "Cleared 2×2 cells connected to a city road"],
	"catalog_requirement_logistics_center": ["Этап 6 · один центр на город; к нему подключаются склады", "Stage 6 · one center per city; warehouses connect to it"],
	"catalog_requirement_warehouse": ["Сначала постройте логистический центр; число и уровень складов зависят от его уровня", "Build a logistics center first; warehouse count and level depend on its level"],
	"catalog_requirement_city_hall": ["Отмеченный центральный участок 2×2; сначала расчистите его", "Highlighted central 2×2 site; clear it first"],
	"catalog_requirement_landscape": ["Одна свободная расчищенная клетка", "One cleared free cell"],
	"catalog_requirement_clear": ["Выберите лесную клетку", "Select a forest cell"],
	"catalog_requirement_road": ["Свободная клетка рядом с соединённой дорогой", "Free cell beside a connected road"],
	"catalog_requirement_legacy": ["Свободный участок старого квартала", "A vacant lot in the existing district"],
	"catalog_footprint_small": ["1 клетка", "1 cell"],
	"catalog_footprint_large": ["2×2 клетки", "2×2 cells"],
	"catalog_footprint_renewal": ["4×4 клетки · снос двух домов", "4×4 cells · replace two homes"],
	"catalog_footprint_legacy": ["1 участок · 9×9 м", "1 lot · 9×9 m"],
	"category_residential": ["Жилые", "Residential"],
	"category_commercial": ["Коммерция", "Commercial"],
	"category_infrastructure": ["Инфраструктура", "Infrastructure"],
	"category_services": ["Службы", "Services"],
	"category_landscaping": ["Благоустройство", "Landscaping"],
	"place_catalog_item": ["Разместить: %s", "Place: %s"],
	"selected_cell": ["Выбрана клетка: %s", "Selected cell: %s"],
	"cell_unselected": ["Нажмите на карту и выберите допустимое место", "Tap the map and choose a valid location"],
	"road_demolition_safe": ["После сноса все здания и остановки сохранят связь с городом.", "All buildings and stops remain connected after demolition."],
	"road_demolition_blocked": ["Снос отсоединит здания, остановку или активный маршрут.", "Demolition would disconnect buildings, a stop, or an active route."],
	"demolish_road": ["Снести дорогу", "Demolish road"],
	"demolish_building": ["Снести", "Demolish"],
	"demolish_confirm_title": ["Подтвердить снос", "Confirm demolition"],
	"demolish_confirm_body": ["Здание будет удалено, жители и доход пересчитаются. Освободившийся участок можно благоустроить.", "The building will be removed; population and income will update. You can landscape the free lot."],
	"road_confirm_body": ["Дорога будет удалена. Подключение города будет проверено ещё раз перед действием.", "The road will be removed. City connectivity is checked again before demolition."],
		"fire_dispatching": ["Пожарная машина выехала", "Fire engine dispatched"]
}

func t(key: String) -> String:
	return TEXT[key][0 if game.language == "ru" else 1]

func flat_button(parent: Control, caption: String, action: Callable, prominent: bool = false) -> Button:
	var item := button(parent, caption, action, prominent)
	item.add_theme_stylebox_override("normal", style(Color("e8eee8") if not prominent else Color("3e8b70"), 5, Color("b8c5bb")))
	item.add_theme_stylebox_override("hover", style(Color("d9e7dd") if not prominent else Color("34785f"), 5, Color("8aa997")))
	item.add_theme_stylebox_override("pressed", style(Color("cbdccf") if not prominent else Color("28644f"), 5, Color("6b8c78")))
	return item

func _ready() -> void:
	# Read only the layout version before restoring. Previous showcase saves are
	# intentionally discarded at ordinary startup, so do not construct their
	# legacy road grid even transiently. load_game() still performs the explicit
	# legacy migration when a caller actually requests loading that save.
	var restored := false
	if FileAccess.file_exists(game.save_path):
		var save_file := FileAccess.open(game.save_path, FileAccess.READ)
		if save_file != null:
			var save_header: Variant = JSON.parse_string(save_file.get_as_text())
			if save_header is Dictionary and int(save_header.get("city_layout_version", 0)) >= 3:
				restored = game.load_game()
	# Version 3 removes both the former showcase layout and the tiled plot-like
	# terrain presentation. It is a one-time migration; later launches preserve
	# the player's new city.
	var clean_start_required: bool = not restored or game.city_layout_version < 3
	if clean_start_required:
		game.start_empty_city()
		game.save_game()
	elif game.empty_city_mode and game.all_buildings().is_empty() and (game.leak_fixed or game.signal_fixed):
		# Normalize early test builds that marked nonexistent legacy services as repaired.
		game.leak_fixed = false
		game.signal_fixed = false
		game.save_game()
	if game.empty_city_mode:
		var starting_hall: Dictionary = game.territory.building_by_id("pine_district_city_hall_12_19")
		if not starting_hall.is_empty():
			focus_point = game.territory.building_center(starting_hall)
	for identifier in game.fires:
		notified_fire_ids[str(identifier)] = true
	if OS.is_debug_build() and OS.has_feature("android"):
		print("FMT_RESTORE ", JSON.stringify({"budget": game.budget, "job": game.job, "phase": game.job_phase, "target": game.target_instance_id, "vehicle": str(game.vehicle), "route_index": game.route_index, "expansion": game.territory.buildings.filter(func(entry): return not entry.has("legacy_plot"))}))
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
		item.size.x = maxf(100, screen.size.x - safe_left - safe_right - 64)
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
	# Обновление панели удаляет нажатую кнопку. Выполняем действие после
	# завершения GUI-dispatch, чтобы Godot не опрашивал уже снятый с дерева узел.
	item.pressed.connect(callback, CONNECT_DEFERRED)
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
	var top_row := hbox(hud, 4)
	var name_card := card(top_row)
	name_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_card.add_theme_stylebox_override("panel", style(PAPER, 12))
	district_label = label(20, name_card, "", true)
	district_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	district_label.clip_text = false
	var budget_card := card(top_row)
	budget_card.custom_minimum_size.x = 120
	budget_card.add_theme_stylebox_override("panel", style(PAPER, 12))
	var budget_row := hbox(budget_card, 5)
	icon(budget_row, "coin", 25)
	budget_label = label(22, budget_row, "", true)
	var rating_card := card(top_row)
	rating_card.custom_minimum_size.x = 132
	rating_card.add_theme_stylebox_override("panel", style(PAPER, 12))
	var rating_row := hbox(rating_card, 5)
	icon(rating_row, "star", 26)
	rating_label = label(18, rating_row, "", true)
	var tools := VBoxContainer.new()
	tools.name = "MapTools"
	tools.add_theme_constant_override("separation", 4)
	screen.add_child(tools)
	var controls_row := HBoxContainer.new()
	controls_row.name = "MapControlsRow"
	controls_row.add_theme_constant_override("separation", 4)
	tools.add_child(controls_row)
	language_button = button(screen, "EN", switch_language)
	language_button.hide()
	audio_button = button(controls_row, "☷", open_settings)
	state_button = button(controls_row, "", toggle_quality)
	state_button.add_theme_font_size_override("font_size", 18)
	var bus_row := HBoxContainer.new()
	bus_row.name = "BusControlRow"
	bus_row.add_theme_constant_override("separation", 4)
	tools.add_child(bus_row)
	var bus_alignment := Control.new()
	bus_alignment.name = "BusAlignmentSpacer"
	# Align the BUS button under the second map action (State), with its 4 px row gap.
	bus_alignment.custom_minimum_size = Vector2(103, 62)
	bus_row.add_child(bus_alignment)
	transit_button = button(bus_row, "BUS", open_transit)
	mode_switcher.hide()
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
	for map_button in [audio_button, state_button, transit_button]:
		map_button.custom_minimum_size = Vector2(68, 62)
		map_button.add_theme_font_size_override("font_size", 17)
		map_button.add_theme_stylebox_override("normal", style(Color(0.98, 0.97, 0.94, 0.93), 14))
	state_button.add_theme_font_size_override("font_size", 15)
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
	fire_notice = card(screen, Color("fff5ec"))
	fire_notice.name = "FireDispatchNotice"
	fire_notice.add_theme_stylebox_override("panel", style(Color("fff5ec"), 14, Color("db7651")))
	fire_notice_label = label(22, fire_notice, "", true)
	fire_notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fire_notice.hide()
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
	safe_left = maxf(16, safe_override.x)
	safe_right = maxf(16, safe_override.z)
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
	var tools_width := maxf(220, tools.get_combined_minimum_size().x)
	tools.position = Vector2(size_value.x - safe_right - tools_width, safe_top + 84)
	tools.custom_minimum_size.x = 220
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
	if game.empty_city_mode:
		mission.position.y -= 22
		mission.size.y = 110
	fire_notice.position = Vector2(safe_left, tools.position.y + tools.size.y + 8)
	fire_notice.size = Vector2(size_value.x - safe_left - safe_right, 72)
	var service_mode: bool = selection_kind in ["signal", "leak", "fire"]
	var fullscreen_menu: bool = selection_kind in ["catalog", "catalog_detail", "catalog_legacy_placement", "land_cell", "grid_house", "grid_upgrade", "grid_road", "district_status", "construction_job"]
	navbar.visible = not service_mode
	hud.visible = not fullscreen_menu
	tools.visible = not fullscreen_menu
	if fullscreen_menu:
		sheet.position = Vector2.ZERO
		sheet.size = size_value
		var full_style := style(Color("f7f7f2"), 0)
		full_style.content_margin_left = safe_left + 18
		full_style.content_margin_right = safe_right + 18
		full_style.content_margin_top = safe_top + 18
		full_style.content_margin_bottom = safe_bottom + 18
		sheet.add_theme_stylebox_override("panel", full_style)
		sheet_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sheet_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
		navbar.hide()
		fire_notice.hide()
	elif service_mode:
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
	if size_value.x < 620 or mode_switcher.get_child_count() >= 4:
		mode_switcher.position = Vector2(safe_left, tools.position.y + tools.size.y + 8)
		mode_switcher.size = Vector2(size_value.x - safe_left - safe_right, 72)
		mode_switcher.add_theme_constant_override("separation", 5)
		var mode_buttons := mode_switcher.get_children()
		var mode_button_width := maxf(72, (mode_switcher.size.x - 5.0 * maxf(0, mode_buttons.size() - 1)) / maxf(1, mode_buttons.size()))
		for choice in mode_switcher.get_children():
			if choice is Button:
				choice.custom_minimum_size.x = mode_button_width
				choice.add_theme_font_size_override("font_size", 13)
	else:
		mode_switcher.position = Vector2(safe_left, safe_top + 92)
		mode_switcher.size = Vector2(minf(360, size_value.x - safe_left - safe_right - tools_width - 16), 72)
	updating_layout = false
	layout_subsidy_offer()

func map_position(point: Vector3) -> Vector3:
	return DistrictWorld.world_position(point)

func build_world() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 52 if game.empty_city_mode else 76
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
	var empty_city: bool = game.empty_city_mode or (game.buildings.all(func(kind: String) -> bool: return kind == "empty") and game.territory.buildings.is_empty())
	clean_start_visual = empty_city
	if empty_city:
		# A clean city gets an empty traffic controller only. Do not instantiate
		# the legacy roads, intersection signals, traffic, lamps, or showcase trees.
		scenery = DistrictWorld.new()
		world.add_child(scenery)
		scenery.initialize_empty()
	else:
		scenery = DistrictWorld.new()
		world.add_child(scenery)
		scenery.build()
	var backdrop := Node3D.new()
	backdrop.name = "NeighborhoodBackdrop"
	world.add_child(backdrop)
	# Decorative background houses are only shown for an occupied legacy city.
	# A fresh test city must really be empty, including the distant backdrop.
	var has_legacy_buildings: bool = game.buildings.any(func(kind: String) -> bool: return kind != "empty")
	if has_legacy_buildings:
		for x in [-50.4, -36]:
			for z in [-36, -21.6, -7.2, 7.2, 21.6, 36]:
				var kind := "park" if x == -36 and z == -7.2 else "house"
				var object := create_object(backdrop, kind, "backdrop_%s_%s" % [x, z], Vector3(x, 0, z))
				object.interaction_area.collision_layer = 0
				object.set_serviced(true)
				Art.box(object, Vector3(0, 0.02, 0), Vector3(9, 0.12, 9), Color("91a66f"))
	plots = Node3D.new()
	world.add_child(plots)
	territory_visuals = Node3D.new()
	territory_visuals.name = "ExpansionTerritory"
	world.add_child(territory_visuals)
	build_fog_overlay()
	if game.empty_city_mode and not game.has_city_hall():
		create_city_hall_site_guide()
	construction_root = Node3D.new()
	construction_root.name = "ConstructionWorksite"
	world.add_child(construction_root)
	if game.legacy_problem_available("signal"):
		signal_object = scenery.traffic_controller.get_problem_signal()
		make_marker("SignalMarker", Vector3(-14.4, 5, 0))
	if game.legacy_problem_available("leak"):
		leak_effect = create_object(world, "water_leak", "leak_0", map_position(Vector3(-9, 0.24, 6)))
		make_marker("LeakMarker", map_position(Vector3(-9, 5, 6)))
	if game.job != "" and game.job != "fire":
		car = create_object(world, "repair_van", "crew_0", map_position(game.vehicle))
	if game.job == "fire" or not game.fire_assignments().is_empty():
		fire_car = create_object(world, "fire_engine", "fire_engine_0", map_position(game.vehicle))
		fire_car.set_language(game.language)
	transit_visuals = Node3D.new()
	world.add_child(transit_visuals)
	logistics_visuals = Node3D.new()
	logistics_visuals.name = "LogisticsVehicles"
	world.add_child(logistics_visuals)
	stop_candidate_visuals = Node3D.new()
	stop_candidate_visuals.name = "StopCandidates"
	world.add_child(stop_candidate_visuals)
	highlights = Node3D.new()
	world.add_child(highlights)
	citizen_pool = CitizenPool.new()
	citizen_pool.name = "CitizenPool"
	world.add_child(citizen_pool)
	citizen_pool.setup(game, quality, Callable(self, "map_position"), scenery.traffic_controller)

func create_object(parent: Node3D, type_id: String, persistent_id: String, point: Vector3) -> Node3D:
	var object := GameObjectScene.instantiate()
	object.name = persistent_id
	parent.add_child(object)
	object.setup(type_id, persistent_id)
	object.position = point
	return object

func create_city_hall_site_guide() -> void:
	var guide := Node3D.new()
	guide.name = "CityHallSiteGuide"
	world.add_child(guide)
	var point: Vector3 = game.territory.cell_world(TerritoryGrid.CITY_HALL_SITE.x, TerritoryGrid.CITY_HALL_SITE.y) + Vector3(TerritoryGrid.CELL_SIZE * 0.5, 0.12, TerritoryGrid.CELL_SIZE * 0.5)
	var ghost_hall := create_object(guide, "city_hall", "CityHallSitePreview", point)
	make_ghost(ghost_hall, Color("78c8ed"))
	ghost_hall.interaction_area.collision_layer = 0
	var label_3d := Label3D.new()
	label_3d.name = "CityHallSiteLabel"
	label_3d.text = tr_text("МЭРИЯ · ОЧИСТИТЕ 2×2", "CITY HALL · CLEAR 2×2")
	label_3d.font_size = 56
	label_3d.pixel_size = 0.009
	label_3d.position = point + Vector3(0, 8.4, 0)
	label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_3d.no_depth_test = true
	world.add_child(label_3d)

func sync_construction_site() -> void:
	if construction_root == null:
		return
	if game.construction_job.is_empty():
		clear_children(construction_root)
		construction_objects.clear()
		construction_bar_fill = null
		return
	var task: Dictionary = game.construction_job
	var raw_position: Array = task.get("position", [0.0, 0.0, 0.0])
	var raw_digger: Array = task.get("excavator_position", raw_position)
	var raw_truck: Array = task.get("truck_position", raw_position)
	if raw_position.size() != 3 or raw_digger.size() != 3 or raw_truck.size() != 3:
		return
	var site := Vector3(float(raw_position[0]), float(raw_position[1]), float(raw_position[2]))
	if construction_objects.is_empty():
		var digger := create_object(construction_root, "work_vehicle", "ConstructionWorkVehicle", Vector3(float(raw_digger[0]), float(raw_digger[1]), float(raw_digger[2])))
		digger.interaction_area.collision_layer = 0
		var truck := create_object(construction_root, "dump_truck", "ConstructionDumpTruck", Vector3(float(raw_truck[0]), float(raw_truck[1]), float(raw_truck[2])))
		truck.interaction_area.collision_layer = 0
		truck.rotation.y = PI / 2
		var signs := Node3D.new()
		signs.name = "WorkSigns"
		construction_root.add_child(signs)
		var work_sign_positions: Array[Vector3] = []
		var nearest_road: Vector2i = game.territory.nearest_road(site)
		var road_point: Vector3 = game.territory.cell_world(nearest_road.x, nearest_road.y) if nearest_road.x >= 0 else site
		var sign_axis := Vector3(0.0, 0.0, 1.0) if game.territory.road_orientation(nearest_road.x, nearest_road.y) == "horizontal" else Vector3(1.0, 0.0, 0.0)
		for side in [-1, 1]:
			var sign_position: Vector3 = road_point + Vector3(0, 0, float(side) * 1.0) if sign_axis.z != 0 else road_point + Vector3(float(side) * 1.0, 0, 0)
			work_sign_positions.append(sign_position)
			Art.cylinder(signs, sign_position + Vector3(0, 0.65, 0), 0.1, 1.3, Color("e9a839"), 0.0, 8)
			var plate := Art.box(signs, sign_position + Vector3(0, 1.48, 0), Vector3(1.4, 1.0, 0.16), Color("f0bd45"))
			plate.rotation.z = 0.08 * side
			var sign_text := Label3D.new()
			sign_text.text = "РАБОТЫ" if game.language == "ru" else "WORKS"
			sign_text.font_size = 48
			sign_text.pixel_size = 0.008
			sign_text.position = sign_position + Vector3(0, 1.5, 0.1)
			sign_text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			signs.add_child(sign_text)
		construction_objects = {"digger": digger, "truck": truck, "sign_positions": work_sign_positions}
	var active_digger: Node3D = construction_objects.get("digger")
	var active_truck: Node3D = construction_objects.get("truck")
	if active_digger != null and is_instance_valid(active_digger):
		active_digger.position = Vector3(float(raw_digger[0]), float(raw_digger[1]), float(raw_digger[2]))
	if active_truck != null and is_instance_valid(active_truck):
		active_truck.position = Vector3(float(raw_truck[0]), float(raw_truck[1]), float(raw_truck[2]))
	var beacon: Node = active_digger.visual_root.find_child("BeaconLamp", true, false) if active_digger != null else null
	if beacon != null:
		beacon.visible = fposmod(elapsed, 0.7) < 0.35

func make_marker(marker_name: String, point: Vector3) -> void:
	var existing := world.get_node_or_null(marker_name)
	if existing != null:
		return
	var marker := Sprite3D.new()
	marker.name = marker_name
	marker.texture = load("res://assets/icons/problem_marker.svg")
	marker.pixel_size = 0.035
	marker.position = point
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.no_depth_test = true
	world.add_child(marker)

func update_fire_visuals() -> void:
	for identifier in fire_markers.keys():
		if not game.fires.has(identifier):
			var old_marker: Node = fire_markers[identifier]
			if is_instance_valid(old_marker):
				old_marker.queue_free()
			fire_markers.erase(identifier)
	for raw_id in game.fires.keys():
		var identifier := str(raw_id)
		var marker: Sprite3D = fire_markers.get(identifier)
		if marker == null or not is_instance_valid(marker):
			marker = Sprite3D.new()
			marker.name = "Incident_" + identifier
			marker.texture = load("res://assets/icons/fire_marker.svg")
			marker.pixel_size = 0.06
			marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			marker.no_depth_test = true
			var flame := Sprite3D.new()
			flame.name = "FlameAndSmoke"
			flame.texture = load("res://assets/icons/fire_effect.svg")
			flame.position = Vector3(0, -2.5, 0.05)
			flame.pixel_size = 0.037
			flame.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			flame.no_depth_test = true
			marker.add_child(flame)
			var smoke := AnimatedSprite3D.new()
			smoke.name = "AnimatedSmoke"
			var smoke_frames := SpriteFrames.new()
			smoke_frames.add_animation("smoke")
			smoke_frames.set_animation_speed("smoke", 5.0)
			smoke_frames.set_animation_loop("smoke", true)
			for frame_index in range(1, 5):
				smoke_frames.add_frame("smoke", load("res://assets/icons/smoke_%d.svg" % frame_index))
			smoke.sprite_frames = smoke_frames
			smoke.animation = "smoke"
			smoke.position = Vector3(0.38, -0.45, 0.08)
			smoke.pixel_size = 0.045
			smoke.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			smoke.no_depth_test = true
			marker.add_child(smoke)
			smoke.play("smoke")
			var danger := Label3D.new()
			danger.name = "DangerLevel"
			danger.position = Vector3(0, 1.45, 0.1)
			danger.font_size = 48
			danger.outline_size = 12
			danger.modulate = Color.WHITE
			danger.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			marker.add_child(danger)
			world.add_child(marker)
		fire_markers[identifier] = marker
		if not notified_fire_ids.has(identifier):
			notified_fire_ids[identifier] = true
			fire_notice_left = 4.0
			fire_notice_label.text = tr_text("911 · Пожар. Нажмите на дом, чтобы вызвать пожарных.", "911 · Fire. Tap the house to call firefighters.")
			fire_notice.show()
			if audio != null:
				audio.play("radio_call", "Effects", game.building_world_for_id(identifier))
		marker.position = game.building_world_for_id(identifier) + Vector3(0, 7.0 + sin(elapsed * 2.6) * 0.18, 0)
		marker.modulate = Color("f17a3d") if game.fire_severity(identifier) == 1 else (Color("e75439") if game.fire_severity(identifier) == 2 else Color("c92e32"))
		marker.get_node("DangerLevel").text = "%d/3" % game.fire_severity(identifier)
		var flame_effect := marker.get_node("FlameAndSmoke") as Sprite3D
		flame_effect.position.y = -2.5 + sin(elapsed * 8.0 + float(game.fire_severity(identifier))) * 0.12
		flame_effect.scale = Vector3.ONE * (1.0 + sin(elapsed * 11.0) * 0.06)
		var smoke_effect := marker.get_node("AnimatedSmoke") as AnimatedSprite3D
		smoke_effect.position.y = -0.45 + sin(elapsed * 1.7 + float(game.fire_severity(identifier))) * 0.18
		smoke_effect.scale = Vector3.ONE * (1.0 + sin(elapsed * 2.3) * 0.08)

func redraw_plots() -> void:
	var empty_city: bool = game.empty_city_mode or (game.buildings.all(func(kind: String) -> bool: return kind == "empty") and game.territory.buildings.is_empty())
	plots.visible = not empty_city
	if empty_city:
		clear_children(plots)
		redraw_territory()
		return
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
		object.set_ruined(game.is_ruined("pine_district_legacy_%d" % i))
		object.visual_root.visible = true
		object.set_serviced(game.has_water(i) if kind == "house" else true)
		var base := object.get_node("PlotBase") as MeshInstance3D
		base.material_override = Art.material(quality_color(game.house_quality(i).score) if quality_mode and kind == "house" else (Color("91a66f") if kind != "empty" else Color("9cab7a")))
		object.set_language(game.language)
	redraw_territory()

func is_in_compact_road_square(col: int, row: int) -> bool:
	# A 2x2 cleared road block is an open paved square, not four
	# independent intersections. Suppress junction markings inside it.
	for origin_x in [col - 1, col]:
		for origin_z in [row - 1, row]:
			var all_roads := true
			for dx in [0, 1]:
				for dz in [0, 1]:
					if game.territory.state_at(origin_x + dx, origin_z + dz) != "road":
						all_roads = false
			if all_roads:
				# Do not treat a 2x2 part of a larger 3x2/2x3 block as an
				# isolated square: its outer roads still need their markings.
				var perimeter_open := true
				for dx in [-1, 0, 1, 2]:
					if game.territory.state_at(origin_x + dx, origin_z - 1) == "road" or game.territory.state_at(origin_x + dx, origin_z + 2) == "road":
						perimeter_open = false
				for dz in [0, 1]:
					if game.territory.state_at(origin_x - 1, origin_z + dz) == "road" or game.territory.state_at(origin_x + 2, origin_z + dz) == "road":
						perimeter_open = false
				if perimeter_open:
					return true
	return false

func build_fog_overlay() -> void:
	fog_visuals = MultiMeshInstance3D.new()
	fog_visuals.name = "FogOfWar"
	fog_visuals.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(fog_visuals)

func update_fog_overlay() -> void:
	if fog_visuals == null:
		return
	var transforms: Array[Transform3D] = []
	for row in range(TerritoryGrid.HEIGHT):
		for col in range(TerritoryGrid.WIDTH):
			if not game.territory.is_revealed(col, row):
				transforms.append(Transform3D(Basis.IDENTITY, game.territory.cell_world(col, row) + Vector3(0, 6.2, 0)))
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.instance_count = transforms.size()
	var plane := PlaneMesh.new()
	plane.size = Vector2(TerritoryGrid.CELL_SIZE, TerritoryGrid.CELL_SIZE)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.97, 0.985, 0.985, 1.0) if game.empty_city_mode else Color(0.93, 0.96, 0.96, 0.90)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	plane.material = material
	multi.mesh = plane
	for index in range(transforms.size()):
		multi.set_instance_transform(index, transforms[index])
	fog_visuals.multimesh = multi

func redraw_territory() -> void:
	var signature := JSON.stringify(game.territory.data()) + JSON.stringify(game.fire_ruins) + JSON.stringify(game.fire_damage) + str([quality_mode, game.language, game.signal_fixed, game.transit.active, game.transit.funded, game.transit.stops])
	if signature == territory_signature:
		return
	territory_signature = signature
	clear_children(territory_visuals)
	if game.has_city_hall():
		for guide_name in ["CityHallSiteGuide", "CityHallSiteLabel"]:
			var guide := world.get_node_or_null(guide_name)
			if guide != null:
				guide.queue_free()
	var tile_visuals := Node3D.new()
	tile_visuals.name = "GridCells"
	territory_visuals.add_child(tile_visuals)
	if game.empty_city_mode:
		# Natural ground is one continuous surface. Cell borders are logical only;
		# drawing a box for every forest cell made the fresh map look like old lots.
		var ground := MeshInstance3D.new()
		var ground_mesh := PlaneMesh.new()
		ground_mesh.size = Vector2(TerritoryGrid.WIDTH * TerritoryGrid.CELL_SIZE, TerritoryGrid.HEIGHT * TerritoryGrid.CELL_SIZE)
		var ground_material := StandardMaterial3D.new()
		ground_material.albedo_color = Color("607e4c")
		ground_material.roughness = 1.0
		ground.mesh = ground_mesh
		ground.material_override = ground_material
		ground.position = TerritoryGrid.ORIGIN + Vector3((TerritoryGrid.WIDTH - 1) * TerritoryGrid.CELL_SIZE * 0.5, -0.015, (TerritoryGrid.HEIGHT - 1) * TerritoryGrid.CELL_SIZE * 0.5)
		tile_visuals.add_child(ground)
	# Старый квартал нарисован DistrictWorld исторически. Закрываем газоном удалённые сегменты, чтобы карта совпадала с сеткой.
	var row_range := range(TerritoryGrid.HEIGHT) if game.empty_city_mode else range(TerritoryGrid.EXPANSION_ROWS.x, TerritoryGrid.EXPANSION_ROWS.y + 1)
	var col_range := range(TerritoryGrid.WIDTH) if game.empty_city_mode else range(TerritoryGrid.EXPANSION_COLS.x, TerritoryGrid.EXPANSION_COLS.y + 1)
	if not game.empty_city_mode:
		for row in range(0, TerritoryGrid.EXPANSION_ROWS.x):
			for col in range(0, TerritoryGrid.EXPANSION_COLS.y + 1):
				var expected_road := (row % 3 == 0) or (col % 3 == 0 and row <= 18)
				if expected_road and game.territory.state_at(col, row) != "road":
					var legacy_center: Vector3 = game.territory.cell_world(col, row)
					Art.box(tile_visuals, legacy_center + Vector3(0, 0.28, 0), Vector3(TerritoryGrid.CELL_SIZE - 0.1, 0.18, TerritoryGrid.CELL_SIZE - 0.1), Color("91a66f"))
	for row in row_range:
		for col in col_range:
			if game.empty_city_mode and not game.territory.is_revealed(col, row):
				continue
			var state: String = game.territory.state_at(col, row)
			var center: Vector3 = game.territory.cell_world(col, row)
			if state == "forest":
				var hall_site: bool = col in range(TerritoryGrid.CITY_HALL_SITE.x, TerritoryGrid.CITY_HALL_SITE.x + 2) and row in range(TerritoryGrid.CITY_HALL_SITE.y, TerritoryGrid.CITY_HALL_SITE.y + 2)
				if game.empty_city_mode and not game.has_city_hall() and hall_site:
					continue
				# Forest cells deliberately use several deterministic variants so
				# the expansion reads as a natural edge rather than a repeated wall
				# of identical firs.  The coordinate seed keeps the look stable after
				# saving and loading.
				var forest_seed := absi(row * 53 + col * 17 + row * col)
				var forest_variant := forest_seed % 10
				var forest_rng := RandomNumberGenerator.new()
				forest_rng.seed = forest_seed
				var forest_center := center + Vector3(forest_rng.randf_range(-1.25, 1.25), 0.1, forest_rng.randf_range(-1.25, 1.25))
				if forest_variant < 4:
					Art.tree(tile_visuals, forest_center, 0.9 + float(forest_seed % 3) * 0.08, true, forest_seed)
				elif forest_variant < 7:
					Art.tree(tile_visuals, forest_center, 0.75 + float(forest_seed % 4) * 0.08, false, forest_seed)
				elif forest_variant < 9:
					Art.tree(tile_visuals, forest_center + Vector3(-0.75, 0, 0.45), 0.38, false, forest_seed)
					Art.tree(tile_visuals, forest_center + Vector3(0.65, 0, -0.5), 0.3, false, forest_seed + 1)
				# The remaining variant is an open clearing: grass remains visible
				# and the player can immediately read it as a future work site.
			elif state == "road":
				var links: Array[Vector2i] = []
				for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					if game.territory.state_at(col + offset.x, row + offset.y) == "road":
						links.append(offset)
				var topology := road_topology(links)
				var asphalt := Color("777d80")
				var concrete := Color("b6b2a3")
				var markings := Color("e4e1d0")
				var half_road := 1.4
				# Each tile uses a topology-specific road surface. Turns and junctions
				# are assembled from the connected arms instead of covering the tile.
				if topology in ["corner", "tee", "cross"]:
					Art.box(tile_visuals, center + Vector3(0, 0.14, 0), Vector3(2.8, 0.08, 2.8), asphalt)
					for offset: Vector2i in links:
						var arm_center := center + Vector3(offset.x * 1.35, 0.14, offset.y * 1.35)
						var arm_size := Vector3(TerritoryGrid.CELL_SIZE * 0.5 + 0.7, 0.08, 2.8) if offset.x != 0 else Vector3(2.8, 0.08, TerritoryGrid.CELL_SIZE * 0.5 + 0.7)
						Art.box(tile_visuals, arm_center, arm_size, asphalt)
						# Sidewalks begin outside the central asphalt square. They never
						# cut diagonally through the intersection.
						if offset.x != 0:
							for side in [-1.0, 1.0]:
								Art.box(tile_visuals, center + Vector3(offset.x * 1.8, 0.16, side * 1.85), Vector3(1.2, 0.1, 0.9), concrete)
						else:
							for side in [-1.0, 1.0]:
								Art.box(tile_visuals, center + Vector3(side * 1.85, 0.16, offset.y * 1.8), Vector3(0.9, 0.1, 1.2), concrete)
						if topology in ["tee", "cross"] and not is_in_compact_road_square(col, row):
							# Only the junction cell owns its crossings. Neighbouring road
							# cells must not add a second STOP line at the same approach.
							# Crosswalks sit at the outer edge, leaving the centre clear.
							var cross_center := center + Vector3(offset.x * 2.0, 0.23, offset.y * 2.0)
							for stripe in range(-1, 2):
								var stripe_center := cross_center + (Vector3(0, 0, stripe * 0.38) if offset.x != 0 else Vector3(stripe * 0.38, 0, 0))
								var stripe_size := Vector3(0.14, 0.018, 1.35) if offset.x != 0 else Vector3(1.35, 0.018, 0.14)
								Art.box(tile_visuals, stripe_center, stripe_size, markings)
							# One short STOP line outside the crossing, half a road wide.
							var stop_center := center + Vector3(offset.x * 2.3, 0.25, offset.y * 2.3)
							var stop_size := Vector3(0.10, 0.02, 1.35) if offset.x != 0 else Vector3(1.35, 0.02, 0.10)
							Art.box(tile_visuals, stop_center, stop_size, Color("f4f0d8"))
					# Four small corner pads connect the split sidewalk segments.
					for side_x in [-1.0, 1.0]:
						for side_z in [-1.0, 1.0]:
							Art.box(tile_visuals, center + Vector3(side_x * 1.85, 0.16, side_z * 1.85), Vector3(1.0, 0.1, 1.0), concrete)
				elif Vector2i.LEFT in links or Vector2i.RIGHT in links:
					Art.box(tile_visuals, center + Vector3(0, 0.14, 0), Vector3(TerritoryGrid.CELL_SIZE - 0.04, 0.08, 2.8), asphalt)
					for side in [-1.0, 1.0]:
						Art.box(tile_visuals, center + Vector3(0, 0.16, side * 1.85), Vector3(TerritoryGrid.CELL_SIZE - 0.04, 0.1, 0.9), concrete)
				else:
					Art.box(tile_visuals, center + Vector3(0, 0.14, 0), Vector3(2.8, 0.08, TerritoryGrid.CELL_SIZE - 0.04), asphalt)
					for side in [-1.0, 1.0]:
						Art.box(tile_visuals, center + Vector3(side * 1.85, 0.16, 0), Vector3(0.9, 0.1, TerritoryGrid.CELL_SIZE - 0.04), concrete)
				# Fresh expansion streets use broken centre markings; the dashes
				# continue into each arm of a bend and stop before crosswalks.
				for offset: Vector2i in links:
					# Junction arms already have their own crosswalk and STOP line.
					# Do not draw the old centre-marking fan there: in isometric view
					# it becomes a confusing white grid over the intersection.
					if topology not in ["tee", "cross"]:
						for dash in range(2):
							var distance := 0.65 + dash * 1.05
							var dash_center := center + Vector3(offset.x * distance, 0.205, offset.y * distance)
							var dash_size := Vector3(0.62, 0.018, 0.055) if offset.x != 0 else Vector3(0.055, 0.018, 0.62)
							Art.box(tile_visuals, dash_center, dash_size, markings)
				var junction_signal := topology == "cross"
				if topology == "tee":
					# A tee directly beside a cross belongs to the same junction;
					# the cross cell owns the single signal controller.
					for neighbour: Vector2i in links:
						var neighbour_links: Array[Vector2i] = []
						for candidate: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
							if game.territory.state_at(col + neighbour.x + candidate.x, row + neighbour.y + candidate.y) == "road":
								neighbour_links.append(candidate)
						if road_topology(neighbour_links) == "cross":
							junction_signal = false
							break
				if junction_signal:
					var road_light := create_object(territory_visuals, "traffic_signal", "expansion_signal_%d_%d" % [col, row], center)
					road_light.set_meta("expansion_intersection", true)
					road_light.set_meta("signal_offset", float((col + row) % 3) * 2.0)
					road_light.interaction_area.collision_layer = 0
	for entry: Dictionary in game.territory.buildings:
		if not game.empty_city_mode and (entry.row < TerritoryGrid.EXPANSION_ROWS.x or entry.row > TerritoryGrid.EXPANSION_ROWS.y):
			continue
		var position: Vector3 = game.territory.building_center(entry)
		var object := create_object(territory_visuals, entry.type_id, entry.instance_id, position)
		object.set_meta("grid_instance_id", entry.instance_id)
		object.set_level(int(entry.get("level", 1)))
		object.set_ruined(game.is_ruined(entry.instance_id))
		object.set_language(game.language)
		var record: Dictionary = entry.duplicate(true)
		record.position = position
		record.level = int(entry.get("level", 1))
		var base_color := quality_color(game.record_quality(record).score) if quality_mode else Color("91a66f")
		var lot_size := territory_building_visual_size(entry)
		Art.box(object, Vector3(0, 0.14, 0), Vector3(lot_size.x, 0.12, lot_size.y), base_color)
	Art.batch(tile_visuals)
	update_fog_overlay()

func road_topology(links: Array[Vector2i]) -> String:
	var horizontal := Vector2i.LEFT in links or Vector2i.RIGHT in links
	var vertical := Vector2i.UP in links or Vector2i.DOWN in links
	if links.size() >= 4:
		return "cross"
	if links.size() == 3:
		return "tee"
	if links.size() == 2 and horizontal and vertical:
		return "corner"
	if links.size() == 1:
		return "dead_end"
	return "straight"

func territory_building_visual_size(entry: Dictionary) -> Vector2:
	return Vector2(float(entry.get("width", 1)) * TerritoryGrid.CELL_SIZE - 0.2,
		float(entry.get("height", 1)) * TerritoryGrid.CELL_SIZE - 0.2)

func set_camera_focus(point: Vector3) -> void:
	focus_point = Vector3(clampf(point.x, -55, 65), 0, clampf(point.z, -80, 105))
	camera.position = focus_point + Vector3(70, 88, 70)
	camera.look_at(focus_point)

func focus_problem() -> void:
	close_sheet()
	var point := map_position(Vector3(-9, 0, 6)) if game.legacy_problem_available("leak") else Vector3(-14.4, 0, 0)
	set_camera_focus(point + Vector3(5, 0, 5))

func change_zoom(amount: float) -> void:
	camera.size = clampf(camera.size + amount, 45, 110)

func handle_map_gesture(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_points[event.index] = event.position
			if touch_points.size() >= 2:
				pinching = true
				dragging = false
				drag_moved = true
				pinch_distance = _touch_distance()
				return
			if event.index == 0:
				dragging = true
				drag_moved = false
				drag_start = event.position
				drag_previous = event.position
		else:
			touch_points.erase(event.index)
			if pinching:
				if touch_points.size() < 2:
					pinching = false
					dragging = false
					drag_moved = true
					pinch_distance = 0.0
				return
			if event.index == 0 and dragging and not drag_moved:
				map_input(event)
			if event.index == 0:
				dragging = false
		return
	if event is InputEventScreenDrag:
		if pinching:
			touch_points[event.index] = event.position
			var current_distance := _touch_distance()
			if pinch_distance > 0.0 and current_distance > 1.0:
				camera.size = clampf(camera.size * pinch_distance / current_distance, 45.0, 110.0)
			pinch_distance = current_distance
			return
		var motion := InputEventMouseMotion.new()
		motion.position = event.position
		_handle_mouse_gesture(motion)
		return
	# Android присылает исходное касание и эмулированную мышь. Карта обрабатывает один поток.
	if OS.has_feature("android"):
		return
	_handle_mouse_gesture(event)

func _touch_distance() -> float:
	if touch_points.size() < 2:
		return 0.0
	var points: Array = touch_points.values()
	return (points[0] as Vector2).distance_to(points[1])

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
				elif dragging and drag_moved and placing_stop:
					update_preview()
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
	if placing_stop:
		var old_stop_index := tapped_existing_stop(point)
		if old_stop_index >= 0:
			return # The existing stop stays until a different road point is chosen.
		var candidate_row := tapped_stop_candidate(point)
		if candidate_row >= 0:
			confirm_stop(candidate_row)
		return
	if selection_kind not in ["territory", "stop_place"]:
		var tapped_stop := tapped_existing_stop(point)
		if tapped_stop >= 0:
			open_stop_card(tapped_stop)
			return
	for identifier in game.fires:
		var marker: Sprite3D = fire_markers.get(identifier)
		if marker != null and marker.visible and camera.unproject_position(marker.position).distance_to(point) < 42.0 * render_scale / viewport_container.stretch_shrink:
			selected_fire_id = str(identifier)
			select_problem("fire")
			return
	for kind in ["leak", "signal"]:
		var fixed: bool = game.leak_fixed if kind == "leak" else game.signal_fixed
		var marker := world.get_node_or_null("LeakMarker" if kind == "leak" else "SignalMarker") as Node3D
		if marker != null and game.legacy_problem_available(kind) and not fixed and camera.unproject_position(marker.position).distance_to(point) < 36.0 * render_scale / viewport_container.stretch_shrink:
			select_problem(kind)
			return
	if selection_kind != "territory" and select_projected_building(point):
		return
	if selection_kind != "territory" and select_vehicle_at(point):
		return
	var hit = Plane(Vector3.UP, 0).intersects_ray(camera.project_ray_origin(point), camera.project_ray_normal(point))
	if hit == null:
		if selection_kind not in ["", "territory", "stop_place"]:
			close_sheet()
		return
	var hit_col := roundi((hit.x - TerritoryGrid.ORIGIN.x) / TerritoryGrid.CELL_SIZE)
	var hit_row := roundi((hit.z - TerritoryGrid.ORIGIN.z) / TerritoryGrid.CELL_SIZE)
	if game.territory.in_bounds(hit_col, hit_row) and not game.territory.is_revealed(hit_col, hit_row):
		return
	if selection_kind == "territory":
		# The visible tile is centered on `cell_world`.  Ray intersections can
		# land a few floating point units either side of that center, so use the
		# nearest cell rather than the lower-left cell.
		var col := roundi((hit.x - TerritoryGrid.ORIGIN.x) / TerritoryGrid.CELL_SIZE)
		var row := roundi((hit.z - TerritoryGrid.ORIGIN.z) / TerritoryGrid.CELL_SIZE)
		if game.territory.in_bounds(col, row):
			var selected_cell := Vector2i(col, row)
			var cell_state: String = game.territory.state_at(col, row)
			var hall_footprint := col in range(TerritoryGrid.CITY_HALL_SITE.x, TerritoryGrid.CITY_HALL_SITE.x + 2) and row in range(TerritoryGrid.CITY_HALL_SITE.y, TerritoryGrid.CITY_HALL_SITE.y + 2)
			if territory_tool == TerritoryGrid.CITY_HALL_TYPE and not game.has_city_hall() and hall_footprint and cell_state == "forest":
				open_land_cell(selected_cell)
				return
			var selectable: bool = cell_state == "forest" if territory_tool == "clear" else cell_state == "free"
			if selectable:
				select_territory_cell(selected_cell)
		return
	if placing_stop:
		var nearest := INF
		var candidates := valid_stop_cells()
		for index in range(candidates.size()):
			var cell: Vector2i = candidates[index]
			var distance: float = game.territory.cell_world(cell.x, cell.y).distance_to(hit)
			if distance < nearest:
				stop_candidate = index
				nearest = distance
		if nearest <= TerritoryGrid.CELL_SIZE * 0.65:
			confirm_stop(stop_candidate)
		else:
			refresh()
		return
	var picked_col := roundi((hit.x - TerritoryGrid.ORIGIN.x) / TerritoryGrid.CELL_SIZE)
	var picked_row := roundi((hit.z - TerritoryGrid.ORIGIN.z) / TerritoryGrid.CELL_SIZE)
	if game.territory.in_bounds(picked_col, picked_row):
		var tapped_cell := Vector2i(picked_col, picked_row)
		var tapped_state: String = game.territory.state_at(picked_col, picked_row)
		if tapped_state == "road":
			return
		if tapped_state in ["forest", "free"]:
			open_land_cell(tapped_cell)
			return
	for kind in ["leak", "signal"]:
		var location := map_position(Vector3(-9, 0, 6)) if kind == "leak" else Vector3(-14.4, 0, 0)
		if game.legacy_problem_available(kind) and location.distance_to(hit) < 2.2:
			select_problem(kind)
			return
	# Pick the dedicated object volume so a tap on a roof still selects its plot.
	var ray_from: Vector3 = camera.project_ray_origin(point)
	var query := PhysicsRayQueryParameters3D.create(ray_from, ray_from + camera.project_ray_normal(point) * 240.0, 1)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var collider: Object = world.get_world_3d().direct_space_state.intersect_ray(query).get("collider")
	if collider is Area3D and collider.name == "InteractionArea":
		var object: Node = collider.get_parent()
		if object != null and object.name.begins_with("plot_"):
			select_plot(int(object.name.trim_prefix("plot_")))
			return
		if object != null and object.has_meta("grid_instance_id"):
			select_grid_house(str(object.get_meta("grid_instance_id")))
			return
	for i in range(24):
		var location := map_position(game.plot_position(i))
		if absf(location.x - hit.x) <= 4.6 and absf(location.z - hit.z) <= 4.6:
			select_plot(i)
			return
	var cell := Vector2i(roundi((hit.x - TerritoryGrid.ORIGIN.x) / TerritoryGrid.CELL_SIZE), roundi((hit.z - TerritoryGrid.ORIGIN.z) / TerritoryGrid.CELL_SIZE))
	var entry: Dictionary = game.territory.building_at(cell.x, cell.y)
	if not entry.is_empty() and not entry.has("legacy_plot"):
		select_grid_house(entry.instance_id)
		return
	if selection_kind not in ["", "territory", "stop_place"]:
		close_sheet()

func select_projected_building(point: Vector2) -> bool:
	var best_score := INF
	var legacy_hit := -1
	for index in range(game.buildings.size()):
		if game.buildings[index] == "empty":
			continue
		var center: Vector3 = map_position(game.plot_position(index))
		var corners := PackedVector2Array()
		# Keep the hit area slightly larger than the model.  This is especially
		# important for the foreshortened top and left edge plots on portrait
		# screens, where only part of a building may be visible.
		for offset in [Vector2(-8.0, -8.0), Vector2(8.0, -8.0), Vector2(8.0, 8.0), Vector2(-8.0, 8.0)]:
			corners.append(camera.unproject_position(center + Vector3(offset.x, 0.2, offset.y)))
		if Geometry2D.is_point_in_polygon(point, corners):
			var score: float = camera.unproject_position(center + Vector3(0, 0.2, 0)).distance_squared_to(point)
			if score < best_score:
				best_score = score
				legacy_hit = index
	if legacy_hit >= 0:
		select_plot(legacy_hit)
		return true
	var grid_hit: String = ""
	for entry: Dictionary in game.territory.buildings:
		if entry.has("legacy_plot"):
			continue
		var center: Vector3 = game.territory.building_center(entry)
		var half_x: float = float(entry.width) * TerritoryGrid.CELL_SIZE / 2 + 0.85
		var half_z: float = float(entry.height) * TerritoryGrid.CELL_SIZE / 2 + 0.85
		var corners := PackedVector2Array()
		for offset in [Vector2(-half_x, -half_z), Vector2(half_x, -half_z), Vector2(half_x, half_z), Vector2(-half_x, half_z)]:
			corners.append(camera.unproject_position(center + Vector3(offset.x, 0.2, offset.y)))
		if Geometry2D.is_point_in_polygon(point, corners):
			var score: float = camera.unproject_position(center + Vector3(0, 0.2, 0)).distance_squared_to(point)
			if score < best_score:
				best_score = score
				grid_hit = entry.instance_id
	if grid_hit != "":
		select_grid_house(grid_hit)
		return true
	return false

func select_vehicle_at(point: Vector2) -> bool:
	var candidates: Array[Node3D] = [car, fire_car]
	for engine in fire_engine_nodes.values():
		if is_instance_valid(engine):
			candidates.append(engine)
	var police_node := world.get_node_or_null("PoliceVehicle") as Node3D
	if police_node != null:
		candidates.append(police_node)
	for vehicle: Dictionary in scenery.traffic_controller.vehicles:
		var node: Node3D = vehicle.node
		if node.visible:
			candidates.append(node)
	var best: Node3D
	var best_distance := 44.0 * render_scale / viewport_container.stretch_shrink
	for node in candidates:
		if node == null or not is_instance_valid(node) or not node.visible:
			continue
		var distance := camera.unproject_position(node.global_position + Vector3(0, 0.9, 0)).distance_to(point)
		if distance < best_distance:
			best = node
			best_distance = distance
	if best == null:
		return false
	selected_vehicle_type = best.type_id
	if best.type_id == "fire_engine":
		for assignment: Dictionary in game.fire_assignments():
			if assignment.vehicle_id == best.instance_id and assignment.phase == "repair" and not bool(assignment.get("jam_cleared", false)):
				selected_fire_id = str(assignment.instance_id)
				selection_kind = "traffic_jam"
				selected = -1
				active_tab = "services"
				refresh()
				return true
	if best.type_id == "police_car":
		selection_kind = "police_vehicle"
		selected = -1
		active_tab = "services"
		refresh()
		return true
	selection_kind = "bus" if best.type_id == "city_bus" else "vehicle"
	selected = -1
	active_tab = "services"
	refresh()
	return true

func select_grid_house(identifier: String) -> void:
	if game.fires.has(identifier):
		selected_fire_id = identifier
		audio.play_building_select("house", game.is_ruined(identifier))
		select_problem("fire")
		return
	grid_selected_id = identifier
	selection_kind = "grid_house"
	selected = -1
	active_tab = "district"
	audio.play_building_select(str(game.territory.building_by_id(identifier).get("type_id", "")), game.is_ruined(identifier))
	refresh()

func select_plot(index: int) -> void:
	if index < 0 or index >= game.buildings.size():
		return
	if game.buildings[index] == "empty":
		open_catalog(index)
		return
	if game.fires.has("pine_district_legacy_%d" % index):
		selected_fire_id = "pine_district_legacy_%d" % index
		select_problem("fire")
		return
	selected = index
	selection_kind = "plot"
	active_tab = "build_tab" if game.buildings[index] == "empty" else "district"
	audio.play_building_select(game.buildings[index], game.is_ruined("pine_district_legacy_%d" % index))
	refresh()

func select_problem(kind: String) -> void:
	if kind in ["leak", "signal"] and not game.legacy_problem_available(kind):
		selection_kind = "district_status"
		selected = -1
		refresh()
		return
	selection_kind = kind
	selected = -1
	if kind == "fire" and not game.fires.has(selected_fire_id):
		selected_fire_id = game.fire_target()
	active_tab = "services"
	if audio != null and kind != "fire":
		audio.play_ui("tesla")
	refresh()

func select_tab(key: String) -> void:
	active_tab = key
	if key == "services":
		if not game.fires.is_empty():
			select_problem("fire")
		elif game.legacy_problem_available("leak"):
			select_problem("leak")
		elif game.legacy_problem_available("signal"):
			select_problem("signal")
		else:
			selection_kind = "district_status"
			selected = -1
			refresh()
		return
	if key == "build_tab":
		open_catalog(selected if selected >= 0 and game.buildings[selected] == "empty" else -1)
		return
	else:
		selection_kind = "district_status"
		selected = -1
	refresh()

func open_catalog(target_plot: int = -1) -> void:
	active_tab = "build_tab"
	catalog_target_plot = target_plot if target_plot >= 0 and target_plot < game.buildings.size() and game.buildings[target_plot] == "empty" else -1
	catalog_category = "infrastructure" if game.empty_city_mode and not game.has_city_hall() else "residential"
	catalog_screen_mode = "categories"
	selected_catalog_type = ""
	catalog_grid_target = Vector2i(-1, -1)
	selection_kind = "catalog"
	selected = catalog_target_plot
	territory_cell = Vector2i(-1, -1)
	if catalog_target_plot >= 0:
		set_camera_focus(map_position(game.plot_position(catalog_target_plot)) + Vector3(6, 0, 6))
	else:
		set_camera_focus(game.territory.cell_world(12, 21) + Vector3(7, 0, 7))
	refresh()

func set_catalog_category(category: String) -> void:
	if category in CATALOG_CATEGORIES:
		catalog_category = category
		catalog_screen_mode = "items"
		refresh()

func return_to_catalog_categories() -> void:
	catalog_screen_mode = "categories"
	selected_catalog_type = ""
	selection_kind = "catalog"
	refresh()

func return_to_catalog_items() -> void:
	catalog_screen_mode = "items"
	selected_catalog_type = ""
	selection_kind = "catalog"
	refresh()

func close_sheet() -> void:
	placing_stop = false
	selection_kind = ""
	selected = -1
	catalog_grid_target = Vector2i(-1, -1)
	active_tab = "district"
	refresh()

func open_land_cell(cell: Vector2i) -> void:
	territory_cell = cell
	selection_kind = "land_cell"
	selected = -1
	active_tab = "district"
	refresh()

func open_land_catalog(cell: Vector2i) -> void:
	active_tab = "build_tab"
	catalog_target_plot = -1
	catalog_grid_target = cell
	catalog_category = "landscaping"
	catalog_screen_mode = "items"
	territory_cell = cell
	selection_kind = "catalog"
	selected = -1
	refresh()

func clear_selected_land_cell() -> void:
	if territory_cell.x < 0 or game.territory.state_at(territory_cell.x, territory_cell.y) != "forest":
		return
	territory_tool = "clear"
	selection_kind = "territory"
	refresh()

func open_territory() -> void:
	selection_kind = "territory"
	selected = -1
	territory_tool = "clear"
	territory_cell = Vector2i(-1, -1)
	set_camera_focus(game.territory.cell_world(12, 21) + Vector3(7, 0, 7))
	refresh()
	log_territory_probe()

func log_territory_probe() -> void:
	if not OS.is_debug_build() or not OS.has_feature("android"):
		return
	var points: Dictionary = {}
	var physical := Vector2(DisplayServer.window_get_size()) / screen.size
	for cell in [Vector2i(12, 19), Vector2i(12, 20), Vector2i(12, 21), Vector2i(13, 21), Vector2i(14, 21), Vector2i(14, 22), Vector2i(15, 21), Vector2i(16, 21), Vector2i(15, 22), Vector2i(16, 22)]:
		var point: Vector2 = camera.unproject_position(game.territory.cell_world(cell.x, cell.y)) * viewport_container.stretch_shrink / render_scale * physical
		points["%d,%d" % [cell.x, cell.y]] = [roundi(point.x), roundi(point.y)]
	print("FMT_TERRITORY ", JSON.stringify({"points": points, "selected": str(territory_cell), "tool": territory_tool}))

func select_territory_cell(cell: Vector2i) -> void:
	var placement_type := service_type if territory_tool == "service" else territory_tool
	if placement_type not in ["clear", "road", ""] and not Catalog.is_landscaping(placement_type):
		# Snap any tapped cell inside the selected footprint to its valid top-left.
		var footprint := Catalog.footprint_cells(placement_type)
		for dy in range(footprint.y):
			for dx in range(footprint.x):
				var candidate := cell - Vector2i(dx, dy)
				if game.territory.placement_reason(candidate.x, candidate.y, placement_type) == "":
					cell = candidate
					break
			if game.territory.placement_reason(cell.x, cell.y, placement_type) == "":
				break
	territory_cell = cell
	refresh()
	log_territory_probe()

func catalog_items_for(category: String) -> Array:
	return CATALOG_ITEMS.get(category, [])

func catalog_cost(type_id: String) -> int:
	if type_id == "clear":
		return 5
	if type_id == "road":
		return 12
	return Catalog.cost(type_id)

func catalog_icon(type_id: String) -> String:
	if type_id == "clear":
		return "res://assets/icons/catalog_clear.svg"
	if type_id == "road":
		return "res://assets/icons/catalog_road.svg"
	return Catalog.icon_path(type_id)

func catalog_size(type_id: String) -> String:
	if type_id in ["clear", "road"] or Catalog.is_landscaping(type_id):
		return t("catalog_footprint_small")
	if type_id == "logistics_center":
		return tr_text("3×3 клетки", "3×3 cells")
	if type_id in ["elite_residence", "business_tower"]:
		return t("catalog_footprint_renewal")
	if catalog_target_plot >= 0 and type_id in ["house", "cafe", "park"]:
		return t("catalog_footprint_legacy")
	return t("catalog_footprint_large")

func catalog_requirement(type_id: String) -> String:
	if type_id == "city_hall":
		return t("catalog_requirement_city_hall")
	if catalog_target_plot >= 0 and type_id in ["house", "cafe", "park"]:
		return t("catalog_requirement_legacy")
	if type_id == "clear":
		return t("catalog_requirement_clear")
	if type_id == "logistics_center":
		return t("catalog_requirement_logistics_center")
	if type_id == "warehouse":
		return t("catalog_requirement_warehouse")
	if type_id == "road":
		return t("catalog_requirement_road")
	if Catalog.is_landscaping(type_id):
		return t("catalog_requirement_landscape")
	if type_id in ["elite_residence", "business_tower"]:
		return tr_text("Нужны 2 жетона обновления: снесите два обычных дома. Затем расчистите площадку 4×4.", "Requires 2 renewal credits: demolish two ordinary homes, then clear a 4×4 site.")
	return t("catalog_requirement_house")

func catalog_item_unlocked(type_id: String) -> bool:
	if type_id == TerritoryGrid.CITY_HALL_TYPE:
		return game.empty_city_mode and not game.has_city_hall()
	if game.empty_city_mode and not game.has_city_hall() and type_id not in ["city_hall", "clear"]:
		return false
	if type_id in ["logistics_center", "warehouse"] and not game.logistics_building_allowed(type_id):
		return false
	return maxi(game.city_level(), game.campaign_stage) >= Catalog.unlock_level(type_id)

func catalog_entry_button(parent: Control, type_id: String) -> Button:
	var item := Button.new()
	item.name = "CatalogItem_" + type_id
	item.custom_minimum_size.y = 96
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.disabled = not catalog_item_unlocked(type_id)
	item.add_theme_stylebox_override("normal", style(Color("eaf4f0"), 5, Color("b4c9bf")))
	item.add_theme_stylebox_override("hover", style(Color("d8ece3"), 5, Color("8eb7a1")))
	item.add_theme_stylebox_override("pressed", style(Color("c3e0d1"), 5, Color("6e9d83")))
	item.add_theme_stylebox_override("disabled", style(Color("e9e8e3"), 5, Color("d4d3cd")))
	item.add_theme_color_override("font_color", INK)
	item.add_theme_color_override("font_hover_color", INK)
	item.add_theme_color_override("font_pressed_color", INK)
	if not catalog_item_unlocked(type_id) and type_id == "warehouse" and game.logistics_center_entry().is_empty():
		item.tooltip_text = tr_text("Сначала постройте логистический центр", "Build a logistics center first")
	else:
		item.tooltip_text = tr_text("Сначала постройте городской центр", "Build City Hall first") if not catalog_item_unlocked(type_id) and game.empty_city_mode and not game.has_city_hall() else t(type_id)
	item.pressed.connect(func():
		if audio != null:
			audio.play_ui("select"))
	item.pressed.connect(select_catalog_item.bind(type_id), CONNECT_DEFERRED)
	var row := hbox(item, 10)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_top = 4
	row.offset_right = -10
	row.offset_bottom = -4
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var image: Control
	if Catalog.TYPES.has(type_id):
		image = catalog_model_preview(type_id)
	else:
		var icon_image := TextureRect.new()
		icon_image.texture = load(catalog_icon(type_id))
		icon_image.custom_minimum_size = Vector2(64, 64)
		icon_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		image = icon_image
	image.custom_minimum_size = Vector2(68, 68)
	image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(image)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(info)
	var name_label := label(18, info, t(type_id), true)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var size_label := label(14, info, t("catalog_size") % catalog_size(type_id))
	size_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var requirement := label(13, info, t("catalog_requires") % catalog_requirement(type_id))
	requirement.mouse_filter = Control.MOUSE_FILTER_IGNORE
	requirement.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var cost_label := label(17, row, t("catalog_price") % catalog_cost(type_id), true)
	cost_label.custom_minimum_size.x = 88
	cost_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not catalog_item_unlocked(type_id):
		var lock_text := t("catalog_locked") % Catalog.unlock_level(type_id)
		if type_id == "warehouse" and game.logistics_center_entry().is_empty():
			lock_text = tr_text("Нужен логистический центр", "Logistics center required")
		elif type_id == "warehouse" and game.logistics_warehouse_count() >= game.logistics_warehouse_limit():
			lock_text = tr_text("Лимит складов", "Warehouse limit")
		var lock_label := label(14, item, lock_text, true)
		lock_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		lock_label.add_theme_color_override("font_color", Color("986f48"))
		lock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item)
	return item

func catalog_model_preview(type_id: String) -> Control:
	var preview_box := SubViewportContainer.new()
	preview_box.name = "ModelPreview_" + type_id
	preview_box.stretch = true
	var preview_viewport := SubViewport.new()
	preview_viewport.size = Vector2i(128, 112)
	preview_viewport.own_world_3d = true
	preview_viewport.transparent_bg = true
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	preview_box.add_child(preview_viewport)
	var preview_world := Node3D.new()
	preview_world.name = "PreviewWorld"
	preview_viewport.add_child(preview_world)
	var preview_object := GameObjectScene.instantiate()
	preview_world.add_child(preview_object)
	preview_object.setup(type_id, "catalog_preview_" + type_id)
	preview_object.interaction_area.collision_layer = 0
	preview_object.rotation.y = -0.45
	var key_light := DirectionalLight3D.new()
	key_light.rotation = Vector3(deg_to_rad(-38), deg_to_rad(35), 0)
	key_light.light_energy = 1.25
	preview_world.add_child(key_light)
	var fill_light := DirectionalLight3D.new()
	fill_light.rotation = Vector3(deg_to_rad(-18), deg_to_rad(-145), 0)
	fill_light.light_energy = 0.4
	preview_world.add_child(fill_light)
	var camera_preview := Camera3D.new()
	camera_preview.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera_preview.size = 20.0 if type_id in ["elite_residence", "business_tower"] else (17.0 if type_id == "logistics_center" else 13.2)
	camera_preview.position = Vector3(12, 11, 14)
	camera_preview.look_at_from_position(camera_preview.position, Vector3(0, 2.0, 0), Vector3.UP)
	camera_preview.current = true
	preview_world.add_child(camera_preview)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0, 0, 0, 0)
	preview_world.add_child(environment)
	return preview_box

func build_catalog_sheet() -> void:
	action_height = 0
	header(t("catalog_title"))
	label(18, sheet_column, tr_text("Этап %d · %s", "Stage %d · %s") % [game.campaign_stage, game.campaign_stage_title()])
	if catalog_screen_mode == "categories":
		label(17, sheet_column, tr_text("Выберите направление строительства", "Choose a construction category"))
		for category: String in CATALOG_CATEGORIES:
			var count := catalog_items_for(category).size()
			var category_button := flat_button(sheet_column, t("category_" + category) + "   ·   %d" % count, set_catalog_category.bind(category), true)
			category_button.name = "CatalogCategory_" + category
			category_button.custom_minimum_size.y = 64
		button(sheet_column, t("cancel"), close_sheet)
		return
	var category_row := hbox(sheet_column)
	button(category_row, tr_text("← Категории", "← Categories"), return_to_catalog_categories)
	var category_heading := label(21, category_row, t("category_" + catalog_category), true)
	category_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if catalog_grid_target.x >= 0:
		label(15, sheet_column, tr_text("Место выберете на карте после подготовки объекта.", "Choose a map location after confirming the object."))
	var scroll := ScrollContainer.new()
	scroll.name = "CatalogItemsScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.scroll_deadzone = 10
	catalog_scroll = scroll
	scroll.gui_input.connect(_on_catalog_scroll_input)
	sheet_column.add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "CatalogItems"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for type_id in catalog_items_for(catalog_category):
		catalog_entry_button(list, type_id)
	button(sheet_column, t("cancel"), close_sheet).name = "CancelCatalog"

func build_catalog_detail_sheet() -> void:
	action_height = 0
	var type_id := selected_catalog_type
	if type_id == "" or (not Catalog.TYPES.has(type_id) and type_id != "clear"):
		return_to_catalog_items()
		return
	var title_row := hbox(sheet_column)
	button(title_row, tr_text("← Назад", "← Back"), return_to_catalog_items)
	var title := label(24, title_row, t(type_id), true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var preview_row := hbox(card(sheet_column, Color("e9f0ed")))
	var model: Control
	if Catalog.TYPES.has(type_id):
		model = catalog_model_preview(type_id)
	else:
		var icon_preview := TextureRect.new()
		icon_preview.texture = load(catalog_icon(type_id))
		icon_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		model = icon_preview
	model.custom_minimum_size = Vector2(minf(300, screen.size.x - 96), minf(300, screen.size.x - 96))
	model.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	model.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_row.add_child(model)
	var details_column := VBoxContainer.new()
	details_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_row.add_child(details_column)
	label(19, details_column, tr_text("Размер: %s", "Footprint: %s") % catalog_size(type_id), true)
	if Catalog.TYPES.has(type_id):
		label(17, details_column, tr_text("Доход за цикл: %d", "Income per cycle: %d") % int(Catalog.TYPES[type_id].get("income", 0)))
	if type_id in ["elite_residence", "business_tower"]:
		label(17, details_column, tr_text("Нужно снести два обычных дома. Доступно жетонов обновления: %d", "Demolish two ordinary homes. Renewal credits available: %d") % game.renewal_credits).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label(17, details_column, tr_text("В доме — парковка, мини-сад и частная инфраструктура. Работы по авариям в крупных зданиях идут дольше.", "Includes parking, a mini-garden and private amenities. Incidents at larger buildings take longer to resolve.")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if type_id in ["logistics_center", "warehouse"]:
		label(17, details_column, building_effect(type_id, 1)).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label(16, sheet_column, t("catalog_requires") + ": " + catalog_requirement(type_id)).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label(22, sheet_column, t("catalog_price") % catalog_cost(type_id), true)
	var build_button := button(sheet_column, tr_text("Выбрать место строительства", "Choose construction location"), begin_catalog_placement.bind(type_id), true)
	build_button.custom_minimum_size.y = 64
	build_button.name = "PrepareCatalogPlacement"
	build_button.disabled = not catalog_item_unlocked(type_id) or game.budget < catalog_cost(type_id) or (type_id in ["elite_residence", "business_tower"] and game.renewal_credits < 2)
	button(sheet_column, t("cancel"), return_to_catalog_items)

func _input(event: InputEvent) -> void:
	# Карточки каталога являются кнопками и забирают GUI-события себе. Здесь
	# перехватываем только жест внутри списка, чтобы свайп по карточке тоже
	# прокручивал каталог, а короткое касание по-прежнему нажимало карточку.
	if selection_kind != "catalog" or catalog_scroll == null or not is_instance_valid(catalog_scroll) or not catalog_scroll.visible:
		return
	var point := Vector2.ZERO
	var pressed := false
	var released := false
	var moved := false
	if event is InputEventScreenTouch:
		point = event.position / viewport_container.stretch_shrink
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventScreenDrag:
		point = event.position / viewport_container.stretch_shrink
		moved = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		point = event.position / viewport_container.stretch_shrink
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		point = event.position / viewport_container.stretch_shrink
		moved = true
	else:
		return
	if not catalog_scroll.get_global_rect().has_point(point):
		return
	if pressed:
		catalog_scroll_dragging = true
		catalog_drag_start = point
		catalog_drag_last = point
		catalog_drag_moved = false
		return
	if moved and catalog_scroll_dragging:
		var dy := point.y - catalog_drag_last.y
		if absf(point.y - catalog_drag_start.y) > 8.0 * render_scale:
			catalog_drag_moved = true
		catalog_scroll.scroll_vertical = clampi(catalog_scroll.scroll_vertical - roundi(dy), 0, int(catalog_scroll.get_v_scroll_bar().max_value))
		get_viewport().set_input_as_handled()
		catalog_drag_last = point
		return
	if released:
		if catalog_drag_moved:
			get_viewport().set_input_as_handled()
		catalog_scroll_dragging = false
		catalog_drag_moved = false

func _on_catalog_scroll_input(event: InputEvent) -> void:
	if catalog_scroll == null:
		return
	if event is InputEventScreenTouch:
		catalog_scroll_dragging = event.pressed
		if event.pressed:
			get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenDrag and catalog_scroll_dragging:
		catalog_scroll.scroll_vertical = clampi(catalog_scroll.scroll_vertical - roundi(event.relative.y), 0, int(catalog_scroll.get_v_scroll_bar().max_value))
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		catalog_scroll_dragging = event.pressed
		return
	if event is InputEventMouseMotion and catalog_scroll_dragging and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		catalog_scroll.scroll_vertical = clampi(catalog_scroll.scroll_vertical - roundi(event.relative.y), 0, int(catalog_scroll.get_v_scroll_bar().max_value))
		get_viewport().set_input_as_handled()

func build_land_cell_sheet() -> void:
	action_height = 235
	var state: String = game.territory.state_at(territory_cell.x, territory_cell.y)
	header(tr_text("Земля района", "District land"))
	label(20, sheet_column, tr_text("Клетка %d,%d · %s", "Cell %d,%d · %s") % [territory_cell.x + 1, territory_cell.y + 1, t(state)])
	if state == "forest":
		label(18, sheet_column, tr_text("Освободите место, чтобы построить объект.", "Clear this tile before placing an object."))
		var clear_button := button(sheet_column, tr_text("Расчистить участок · 5", "Clear tile · 5"), clear_selected_land_cell, true)
		clear_button.name = "ClearLandCell"
		clear_button.disabled = game.budget < 5 or not game.construction_job.is_empty()
	else:
		label(18, sheet_column, tr_text("Выберите, как использовать свободное место.", "Choose how to use this free space."))
		button(sheet_column, tr_text("Открыть каталог строительства", "Open building catalog"), func():
			catalog_grid_target = territory_cell
			active_tab = "build_tab"
			catalog_category = "infrastructure" if game.empty_city_mode and not game.has_city_hall() else "residential"
			selection_kind = "catalog"
			refresh(), true).name = "BuildOnLandCell"
		button(sheet_column, tr_text("Благоустроить", "Landscaping"), open_land_catalog.bind(territory_cell), true).name = "LandscapeLandCell"
		button(sheet_column, tr_text("Построить службу", "Build a service"), func():
			catalog_grid_target = territory_cell
			active_tab = "build_tab"
			catalog_category = "services"
			selection_kind = "catalog"
			refresh(), true).name = "BuildServiceOnLandCell"
	button(sheet_column, t("cancel"), close_sheet).name = "CancelLandCell"

func build_road_piece_catalog() -> void:
	action_height = 250
	header(tr_text("Элемент дороги", "Road piece"))
	label(17, sheet_column, tr_text("Выберите тип узла. Направление подберётся по соединённым сторонам; зеркальное размещение запрещено.", "Choose a road piece. Orientation follows connected sides; mirrored placement is blocked." )).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for piece in [
		{"id": "straight", "ru": "Прямая", "en": "Straight"},
		{"id": "corner", "ru": "Поворот 90°", "en": "90° turn"},
		{"id": "tee", "ru": "Т‑перекрёсток", "en": "T-junction"},
		{"id": "cross", "ru": "Крестовой перекрёсток", "en": "Four-way junction"}
	]:
		var title := tr_text(str(piece.ru), str(piece.en))
		var item_button := button(sheet_column, title + (" ✓" if road_piece_type == piece.id else ""), choose_road_piece.bind(str(piece.id)), true)
		item_button.custom_minimum_size.y = 52
	button(sheet_column, t("cancel"), close_sheet).name = "CancelRoadPieceCatalog"

func select_catalog_item(type_id: String) -> void:
	if not catalog_items_for(catalog_category).has(type_id) or not catalog_item_unlocked(type_id):
		return
	selected_catalog_type = type_id
	selection_kind = "catalog_detail"
	refresh()

func begin_catalog_placement(type_id: String) -> void:
	if not catalog_item_unlocked(type_id):
		return
	territory_tool = type_id
	preview_kind = type_id
	selected = catalog_target_plot
	if catalog_target_plot >= 0 and type_id in ["house", "cafe", "park"]:
		selection_kind = "catalog_legacy_placement"
	else:
		catalog_target_plot = -1
		selected = -1
		territory_cell = TerritoryGrid.CITY_HALL_SITE if type_id == TerritoryGrid.CITY_HALL_TYPE else (catalog_grid_target if catalog_grid_target.x >= 0 else Vector2i(-1, -1))
		selection_kind = "territory"
		if territory_cell.x < 0 and type_id not in ["fire_station", "police_station", "hospital", "depot"]:
			set_camera_focus(game.territory.cell_world(12, 21) + Vector3(7, 0, 7))
	refresh()

func cancel_catalog_placement() -> void:
	selection_kind = "catalog"
	selected = catalog_target_plot
	territory_cell = catalog_grid_target if catalog_grid_target.x >= 0 else Vector2i(-1, -1)
	refresh()

func choose_road_piece(piece_type: String) -> void:
	road_piece_type = piece_type
	territory_tool = "road"
	selection_kind = "territory"
	refresh()

func build_legacy_catalog_placement_sheet() -> void:
	if selected < 0 or game.buildings[selected] != "empty":
		selection_kind = "catalog"
		build_catalog_sheet()
		return
	action_height = 330
	header(t("place_catalog_item") % t(preview_kind))
	var info_row := hbox(card(sheet_column, Color("eeefec")))
	var image := TextureRect.new()
	image.texture = load(catalog_icon(preview_kind))
	image.custom_minimum_size = Vector2(64, 64)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	info_row.add_child(image)
	var info := VBoxContainer.new()
	info_row.add_child(info)
	label(18, info, t("catalog_size") % catalog_size(preview_kind))
	label(16, info, t("catalog_requires") % catalog_requirement(preview_kind)).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label(22, sheet_column, t("catalog_price") % Catalog.cost(preview_kind), true)
	var confirm := button(sheet_column, t("build_confirm"), construct.bind(preview_kind), true)
	confirm.name = "ConfirmCatalogPlacement"
	confirm.disabled = game.budget < Catalog.cost(preview_kind)
	button(sheet_column, t("cancel"), cancel_catalog_placement).name = "CancelCatalogPlacement"

func build_territory_sheet() -> void:
	action_height = 300
	var selected_type := service_type if territory_tool == "service" else territory_tool
	header(t("place_catalog_item") % t(selected_type))
	var info_row := hbox(card(sheet_column, Color("eeefec")))
	var image := TextureRect.new()
	image.texture = load(catalog_icon(selected_type))
	image.custom_minimum_size = Vector2(54, 54)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	info_row.add_child(image)
	var info := VBoxContainer.new()
	info_row.add_child(info)
	label(16, info, t("catalog_size") % catalog_size(selected_type))
	label(14, info, t("catalog_requires") % catalog_requirement(selected_type)).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var reason := territory_reason()
	var status_text := t("cell_unselected")
	if territory_cell.x >= 0:
		var cell_state: String = game.territory.state_at(territory_cell.x, territory_cell.y)
		status_text = tr_text("Клетка %d,%d · %s", "Cell %d,%d · %s") % [territory_cell.x + 1, territory_cell.y + 1, t("occupied_state") if cell_state == "occupied" else t(cell_state)]
	var cell_status := label(15, sheet_column, status_text)
	cell_status.name = "TerrainCellStatus"
	var hint := label(16, sheet_column, placement_hint(reason))
	hint.name = "TerrainPlacementHint"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var confirm := button(sheet_column, t("catalog_price") % catalog_cost(selected_type), apply_territory_tool, true)
	confirm.name = "ConfirmTerritory"
	confirm.disabled = reason != ""
	button(sheet_column, t("cancel"), cancel_catalog_placement).name = "CancelTerritory"

func open_grid_road_card(cell: Vector2i) -> void:
	road_selected_cell = cell
	selection_kind = "grid_road"
	selected = -1
	active_tab = "district"
	refresh()

func build_road_sheet() -> void:
	action_height = 215
	header(t("road"))
	var info := label(19, sheet_column, tr_text("Дороги формируются при размещении зданий и сохраняют общую сеть города. Снос дорог отключён, чтобы не разрывать подъезды к домам и службам.", "Roads are formed when buildings are placed and keep the city network connected."))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func request_road_demolition() -> void:
	if not game.can_demolish_road(road_selected_cell.x, road_selected_cell.y):
		refresh()
		return
	var dialog := ConfirmationDialog.new()
	dialog.name = "RoadDemolitionConfirmation"
	dialog.theme = ui_theme
	dialog.title = t("demolish_confirm_title")
	# Короткое предупреждение оставляет место двум крупным кнопкам даже на
	# портретном экране. Детали шестисекундной работы уже показаны в карточке.
	dialog.dialog_text = t("road_confirm_body")
	dialog.ok_button_text = t("demolish_road")
	dialog.cancel_button_text = t("cancel")
	add_child(dialog)
	decorate_dialog(dialog)
	dialog.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog.get_label().custom_minimum_size = Vector2(0, 72)
	dialog.get_ok_button().custom_minimum_size = Vector2(0, 64)
	dialog.get_cancel_button().custom_minimum_size = Vector2(0, 64)
	dialog.get_ok_button().add_theme_font_size_override("font_size", 19)
	dialog.get_cancel_button().add_theme_font_size_override("font_size", 19)
	dialog.confirmed.connect(func():
		if game.start_road_demolition(road_selected_cell.x, road_selected_cell.y):
			selection_kind = "construction_job"
			refresh()
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	var dialog_width := clampi(int(screen.size.x - safe_left - safe_right - 24), 300, 420)
	var dialog_height := clampi(int(screen.size.y * 0.25), 240, 300)
	dialog.popup_centered(Vector2i(dialog_width, dialog_height))

func build_construction_job_sheet() -> void:
	action_height = 230
	var task: Dictionary = game.construction_job
	var task_kind := str(task.get("kind", ""))
	var verb := tr_text("Техника уезжает", "Work crew is leaving") if task_kind == "departing" else (t("construction_demolish") if task_kind.begins_with("demolish") else (tr_text("Восстановление", "Restoration") if task_kind.begins_with("restore") else (t("construction_upgrade") if task_kind.begins_with("upgrade") else t("construction_build"))))
	header(verb)
	var item_id := str(task.get("type_id", ""))
	if item_id != "":
		label(21, sheet_column, t(item_id))
	label(18, sheet_column, tr_text("Экскаватор и грузовик выполняют короткую работу. Состояние сохранится, если выйти из игры.", "The work vehicle and truck are on a short job. Progress is saved when you leave the game."))
	button(sheet_column, t("close"), close_sheet).name = "CloseConstructionPanel"

func handle_construction_finish(task: Dictionary) -> void:
	var kind := str(task.get("completed_kind", task.get("kind", "")))
	if kind in ["build_legacy", "upgrade_legacy"]:
		select_plot(int(task.get("index", -1)))
	elif kind == "build_grid":
		var entry: Dictionary = game.territory.building_at(int(task.get("col", -1)), int(task.get("row", -1)))
		if not entry.is_empty():
			select_grid_house(str(entry.instance_id))
		else:
			close_sheet()
	elif kind == "upgrade_grid":
		select_grid_house(str(task.get("identifier", "")))
	elif kind == "restore_grid":
		select_grid_house(str(task.get("identifier", "")))
	elif kind == "restore_legacy":
		select_plot(int(task.get("index", -1)))
	elif kind == "demolish_grid":
		open_catalog()
		catalog_category = "landscaping"
		refresh()
	elif kind == "demolish_legacy":
		open_catalog()
	elif kind == "road" or kind == "clear" or kind == "demolish_road" or kind == "departing":
		if kind == "clear":
			open_land_cell(Vector2i(int(task.get("col", -1)), int(task.get("row", -1))))
		else:
			open_catalog()
			catalog_category = "infrastructure"
			refresh()

func territory_reason() -> String:
	if territory_cell.x < 0:
		return "select"
	var selected_type := service_type if territory_tool == "service" else territory_tool
	if territory_tool not in ["clear", "road"] and not game.has_city_hall():
		if selected_type != TerritoryGrid.CITY_HALL_TYPE:
			return "city_hall_first"
		if territory_cell != TerritoryGrid.CITY_HALL_SITE:
			return "city_hall_site"
	if territory_tool == "road" and not game.has_city_hall():
		return "city_hall_first"
	if selected_type in ["logistics_center", "warehouse"] and not game.logistics_site_allowed(selected_type, territory_cell.x, territory_cell.y):
		return "logistics_requirement"
	var placement_kind := "landscaping" if Catalog.is_landscaping(selected_type) else selected_type
	var reason: String = game.territory.placement_reason(territory_cell.x, territory_cell.y, territory_tool if territory_tool in ["clear", "road"] else placement_kind)
	if reason != "":
		return reason
	if territory_tool == "road" and road_piece_type != "auto":
		var links: Array[Vector2i] = []
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if game.territory.state_at(territory_cell.x + offset.x, territory_cell.y + offset.y) == "road":
				links.append(offset)
		if links.size() >= 2 and road_topology(links) != road_piece_type:
			return tr_text("Выбранный элемент не совпадает с подключёнными сторонами дороги.", "This road piece does not match the connected sides.")
	if territory_tool not in ["clear", "road"] and maxi(game.city_level(), game.campaign_stage) < Catalog.unlock_level(selected_type):
		return "locked"
	if selected_type in ["elite_residence", "business_tower"] and game.renewal_credits < 2:
		return "renewal_credits"
	var cost := catalog_cost(selected_type)
	return "" if game.budget >= cost else "budget"

func placement_hint(reason: String) -> String:
	match reason:
		"select": return tr_text("Начните у края существующей дороги.", "Start at an existing road edge.")
		"outside": return tr_text("Весь участок должен быть в области освоения.", "The whole footprint must fit the expansion area.")
		"city_hall_first": return tr_text("Сначала постройте городской центр на отмеченном месте.", "Build City Hall on the marked site first.")
		"city_hall_site": return tr_text("Городской центр строится только на отмеченном центральном участке.", "City Hall can only be built on the highlighted central site.")
		"not_forest": return tr_text("Здесь уже нет леса. Выберите зелёную клетку.", "No forest here. Select a green cell.")
		"clear_first": return tr_text("Сначала расчистите весь отмеченный участок.", "Clear the entire highlighted footprint first.")
		"no_road": return tr_text("Нужна соседняя дорога, соединённая с городом.", "An adjacent road connected to the city is required.")
		"budget": return tr_text("Недостаточно средств.", "Not enough funds.")
		"locked": return tr_text("Это здание ещё не открыто.", "This building is still locked.")
		"renewal_credits": return tr_text("Для элитной застройки нужно снести два обычных дома.", "Demolish two ordinary homes to unlock this elite site.")
		"logistics_requirement": return tr_text("Склад открывается после логистического центра; проверьте его уровень и лимит складов.", "A warehouse requires a logistics center and an available warehouse slot.")
	if territory_tool == "clear":
		return tr_text("Расчистка стоит 5. Для дома очистите все клетки его контура 2×2.", "Clear for 5. Clear all four cells in the 2×2 home footprint.")
	if territory_tool == "road":
		return tr_text("Дорога стоит 12 за клетку. Начните у существующей дороги; поворот можно сделать следующей клеткой.", "Road costs 12 per tile. Start beside an existing road; add a turn with the next tile.")
	var selected_type := service_type if territory_tool == "service" else territory_tool
	if Catalog.is_landscaping(selected_type):
		return t("catalog_requirement_landscape")
	return tr_text("Здание занимает участок %s и стоит %d. Разместите его рядом с соединённой дорогой.", "The building uses a %s lot and costs %d. Place it beside a connected road.") % [catalog_size(selected_type), catalog_cost(selected_type)]

func set_territory_tool(tool: String) -> void:
	territory_tool = tool
	refresh()

func set_service_type(type_id: String) -> void:
	service_type = type_id
	refresh()

func apply_territory_tool() -> void:
	if territory_cell.x < 0:
		return
	var selected_type := service_type if territory_tool == "service" else territory_tool
	var success := game.start_grid_clear(territory_cell.x, territory_cell.y) if territory_tool == "clear" else game.start_grid_road(territory_cell.x, territory_cell.y) if territory_tool == "road" else game.start_grid_construction(territory_cell.x, territory_cell.y, selected_type)
	if success:
		selection_kind = "construction_job"
		audio.play_construction(DistrictWorld.logical_position(game.territory.cell_world(territory_cell.x, territory_cell.y)))
		refresh()
	else:
		audio.play_ui("deny")
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
	ensure_legacy_visuals()
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
	stats.text = t("stats") % [game.budget, game.population(), game.happiness(), game.net_income()]
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
	var leak_active := game.legacy_problem_available("leak")
	var signal_active := game.legacy_problem_available("signal")
	var mission_symbol := "star" if game.completed else ("drop" if leak_active else ("hammer" if signal_active else "pin"))
	mission_icon.texture = load("res://assets/icons/ui_" + mission_symbol + ".svg")
	if game.empty_city_mode:
		objective.text = tr_text("Этап %d · %s\n%s", "Stage %d · %s\n%s") % [game.campaign_stage, game.campaign_stage_title(), campaign_goal_text(game.campaign_stage)]
		objective.add_theme_font_size_override("font_size", 16)
		objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		objective.size_flags_vertical = Control.SIZE_EXPAND_FILL
		objective.get_parent().get_node("MissionCounter").text = format_duration(game.campaign_elapsed_seconds)
		progress_bar.max_value = 1.0
		progress_bar.value = game.campaign_stage_progress()
		mission_icon.texture = load("res://assets/icons/ui_star.svg")
	else:
		var completed_steps := int(not leak_active) + int(not signal_active) + int(game.buildings.has("cafe") or game.buildings.has("park"))
		objective.text = t("mission_done") if game.completed else (t("mission_water") if leak_active else (t("mission_signal") if signal_active else t("mission_build")))
		objective.get_parent().get_node("MissionCounter").text = "%d / 3" % completed_steps
		progress_bar.max_value = 3
		progress_bar.value = completed_steps
	redraw_plots()
	redraw_logistics_vehicles()
	maybe_offer_subsidy()
	update_fire_visuals()
	scenery.traffic_controller.signal_fixed = game.signal_fixed
	scenery.traffic_controller.update_lights()
	if leak_effect != null and is_instance_valid(leak_effect):
		leak_effect.visible = game.legacy_problem_available("leak")
	var leak_marker := world.get_node_or_null("LeakMarker") as Node3D
	if leak_marker != null:
		leak_marker.visible = game.legacy_problem_available("leak")
	var signal_marker := world.get_node_or_null("SignalMarker") as Node3D
	if signal_marker != null:
		signal_marker.visible = game.legacy_problem_available("signal")
	build_sheet()
	update_preview()
	sync_construction_site()
	update_layout()
	update_campaign_completion()

func campaign_goal_text(stage: int) -> String:
	match stage:
		1: return tr_text("постройте мэрию, дом и пожарную службу", "build City Hall, a home and a fire service")
		2: return tr_text("3 дома, кафе или парк и улучшите один дом", "3 homes, a café or park, and upgrade one home")
		3: return tr_text("5 домов, 2 службы и дом 3-го уровня", "5 homes, 2 services and a level-3 home")
		4: return tr_text("создайте элитную резиденцию из двух домов", "replace two homes with an elite residence")
		5: return tr_text("постройте первую деловую башню", "build the first business tower")
		6: return tr_text("постройте 2 башни, 2 резиденции, логистический центр и склад", "build 2 towers, 2 residences, a logistics center and a warehouse")
		7: return tr_text("3 башни и настроение не ниже 65", "3 towers and happiness of at least 65")
		8: return tr_text("4 башни и настроение не ниже 72", "4 towers and happiness of at least 72")
		9: return tr_text("6 башен и настроение не ниже 78", "6 towers and happiness of at least 78")
		_: return tr_text("8 башен и настроение не ниже 85", "8 towers and happiness of at least 85")

func format_duration(seconds: float) -> String:
	var whole := maxi(0, floori(seconds))
	return "%02d:%02d" % [int(whole / 60), whole % 60]

func update_campaign_completion() -> void:
	if not game.empty_city_mode or not game.campaign_complete_pending:
		if campaign_dialog != null and is_instance_valid(campaign_dialog):
			campaign_dialog.queue_free()
		campaign_dialog = null
		return
	if campaign_dialog != null and is_instance_valid(campaign_dialog):
		return
	var overlay := Control.new()
	overlay.name = "CampaignCompletionOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	screen.add_child(overlay)
	campaign_dialog = overlay
	var background := TextureRect.new()
	background.name = "CampaignArtwork"
	background.texture = load("res://assets/backgrounds/city_level_celebration.jpg")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(background)
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.11, 0.14, 0.48)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_left = safe_left + 18
	center.offset_right = -(safe_right + 18)
	center.offset_top = safe_top + 20
	center.offset_bottom = -(safe_bottom + 20)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(minf(500, screen.size.x - safe_left - safe_right - 36), 0)
	panel.add_theme_stylebox_override("panel", style(Color("fbf9f4"), 16, Color("e5c879")))
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	var stage: int = int(game.campaign_completed_stage)
	var heading := label(28, content, tr_text("Район развивается!", "District upgraded!"), true)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var subheading := label(20, content, tr_text("Этап %d · %s", "Stage %d · %s") % [stage, game.campaign_stage_title(stage)], true)
	subheading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var stars := label(38, content, "★".repeat(game.campaign_star_rating) + "☆".repeat(3 - game.campaign_star_rating), true)
	stars.name = "CampaignStars"
	stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stars.add_theme_color_override("font_color", Color("d49b29"))
	var time := label(20, content, tr_text("Время прохождения: %s", "Completion time: %s") % format_duration(game.campaign_elapsed_seconds))
	time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var unlocked := label(17, content, tr_text("Новые здания и более высокий этап застройки открыты.", "New buildings and a higher development stage are unlocked."))
	unlocked.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	unlocked.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var next_caption := tr_text("Продолжить развитие", "Continue developing") if stage < 10 else tr_text("Продолжить свободную игру", "Continue sandbox")
	var next := flat_button(content, next_caption, func():
		game.continue_campaign()
		campaign_dialog.queue_free()
		campaign_dialog = null
		refresh(), true)
	next.name = "ContinueCampaign"
	next.custom_minimum_size.y = 64
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE

func header(title_value: String, icon_key: String = "") -> void:
	var row := hbox(sheet_column)
	if icon_key != "":
		var tile := card(row, Color("e68a3c"))
		icon(tile, icon_key, 42)
	var title := label(26 if screen.size.x < 420 else 30, row, title_value, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.custom_minimum_size.x = 0
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var close := button(row, "×", close_sheet)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.custom_minimum_size = Vector2(72, 72)
	close.add_theme_stylebox_override("normal", style(PAPER))

func build_sheet() -> void:
	clear_children(sheet_column)
	clear_children(mode_switcher)
	mode_switcher.hide()
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
	elif selection_kind == "catalog":
		build_catalog_sheet()
	elif selection_kind == "catalog_detail":
		build_catalog_detail_sheet()
	elif selection_kind == "road_piece_catalog":
		build_road_piece_catalog()
	elif selection_kind == "catalog_legacy_placement":
		build_legacy_catalog_placement_sheet()
	elif selection_kind == "territory":
		build_territory_sheet()
	elif selection_kind == "land_cell":
		build_land_cell_sheet()
	elif selection_kind == "construction_job":
		build_construction_job_sheet()
	elif selection_kind == "grid_road":
		build_road_sheet()
	elif selection_kind == "grid_house":
		build_grid_house_sheet()
	elif selection_kind == "grid_upgrade":
		build_grid_upgrade_sheet()
	elif selection_kind == "transit":
		build_transit_sheet()
	elif selection_kind == "bus":
		build_bus_sheet()
	elif selection_kind == "stop":
		build_stop_sheet()
	elif selection_kind == "stop_place":
		build_stop_placement_sheet()
	elif selection_kind == "vehicle":
		action_height = 190
		header(t(selected_vehicle_type) if TEXT.has(selected_vehicle_type) else tr_text("Транспорт", "Vehicle"))
		var busy_text := tr_text("В пути по поручению", "On assignment") if game.job != "" and selected_vehicle_type in ["repair_van", "fire_engine"] else tr_text("Ожидает поручения", "Waiting for an assignment")
		label(20, sheet_column, busy_text)
	elif selection_kind == "traffic_jam":
		action_height = 300
		header(tr_text("Затор у пожарной машины", "Fire engine roadblock"))
		label(20, sheet_column, tr_text("Дорога перекрыта. Полиция поможет освободить проезд.", "The lane is blocked. Police can clear traffic."))
		var police_available: bool = game.has_service_building("police_station")
		var call_police := button(sheet_column, tr_text("Вызвать полицию", "Call police") if police_available else tr_text("Построить участок", "Build police station"), call_police_for_jam if police_available else open_police_station_build, true)
		call_police.name = "CallPolice"
		call_police.disabled = police_available and (not game.police_job.is_empty() or bool(game.jam_cleared.get(selected_fire_id, false)))
	elif selection_kind == "police_vehicle":
		action_height = 190
		header(tr_text("Патруль", "Police patrol"))
		label(20, sheet_column, tr_text("Едет освобождать дорогу", "Clearing the road"))
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
	elif selection_kind == "fire":
		action_height = 390
		var identifier := selected_fire_id if game.fires.has(selected_fire_id) else game.fire_target()
		selected_fire_id = identifier
		var fire: Dictionary = game.fires.get(identifier, {})
		if fire.is_empty():
			selection_kind = ""
			sheet.visible = false
			return
		header(t("fire_title"))
		var danger := label(22, sheet_column, t("fire_warning") % ceili(float(fire.warning_left)) if fire.phase == "warning" else t("fire_burning") % game.fire_severity(identifier), true)
		danger.add_theme_color_override("font_color", Color("dc633c"))
		for other_id in game.fires:
			if other_id == identifier:
				continue
			var threat: Dictionary = game.fires[other_id]
			var warning_text := t("fire_neighbor") % ceili(float(threat.warning_left)) if threat.phase == "warning" else t("fire_spread")
			label(20, sheet_column, warning_text).add_theme_color_override("font_color", Color("cf7543"))
		var damage := game.house_damage(identifier)
		label(20, sheet_column, t("fire_damaged") % damage)
		var has_station: bool = game.has_service_building("fire_station")
		var fire_action := button(sheet_column, t("fire_call") if has_station else tr_text("Построить пожарное депо", "Build fire station"), dispatch_fire if has_station else open_fire_station_build, true)
		fire_action.name = "DispatchFirefighters"
		fire_action.disabled = has_station and (not game.can_dispatch_fire(identifier) or not game.fire_assignment(identifier).is_empty())
		status = label(19, sheet_column)
		status.visible = has_station
		if has_station:
			status.text = t("fire_engine_available") if game.can_dispatch_fire(identifier) else t("fire_engine_unavailable")
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

func outline_land_cell(point: Vector3, color: Color) -> void:
	var half_cell := TerritoryGrid.CELL_SIZE * 0.5
	for z in [-half_cell, half_cell]:
		Art.box(highlights, point + Vector3(0, 0.26, z), Vector3(TerritoryGrid.CELL_SIZE, 0.08, 0.13), color)
	for x in [-half_cell, half_cell]:
		Art.box(highlights, point + Vector3(x, 0.26, 0), Vector3(0.13, 0.08, TerritoryGrid.CELL_SIZE), color)

func influence_targets(index: int, kind: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var point: Vector3 = game.building_world(index)
	for entry: Dictionary in game.all_buildings():
		var relevant: bool = entry.type_id in ["cafe", "park"] if kind == "house" else entry.type_id == "house"
		if entry.get("legacy_plot", -1) != index and relevant and entry.position.distance_to(point) < Simulation.AMENITY_RADIUS:
			result.append(entry)
	return result

func update_preview() -> void:
	clear_children(stop_candidate_visuals)
	# Любой выход из предпросмотра восстанавливает реальную модель.
	for object in territory_visuals.get_children():
		if object.has_meta("grid_instance_id"):
			object.visual_root.show()
	if preview != null:
		world.remove_child(preview)
		preview.queue_free()
		preview = null
	clear_children(highlights)
	if selection_kind == "territory":
		var selected_type := service_type if territory_tool == "service" else territory_tool
		draw_buildable_hints(selected_type)
		if territory_cell.x < 0:
			return
		var color := Color("8ed6f8") if territory_reason() == "" else Color("e18470")
		var footprint := Vector2i.ONE if territory_tool in ["clear", "road"] else Catalog.footprint_cells(selected_type)
		for dy in range(footprint.y):
			for dx in range(footprint.x):
				var point: Vector3 = game.territory.cell_world(territory_cell.x + dx, territory_cell.y + dy)
				for side in [-1, 1]:
					Art.box(highlights, point + Vector3(side * 2.3, 0.3, 0), Vector3(0.15, 0.08, 4.6), color)
					Art.box(highlights, point + Vector3(0, 0.3, side * 2.3), Vector3(4.6, 0.08, 0.15), color)
		if territory_tool not in ["clear", "road"]:
			var point: Vector3 = game.territory.cell_world(territory_cell.x, territory_cell.y) + Vector3((footprint.x - 1) * TerritoryGrid.CELL_SIZE / 2, 0.2, (footprint.y - 1) * TerritoryGrid.CELL_SIZE / 2)
			preview = create_object(world, selected_type, "grid_build_preview", point)
			make_ghost(preview, color)
		return
	if selection_kind == "land_cell" and territory_cell.x >= 0:
		var selected_center: Vector3 = game.territory.cell_world(territory_cell.x, territory_cell.y)
		outline_land_cell(selected_center, Color("8ed6f8"))
		return
	if selection_kind == "grid_road" and road_selected_cell.x >= 0:
		var road_center: Vector3 = game.territory.cell_world(road_selected_cell.x, road_selected_cell.y)
		outline_land_cell(road_center, Color("f1c75b"))
		return
	if selection_kind in ["grid_house", "grid_upgrade"]:
		var entry: Dictionary = game.territory.building_by_id(grid_selected_id)
		if entry.is_empty():
			return
		var point: Vector3 = game.territory.building_center(entry)
		outline(point, Color("8ed6f8"))
		if selection_kind == "grid_upgrade":
			var current := territory_visuals.get_node_or_null(NodePath(grid_selected_id))
			if current != null:
				current.visual_root.hide()
			preview = create_object(world, entry.type_id, "grid_upgrade_preview", point)
			preview.set_level(mini(3, int(entry.get("level", 1)) + 1))
			preview.interaction_area.collision_layer = 0
			preview.set_language(game.language)
		else:
			if entry.type_id in ["logistics_center", "warehouse"]:
				for delivered: Dictionary in game.logistics_covered_buildings(entry.instance_id):
					outline(delivered.position, Color("83c99a"))
			var route: Array = game.service_route(grid_selected_id)
			for index in range(1, route.size()):
				var first := map_position(route[index - 1]) + Vector3(0, 0.3, 0)
				var second := map_position(route[index]) + Vector3(0, 0.3, 0)
				var edge := Art.box(highlights, (first + second) / 2, Vector3(0.17, 0.06, first.distance_to(second)), Color("8ed6f8"))
				edge.rotation.y = atan2(second.x - first.x, second.z - first.z)
		return
	if placing_stop:
		for cell: Vector2i in displayed_stop_cells():
			var point: Vector3 = game.territory.cell_world(cell.x, cell.y)
			var candidate := Sprite3D.new()
			candidate.name = "stop_candidate_%d_%d" % [cell.x, cell.y]
			candidate.texture = load("res://assets/icons/bus_stop_candidate.svg")
			candidate.pixel_size = 0.018
			candidate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			candidate.no_depth_test = true
			candidate.position = point + Vector3(0, 2.4, 0)
			stop_candidate_visuals.add_child(candidate)
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
	for entry: Dictionary in influence_targets(selected, preview_kind):
		outline(entry.position, Color("a7f384"))

func draw_buildable_hints(type_id: String) -> void:
	if type_id == "" or highlights == null:
		return
	if type_id in ["logistics_center", "warehouse"] and not game.logistics_building_allowed(type_id):
		return
	var footprint := Vector2i.ONE if type_id in ["clear", "road"] or Catalog.is_landscaping(type_id) else Catalog.footprint_cells(type_id)
	if game.budget < catalog_cost(type_id):
		return
	if type_id not in ["clear", "road"] and maxi(game.city_level(), game.campaign_stage) < Catalog.unlock_level(type_id):
		return
	if type_id in ["elite_residence", "business_tower"] and game.renewal_credits < 2:
		return
	var placements: Array[Vector3] = []
	for row in range(TerritoryGrid.HEIGHT):
		for col in range(TerritoryGrid.WIDTH):
			if game.empty_city_mode and not game.territory.is_revealed(col, row):
				continue
			if type_id in ["logistics_center", "warehouse"] and not game.logistics_site_allowed(type_id, col, row):
				continue
			var kind := "landscaping" if Catalog.is_landscaping(type_id) else type_id
			if game.territory.placement_reason(col, row, kind) != "":
				continue
			var offset := Vector3((footprint.x - 1) * TerritoryGrid.CELL_SIZE * 0.5, 0.24, (footprint.y - 1) * TerritoryGrid.CELL_SIZE * 0.5)
			placements.append(game.territory.cell_world(col, row) + offset)
	if placements.is_empty():
		return
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = plane
	multimesh.instance_count = placements.size()
	var patch_size := Vector3(footprint.x * TerritoryGrid.CELL_SIZE - 0.9, 1.0, footprint.y * TerritoryGrid.CELL_SIZE - 0.9)
	for index in range(placements.size()):
		multimesh.set_instance_transform(index, Transform3D(Basis().scaled(patch_size), placements[index]))
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.68, 0.82, 0.54, 0.19) if type_id == "clear" else Color(0.48, 0.8, 0.67, 0.17)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var hint := MultiMeshInstance3D.new()
	hint.name = "BuildableFrontierHints"
	hint.multimesh = multimesh
	hint.material_override = material
	hint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	highlights.add_child(hint)

func make_ghost(object: Node3D, color: Color) -> void:
	object.interaction_area.collision_layer = 0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, 0.42)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for item in object.visual_root.find_children("*", "GeometryInstance3D", true, false):
		item.material_override = material
		item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func dispatch() -> void:
	if game.dispatch(selection_kind):
		audio.play("siren", "Effects", game.vehicle)
	else:
		audio.play_ui("deny")
	refresh()

func ensure_legacy_visuals() -> void:
	if world == null or scenery == null:
		return
	if game.job != "" and game.job != "fire" and (car == null or not is_instance_valid(car)):
		car = create_object(world, "repair_van", "crew_0", map_position(game.vehicle))
	if game.job == "fire" and (fire_car == null or not is_instance_valid(fire_car)):
		fire_car = create_object(world, "fire_engine", "fire_engine_0", map_position(game.vehicle))
		fire_car.set_language(game.language)
	if game.legacy_problem_available("leak"):
		if leak_effect == null or not is_instance_valid(leak_effect):
			leak_effect = create_object(world, "water_leak", "leak_0", map_position(Vector3(-9, 0.24, 6)))
		make_marker("LeakMarker", map_position(Vector3(-9, 5, 6)))
	else:
		if leak_effect != null and is_instance_valid(leak_effect):
			leak_effect.queue_free()
			leak_effect = null
		var old_leak_marker := world.get_node_or_null("LeakMarker")
		if old_leak_marker != null:
			old_leak_marker.queue_free()
	if game.legacy_problem_available("signal"):
		if signal_object == null or not is_instance_valid(signal_object):
			signal_object = scenery.traffic_controller.get_problem_signal()
			if signal_object == null:
				signal_object = create_object(world, "traffic_signal", "LegacyProblemSignal", Vector3(-14.4, 0.18, 0))
		make_marker("SignalMarker", Vector3(-14.4, 5, 0))
	else:
		if signal_object != null and is_instance_valid(signal_object):
			signal_object.queue_free()
			signal_object = null
		var old_signal_marker := world.get_node_or_null("SignalMarker")
		if old_signal_marker != null:
			old_signal_marker.queue_free()
	if game.job == "" and car != null and is_instance_valid(car):
		car.queue_free()
		car = null

func dispatch_fire() -> void:
	if game.dispatch_fire(selected_fire_id):
		var assignment: Dictionary = game.fire_assignment(selected_fire_id)
		audio.play("siren", "Effects", assignment.get("vehicle", game.vehicle))
	else:
		audio.play_ui("deny")
	refresh()

func call_police_for_jam() -> void:
	if game.dispatch_police(selected_fire_id):
		audio.play("siren", "Effects", game.police_job.vehicle)
	else:
		audio.play_ui("deny")
	refresh()

func open_police_station_build() -> void:
	open_service_catalog("police_station")
	refresh()

func open_service_catalog(type_id: String) -> void:
	active_tab = "build_tab"
	catalog_category = "services"
	catalog_grid_target = Vector2i(-1, -1)
	territory_cell = Vector2i(-1, -1)
	territory_tool = "service"
	service_type = type_id
	selection_kind = "catalog"
	selected = -1

func sync_fire_engine_nodes() -> void:
	var active_ids: Dictionary = {}
	var active_siren_ids: Dictionary = {}
	for assignment: Dictionary in game.fire_assignments():
		var identifier: String = str(assignment.vehicle_id)
		var is_primary: bool = bool(assignment.get("primary", false))
		active_siren_ids[identifier] = true
		if is_primary:
			fire_car.visible = true
			fire_car.instance_id = identifier
			var primary_offset := Vector3.ZERO
			if assignment.phase == "repair" and bool(assignment.get("jam_cleared", false)):
				primary_offset = Vector3(0, 0, -2.4)
			fire_car.position = map_position(assignment.vehicle) + Vector3(0, 0.18, 0) + primary_offset
			fire_car.set_emergency_lights(assignment.phase == "travel", elapsed)
			if audio != null:
				audio.set_loop("fire_siren_" + identifier, "siren", "Effects", assignment.phase == "travel", assignment.vehicle, 0.28)
			continue
		active_ids[identifier] = true
		var engine: Node3D = fire_engine_nodes.get(identifier)
		if engine == null or not is_instance_valid(engine):
			engine = create_object(world, "fire_engine", identifier, map_position(assignment.vehicle))
			fire_engine_nodes[identifier] = engine
		engine.visible = true
		var roadside_offset := Vector3(0, 0, -2.4) if assignment.phase == "repair" and bool(assignment.get("jam_cleared", false)) else Vector3.ZERO
		engine.position = map_position(assignment.vehicle) + Vector3(0, 0.18, 0) + roadside_offset
		var route: Array = assignment.route
		if int(assignment.route_index) < route.size():
			var target_point: Vector3 = map_position(route[int(assignment.route_index)])
			var direction: Vector3 = target_point - engine.position
			if direction.length() > 0.01:
				engine.rotation.y = atan2(direction.x, direction.z)
		engine.set_emergency_lights(assignment.phase == "travel", elapsed)
		if audio != null:
			audio.set_loop("fire_siren_" + identifier, "siren", "Effects", assignment.phase == "travel", assignment.vehicle, 0.28)
	for identifier in fire_engine_nodes:
		var engine: Node3D = fire_engine_nodes[identifier]
		if is_instance_valid(engine):
			engine.visible = active_ids.has(identifier)
		if audio != null and not active_ids.has(identifier):
			audio.set_loop("fire_siren_" + identifier, "siren", "Effects", false)
	if not game.fire_assignments().any(func(assignment): return bool(assignment.get("primary", false))):
		if fire_car != null and is_instance_valid(fire_car):
			fire_car.queue_free()
			fire_car = null
	for identifier in fire_engine_nodes.keys():
		if active_ids.has(identifier):
			continue
		var inactive_engine: Node3D = fire_engine_nodes[identifier]
		if is_instance_valid(inactive_engine):
			inactive_engine.queue_free()
		fire_engine_nodes.erase(identifier)
	if audio != null:
		for loop_key in audio.loops.keys():
			if str(loop_key).begins_with("fire_siren_") and not active_siren_ids.has(str(loop_key).trim_prefix("fire_siren_")):
				audio.set_loop(str(loop_key), "siren", "Effects", false)

func sync_police_vehicle() -> void:
	var police := world.get_node_or_null("PoliceVehicle") as Node3D
	if game.police_job.is_empty():
		if police != null:
			police.queue_free()
		if audio != null:
			audio.set_loop("police_siren", "siren", "Effects", false)
		return
	if police == null:
		police = create_object(world, "police_car", "PoliceVehicle", map_position(game.police_job.vehicle))
		police.name = "PoliceVehicle"
	police.visible = true
	police.position = map_position(game.police_job.vehicle) + Vector3(0, 0.18, 0)
	if int(game.police_job.route_index) < game.police_job.route.size():
		var point: Vector3 = map_position(game.police_job.route[int(game.police_job.route_index)])
		var direction := point - police.position
		if direction.length() > 0.01:
			police.rotation.y = atan2(direction.x, direction.z)
	police.set_emergency_lights(game.police_job.phase == "travel", elapsed)
	if audio != null:
		audio.set_loop("police_siren", "siren", "Effects", game.police_job.phase == "travel", game.police_job.vehicle, 0.3)

func open_fire_station_build() -> void:
	open_service_catalog("fire_station")
	refresh()

func construct(kind: String) -> void:
	if game.start_legacy_construction(selected, kind):
		audio.play_construction(game.plot_position(selected), kind == "park")
		selection_kind = "construction_job"
		refresh()
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
	if world == null or camera == null:
		return
	ensure_legacy_visuals()
	elapsed += delta
	completion_left = maxf(0, completion_left - delta)
	if fire_notice_left > 0:
		fire_notice_left = maxf(0, fire_notice_left - delta)
		fire_notice.visible = fire_notice_left > 0
	jam_notice_cooldown = maxf(0.0, jam_notice_cooldown - delta)
	if game.completed and not game.fire_triggered and elapsed >= 5.0:
		if game.start_fire():
			refresh()
	update_mission_visibility()
	if OS.is_debug_build() and OS.has_feature("android"):
		diagnostic_clock += delta
		if diagnostic_clock >= 5:
			diagnostic_clock = 0
			print("FMT_METRICS ", JSON.stringify({"quality": quality, "fps": Engine.get_frames_per_second(), "citizens_pool": citizen_pool.get_child_count() if citizen_pool != null else 0, "citizens_on_screen": on_screen_citizen_count(), "map_size": str(viewport_container.get_child(0).size), "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "safe_top": safe_top, "safe_bottom": safe_bottom, "selection": selection_kind, "job": game.job, "leak_fixed": game.leak_fixed, "signal_fixed": game.signal_fixed}))
	scenery.traffic_controller.signal_fixed = game.signal_fixed
	scenery.traffic_controller.service_position = car.position if car != null else Vector3(1000, 0, 1000)
	scenery.traffic_controller.service_active = game.job != "" and game.job != "fire" and car != null
	scenery.traffic_controller.blocking_positions.clear()
	tick_logistics_vehicles(delta)
	sync_construction_site()
	var construction_truck: Node3D = construction_objects.get("truck")
	if construction_truck != null and is_instance_valid(construction_truck):
		scenery.traffic_controller.blocking_positions.append({"id": "construction_dump_truck", "position": construction_truck.position})
	var construction_work_vehicle: Node3D = construction_objects.get("digger")
	if construction_work_vehicle != null and is_instance_valid(construction_work_vehicle):
		scenery.traffic_controller.blocking_positions.append({"id": "construction_work_vehicle", "position": construction_work_vehicle.position})
	for sign_index in range(construction_objects.get("sign_positions", []).size()):
		scenery.traffic_controller.blocking_positions.append({"id": "construction_sign_%d" % sign_index, "position": construction_objects.sign_positions[sign_index]})
	var fire_motion: Dictionary = {}
	for assignment: Dictionary in game.fire_assignments():
		var fire_id: String = str(assignment.instance_id)
		if assignment.phase == "repair" and not bool(assignment.get("jam_cleared", false)):
			scenery.traffic_controller.blocking_positions.append({"id": str(assignment.vehicle_id), "incident_id": fire_id, "position": map_position(assignment.vehicle)})
		fire_motion[fire_id] = 1.0
		if assignment.phase == "travel" and int(assignment.route_index) < assignment.route.size():
			var current_fire := map_position(assignment.vehicle)
			var next_fire := map_position(assignment.route[int(assignment.route_index)])
			var intended_fire := current_fire.distance_to(next_fire)
			if intended_fire > 0.0001:
				fire_motion[fire_id] = scenery.traffic_controller.service_travel_distance(current_fire, current_fire.move_toward(next_fire, delta * 2.6), delta, str(assignment.vehicle_id), true) / intended_fire
	if not game.police_job.is_empty():
		if game.police_job.phase == "clearing":
			scenery.traffic_controller.blocking_positions.append({"id": "police_" + str(game.police_job.get("depot_instance_id", "")), "position": map_position(game.police_job.vehicle)})
		fire_motion["police"] = 1.0
		if game.police_job.phase == "travel" and int(game.police_job.route_index) < game.police_job.route.size():
			var police_current := map_position(game.police_job.vehicle)
			var police_next := map_position(game.police_job.route[int(game.police_job.route_index)])
			var police_intended := police_current.distance_to(police_next)
			if police_intended > 0.0001:
				fire_motion["police"] = scenery.traffic_controller.service_travel_distance(police_current, police_current.move_toward(police_next, delta * 2.8), delta, "police", false, str(game.police_job.incident_id)) / police_intended
	if scenery.traffic_controller.vehicles.size() > 2:
		scenery.traffic_controller.vehicles[2].managed = game.transit.active
	scenery.animate(elapsed)
	check_traffic_jam_notice()
	game.transit.tick(delta, scenery.traffic_controller, game.territory)
	if citizen_pool != null and is_instance_valid(citizen_pool):
		citizen_pool.tick(delta)
	update_transit_stats()
	var movement_fraction := 1.0
	if game.job != "" and game.route_index < game.route.size():
		var current := map_position(game.vehicle)
		var proposed := map_position(game.proposed_vehicle(delta))
		var intended := current.distance_to(proposed)
		if intended > 0.0001:
			movement_fraction = scenery.traffic_controller.service_travel_distance(current, proposed, delta, "crew_0", game.job == "fire" and game.job_phase == "travel") / intended
	var construction_was_active: bool = not game.construction_job.is_empty()
	var completed_construction: Dictionary = game.construction_job.duplicate(true)
	if game.tick(delta, true, movement_fraction, fire_motion):
		if construction_was_active and game.construction_job.is_empty():
			territory_signature = ""
			audio.play_ui("success")
			handle_construction_finish(completed_construction)
		else:
			refresh()
	sync_construction_site()
	audio.sync(game, camera.size / 2.2, delta)
	update_crew_status()
	if car != null and is_instance_valid(car):
		car.position = map_position(game.vehicle) + Vector3(0, 0.18, 0)
		car.visible = game.job != "fire" and game.job != ""
	if fire_car != null and is_instance_valid(fire_car):
		fire_car.position = map_position(game.vehicle) + Vector3(0, 0.18, 0)
		fire_car.visible = game.job == "fire"
	if fire_car != null and is_instance_valid(fire_car) and fire_car.visual_root.get_child_count() > 0:
		var primary_model: Node = fire_car.visual_root.get_child(0)
		if primary_model.has_method("set_emergency_lights"):
			primary_model.set_emergency_lights(game.job == "fire" and game.job_phase == "travel", elapsed)
	if car != null and game.job != "" and game.job != "fire" and game.route_index < game.route.size():
		var direction: Vector3 = map_position(game.route[game.route_index]) - car.position
		if direction.length() > 0.01:
			car.rotation.y = atan2(direction.x, direction.z)
			if absf(direction.x) > absf(direction.z):
				car.position.z += signf(direction.x)
			else:
				car.position.x -= signf(direction.z)
	if fire_car != null and is_instance_valid(fire_car) and car != null and is_instance_valid(car):
		fire_car.position = car.position
		fire_car.rotation = car.rotation
	sync_fire_engine_nodes()
	sync_police_vehicle()
	if leak_effect != null and is_instance_valid(leak_effect):
		leak_effect.visual_root.position.y = sin(elapsed * 6) * 0.12
	for marker_name in ["LeakMarker", "SignalMarker"]:
		var marker := world.get_node_or_null(marker_name) as Node3D
		if marker != null:
			marker.position.y = 5.2 + sin(elapsed * 2) * 0.15
	for road_signal in territory_visuals.get_children():
		if not road_signal.has_meta("expansion_intersection"):
			continue
		var offset: float = road_signal.get_meta("signal_offset", 0.0)
		road_signal.set_traffic_state(scenery.traffic_controller.phase("H", elapsed + offset), scenery.traffic_controller.phase("V", elapsed + offset))
	update_fire_visuals()
	save_clock += delta
	if save_clock > 2:
		game.save_game()
		save_clock = 0

func check_traffic_jam_notice() -> void:
	if jam_notice_cooldown > 0.0 or not game.police_job.is_empty() or scenery == null:
		return
	var jam_id := ""
	var blocker_position := Vector3.ZERO
	for blocker: Dictionary in scenery.traffic_controller.blocking_positions:
		var incident := str(blocker.get("incident_id", ""))
		if incident != "":
			jam_id = incident
			blocker_position = blocker.position
			break
	if jam_id == "":
		return
	for vehicle: Dictionary in scenery.traffic_controller.vehicles:
		if vehicle.node.type_id == "city_bus" or not vehicle.node.visible:
			continue
		if vehicle.node.position.distance_to(blocker_position) < 14.0 and scenery.traffic_controller.travel_distance(vehicle, 0.12) < 0.01:
			selected_fire_id = jam_id
			fire_notice_left = 4.0
			fire_notice_label.text = tr_text("Затор у пожарной машины · Нажмите на технику и вызовите полицию.", "Fire engine traffic jam · Tap the vehicle and call police.")
			fire_notice.show()
			jam_notice_cooldown = 4.0
			return

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if placing_stop:
			cancel_stop_placement()
		else:
			close_sheet()
		get_viewport().set_input_as_handled()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
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
	scenery.traffic_controller.set_active_count(0 if game.empty_city_mode else (8 if quality == "low" else (16 if quality == "medium" else 24)))
	if citizen_pool != null and is_instance_valid(citizen_pool):
		citizen_pool.set_quality(quality)
	Engine.max_fps = 30 if quality == "low" else 60
	update_layout()

func on_screen_citizen_count() -> int:
	if citizen_pool == null or camera == null or viewport_container.get_child_count() == 0:
		return 0
	var viewport := viewport_container.get_child(0) as SubViewport
	var bounds := Rect2(Vector2.ZERO, Vector2(viewport.size))
	var count := 0
	for walker: Dictionary in citizen_pool.walkers:
		var visual: Sprite3D = walker.visual
		if not visual.visible or camera.is_position_behind(visual.global_position):
			continue
		if bounds.has_point(camera.unproject_position(visual.global_position)):
			count += 1
	return count


func open_settings() -> void:
	close_sheet()
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
		game = Simulation.new(false)
		game.start_empty_city()
		game.language = previous_language
		game.save_game()
		get_tree().reload_current_scene())
	dialog.close_requested.connect(dialog.queue_free)
	dialog.canceled.connect(func():
		audio.play_ui("cancel")
		dialog.queue_free())
	dialog.get_ok_button().custom_minimum_size.y = 72
	dialog.get_cancel_button().custom_minimum_size.y = 72
	decorate_dialog(dialog)
	dialog.popup_centered()


func open_audio_settings() -> void:
	close_sheet()
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
	close_sheet()
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
	var task_done := game.district_task_progress()
	label(18, sheet_column, tr_text("Построено домов: %d/%d", "Homes built: %d/%d") % [game.district_house_count(), game.district_house_limit])
	label(18, sheet_column, tr_text("Заданий выполнено: %d/%d", "Tasks complete: %d/%d") % [task_done, game.district_tasks.size()])
	var district_progress := ProgressBar.new()
	district_progress.custom_minimum_size.y = 10
	district_progress.max_value = maxf(1.0, float(game.district_tasks.size()))
	district_progress.value = task_done
	district_progress.show_percentage = false
	district_progress.add_theme_stylebox_override("fill", style(Color("5b9bd5"), 5))
	sheet_column.add_child(district_progress)
	var next_goal := ""
	if game.completed:
		var has_new_road := false
		var has_new_house := false
		for entry: Dictionary in game.all_buildings():
			if not entry.has("legacy_plot"):
				has_new_house = has_new_house or entry.type_id == "house"
		for row in range(game.territory.expansion_rows.x, game.territory.expansion_rows.y + 1):
			for col in range(game.territory.expansion_cols.x, game.territory.expansion_cols.y + 1):
				if game.territory.state_at(col, row) == "road":
					has_new_road = true
		if not has_new_road:
			next_goal = t("next_goal_clear")
		elif not has_new_house:
			next_goal = t("next_goal_house")
		else:
			next_goal = t("next_goal_expand")
	else:
		next_goal = t("next_goal_expand")
	var goal_label := label(18, sheet_column, next_goal)
	goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal_label.add_theme_color_override("font_color", Color("506477"))
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

func selected_grid_record() -> Dictionary:
	for entry: Dictionary in game.all_buildings():
		if entry.instance_id == grid_selected_id:
			return entry
	return {}

func build_grid_house_sheet() -> void:
	var entry := selected_grid_record()
	if entry.is_empty():
		return
	if entry.type_id != "house":
		action_height = 270
		header(t(entry.type_id) + (" · %d/3" % entry.level if Catalog.LEVELS.has(entry.type_id) else ""))
		var premium_damage := game.house_damage(entry.instance_id)
		if premium_damage > 0:
			label(18, sheet_column, t("fire_damaged") % premium_damage).add_theme_color_override("font_color", Color("c96b52"))
			if game.fires.is_empty():
				var restoration_cost := 120 if game.is_ruined(entry.instance_id) else 40 + premium_damage
				if game.is_ruined(entry.instance_id):
					restoration_cost = maxi(120, int(Catalog.cost(entry.type_id) / 2))
				var restore_premium := button(sheet_column, (tr_text("Восстановить здание", "Restore building") if game.is_ruined(entry.instance_id) else tr_text("Устранить повреждения", "Repair damage")) + " · %d" % restoration_cost, func():
					if game.repair_fire_damage(entry.instance_id):
						audio.play_ui("success")
					refresh(), true)
				restore_premium.disabled = game.budget < restoration_cost or not game.construction_job.is_empty()
		if Catalog.LEVELS.has(entry.type_id):
			label(20, sheet_column, building_effect(entry.type_id, entry.level)).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			if entry.type_id == "logistics_center":
				label(18, sheet_column, tr_text("Склады: %d / %d · в зоне доставки: %d зданий", "Warehouses: %d / %d · %d buildings in delivery range") % [game.logistics_warehouse_count(), game.logistics_warehouse_limit(), game.logistics_covered_buildings(entry.instance_id).size()]).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			elif entry.type_id == "warehouse":
				var logistics_center := game.logistics_center_entry()
				var supplied_by_center := not logistics_center.is_empty() and game.territory.road_distance_between_buildings(logistics_center, entry, game.logistics_center_range()) >= 0
				label(18, sheet_column, tr_text("Связь с центром: %s · объектов вокруг: %d", "Connected to center: %s · nearby buildings: %d") % [tr_text("есть", "yes") if supplied_by_center else tr_text("нет", "no"), game.logistics_covered_buildings(entry.instance_id).size()]).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			var next_price: int = Catalog.level_data(entry.type_id, entry.level).upgrade_cost
			var improve := button(sheet_column, tr_text("Улучшить · %d", "Upgrade · %d") % next_price, func():
				selection_kind = "grid_upgrade"
				refresh(), true)
			var upgrade_unlocked: bool = not game.empty_city_mode or game.campaign_stage > entry.level
			improve.disabled = entry.level >= 3 or game.budget < next_price or not game.construction_job.is_empty() or not upgrade_unlocked or not game.logistics_upgrade_allowed(entry)
			if not upgrade_unlocked:
				label(15, sheet_column, tr_text("Улучшение откроется на этапе %d", "Upgrade unlocks at stage %d") % (entry.level + 1))
			elif entry.type_id == "warehouse" and not game.logistics_upgrade_allowed(entry):
				label(15, sheet_column, tr_text("Сначала улучшите логистический центр", "Upgrade the logistics center first"))
		else:
			label(20, sheet_column, tr_text("Занимает участок и сохраняет своё состояние.", "Occupies the lot and keeps its own state."))
		button(sheet_column, tr_text("Ещё", "More"), open_grid_more).name = "MoreButton"
		return
	action_height = 430
	header(t("house") + " · %d/3" % entry.level)
	var data: Dictionary = game.record_quality(entry)
	var condition := label(25, sheet_column, "● " + quality_name(data.score), true)
	condition.add_theme_color_override("font_color", quality_color(data.score))
	if not data.transport:
		var issue := label(20, sheet_column, tr_text("Нет транспорта — нужна остановка на полезном маршруте", "No transit — a stop on a useful route is needed"))
		issue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not data.services:
		label(20, sheet_column, tr_text("Службы задерживаются — проверьте дорогу и светофор", "Services delayed — check the road and signal")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var grid_damage := game.house_damage(grid_selected_id)
	var grid_ruined := game.is_ruined(grid_selected_id)
	if grid_damage > 0:
		label(20, sheet_column, t("fire_damaged") % grid_damage).add_theme_color_override("font_color", Color("c96b52"))
		if game.fires.is_empty():
			var grid_repair_price := 120 if game.is_ruined(grid_selected_id) else 40 + grid_damage
			var grid_restore := button(sheet_column, (tr_text("Восстановить дом", "Rebuild home") if game.is_ruined(grid_selected_id) else tr_text("Восстановить дом", "Restore home")) + " · %d" % grid_repair_price, func():
				if game.repair_fire_damage(grid_selected_id):
					audio.play_ui("success")
				refresh(), true)
			grid_restore.name = "RestoreDamagedHouse"
			grid_restore.disabled = game.budget < grid_repair_price
	label(20, sheet_column, t("residents") % [game.record_residents(entry), Catalog.level_data("house", entry.level).income])
	var narrow_screen: bool = screen.size.x < 420
	var row: HBoxContainer
	if not narrow_screen:
		row = hbox(sheet_column)
	var price: int = Catalog.level_data("house", entry.level).upgrade_cost
	var improve := button(sheet_column if narrow_screen else row, tr_text("Улучшить · %d", "Upgrade · %d") % price if entry.level < 3 else tr_text("Максимум", "Maximum"), func():
		selection_kind = "grid_upgrade"
		refresh(), true)
	improve.name = "UpgradeButton"
	var next_house_stage_unlocked: bool = not game.empty_city_mode or game.campaign_stage > entry.level
	improve.disabled = grid_ruined or entry.level >= 3 or not game.construction_job.is_empty() or not next_house_stage_unlocked
	if grid_ruined:
		label(18, sheet_column, tr_text("Руины нельзя улучшать. Сначала восстановите дом.", "Ruins cannot be upgraded. Rebuild the home first.")).add_theme_color_override("font_color", Color("b35b49"))
	elif not next_house_stage_unlocked:
		label(16, sheet_column, tr_text("Новый архитектурный этап откроется на уровне %d.", "The next architectural stage unlocks at level %d.") % (entry.level + 1))
	button(sheet_column if narrow_screen else row, tr_text("Ещё", "More"), open_grid_more).name = "MoreButton"
	var inspected: bool = bool(entry.get("inspected", false))
	if not inspected:
		var inspect_button := button(sheet_column, tr_text("Проверить выезд бригады", "Check crew access"), dispatch_grid_inspection)
		inspect_button.name = "InspectGridHouse"
		inspect_button.disabled = game.job != "" or game.service_route(grid_selected_id).is_empty()
		status = label(19, sheet_column)
		update_crew_status()

func dispatch_grid_inspection() -> void:
	if game.dispatch_to_building(grid_selected_id):
		audio.play("siren", "Effects", game.vehicle)
	else:
		audio.play_ui("deny")
	refresh()

func build_grid_upgrade_sheet() -> void:
	var entry := selected_grid_record()
	if entry.is_empty():
		return
	action_height = 320
	header(tr_text("Предпросмотр · %d/3", "Preview · %d/3") % mini(3, entry.level + 1))
	label(22, sheet_column, building_effect(entry.type_id, mini(3, entry.level + 1))).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var price: int = Catalog.level_data(entry.type_id, entry.level).upgrade_cost
	var confirm := button(sheet_column, tr_text("Улучшить · %d", "Upgrade · %d") % price, func():
		if game.start_grid_upgrade(grid_selected_id):
			audio.play_construction(DistrictWorld.logical_position(entry.position))
			selection_kind = "construction_job"
		else:
			selection_kind = "grid_house"
		refresh(), true)
	confirm.name = "ConfirmGridUpgrade"
	confirm.disabled = entry.level >= 3 or game.budget < price or not game.construction_job.is_empty() or not game.logistics_upgrade_allowed(entry)
	button(sheet_column, t("cancel"), func():
		selection_kind = "grid_house"
		refresh()).name = "CancelGridUpgrade"

func open_grid_more() -> void:
	var entry := selected_grid_record()
	if entry.is_empty():
		return
	var dialog := ConfirmationDialog.new()
	dialog.name = "GridDemolitionConfirmation"
	dialog.theme = ui_theme
	dialog.title = tr_text("Подтвердите снос", "Confirm demolition")
	dialog.ok_button_text = tr_text("Снести", "Demolish")
	dialog.cancel_button_text = t("cancel")
	var residents := game.record_residents(entry)
	var income_value := game.record_income(entry)
	dialog.dialog_text = tr_text("%s будет разобран примерно за 6 секунд. Участок освободится.\nЖители: −%d · доход: −%d/12 сек.\nТранспортный спрос и качество пересчитаются.\nВозврат: %d", "%s will be dismantled in about 6 seconds, freeing the lot.\nResidents: −%d · income: −%d/12 sec.\nTransit demand and quality will be recalculated.\nRefund: %d") % [t(entry.type_id), residents, income_value, game.grid_demolition_refund(grid_selected_id)]
	if Catalog.is_landscaping(entry.type_id):
		dialog.dialog_text = tr_text("Объект благоустройства будет удалён за 6 секунд; клетка освободится для нового оформления.", "The landscaping item will be removed in 6 seconds; the cell will be freed for another item.")
	var identifier := grid_selected_id
	var busy: bool = game.job != "" and game.target_instance_id == identifier
	if busy:
		dialog.dialog_text = tr_text("Дождитесь возвращения бригады в депо.", "Wait for the crew to return to the depot.")
	add_child(dialog)
	decorate_dialog(dialog)
	dialog.get_ok_button().disabled = busy or not game.can_demolish_grid_building(identifier) or not game.construction_job.is_empty()
	dialog.confirmed.connect(func():
		if game.start_grid_demolition(identifier):
			selection_kind = "construction_job"
			refresh()
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(480, 380))

func build_building_sheet() -> void:
	action_height = 0
	var kind: String = game.buildings[selected]
	var level_value: int = game.building_level(selected)
	var legacy_ruined := game.is_ruined("pine_district_legacy_%d" % selected)
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
		var damage := game.house_damage("pine_district_legacy_%d" % selected)
		if damage > 0:
			label(20, sheet_column, t("fire_damaged") % damage).add_theme_color_override("font_color", Color("c96b52"))
			if game.fires.is_empty():
				var house_id := "pine_district_legacy_%d" % selected
				var repair_price := 120 if game.is_ruined(house_id) else 40 + damage
				var restore := button(sheet_column, (tr_text("Восстановить дом", "Rebuild home") if game.is_ruined(house_id) else tr_text("Восстановить дом", "Restore home")) + " · %d" % repair_price, func():
					if game.repair_fire_damage(house_id):
						audio.play_ui("success")
					refresh(), true)
				restore.add_theme_font_size_override("font_size", 21 if screen.size.x < 420 else 24)
				restore.disabled = game.budget < repair_price
	else:
		label(22, sheet_column, building_effect(kind, level_value))
	if level_value < 3:
		label(20, sheet_column, tr_text("Следующий: ", "Next: ") + building_effect(kind, level_value + 1))
	else:
		label(20, sheet_column, tr_text("Достигнут третий уровень", "Level three reached"))
	var narrow_screen: bool = screen.size.x < 420
	var action_row: HBoxContainer
	if not narrow_screen:
		action_row = hbox(sheet_column)
	var improve_parent: Node = sheet_column if narrow_screen else action_row
	var improve := button(improve_parent, tr_text("Улучшить · %d", "Upgrade · %d") % game.upgrade_cost(selected) if level_value < 3 else tr_text("Максимум", "Maximum"), begin_upgrade, true)
	improve.name = "UpgradeButton"
	improve.disabled = legacy_ruined or level_value >= 3 or not game.construction_job.is_empty()
	if legacy_ruined:
		label(18, sheet_column, tr_text("Руины нельзя улучшать. Сначала восстановите дом.", "Ruins cannot be upgraded. Rebuild the home first.")).add_theme_color_override("font_color", Color("b35b49"))
	var more := button(sheet_column if narrow_screen else action_row, tr_text("Ещё", "More"), open_building_more)
	if not narrow_screen:
		more.size_flags_horizontal = Control.SIZE_SHRINK_END
		more.custom_minimum_size.x = 100
	more.name = "MoreButton"
	if not issues.is_empty():
		var key: String = issues[0][1]
		var caption: String = (tr_text("Устранить протечку", "Fix the leak") if key == "leak" else tr_text("Починить светофор", "Fix the signal")) if key in ["leak", "signal"] else tr_text("Открыть транспорт", "Open transit") if key == "transit" else t("build_tab")
		button(sheet_column, caption, house_action.bind(key))
	action_height = sheet_column.get_combined_minimum_size().y + 34

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
	moving_stop_index = -1
	selected_stop_index = -1
	refresh()

func open_stop_card(index: int) -> void:
	if index < 0 or index >= game.transit.stops.size():
		return
	selection_kind = "stop"
	selected_stop_index = index
	selected = -1
	placing_stop = false
	moving_stop_index = -1
	active_tab = "district"
	refresh()

func tapped_existing_stop(point: Vector2) -> int:
	for index in range(game.transit.stops.size()):
		var marker := camera.unproject_position(game.transit.stop_position(game.transit.stops[index], game.territory) + Vector3(0, 1.2, 0))
		if marker.distance_to(point) <= stop_tap_radius():
			return index
	return -1

func tapped_stop_candidate(point: Vector2) -> int:
	var candidates := displayed_stop_cells()
	for index in range(candidates.size()):
		var cell: Vector2i = candidates[index]
		var marker := camera.unproject_position(game.territory.cell_world(cell.x, cell.y) + Vector3(0, 1.6, 0))
		if marker.distance_to(point) <= stop_tap_radius():
			return index
	return -1

func stop_tap_radius() -> float:
	return 46.0 * render_scale / viewport_container.stretch_shrink

func valid_stop_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for row in range(TerritoryGrid.HEIGHT):
		for col in range(TerritoryGrid.WIDTH):
			var cell := Vector2i(col, row)
			if game.valid_stop_cell(cell, moving_stop_index if placing_stop else -1):
				if placing_stop and moving_stop_index >= 0 and game.transit.stop_cell(game.transit.stops[moving_stop_index], game.territory) == cell:
					continue
				result.append(cell)
	return result

func displayed_stop_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var visible_rect := Rect2(Vector2.ZERO, screen.size / viewport_container.stretch_shrink)
	for cell: Vector2i in valid_stop_cells():
		var point: Vector3 = game.territory.cell_world(cell.x, cell.y)
		var projected := camera.unproject_position(point + Vector3(0, 1.6, 0))
		if point.distance_to(focus_point) > 14.4 or not visible_rect.has_point(projected):
			continue
		result.append(cell)
		if result.size() >= 12:
			break
	return result

func stop_label(stop: Variant) -> String:
	var point: Vector3 = game.transit.stop_position(stop, game.territory)
	return "%.0f, %.0f" % [point.x, point.z]

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
		button(sheet_column, tr_text("Разместить остановку · 40", "Place a stop · 40"), begin_stop_placement, true)
	else:
		for index in range(game.transit.stops.size()):
			var stop_row := hbox(sheet_column)
			label(19, stop_row, tr_text("Остановка %d · дорога %s" % [index + 1, stop_label(game.transit.stops[index])], "Stop %d · road %s" % [index + 1, stop_label(game.transit.stops[index])]))
			button(stop_row, tr_text("Перенести", "Move"), begin_move_stop.bind(index))
		var launch := button(sheet_column, tr_text("Маршрут работает", "Route running") if game.transit.active else tr_text("Запустить автобус · 60", "Start bus · 60"), launch_transit, true)
		launch.disabled = game.transit.active or game.budget < 60
	var note := label(20, sheet_column, tr_text("Остановки связаны по дорожной сети, включая повороты. Полезна связь жилья с рабочими местами или кафе.", "Stops are connected through the road network, including turns. Routes are useful when they link homes to jobs or cafés."))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func build_bus_sheet() -> void:
	action_height = 360
	header(tr_text("Городской автобус", "City bus"), "pin")
	var metrics: Dictionary = game.transit_metrics()
	label(21, sheet_column, tr_text("Маршрут: %d остановки · охват %d жителей\nПолезные связи: %d · загрузка %d/%d\nЗадержка: %.0f сек.", "Route: %d stops · coverage %d residents\nUseful links: %d · load %d/%d\nDelay: %.0f sec.") % [game.transit.stops.size(), metrics.covered, metrics.served, metrics.load, metrics.capacity, maxf(game.transit.delay, game.transit.last_delay)])
	for index in range(game.transit.stops.size()):
		label(18, sheet_column, tr_text("Остановка %d · дорога %s" % [index + 1, stop_label(game.transit.stops[index])], "Stop %d · road %s" % [index + 1, stop_label(game.transit.stops[index])]))
	button(sheet_column, tr_text("Открыть транспорт", "Open transit"), open_transit)

func build_stop_sheet() -> void:
	action_height = 290
	if selected_stop_index < 0 or selected_stop_index >= game.transit.stops.size():
		selection_kind = "transit"
		build_transit_sheet()
		return
	header(tr_text("Остановка", "Bus stop"), "pin")
	label(21, sheet_column, tr_text("Остановка %d · охват маршрута: %d жителей", "Stop %d · route coverage: %d residents") % [selected_stop_index + 1, game.transit_metrics().covered])
	button(sheet_column, tr_text("Перенести", "Move stop"), begin_move_stop.bind(selected_stop_index), true).name = "MoveStopButton"
	button(sheet_column, t("cancel"), open_transit).name = "CloseStopButton"

func build_stop_placement_sheet() -> void:
	action_height = 265
	header(tr_text("Перенос остановки", "Move bus stop"), "pin")
	var instruction := label(23, sheet_column, tr_text("Выберите новое место у дороги", "Choose a new place by the road"), true)
	instruction.name = "MoveStopInstruction"
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label(19, sheet_column, tr_text("Старая остановка и маршрут останутся до выбора места.", "The old stop and route stay in place until you choose a location."))
	button(sheet_column, tr_text("Отмена", "Cancel"), cancel_stop_placement).name = "CancelStopPlacement"

func begin_stop_placement() -> void:
	placing_stop = true
	moving_stop_index = -1
	selected_stop_index = -1
	selection_kind = "stop_place"
	var candidates := valid_stop_cells()
	stop_candidate = 0
	set_camera_focus(Vector3(-14.4, 0, 0))
	refresh()

func begin_move_stop(index: int) -> void:
	if index < 0 or index >= game.transit.stops.size():
		return
	placing_stop = true
	moving_stop_index = index
	selected_stop_index = index
	selection_kind = "stop_place"
	var target_point: Vector3 = game.transit.stop_position(game.transit.stops[index], game.territory)
	set_camera_focus(target_point + Vector3(7, 0, 7))
	refresh()

func change_stop_candidate(delta: int) -> void:
	var candidates := displayed_stop_cells()
	if candidates.is_empty():
		return
	stop_candidate = posmod(stop_candidate + delta, candidates.size())
	var cell: Vector2i = candidates[stop_candidate]
	set_camera_focus(game.territory.cell_world(cell.x, cell.y) + Vector3(7, 0, 7))
	refresh()

func confirm_stop(candidate_index: int = -1) -> void:
	var candidates := displayed_stop_cells()
	if candidate_index < 0:
		candidate_index = stop_candidate
	if candidate_index < 0 or candidate_index >= candidates.size():
		audio.play_ui("deny")
		return
	var success: bool = game.move_stop(moving_stop_index, candidates[candidate_index]) if moving_stop_index >= 0 else game.place_stop(candidates[candidate_index])
	if success:
		placing_stop = false
		moving_stop_index = -1
		selected_stop_index = -1
		selection_kind = "transit"
		transit_signature = ""
		audio.play_ui("success")
	else:
		audio.play_ui("deny")
	refresh()

func cancel_stop_placement() -> void:
	placing_stop = false
	moving_stop_index = -1
	selection_kind = "stop" if selected_stop_index >= 0 else "transit"
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
	var show_route: bool = selection_kind in ["transit", "bus"] and game.transit.stops.size() == 2
	var signature := str([game.transit.stops, show_route])
	if signature == transit_signature:
		return
	transit_signature = signature
	clear_children(transit_visuals)
	for index in range(game.transit.stops.size()):
		var stop := create_object(transit_visuals, "bus_stop", "bus_stop_%d" % index, game.transit.stop_position(game.transit.stops[index], game.territory))
		if game.stop_orientation(game.transit.stops[index]) == "horizontal":
			stop.rotation.y = PI / 2.0
		stop.interaction_area.collision_layer = 0
	if show_route:
		var path: Array[Vector3] = game.transit.route_for(game.territory, 0, 1)
		for index in range(1, path.size()):
			var first: Vector3 = path[index - 1] + Vector3(0, 0.36, 0)
			var second: Vector3 = path[index] + Vector3(0, 0.36, 0)
			var edge := Art.box(transit_visuals, (first + second) / 2, Vector3(0.34, 0.08, first.distance_to(second)), Color("3daee8"))
			edge.rotation.y = atan2(second.x - first.x, second.z - first.z)

func redraw_logistics_vehicles() -> void:
	if logistics_visuals == null:
		return
	var signature := territory_signature
	if signature == logistics_visual_signature:
		return
	logistics_visual_signature = signature
	clear_children(logistics_visuals)
	logistics_vehicles.clear()
	var center := game.logistics_center_entry()
	if center.is_empty():
		return
	var center_routes := game.logistics_vehicle_routes(str(center.instance_id))
	var fleet_size: int = maxi(1, int(center.get("level", 1)))
	var center_groups: Array = []
	center_groups.resize(fleet_size)
	for index in range(fleet_size):
		center_groups[index] = []
	for route_index in range(center_routes.size()):
		center_groups[route_index % fleet_size].append(center_routes[route_index])
	for index in range(fleet_size):
		if not center_groups[index].is_empty():
			create_logistics_vehicle(str(center.instance_id), index, center_groups[index])
	for warehouse: Dictionary in game.territory.buildings:
		if warehouse.type_id != "warehouse":
			continue
		var local_routes := game.logistics_vehicle_routes(str(warehouse.instance_id))
		if not local_routes.is_empty():
			create_logistics_vehicle(str(warehouse.instance_id), 0, local_routes)

func create_logistics_vehicle(source_id: String, index: int, routes: Array) -> void:
	var first_route: Array = routes[0]
	if first_route.size() < 2:
		return
	var identifier := "delivery_%s_%d" % [source_id, index]
	var truck := create_object(logistics_visuals, "delivery_truck", identifier, first_route[0])
	truck.interaction_area.collision_layer = 0
	truck.set_language(game.language)
	logistics_vehicles.append({"object": truck, "routes": routes, "route_index": 0, "progress": 0.0, "speed": 5.8})

func tick_logistics_vehicles(delta: float) -> void:
	for vehicle: Dictionary in logistics_vehicles:
		var truck: Node3D = vehicle.get("object")
		if truck == null or not is_instance_valid(truck):
			continue
		var routes: Array = vehicle.routes
		if routes.is_empty():
			continue
		var route_index: int = int(vehicle.route_index)
		var route: Array = routes[route_index]
		if route.size() < 2:
			continue
		var lengths: Array[float] = []
		var total_length := 0.0
		for segment in range(1, route.size()):
			var segment_length: float = route[segment - 1].distance_to(route[segment])
			lengths.append(segment_length)
			total_length += segment_length
		if total_length <= 0.01:
			continue
		var progress: float = float(vehicle.progress) + delta * float(vehicle.speed)
		while progress >= total_length:
			progress -= total_length
			route_index = (route_index + 1) % routes.size()
			route = routes[route_index]
			if route.size() < 2:
				break
			lengths.clear()
			total_length = 0.0
			for segment in range(1, route.size()):
				var segment_length: float = route[segment - 1].distance_to(route[segment])
				lengths.append(segment_length)
				total_length += segment_length
		if total_length <= 0.01:
			continue
		vehicle.route_index = route_index
		vehicle.progress = progress
		var remaining := progress
		for segment in range(lengths.size()):
			var segment_length: float = lengths[segment]
			if remaining > segment_length:
				remaining -= segment_length
				continue
			var first: Vector3 = route[segment]
			var second: Vector3 = route[segment + 1]
			var direction := second - first
			truck.position = first.lerp(second, clampf(remaining / maxf(segment_length, 0.001), 0.0, 1.0))
			truck.rotation.y = atan2(direction.x, direction.z)
			break

func building_effect(kind: String, level_value: int) -> String:
	var data := Catalog.level_data(kind, level_value)
	if kind == "logistics_center":
		return tr_text("Прямой радиус %d дорожных клеток · разрешает %d склада", "Direct range %d road cells · permits %d warehouses") % [data.delivery_range, data.warehouse_limit]
	if kind == "warehouse":
		return tr_text("Запас %d единиц · местный радиус %d дорожных клеток", "Stores %d units · local range %d road cells") % [data.storage_capacity, data.delivery_range]
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
	if game.buildings[index] == kind and game.building_level(index) == expected_level and game.start_legacy_upgrade(index):
		audio.play_construction(game.plot_position(index), kind == "park")
		selection_kind = "construction_job"
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
	message.text += tr_text("\nВозврат средств: %d\nБонус соседства и окружение пересчитаются. Экскаватор и грузовик будут работать около 6 секунд.", "\nRefund: %d\nNeighbor bonuses and amenities will be recalculated. The excavator and dump truck will work for about 6 seconds.") % game.demolition_refund(index)
	add_child(dialog)
	decorate_dialog(dialog)
	dialog.confirmed.connect(func():
		if game.buildings[index] == kind and game.building_level(index) == level_value and game.start_legacy_demolition(index):
			selection_kind = "construction_job"
			refresh()
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(480, 570))

func update_mission_visibility() -> void:
	if game.empty_city_mode:
		mission.visible = not sheet.visible and not game.campaign_complete_pending
	else:
		mission.visible = not sheet.visible and (not game.completed or completion_left > 0)

func maybe_offer_subsidy() -> void:
	if not game.can_offer_subsidy() or (subsidy_dialog != null and is_instance_valid(subsidy_dialog)):
		return
	var overlay := ColorRect.new()
	overlay.name = "SubsidyOfferOverlay"
	overlay.color = Color(0.09, 0.12, 0.14, 0.48)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(overlay)
	var panel := PanelContainer.new()
	panel.name = "SubsidyOfferCard"
	panel.theme = ui_theme
	panel.add_theme_stylebox_override("panel", style(PAPER, 18, Color("e4ded2")))
	overlay.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var title_row := hbox(column, 4)
	var heading := label(23, title_row, tr_text("Поддержка города", "City support"), true)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close_button := button(title_row, "×", Callable(self, "close_subsidy_offer"))
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_button.custom_minimum_size = Vector2(56, 56)
	var subheading := label(21, column, tr_text("Бюджет исчерпан", "The city budget is empty"), true)
	var terms := label(18, column)
	terms.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	terms.text = tr_text("500 монет: удержание 100 за каждые 1000 дохода.\n1000 монет: удержание 200 за каждые 2000 дохода.\nДоход между порогами накапливается. Новая субсидия — после полного погашения долга.", "500 coins: repay 100 for each 1,000 income.\n1,000 coins: repay 200 for each 2,000 income.\nIncome between thresholds accumulates. Another grant is available after full repayment.")
	var options := VBoxContainer.new()
	options.add_theme_constant_override("separation", 8)
	column.add_child(options)
	subsidy_dialog = overlay
	var grant_500 := button(options, tr_text("Получить 500 монет", "Receive 500 coins"), func(): choose_subsidy(500), true)
	var grant_1000 := button(options, tr_text("Получить 1000 монет", "Receive 1,000 coins"), func(): choose_subsidy(1000))
	grant_500.custom_minimum_size.y = 72
	grant_1000.custom_minimum_size.y = 72
	layout_subsidy_offer()

func choose_subsidy(amount: int) -> void:
	if game.take_subsidy(amount):
		close_subsidy_offer()
		refresh()

func close_subsidy_offer() -> void:
	if subsidy_dialog != null and is_instance_valid(subsidy_dialog):
		subsidy_dialog.queue_free()
	subsidy_dialog = null

func layout_subsidy_offer() -> void:
	if subsidy_dialog == null or not is_instance_valid(subsidy_dialog) or screen == null:
		return
	var panel := subsidy_dialog.get_node_or_null("SubsidyOfferCard") as Control
	if panel == null:
		return
	var available := screen.size - Vector2(32, safe_top + safe_bottom + 48)
	var panel_size := Vector2(minf(500, available.x), minf(460, available.y))
	panel.position = Vector2((screen.size.x - panel_size.x) * 0.5, safe_top + (available.y - panel_size.y) * 0.5)
	panel.size = panel_size
