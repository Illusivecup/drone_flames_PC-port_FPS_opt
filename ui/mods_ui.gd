class_name ModsUI
extends RefCounted
## Пользовательский интерфейс управления модификациями DroneFlames PC Port
## DroneFlames Reborn — менеджер модов

static var cur_tab: int = 0 # 0: Установленные, 1: Каталог онлайн
static var filter_type: String = "all" # all, map, textures, ui, gameplay
static var selected_mod_id: String = ""
static var _detail_popup: Control = null
static var _verified_popup: Control = null
static var _signals_connected: bool = false
static var _active_menus: Menus = null

const VERIFIED_MODS: Array[String] = [
	"thermo_battery",
	"iskander_strike",
	"nuclear_strike",
	"airborne_assault",
	"fps_ping_overlay",
	"oasis_map"
]

static func is_mod_verified(mod_id: String, _data: Dictionary = {}) -> bool:
	return VERIFIED_MODS.has(mod_id)

static func get_mod_manager() -> Node:
	var loop = Engine.get_main_loop()
	if loop != null and "root" in loop and loop.root != null and loop.root.has_node("ModManager"):
		return loop.root.get_node("ModManager")
	return null

static func is_version_greater(v_new: String, v_cur: String) -> bool:
	if v_new == "" or v_cur == "" or v_new == v_cur:
		return false
	var parts_new: PackedStringArray = v_new.split(".")
	var parts_cur: PackedStringArray = v_cur.split(".")
	var max_len: int = maxi(parts_new.size(), parts_cur.size())
	for i in max_len:
		var n: int = int(parts_new[i]) if i < parts_new.size() else 0
		var c: int = int(parts_cur[i]) if i < parts_cur.size() else 0
		if n > c:
			return true
		elif n < c:
			return false
	return false

static func _ensure_signals(menus: Menus, mm: Node) -> void:
	_active_menus = menus
	if _signals_connected:
		return
	_signals_connected = true
	mm.mods_updated.connect(_refresh_ui)
	mm.catalog_loaded.connect(func(_arr: Array) -> void: _refresh_ui())
	mm.catalog_failed.connect(func(_err: String) -> void: _refresh_ui())
	mm.mod_download_completed.connect(func(_id: String) -> void: _refresh_ui())
	mm.mod_download_failed.connect(func(_id: String, err: String) -> void:
		print("[ModsUI] Download failed: ", err)
		_refresh_ui()
	)

static func _refresh_ui() -> void:
	if _active_menus != null and is_instance_valid(_active_menus) and _active_menus.current == "mods":
		_active_menus.show_mods(true)

static func build(menus: Menus, parent: VBoxContainer) -> void:
	var mm: Node = get_mod_manager()
	if mm == null:
		var err_lbl: Label = UiKit.lbl("Ошибка: ModManager не инициализирован", 12, UiKit.RED)
		parent.add_child(err_lbl)
		return

	_ensure_signals(menus, mm)
	var workshop: Button = UiKit.big("МАСТЕРСКАЯ КАРТ · ЛОКАЛЬНО", "gold", "", 38.0, 11)
	workshop.pressed.connect(func() -> void: menus.show_local_workshop())
	parent.add_child(workshop)


	# Верхняя панель: Переключатель вкладок
	var top_tabs: HBoxContainer = HBoxContainer.new()
	top_tabs.add_theme_constant_override("separation", 8)
	parent.add_child(top_tabs)

	var btn_installed: Button = UiKit.big("УСТАНОВЛЕННЫЕ (%d)" % mm.installed_mods.size(), "green" if cur_tab == 0 else "stone", "", 38.0, 11)
	btn_installed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_installed.pressed.connect(func() -> void:
		cur_tab = 0
		menus.show_mods(true)
	)
	top_tabs.add_child(btn_installed)

	var btn_catalog: Button = UiKit.big("КАТАЛОГ МОДОВ", "green" if cur_tab == 1 else "stone", "", 38.0, 11)
	btn_catalog.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_catalog.pressed.connect(func() -> void:
		cur_tab = 1
		if mm.has_method("get_full_catalog"):
			mm.get_full_catalog()
		if mm.catalog_mods.is_empty():
			mm.fetch_catalog()
		menus.show_mods(true)
	)
	top_tabs.add_child(btn_catalog)

	# Фильтры категорий
	var filter_row: HBoxContainer = HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 4)
	parent.add_child(filter_row)

	var filters: Array = [
		["Все", "all"],
		["Карты", "map"],
		["Текстуры", "textures"],
		["Интерфейс", "ui"],
		["Геймплей", "gameplay"]
	]
	for f in filters:
		var f_label: String = f[0]
		var f_val: String = f[1]
		var is_active: bool = filter_type == f_val
		var fb: Button = UiKit.big(f_label, "gold" if is_active else "stone", "", 28.0, 9)
		fb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fb.pressed.connect(func() -> void:
			filter_type = f_val
			menus.show_mods(true)
		)
		filter_row.add_child(fb)

	menus._sep(parent, 2)

	# Содержимое выбранной вкладки
	if cur_tab == 0:
		_build_installed_tab(menus, parent, mm)
	else:
		_build_catalog_tab(menus, parent, mm)

	menus._sep(parent, 4)

	# Нижняя панель действий
	var action_row: HBoxContainer = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	parent.add_child(action_row)

	var btn_folder: Button = UiKit.big("📁 ПАПКА МОДОВ", "stone", "", 36.0, 10)
	btn_folder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_folder.tooltip_text = mm.get_mods_disk_path()
	btn_folder.pressed.connect(func() -> void:
		mm.open_mods_folder_in_os()
	)
	action_row.add_child(btn_folder)

	var btn_refresh: Button = UiKit.big("🔄 ОБНОВИТЬ СПИСОК", "stone", "", 36.0, 10)
	btn_refresh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_refresh.pressed.connect(func() -> void:
		mm.scan_installed_mods()
		mm.fetch_catalog()
		menus.show_mods(true)
	)
	action_row.add_child(btn_refresh)

	var btn_diagnostics: Button = UiKit.big("📋 ДИАГНОСТИКА", "stone", "Скопировать версии и состояние установленных модов", 36.0, 10)
	btn_diagnostics.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_diagnostics.pressed.connect(func() -> void:
		if mm.has_method("build_diagnostics_report"):
			DisplayServer.clipboard_set(String(mm.call("build_diagnostics_report")))
			menus._mp_toast("Отчёт о модах скопирован. Пришлите его вместе с жалобой.")
	)
	action_row.add_child(btn_diagnostics)

	# Кнопка НАЗАД внизу
	var bot_row: HBoxContainer = menus._bottom_row()
	var back_btn: Button = menus._button(bot_row, "НАЗАД", "stone", "")
	back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_btn.pressed.connect(func() -> void:
		UiKit.snd("ui_click")
		if bool(menus.get("_mods_from_settings")):
			menus.set("_mods_from_settings", false)
			menus.show_mods_settings(menus._from_pause)
		else:
			menus.request.emit("main")
	)

static func _build_installed_tab(menus: Menus, parent: VBoxContainer, mm: Node) -> void:
	var list_container: VBoxContainer = VBoxContainer.new()
	list_container.add_theme_constant_override("separation", 6)
	parent.add_child(list_container)

	var mods: Dictionary = mm.installed_mods
	if mods.is_empty():
		var empty_panel: PanelContainer = PanelContainer.new()
		empty_panel.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 14, 12))
		list_container.add_child(empty_panel)
		var vb_empty: VBoxContainer = VBoxContainer.new()
		vb_empty.add_theme_constant_override("separation", 10)
		empty_panel.add_child(vb_empty)

		var empty_lbl: Label = UiKit.lbl("У вас пока нет установленных модов.\nПерейдите в «КАТАЛОГ МОДОВ», чтобы выбрать и установить нужные модификации.", 11, UiKit.MUTED)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb_empty.add_child(empty_lbl)

		var btn_go_cat: Button = UiKit.big("🛒 ПЕРЕЙТИ В КАТАЛОГ МОДОВ", "green", "", 34.0, 11)
		btn_go_cat.pressed.connect(func() -> void:
			cur_tab = 1
			menus.show_mods(true)
		)
		vb_empty.add_child(btn_go_cat)
		return

	# Сортируем: сначала включенные, потом выключенные
	var keys: Array = mods.keys()
	keys.sort_custom(func(a: String, b: String) -> bool:
		var ea: bool = mm.is_mod_enabled(a)
		var eb: bool = mm.is_mod_enabled(b)
		if ea != eb:
			return ea and not eb
		return a < b
	)

	var count_shown: int = 0
	for mod_id in keys:
		var data: Dictionary = mods[mod_id]
		var type_str: String = String(data.get("type", "other"))
		if filter_type != "all" and type_str != filter_type:
			continue

		count_shown += 1
		_build_mod_card(menus, list_container, data, mm, true)

	if count_shown == 0:
		var no_filter_lbl: Label = UiKit.lbl("Нет установленных модов в категории '%s'" % filter_type, 10, UiKit.MUTED)
		no_filter_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list_container.add_child(no_filter_lbl)

static func _build_catalog_tab(menus: Menus, parent: VBoxContainer, mm: Node) -> void:
	var list_container: VBoxContainer = VBoxContainer.new()
	list_container.add_theme_constant_override("separation", 6)
	parent.add_child(list_container)

	var cat_mods: Array = mm.get_full_catalog() if mm.has_method("get_full_catalog") else mm.catalog_mods
	if cat_mods.is_empty():
		var loading_panel: PanelContainer = PanelContainer.new()
		loading_panel.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 12, 10))
		list_container.add_child(loading_panel)
		var l_col: VBoxContainer = VBoxContainer.new()
		l_col.add_theme_constant_override("separation", 8)
		loading_panel.add_child(l_col)

		var load_lbl: Label = UiKit.lbl("Загрузка каталога модов...", 10, UiKit.GOLD)
		load_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l_col.add_child(load_lbl)

		var retry_btn: Button = UiKit.big("ПРОВЕРИТЬ КАТАЛОГ СЕЙЧАС", "green", "", 34.0, 10)
		retry_btn.pressed.connect(func() -> void:
			mm.fetch_catalog()
		)
		l_col.add_child(retry_btn)
		return

	var count_shown: int = 0
	for cat_data in cat_mods:
		var type_str: String = String(cat_data.get("type", "other"))
		if filter_type != "all" and type_str != filter_type:
			continue

		count_shown += 1
		_build_mod_card(menus, list_container, cat_data, mm, false)

	if count_shown == 0:
		var no_match_lbl: Label = UiKit.lbl("Нет доступных модов в категории '%s'" % filter_type, 10, UiKit.MUTED)
		no_match_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list_container.add_child(no_match_lbl)

static func _format_author(raw_author: String) -> String:
	var author: String = raw_author.strip_edges()
	if author.is_empty():
		return "сообщество"
	if author.begins_with("@"):
		while author.begins_with("@"):
			author = author.substr(1)
		return "@" + author
	return author if author.contains("@") else "@" + author


static func _build_mod_card(menus: Menus, parent: VBoxContainer, data: Dictionary, mm: Node, is_installed_view: bool) -> void:
	var mod_id: String = String(data.get("id", ""))
	var mod_name: String = String(data.get("name", mod_id))
	var mod_ver: String = String(data.get("version", "1.0.0"))
	var mod_author: String = _format_author(String(data.get("author", "сообщество")))
	var mod_desc: String = String(data.get("description", ""))
	var mod_type: String = String(data.get("type", "map"))

	var is_installed: bool = mm.is_mod_installed(mod_id)
	var is_enabled: bool = mm.is_mod_enabled(mod_id)

	# Если это карточка каталога, но мод уже установлен, берем установленную версию
	var installed_ver: String = ""
	if is_installed and mm.installed_mods.has(mod_id):
		installed_ver = String(mm.installed_mods[mod_id].get("version", ""))

	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBox = UiKit.sb("wb_panel", 10, 8)
	if is_installed and is_enabled:
		style = UiKit.sb("wb_window", 10, 8)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)

	# 1. Иконка мода (Единая логика для обеих вкладок)
	var icon_box: TextureRect = TextureRect.new()
	icon_box.custom_minimum_size = Vector2(44, 44)
	icon_box.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_box.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var icon_tex: Texture2D = mm.get_mod_icon(mod_id, data)
	if icon_tex != null:
		icon_box.texture = icon_tex
	else:
		var def_icon_name: String = "map_t_normal"
		match mod_id:
			"city_expansion": def_icon_name = "icon_city"
			"nuclear_strike": def_icon_name = "icon_m_ballistic"
			_:
				match mod_type:
					"textures": def_icon_name = "icon_flag_paint"
					"ui": def_icon_name = "icon_settings"
					"gameplay": def_icon_name = "icon_stance_attack"
		icon_box.texture = UiKit.tex(def_icon_name)
	row.add_child(icon_box)

	# 2. Информационный блок
	var info_col: VBoxContainer = VBoxContainer.new()
	info_col.add_theme_constant_override("separation", 2)
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info_col)

	# Заголовок + версия + бейдж типа
	var title_row: HBoxContainer = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 6)
	info_col.add_child(title_row)

	var title_lbl: Label = UiKit.lbl(mod_name.to_upper(), 11, UiKit.TITLE, 1, 1)
	title_row.add_child(title_lbl)

	if is_mod_verified(mod_id, data):
		var v_tex: Texture2D = UiKit.tex("mod_verified")
		if v_tex != null:
			var v_btn: TextureButton = TextureButton.new()
			v_btn.texture_normal = v_tex
			v_btn.custom_minimum_size = Vector2(16, 16)
			v_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			v_btn.ignore_texture_size = true
			v_btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			v_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			v_btn.tooltip_text = "Верифицированная модификация (нажмите для подробностей)"
			v_btn.pressed.connect(func() -> void: _show_verified_dialog(menus, mod_name))
			title_row.add_child(v_btn)

	var display_ver: String = installed_ver if (is_installed_view and installed_ver != "") else mod_ver
	var ver_lbl: Label = UiKit.lbl("v" + display_ver, 9, UiKit.GOLD)
	title_row.add_child(ver_lbl)

	var type_label_ru: String = "КАРТА"
	match mod_type:
		"textures": type_label_ru = "ТЕКСТУРЫ"
		"ui": type_label_ru = "ИНТЕРФЕЙС"
		"gameplay": type_label_ru = "ГЕЙМПЛЕЙ"
	var type_badge: Label = UiKit.lbl("[" + type_label_ru + "]", 8, UiKit.MUTED)
	title_row.add_child(type_badge)

	# Краткое описание
	var desc_lbl: Label = UiKit.lbl(mod_desc, 9, UiKit.MUTED)
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_col.add_child(desc_lbl)

	# Автор
	var author_lbl: Label = UiKit.lbl("Автор: " + mod_author, 8, Color(0.6, 0.7, 0.9))
	author_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	info_col.add_child(author_lbl)
	var load_error: String = String(data.get("_load_error", ""))
	if load_error != "":
		var error_lbl: Label = UiKit.lbl("ОШИБКА ЗАГРУЗКИ: " + load_error, 8, UiKit.RED)
		error_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_col.add_child(error_lbl)

	# 3. Кнопки действий справа
	var act_col: VBoxContainer = VBoxContainer.new()
	act_col.add_theme_constant_override("separation", 4)
	act_col.custom_minimum_size = Vector2(96, 0)
	act_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(act_col)

	# Проверяем наличие обновления
	var update_available: bool = false
	var latest_ver: String = ""
	var catalog_entry: Dictionary = {}
	if is_installed:
		var cur_v: String = installed_ver if installed_ver != "" else mod_ver
		for cat in mm.catalog_mods:
			if String(cat.get("id", "")) == mod_id:
				catalog_entry = cat
				latest_ver = String(cat.get("version", ""))
				if is_version_greater(latest_ver, cur_v):
					update_available = true
				break

	if update_available:
		var btn_up: Button = UiKit.big("ОБНОВИТЬ v" + latest_ver, "gold", "", 28.0, 9)
		btn_up.pressed.connect(func() -> void:
			if not catalog_entry.is_empty():
				mm.download_and_install_mod(catalog_entry)
		)
		act_col.add_child(btn_up)

	var this_id: String = mod_id
	if is_installed:
		# Тумблер ВКЛ / ВЫКЛ
		var tog_text: String = "ВКЛЮЧЕН" if is_enabled else "ОТКЛЮЧЕН"
		var tog_color: String = "green" if is_enabled else "stone"
		var btn_tog: Button = UiKit.big(tog_text, tog_color, "", 28.0, 9)
		btn_tog.pressed.connect(func() -> void:
			var cur_state: bool = mm.is_mod_enabled(this_id)
			mm.toggle_mod(this_id, not cur_state)
		)
		act_col.add_child(btn_tog)
	else:
		# Кнопка установки
		var is_this_downloading: bool = mm._is_downloading and mm._download_mod_id == mod_id
		if is_this_downloading:
			var btn_down: Button = UiKit.big("ЗАГРУЗКА...", "gold", "", 28.0, 9)
			btn_down.disabled = true
			act_col.add_child(btn_down)
		else:
			var btn_down: Button = UiKit.big("УСТАНОВИТЬ", "green", "", 28.0, 9)
			btn_down.pressed.connect(func() -> void:
				if mm.has_method("install_catalog_mod"):
					mm.install_catalog_mod(data)
				else:
					mm.download_and_install_mod(data)
			)
			act_col.add_child(btn_down)

	# Кнопка «ОПИСАНИЕ»
	var btn_info: Button = UiKit.big("ОПИСАНИЕ", "stone", "", 24.0, 8)
	btn_info.pressed.connect(func() -> void:
		_open_detail_card(menus, data, mm)
	)
	act_col.add_child(btn_info)

	# Кнопка удаления для установленных модов
	if is_installed:
		var btn_del: Button = UiKit.big("УДАЛИТЬ", "red", "", 22.0, 8)
		btn_del.pressed.connect(func() -> void:
			mm.uninstall_mod(this_id)
		)
		act_col.add_child(btn_del)

# ==============================================================================
# МОДАЛЬНОЕ ОКНО ПОДРОБНОГО ОПИСАНИЯ МОДА
# ==============================================================================

static func _open_detail_card(menus: Menus, data: Dictionary, _mm: Node) -> void:
	if _detail_popup != null and is_instance_valid(_detail_popup):
		_detail_popup.queue_free()
		_detail_popup = null

	var mod_id: String = String(data.get("id", ""))
	var mod_name: String = String(data.get("name", mod_id))
	var mod_ver: String = String(data.get("version", "1.0.0"))
	var mod_author: String = _format_author(String(data.get("author", "сообщество")))
	var mod_details: String = String(data.get("details", data.get("description", "")))
	var tags: Array = data.get("tags", [])

	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.04, 0.08, 0.75)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	menus.root.add_child(bg)
	_detail_popup = bg

	var cc: CenterContainer = CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(cc)

	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.sb("wb_window", 16, 14))
	panel.custom_minimum_size = Vector2(460, 0)
	cc.add_child(panel)

	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	# Шапка
	var head_box: HBoxContainer = HBoxContainer.new()
	head_box.add_theme_constant_override("separation", 8)
	vb.add_child(head_box)

	var title_lbl: Label = UiKit.lbl(mod_name.to_upper(), 14, UiKit.TITLE, 2, 2)
	head_box.add_child(title_lbl)

	if is_mod_verified(mod_id, data):
		var v_tex: Texture2D = UiKit.tex("mod_verified")
		if v_tex != null:
			var v_btn: TextureButton = TextureButton.new()
			v_btn.texture_normal = v_tex
			v_btn.custom_minimum_size = Vector2(20, 20)
			v_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			v_btn.ignore_texture_size = true
			v_btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			v_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			v_btn.tooltip_text = "Верифицированная модификация (нажмите для подробностей)"
			v_btn.pressed.connect(func() -> void: _show_verified_dialog(menus, mod_name))
			head_box.add_child(v_btn)

	var meta_row: HBoxContainer = HBoxContainer.new()
	meta_row.add_theme_constant_override("separation", 8)
	vb.add_child(meta_row)

	meta_row.add_child(UiKit.lbl("Версия: v" + mod_ver, 10, UiKit.GOLD))
	meta_row.add_child(UiKit.lbl("•", 10, UiKit.MUTED))
	meta_row.add_child(UiKit.lbl("Автор: " + mod_author, 10, Color(0.6, 0.7, 0.9)))

	if not tags.is_empty():
		var tag_str: String = "Теги: " + ", ".join(tags)
		vb.add_child(UiKit.lbl(tag_str, 9, UiKit.MUTED))

	var div: ColorRect = ColorRect.new()
	div.color = Color(UiKit.GOLD, 0.4)
	div.custom_minimum_size = Vector2(0, 2)
	vb.add_child(div)

	# Детальный текст
	var details_scroll: ScrollContainer = ScrollContainer.new()
	details_scroll.custom_minimum_size = Vector2(0, 150)
	vb.add_child(details_scroll)

	var det_lbl: Label = UiKit.lbl(mod_details, 10, UiKit.TEXT)
	det_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	det_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_scroll.add_child(det_lbl)

	# Кнопка закрытия
	var close_btn: Button = UiKit.big("ЗАКРЫТЬ", "stone", "", 34.0, 11)
	close_btn.pressed.connect(func() -> void:
		bg.queue_free()
		_detail_popup = null
	)
	vb.add_child(close_btn)

# ==============================================================================
# МОДАЛЬНОЕ ОКНО ВЕРИФИКАЦИИ МОДА
# ==============================================================================

static func _show_verified_dialog(menus: Menus, mod_name: String) -> void:
	if _verified_popup != null and is_instance_valid(_verified_popup):
		_verified_popup.queue_free()
		_verified_popup = null

	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.04, 0.08, 0.8)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	menus.root.add_child(bg)
	_verified_popup = bg

	var cc: CenterContainer = CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(cc)

	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.sb("wb_window", 16, 14))
	panel.custom_minimum_size = Vector2(400, 0)
	cc.add_child(panel)

	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	# Шапка окна с иконкой верификации
	var head_row: HBoxContainer = HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 8)
	head_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(head_row)

	var v_icon: TextureRect = TextureRect.new()
	v_icon.texture = UiKit.tex("mod_verified")
	v_icon.custom_minimum_size = Vector2(24, 24)
	v_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	v_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	v_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	head_row.add_child(v_icon)

	var title_lbl: Label = UiKit.lbl("ВЕРИФИЦИРОВАННЫЙ МОД", 12, Color(0.3, 0.7, 1.0), 2, 2)
	head_row.add_child(title_lbl)

	var div: ColorRect = ColorRect.new()
	div.color = Color(UiKit.GOLD, 0.4)
	div.custom_minimum_size = Vector2(0, 2)
	vb.add_child(div)

	# Текст сводки
	var desc_text: String = "Модификация «%s» проверена нашей официальной командой разработчиков.\n\n" % mod_name
	desc_text += "• Полная безопасность и отсутствие вредоносного кода\n"
	desc_text += "• 100% совместимость и стабильная работа в игре\n"
	desc_text += "• Официально протестировано на всех поддерживаемых платформах"
	var text_lbl: Label = UiKit.lbl(desc_text, 10, UiKit.TEXT)
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(text_lbl)

	# Кнопка закрытия
	var close_btn: Button = UiKit.big("ЗАКРЫТЬ", "green", "", 36.0, 11)
	close_btn.pressed.connect(func() -> void:
		if is_instance_valid(bg):
			bg.queue_free()
		_verified_popup = null
	)
	vb.add_child(close_btn)

