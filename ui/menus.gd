class_name Menus
extends CanvasLayer




signal request(name: String)

const VERSION: String = "v0.33.5.38 (PC Port by @droneflamesmod)"

const WHATS_NEW: Array = [
        "ОНЛАЙН v0.33.5.38: друзья, личные сообщения, приглашения, синхронизация профиля и исправления подключения",
        "ОНЛАЙН v0.33.5.37-test: навигация при тайм-ауте, действия в профиле и настройки личных сообщений",
        "ОНЛАЙН v0.33.5.36-test: вход, друзья, личные сообщения и приглашения в лобби",
        "ПЛАТФОРМЫ v0.33.5.35-test: сборка Linux x86_64, установка из релиза и обновление из меню игры",
        "БАЛАНС v0.33.5.34-test: каждый основанный город повышает цену следующего на 250 до максимума в 2000",
        "СЕТЕВАЯ ИГРА v0.33.5.33-test: кнопка чата рядом с лобби, отдельное окно и быстрые фразы",
        "СЕТЕВАЯ ИГРА v0.33.5.32-test: чат до начала матча, исключение игроков хостом",
        "СЕТЕВАЯ ИГРА v0.33.5.30-test: исправлена обработка пакетов relay и подтверждений снапшота, повторная синхронизация теперь отслеживается отдельно для каждого игрока, моды временно выключаются при входе в сетевую игру",
        "ТЕСТ v0.33.5.29-test: исправление бесконечной синхронизации на 10-15 минуте партии (сторожевой таймер 20с для сетевых снапшотов, сглаживание субпиксельных рассинхронов, передача слота ИИ при 3 сбоях вместо зависания хоста); автопроверка модов при входе в лобби с диалогом докачки недостающих модов; починка синтаксиса ядерного мода (nuclear_strike); плавная индикация загрузки и кнопка восстановления модов; автопоиск серверов в локальной сети и Radmin VPN (26.0.0.0/8)",
        "ИНТЕРФЕЙС & ВИДЕО v0.33.5.2: панель склада поднята вплотную к верхней полосе, разграничены клики по ресурсам (деньги -> доходы, энергия -> цепочки, склад -> склад, зеленая полоса -> страна); адаптивный полноэкранный фон вступительного трейлера без черных полос; пасхалка на сплэш-скрине запуска (@droneflamesmod, @nufxa и уточка)",
        "ВЕРИФИКАЦИЯ МОДОВ v0.33.5.2: галочка верификации выдана строго на 6 официальных модов (Солнцепёк, Искандер-М, Ядерный арсенал, ВДВ, FPS-мод, Оазис в пустыне), исправлено отображение иконки без пустых отступов у остальных модов",
        "ИСКАНДЕР & МОДЫ v0.33.5.2: интеграция ОТРК «Искандер-М» в меню ударов (ОФ и кассетные БЧ, гиперзвуковой полёт), ВДВ v1.3.0 с поддержкой нескольких штабов (6 цветов), ядерный удар v1.2.0 с 5-фазной вспышкой, ТОС-1А с радиусом 90-640px, сквозной клик по ярлыкам операций",
        "СТРОИТЕЛЬСТВО v0.33.5.2: живой предпросмотр (обложка) постройки при зажатом Shift в реальном времени под курсором, непрерывное размещение по клику и мгновенное подтверждение по клавише E",
        "МУЛЬТИПЛЕЕР v0.33.5.2: исправлена ошибка проверки TLS сертификата релей-сервера (-9984), восстановлен доступ к сетевой игре",
        "ОПТИМИЗАЦИЯ v0.33.5.2: многоуровневая система оптимизации, батчинг деревьев (сокращение Draw Calls в разы), отсечение невидимых чанков, авто-FPS при просадках, фикс ночных мешей и детальная настройка в меню Графика",
        "КЕЙБИНДЫ v0.33.5.2: постройка зданий и копание окопов без подтверждения по Shift, моментальная установка нескольких казарм подряд, клавиши B (казармы) и T (окопы), умный Esc",
        "МУЛЬТИПЛЕЕР v0.33.4.9: позднее подключение к партии, возврат за свою страну и управление свободной страной ИИ",
        "ЧЁТКОСТЬ v0.33.4.8: исправлено размытие шрифтов и 2D-графики при масштабировании окна",
        "ПВО v0.33.4.8: окно целей и кнопки по размеру панели, без обрезания на широком экране",
        "СОХРАНЕНИЯ v0.33.4.8: постоянная папка данных и безопасное копирование сохранений из папок прошлых версий",
        "МОД СООБЩЕСТВА v0.33.4.8: добавлен оверлей FPS и реального ping для сетевой партии",
        "ХОТФИКС v0.33.4.7: устранена ошибка компиляции меню, вызывавшая серый экран после запуска",
        "ГОРОДА v0.33.4.6: декоратор с деревьями, кустами, цветами, домами, магазинами и улицами",
        "СОХРАНЕНИЯ v0.33.4.6: импорт и экспорт файлов сохранений из списка слотов",
        "АВИАЦИЯ v0.33.4.6: мод добавляет подвес двух КАБ на истребители",
        "ПРОИЗВОДИТЕЛЬНОСТЬ v0.33.4.6: локальные проверки целей и укреплений используют пространственные индексы войск",
        "МОДЫ v0.33.4.6: повторная постройка и единый центр улучшений экономики и вооружения",
        "ИНТЕРФЕЙС v0.33.4.6: автоматическое увеличение до 150% на 4K и до 200% на 5K+, масштаб можно выбрать вручную или вернуть на авто",
        "НАСТРОЙКИ v0.33.4.5: выбор разрешения рендера с сохранением; список ограничен разрешением монитора",
        "СИСТЕМА МОДОВ v0.33.4.5: исправлена загрузка скачанных модов с собственными типами и безопасная установка поверх старой версии",
        "СИСТЕМА МОДОВ v0.33.4.5: после установки встроенного мода каталог обновляется сразу; исправлено отображение авторов без дублирования @",
        "МОД ПТРК v0.33.4.5: урон и проверка целей используют боевую систему игры, союзники защищены от поражения",
        "АВТООБНОВЛЕНИЕ v0.33.4.4: устранено ложное циклическое уведомление об обновлении при уже установленной последней версии",
        "МУЛЬТИПЛЕЕР v0.33.4.3: сохранение партии у хоста по кнопке «СОХРАНИТЬ» в меню паузы (Esc)",
        "МУЛЬТИПЛЕЕР v0.33.4.3: игроки сохраняются у хоста по никам и автоматически восстанавливают свои страны при входе",
        "МУЛЬТИПЛЕЕР v0.33.4.3: приглашение друзей в уже созданное лобби/игру по IP или коду, автопоиск в локальной сети",
        "МУЛЬТИПЛЕЕР v0.33.4.3: кнопка «СОХРАНИТЬ И ВЫЙТИ» для безопасного сохранения сетевой партии",
        "ХОТФИКС v0.33.4.2: чистое ванильное начало — моды устанавливаются игроком вручную из каталога",
        "КАТАЛОГ МОДОВ v0.33.4.2: установка и удаление модов в 1 клик, карточки с описанием и статусом",
        "ОБНОВЛЕНИЯ v0.33.4.2: мгновенный прямой старт скачивания файла установщика через браузер",
        "ИСПРАВЛЕНИЯ МОДОВ: восстановлена установка всех построек (Танковый завод, Ядерная шахта, Штаб ВДВ)",
        "ПК-ПОРТ: управление клавиатурой и мышью (WASD, зум колесом, F11 полный экран)",
        "СИСТЕМА МОДИФИКАЦИЙ: поддержка модов (.dfmod), менеджер модов в главном меню, ВДВ десант",
        "ОПТИМИЗАЦИЯ v0.33.4: быстрый расчёт дистанционного поля территорий и шейдеров границ",
        "ОПТИМИЗАЦИЯ v0.33.4: кэширование категорий тумана для AnimatedSprite2D, снижение нагрузки на GPU/CPU",
        "ПК-ОПТИМИЗАЦИЯ: троттлинг FPS до 15 при неактивном окне/сворачивании для энергосбережения и тишины",
        "ПК-ОПТИМИЗАЦИЯ: WorkerThreadPool с поддержкой многопоточности под современные ПК-процессоры",
        "ИСПРАВЛЕНИЯ v0.33.4: станции и базы нельзя строить на скалах и снегу; деревья не растут на воде и мостах",
        "КОСМЕТИКА v0.33.4: 19 новых титулов соревнований и эксклюзивов (все разблокированы для ПК!)",
        "РАЗБЛОКИРОВАНА ВСЯ КОСМЕТИКА: все рамки, фоны и титулы доступны сразу без ограничений",
        "МУЛЬТИПЛЕЕР: прямое подключение по IP / Radmin без блокировок",
]

var gw: GameWorld
var net: NetSession:
        set(value):
                if net != null and is_instance_valid(net):
                        if net.has_signal("mods_required") and net.mods_required.is_connected(_on_net_mods_required):
                                net.mods_required.disconnect(_on_net_mods_required)
                net = value
                if net != null and is_instance_valid(net):
                        if net.has_signal("mods_required") and not net.mods_required.is_connected(_on_net_mods_required):
                                net.mods_required.connect(_on_net_mods_required)
const KeybindManager = preload("res://core/keybind_manager.gd")
const SavesUI = preload("res://ui/saves_ui.gd")
const ModsUI = preload("res://ui/mods_ui.gd")
var _mp_code: String = ""
var _mp_lan_ip: String = ""
var _mp_browse_ms: int = 0
var _nick_edit: LineEdit = null
var _mods_from_settings: bool = false
var root: Control
var screen: Control
var current: String = ""
var _mp_t: float = -1.0
var _mp_label: Label
var _t: float = 0.0
var _logo: TextureRect
var _clouds: Array = []
var _sparks: Array = []
var _scroll: ScrollContainer
var _inner: Control
const VW_SHORT: float = 64.0
var _from_pause: bool = false
var _prefs_dirty: bool = false
var _bind_waiting_action: String = ""

var _sd_on: bool = false
var _sd_start: Vector2 = Vector2.ZERO
var _sd_origin: int = 0
var _sd_moved: bool = false
var _sd_eat: bool = false
var _wn: Control = null
var _wn_checked: bool = false
var _tap_btn: BaseButton = null

var _pv_rect: TextureRect = null
var _pv_task: int = -1
var _pv_img: Image = null
var _pv_again: bool = false
var _pv_key: String = ""
var _pv_tex: Texture2D = null
var _pv_busy: Control = null
var _pv_name: Label = null
var _pv_hint: Label = null
var _pv_warn: Label = null

var _wn_drones: Array = []
var _wn_scroll: ScrollContainer = null
var _sd_sc: ScrollContainer = null
var _wn_frames: Array = []
var _sm: Vector2 = Vector2.ZERO
var _panel: Control = null
var _sheet: bool = false
var _cc: Control = null
var _rh: Label = null
static var _more_open: bool = false


static var _update_dialog_shown: bool = false
var _up_dialog: Control = null
var _mp_mods_dialog: Control = null

func setup(world: GameWorld) -> void :
        gw = world
        layer = 20
        Save.load_prefs()
        UiKit.ensure()
        root = Control.new()
        root.set_anchors_preset(Control.PRESET_FULL_RECT)
        root.mouse_filter = Control.MOUSE_FILTER_IGNORE
        root.theme = UiKit.make_theme()
        add_child(root)
        _setup_updater()

func _setup_updater() -> void:
        if has_node("/root/Updater"):
                var up: Node = get_node("/root/Updater")
                if not up.update_available.is_connected(_on_updater_available):
                        up.update_available.connect(_on_updater_available)

func _on_updater_available(tag: String, changelog: String, target_url: String, target_name: String) -> void:
        var up: Node = get_node_or_null("/root/Updater")
        var cur_v: String = String(up.get("current_version")).trim_prefix("v").strip_edges() if up != null else ""
        if up != null and up.get_script() != null and up.get_script().has_method("compare_versions"):
                if up.get_script().compare_versions(tag, cur_v) <= 0:
                        return # Already on latest version or newer
        if not _update_dialog_shown:
                _update_dialog_shown = true
                show_update_dialog.call_deferred(tag, changelog, target_url, target_name)


func is_open() -> bool:
        return screen != null


func close() -> void :
        _close_lobby_chat()
        _lobby_chat_button = null
        if _wn != null and is_instance_valid(_wn):
                _wn.queue_free()
        _wn = null
        if _up_dialog != null and is_instance_valid(_up_dialog):
                _up_dialog.queue_free()
        _up_dialog = null
        if _mp_mods_dialog != null and is_instance_valid(_mp_mods_dialog):
                _mp_mods_dialog.queue_free()
        _mp_mods_dialog = null
        if _prefs_dirty:
                _prefs_dirty = false
                Save.save_prefs()
        if screen != null:
                screen.queue_free()
                screen = null
        current = ""
        _logo = null
        _clouds.clear()
        _sparks.clear()


func _process(delta: float) -> void :
        _social_tick()
        if current == "lobby":
                _update_lobby_chat_button()
        _t += delta
        if _pv_task >= 0 and WorkerThreadPool.is_task_completed(_pv_task):
                _pv_done()
        if not _wn_drones.is_empty():
                _wn_anim()
        if _scroll != null and is_instance_valid(_scroll) and _inner != null and is_instance_valid(_inner):
                var stk: Control = _scroll.get_parent().get_node_or_null("Sticky") as Control
                var want: float = minf(_inner.get_combined_minimum_size().y, root.size.y - 170.0 - _sm.x - _sm.y - (stk.get_combined_minimum_size().y + 8.0 if stk != null else 0.0))
                if absf(_scroll.custom_minimum_size.y - want) > 0.5:
                        _scroll.custom_minimum_size.y = want

        if _cc != null and is_instance_valid(_cc) and _panel != null and is_instance_valid(_panel):
                var top: float = _sm.x
                if _sheet:
                        var ph: float = _panel.get_combined_minimum_size().y
                        if ph < (root.size.y - _sm.x - _sm.y) * 0.6:
                                top = root.size.y - _sm.y - 16.0 - ph
                if _top:
                        top = _sm.x + 8.0
                        var bot: float = - (root.size.y - top - _panel.get_combined_minimum_size().y)
                        if absf(_cc.offset_bottom - bot) > 0.5:
                                _cc.offset_bottom = minf(bot, - _sm.y)
                if absf(_cc.offset_top - top) > 0.5:
                        _cc.offset_top = top

        var w: float = root.size.x
        if _logo != null and is_instance_valid(_logo) and _logo.texture != null:
                var lt_sz: Vector2 = _logo.texture.get_size()
                _logo.position.x = (w - lt_sz.x) * 0.5
        for c: Array in _clouds:
                var tr: TextureRect = c[0]
                if not is_instance_valid(tr):
                        continue
                tr.position.x += float(c[1]) * delta
                if tr.position.x > w + 30.0:
                        tr.position.x = - tr.texture.get_size().x * tr.scale.x - 30.0
        for sp: Array in _sparks:
                var s2: TextureRect = sp[0]
                if not is_instance_valid(s2):
                        continue
                s2.position += (sp[1] as Vector2) * delta
                s2.modulate.a -= delta * 0.25
                if s2.modulate.a <= 0.0 or s2.position.y < 120.0:
                        s2.position = Vector2(randf_range(10.0, w - 10.0), root.size.y - randf_range(20.0, 160.0))
                        s2.modulate.a = randf_range(0.6, 1.0)
                        sp[1] = Vector2(randf_range(-8.0, 8.0), - randf_range(18.0, 40.0))
        if _mp_t >= 0.0 and _mp_label != null and is_instance_valid(_mp_label):
                _mp_t += delta
                var dots: String = ".".repeat(int(_mp_t * 2.0) % 4)
                if _mp_t < 4.0:
                        _mp_label.text = "Поиск соперников" + dots
                else:
                        _mp_label.text = "Серверы ещё не запущены. Попробуйте позже"
                        _mp_label.add_theme_color_override("font_color", UiKit.RED)
                        _mp_t = -1.0





func _screen(title: String, dim: float = 0.55, animate: bool = true) -> VBoxContainer:
        close()
        var bg: = ColorRect.new()
        bg.set_anchors_preset(Control.PRESET_FULL_RECT)
        bg.color = Color(0.03, 0.05, 0.1, dim)
        bg.mouse_filter = Control.MOUSE_FILTER_STOP
        root.add_child(bg)
        screen = bg

        _sm = _safe_tb()
        _sheet = false
        _top = false
        var cc: = CenterContainer.new()
        cc.set_anchors_preset(Control.PRESET_FULL_RECT)
        cc.offset_top = _sm.x
        cc.offset_bottom = - _sm.y
        cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
        bg.add_child(cc)
        _cc = cc
        var panel: = PanelContainer.new()
        _panel = panel
        panel.add_theme_stylebox_override("panel", UiKit.sb("wb_window", 16, 14))
        panel.custom_minimum_size = Vector2(minf(500.0 if root.size.x >= 700 else 330.0, root.size.x - 16.0), 0)
        cc.add_child(panel)
        var outer: = VBoxContainer.new()
        outer.add_theme_constant_override("separation", 8)
        panel.add_child(outer)
        if title != "":
                outer.add_child(UiKit.title(Loc.t(title).to_upper(), 22))

        _scroll = ScrollContainer.new()
        _scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
        outer.add_child(_scroll)
        var vb: = VBoxContainer.new()
        vb.add_theme_constant_override("separation", 8)
        vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        _scroll.add_child(vb)
        _inner = vb
        panel.resized.connect( func() -> void : panel.pivot_offset = panel.size * 0.5)
        if not animate:
                return vb
        panel.scale = Vector2(0.9, 0.9)
        panel.modulate.a = 0.0
        var tw: Tween = panel.create_tween().set_parallel(true)
        tw.tween_property(panel, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        tw.tween_property(panel, "modulate:a", 1.0, 0.16)
        UiKit.snd("ui_open")
        return vb


func _label(parent: Control, text: String, size: int = 11, col: Color = UiKit.TEXT, center: bool = true) -> Label:
        var lb: Label = UiKit.lbl(text, size, col, 1 if col == UiKit.MUTED else 2, 2)
        if center:
                lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        parent.add_child(lb)
        return lb


func _button(parent: Control, text: String, colour: String, req: String, enabled: bool = true, h: float = 44.0) -> Button:
        var b: Button = UiKit.big(text, colour, "", h, 14)
        b.disabled = not enabled
        if req != "":
                b.pressed.connect( func() -> void : request.emit(req))
        parent.add_child(b)
        return b


func _sep(parent: Control, h: int = 4) -> void :
        var c: = Control.new()
        c.custom_minimum_size = Vector2(0, h)
        c.mouse_filter = Control.MOUSE_FILTER_IGNORE
        parent.add_child(c)



func _ibutton(parent: Control, text: String, colour: String, req: String, icon: String, h: float = 46.0) -> Button:
        var b: Button = _button(parent, text, colour, req, true, h)
        var t: Texture2D = UiKit.tex(icon) if icon != "" else null
        if t != null:
                b.icon = t
                b.expand_icon = false
                b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
                b.add_theme_constant_override("h_separation", 6)
                b.add_theme_stylebox_override("normal", UiKit.sb("wb_btn_" + colour, 14, 4, -1))
                b.add_theme_stylebox_override("hover", UiKit.sb("wb_btn_" + colour, 14, 4, -1))
        return b

func _apply_mods_button_outline(bb: Button) -> void:
        UiKit.ensure()
        if UiKit.atlas_cosm_tt == null or not UiKit.atlas_cosm_tt.has("tt_plate_dev_rgb_anim"):
                return
        var outline: Panel = Panel.new()
        outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
        outline.set_anchors_preset(Control.PRESET_FULL_RECT)
        outline.offset_left = -3
        outline.offset_top = -3
        outline.offset_right = 3
        outline.offset_bottom = 3
        var sb: StyleBoxTexture = StyleBoxTexture.new()
        sb.texture = UiKit.atlas_cosm_tt.region("tt_plate_dev_rgb_anim", 0)
        sb.draw_center = false
        sb.set_texture_margin_all(12)
        outline.add_theme_stylebox_override("panel", sb)
        outline.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        MpKit.animate_style(outline, sb, UiKit.atlas_cosm_tt, "tt_plate_dev_rgb_anim")
        bb.add_child(outline)



func _section(parent: Control, text: String) -> void :
        var row: = HBoxContainer.new()
        row.add_theme_constant_override("separation", 6)
        row.mouse_filter = Control.MOUSE_FILTER_IGNORE
        parent.add_child(row)
        var l: Label = UiKit.lbl(text, 11, UiKit.GOLD, 3, 3)
        l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        row.add_child(l)
        var line: = ColorRect.new()
        line.color = Color(UiKit.GOLD, 0.35)
        line.custom_minimum_size = Vector2(0, 2)
        line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        line.mouse_filter = Control.MOUSE_FILTER_IGNORE
        row.add_child(line)




func _map_block(parent: Control) -> void :
        var box: = PanelContainer.new()
        box.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 6, 6))
        parent.add_child(box)
        var col: = VBoxContainer.new()
        col.add_theme_constant_override("separation", 6)
        box.add_child(col)
        var cc: = CenterContainer.new()
        cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
        col.add_child(cc)
        var side: float = float(MapPreview.PX) * (2.0 if root.size.x >= 340.0 else 1.5)
        var frame: = PanelContainer.new()
        var fs: = StyleBoxFlat.new()
        fs.bg_color = UiKit.OUTLINE
        fs.set_content_margin_all(2)
        frame.add_theme_stylebox_override("panel", fs)
        frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
        cc.add_child(frame)
        var hold: = Control.new()
        hold.custom_minimum_size = Vector2(side, side)
        hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
        hold.clip_contents = true
        frame.add_child(hold)
        var tr: = TextureRect.new()
        tr.set_anchors_preset(Control.PRESET_FULL_RECT)
        tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        tr.stretch_mode = TextureRect.STRETCH_SCALE
        tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
        tr.texture = _pv_tex
        hold.add_child(tr)
        _pv_rect = tr
        var nm: Label = UiKit.lbl("", 13, UiKit.TITLE, 3, 4)
        nm.position = Vector2(8, side - 26)
        nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
        hold.add_child(nm)
        _pv_name = nm
        var busy: Label = UiKit.lbl("ГЕНЕРАЦИЯ...", 10, UiKit.TEXT, 2, 3)
        busy.position = Vector2(8, 6)
        busy.mouse_filter = Control.MOUSE_FILTER_IGNORE
        busy.visible = false
        hold.add_child(busy)
        _pv_busy = busy
        var dice: Button = UiKit.slot("mi_dice", false, 44.0)
        dice.position = Vector2(side - 48, 4)
        dice.tooltip_text = "Новая карта"
        dice.pressed.connect( func() -> void :
                GameConfig.map_seed = randi() % 100000000
                _pv_request())
        hold.add_child(dice)

        var chips: = HFlowContainer.new()
        chips.alignment = FlowContainer.ALIGNMENT_CENTER
        chips.add_theme_constant_override("h_separation", 6)
        chips.add_theme_constant_override("v_separation", 4)
        col.add_child(chips)
        var grp: = ButtonGroup.new()
        var chip_px: float = 64.0 if root.size.x >= 340.0 else 58.0
        var all_maps: Array = GameConfig.get_all_map_types()
        for t in all_maps.size():
                var map_info: Dictionary = all_maps[t]
                var v: = VBoxContainer.new()
                v.add_theme_constant_override("separation", 1)
                chips.add_child(v)
                var b: Button = UiKit.slot(String(map_info.get("icon", "map_t_normal")), true, chip_px)
                b.button_group = grp
                b.button_pressed = t == GameConfig.map_type
                b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
                var ti: int = t
                b.pressed.connect( func() -> void :
                        GameConfig.map_type = ti
                        _pv_texts()
                        _pv_request())
                v.add_child(b)
                var l: Label = UiKit.lbl(String(map_info.get("name", "")), 9, UiKit.TEXT, 2, 2)
                l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                v.add_child(l)
        _pv_hint = _label(col, "", 10, UiKit.TEXT)
        _pv_warn = _label(col, "", 10, UiKit.GOLD)
        _pv_texts()
        _pv_request()



func _pv_texts() -> void :
        var all_maps: Array = GameConfig.get_all_map_types()
        var max_idx: int = maxi(0, all_maps.size() - 1)
        var t: int = clampi(GameConfig.map_type, 0, max_idx)
        var map_info: Dictionary = all_maps[t] if t < all_maps.size() else {}
        if _pv_name != null and is_instance_valid(_pv_name):
                _pv_name.text = String(map_info.get("name", ""))
        if _pv_hint != null and is_instance_valid(_pv_hint):
                _pv_hint.text = String(map_info.get("hint", ""))
        if _pv_warn != null and is_instance_valid(_pv_warn):
                var w: String = ""
                match t:
                        1:
                                w = Loc.t("Без флота: соседи за морем — только десант и ракеты")
                        2:
                                w = Loc.t("На острове 1–2 страны, к остальным — десантом")
                        3:
                                w = Loc.t("Без ботов: материки делят только игроки") if GameConfig.bots == 0 else (Loc.t("Второй материк пуст: мало ботов") if GameConfig.bots < 3 else Loc.t("На каждом материке 2+ страны, за океан — десант"))
                        _:
                                if t >= 4:
                                        w = "★ Карта из модификации: " + String(map_info.get("hint", ""))
                _pv_warn.text = w
                _pv_warn.visible = w != ""
        _cb_crowd_paint()



var _cb_crowd: Label = null


func _cb_crowd_paint() -> void :
        if _cb_crowd != null and is_instance_valid(_cb_crowd):
                var n: int = GameConfig.cb_list.size() if GameConfig.cb_on else GameConfig.bots
                _cb_crowd.text = Loc.t("Малая карта, %d врагов: тесно — войны сразу") % n
                _cb_crowd.visible = CustomBots.crowded(n)


func _pv_request() -> void :
        _cb_crowd_paint()
        if _pv_rect == null or not is_instance_valid(_pv_rect):
                return
        if GameConfig.map_seed < 0:
                GameConfig.map_seed = randi() % 100000000
        var key: String = "%d/%d/%d/%d/%d" % [GameConfig.map_seed, GameConfig.map_type, GameConfig.rivers_i, GameConfig.lakes_i, GameConfig.size_i]
        if key == _pv_key and _pv_tex != null and _pv_task < 0:
                _pv_rect.texture = _pv_tex
                return
        _pv_rect.modulate = Color(0.7, 0.7, 0.75)
        if _pv_busy != null and is_instance_valid(_pv_busy):
                _pv_busy.visible = true
        if _pv_task >= 0:
                _pv_again = true
                return
        _pv_start(key)


func _pv_start(key: String) -> void :
        var s: WorldSettings = MapPreview.settings_for(GameConfig.map_seed)
        _pv_key = key
        _pv_img = null
        _pv_task = WorkerThreadPool.add_task( func() -> void : _pv_img = MapPreview.build(s), false, "map preview")


func _pv_done() -> void :
        WorkerThreadPool.wait_for_task_completion(_pv_task)
        _pv_task = -1
        if _pv_img != null:
                _pv_tex = ImageTexture.create_from_image(_pv_img)
        if _pv_again:
                _pv_again = false
                _pv_request()
                return
        if _pv_rect != null and is_instance_valid(_pv_rect):
                _pv_rect.texture = _pv_tex
                _pv_rect.modulate = Color.WHITE
                var tw: Tween = _pv_rect.create_tween()
                _pv_rect.modulate = Color(1.25, 1.25, 1.25)
                tw.tween_property(_pv_rect, "modulate", Color.WHITE, 0.25)
        if _pv_busy != null and is_instance_valid(_pv_busy):
                _pv_busy.visible = false




func _exit_tree() -> void :
        if _pv_task >= 0:
                WorkerThreadPool.wait_for_task_completion(_pv_task)
                _pv_task = -1




func _selector(parent: Control, title: String, values: Array, get_i: Callable, set_i: Callable, vw: float = 100.0, icon: String = "") -> void :
        if values.size() == 2 and "ВКЛ" in values and "ВЫКЛ" in values:
                _toggle(parent, title, values, get_i, set_i, icon)
                return
        var pc: = PanelContainer.new()
        pc.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 8, 2))
        parent.add_child(pc)
        var row: = HBoxContainer.new()
        row.add_theme_constant_override("separation", 2)
        pc.add_child(row)
        if icon != "" and UiKit.has(icon):
                vw = minf(vw, 84.0)
                var ic: TextureRect = UiKit.icon_rect(icon, 16.0)
                ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
                row.add_child(ic)
                var gap: = Control.new()
                gap.custom_minimum_size = Vector2(3, 0)
                gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
                row.add_child(gap)
        var t: Label = UiKit.lbl(title, 10 if icon != "" else 11, UiKit.MUTED, 2, 2)
        t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        if icon != "":

                t.autowrap_mode = TextServer.AUTOWRAP_OFF
                var fnt: Font = t.get_theme_font("font")
                if fnt != null and fnt.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x > 70.0:
                        t.add_theme_font_size_override("font_size", 9)
        row.add_child(t)
        var left: Button = UiKit.arrow(true)
        row.add_child(left)
        var v: Label = UiKit.lbl("", 10 if icon != "" else 12, UiKit.TITLE, 2, 3)
        v.custom_minimum_size = Vector2(vw, 0)
        v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        row.add_child(v)
        var right: Button = UiKit.arrow(false)
        row.add_child(right)
        var upd: = func() -> void :
                v.text = str(values[clampi(int(get_i.call()), 0, values.size() - 1)])
                v.add_theme_color_override("font_color", UiKit.MUTED if v.text in ["ВЫКЛ", "НЕТ"] else UiKit.TITLE)
        upd.call()
        left.pressed.connect( func() -> void :
                set_i.call(posmod(int(get_i.call()) - 1, values.size()))
                _prefs_dirty = _prefs_dirty or current.begins_with("settings")
                upd.call()
                _rule_hint(pc, title))
        right.pressed.connect( func() -> void :
                set_i.call(posmod(int(get_i.call()) + 1, values.size()))
                _prefs_dirty = _prefs_dirty or current.begins_with("settings")
                upd.call()
                _rule_hint(pc, title))




func _toggle(parent: Control, title: String, values: Array, get_i: Callable, set_i: Callable, icon: String = "") -> void :
        var b: = Button.new()
        b.focus_mode = Control.FOCUS_NONE
        b.custom_minimum_size = Vector2(0, 48)
        var n: StyleBox = UiKit.sb("wb_panel_dark", 8, 2)
        var pr: StyleBox = UiKit.sb("wb_panel", 8, 2)
        for st: String in ["normal", "hover", "disabled"]:
                b.add_theme_stylebox_override(st, n)
        b.add_theme_stylebox_override("pressed", pr)
        b.add_theme_stylebox_override("hover_pressed", pr)
        b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
        parent.add_child(b)
        var row: = HBoxContainer.new()
        row.set_anchors_preset(Control.PRESET_FULL_RECT)
        row.offset_left = 8.0
        row.offset_right = -8.0
        row.add_theme_constant_override("separation", 3)
        row.mouse_filter = Control.MOUSE_FILTER_IGNORE
        b.add_child(row)
        if icon != "" and UiKit.has(icon):
                var ic: TextureRect = UiKit.icon_rect(icon, 16.0)
                ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
                row.add_child(ic)
                var gap: = Control.new()
                gap.custom_minimum_size = Vector2(3, 0)
                gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
                row.add_child(gap)
        var t: Label = UiKit.lbl(title, 10 if icon != "" else 11, UiKit.MUTED, 2, 2)
        t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        row.add_child(t)

        var track: = PanelContainer.new()
        track.add_theme_stylebox_override("panel", UiKit.sb("wb_slot", 3, 3))
        track.custom_minimum_size = Vector2(76, 32)
        track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        track.mouse_filter = Control.MOUSE_FILTER_IGNORE
        row.add_child(track)
        var tr: = HBoxContainer.new()
        tr.add_theme_constant_override("separation", 2)
        tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
        track.add_child(tr)
        var word: Label = UiKit.lbl("", 10, UiKit.TEXT, 2, 2)
        word.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        word.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        var knob: = Panel.new()
        knob.custom_minimum_size = Vector2(22, 22)
        knob.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
        tr.add_child(word)
        tr.add_child(knob)
        var on_i: int = values.find("ВКЛ")
        var upd: = func() -> void :
                var on: bool = int(get_i.call()) == on_i
                word.text = "ВКЛ" if on else "ВЫКЛ"
                word.add_theme_color_override("font_color", UiKit.GREEN if on else UiKit.MUTED)
                knob.add_theme_stylebox_override("panel", UiKit.sb("wb_btn_green" if on else "wb_btn_stone", 0, 0))
                tr.move_child(knob, 1 if on else 0)
        upd.call()
        UiKit.press_fx(b)
        b.pressed.connect( func() -> void :
                set_i.call(1 - on_i if int(get_i.call()) == on_i else on_i)
                _prefs_dirty = _prefs_dirty or current.begins_with("settings")
                upd.call()
                _rule_hint(b, title))




const RULE_HINTS: Dictionary = {
        "РОСТ БОТОВ": "Как быстро боты занимают свободную землю", 
        "ЗАПАСЫ": "Большие — залежи ×3, бесконечные — нефть и руда не кончаются", 
        "ИИ": "Мирные реже объявляют войну, агрессивные — чаще", 
        "РЕЖИМ": "Творческий — бесконечные деньги и ресурсы", 
}


func _rule_hint(row: Control, title: String) -> void :
        if _rh == null or not is_instance_valid(_rh) or not RULE_HINTS.has(title):
                return
        var h: Variant = RULE_HINTS[title]
        _rh.text = String(h)
        var par: Node = row.get_parent()
        if _rh.get_parent() != par:
                _rh.reparent(par)
        par.move_child(_rh, row.get_index() + (0 if _rh.get_index() < row.get_index() else 1))
        _rh.visible = true



func _volume(parent: Control, title: String, prop: String) -> void :
        if not ResourceLoader.exists("res://core/sfx.gd"):
                return
        var sfx: GDScript = load("res://core/sfx.gd") as GDScript
        var pc: = PanelContainer.new()
        pc.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 8, 2))
        parent.add_child(pc)
        var row: = HBoxContainer.new()
        row.add_theme_constant_override("separation", 8)
        row.custom_minimum_size = Vector2(0, 44)
        pc.add_child(row)
        var t: Label = UiKit.lbl(title, 11, UiKit.MUTED, 2, 2)
        t.custom_minimum_size = Vector2(96, 0)
        t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        row.add_child(t)
        var s: = HSlider.new()
        s.min_value = 0.0
        s.max_value = 1.0
        s.step = 0.05
        s.value = float(sfx.get(prop))
        s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        s.size_flags_vertical = Control.SIZE_FILL
        s.custom_minimum_size = Vector2(0, 44)
        row.add_child(s)
        var v: Label = UiKit.lbl("%d%%" % roundi(s.value * 100.0), 11, UiKit.TITLE, 2, 2)
        v.custom_minimum_size = Vector2(38, 0)
        v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        row.add_child(v)
        s.value_changed.connect( func(val: float) -> void :
                sfx.set(prop, val)
                sfx.call("apply_volumes")
                v.text = "%d%%" % roundi(val * 100.0))


        var mv: Array = [Vector2.ZERO, Vector2.ZERO]
        s.gui_input.connect( func(e: InputEvent) -> void :
                if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
                        mv[0] = (e as InputEventMouseButton).position
                        mv[1] = mv[0]
                elif e is InputEventMouseMotion:
                        mv[1] = (e as InputEventMouseMotion).position)
        s.drag_ended.connect( func(_ch: bool) -> void :
                var d: Vector2 = (mv[1] as Vector2) - (mv[0] as Vector2)
                if not _sd_moved and absf(d.x) >= absf(d.y):
                        UiKit.snd("ui_click"))



func _bottom_row() -> HBoxContainer:
        var row: = HBoxContainer.new()
        row.add_theme_constant_override("separation", 8)
        _scroll.get_parent().add_child(row)
        return row



func _nav_row(parent: Control, title: String, hint: String, open: Callable) -> Button:
        var b: = Button.new()
        b.focus_mode = Control.FOCUS_NONE
        b.custom_minimum_size = Vector2(0, 48)
        var n: StyleBox = UiKit.sb("wb_panel_dark", 8, 2)
        var p: StyleBox = UiKit.sb("wb_panel", 8, 2)
        b.add_theme_stylebox_override("normal", n)
        b.add_theme_stylebox_override("hover", n)
        b.add_theme_stylebox_override("pressed", p)
        b.add_theme_stylebox_override("hover_pressed", p)
        b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
        var row: = HBoxContainer.new()
        row.set_anchors_preset(Control.PRESET_FULL_RECT)
        row.offset_left = 10.0
        row.offset_right = -10.0
        row.mouse_filter = Control.MOUSE_FILTER_IGNORE
        row.add_theme_constant_override("separation", 6)
        b.add_child(row)
        var t: Label = UiKit.lbl(title, 12, UiKit.TITLE, 2, 2)
        t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        row.add_child(t)
        var h: Label = UiKit.lbl(hint, 10, UiKit.MUTED, 1, 1)
        h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        h.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        h.clip_text = true
        h.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        row.add_child(h)
        if UiKit.tex("wb_arrow_r") != null:
                var ic: TextureRect = UiKit.icon_rect("wb_arrow_r", 20.0)
                ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
                row.add_child(ic)
        else:
                row.add_child(UiKit.lbl(">", 14, UiKit.TITLE, 2, 2))
        UiKit.press_fx(b)
        b.pressed.connect(open)
        parent.add_child(b)
        return b




func _input(event: InputEvent) -> void :
        if is_instance_valid(_lobby_chat_overlay) and event.is_action_pressed("ui_cancel"):
                _close_lobby_chat()
                get_viewport().set_input_as_handled()
                return
        if _bind_waiting_action != "":
                if event is InputEventKey and event.pressed and not event.echo:
                        var ek: InputEventKey = event as InputEventKey
                        var act: String = _bind_waiting_action
                        _bind_waiting_action = ""
                        if ek.keycode == KEY_ESCAPE:
                                UiKit.snd("ui_close")
                        else:
                                UiKit.snd("ui_click")
                                KeybindManager.set_binding(act, "key", ek.keycode)
                        show_controls(_from_pause)
                        get_viewport().set_input_as_handled()
                        return
                elif event is InputEventMouseButton and event.pressed:
                        var mb: InputEventMouseButton = event as InputEventMouseButton
                        var act: String = _bind_waiting_action
                        _bind_waiting_action = ""
                        UiKit.snd("ui_click")
                        KeybindManager.set_binding(act, "mouse", mb.button_index)
                        show_controls(_from_pause)
                        get_viewport().set_input_as_handled()
                        return

        if event is InputEventMouseButton and (event as InputEventMouseButton).device != InputEvent.DEVICE_ID_EMULATION\
        and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
                var t: = InputEventScreenTouch.new()
                t.pressed = (event as InputEventMouseButton).pressed
                t.position = (event as InputEventMouseButton).position
                _input(t)
                return
        if event is InputEventMouseMotion and (event as InputEventMouseMotion).device != InputEvent.DEVICE_ID_EMULATION\
        and ((event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
                if _sd_on:
                        var dg: = InputEventScreenDrag.new()
                        dg.position = (event as InputEventMouseMotion).position
                        _input(dg)
                return
        if event is InputEventScreenTouch:
                var st: = event as InputEventScreenTouch
                if st.index != 0:
                        return
                if st.pressed:
                        var hc: Control = get_viewport().gui_get_hovered_control()
                        _tap_btn = null
                        for i in 4:
                                if hc == null or not root.is_ancestor_of(hc):
                                        break
                                if hc is BaseButton:
                                        _tap_btn = hc as BaseButton
                                        break
                                hc = hc.get_parent() as Control

                        _sd_sc = _wn_scroll if _wn != null and is_instance_valid(_wn) and _wn_scroll != null and is_instance_valid(_wn_scroll) else _scroll
                        _sd_on = screen != null and _sd_sc != null and is_instance_valid(_sd_sc) and _sd_sc.is_visible_in_tree()\
                        and _sd_sc.get_v_scroll_bar().max_value > _sd_sc.size.y + 1.0 and _sd_sc.get_global_rect().has_point(st.position)
                        _sd_start = st.position
                        _sd_moved = false
                        if _sd_on:
                                _sd_origin = _sd_sc.scroll_vertical
                else:
                        if _sd_moved:
                                get_viewport().set_input_as_handled()
                        _sd_on = false
                        _sd_moved = false
        elif event is InputEventScreenDrag and _sd_on:
                var sd: = event as InputEventScreenDrag
                if sd.index != 0 or _sd_sc == null or not is_instance_valid(_sd_sc):
                        return
                var dy: float = sd.position.y - _sd_start.y
                if not _sd_moved and absf(dy) > 10.0:
                        _sd_moved = true

                        if _tap_btn != null and is_instance_valid(_tap_btn) and not _tap_btn.disabled:
                                _tap_btn.disabled = true
                                _tap_btn.disabled = false
                        _tap_btn = null
                if _sd_moved:
                        _sd_sc.scroll_vertical = int(float(_sd_origin) - dy)
                        get_viewport().set_input_as_handled()
        elif event is InputEventMouseButton and _sd_eat:
                var mb: = event as InputEventMouseButton
                if mb.device == InputEvent.DEVICE_ID_EMULATION and not mb.pressed:
                        _sd_eat = false
                        get_viewport().set_input_as_handled()
        elif event is InputEventMouseMotion and _sd_moved:
                if (event as InputEventMouseMotion).device == InputEvent.DEVICE_ID_EMULATION:
                        get_viewport().set_input_as_handled()






static func mp_locked() -> bool:
        return (OS.has_feature("android") and not RtcLink.relay_only()) or (OS.is_debug_build() and OS.get_environment("DF_FAKE_ANDROID") != "")



func _mp_gate() -> bool:
        if not mp_locked():
                return false
        show_main.call_deferred()
        return true




func _android_mp_lock(b: Button, label: String) -> void :
        b.self_modulate = Color(0.7, 0.7, 0.7)
        for k: String in ["font_color", "font_hover_color", "font_pressed_color"]:
                b.add_theme_color_override(k, UiKit.MUTED)
        var lt: Texture2D = UiKit.tex("net_lock")
        if lt != null:
                b.icon = lt
        var tag: Label = UiKit.lbl(Loc.t("СКОРО НА ANDROID"), 8, UiKit.GOLD, 2, 2)
        var tsb: = StyleBoxFlat.new()
        tsb.bg_color = Color(UiKit.OUTLINE, 0.92)
        tsb.border_color = Color(UiKit.GOLD, 0.7)
        tsb.set_border_width_all(1)
        tsb.set_corner_radius_all(3)
        tsb.content_margin_left = 5
        tsb.content_margin_right = 5
        tag.add_theme_stylebox_override("normal", tsb)
        tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        tag.set_anchors_preset(Control.PRESET_CENTER_TOP)
        tag.grow_horizontal = Control.GROW_DIRECTION_BOTH
        tag.offset_top = -7
        b.add_child(tag)
        b.pressed.connect( func() -> void :
                UiKit.snd("ui_error")
                b.custom_minimum_size.x = maxf(b.custom_minimum_size.x, b.size.x)
                b.text = "СКОРО"
                var tw: Tween = b.create_tween()
                tw.tween_interval(1.5)
                tw.tween_callback( func() -> void :
                        if is_instance_valid(b):
                                b.text = label))


func show_main() -> void :
        if not GameConfig.graphics_chosen and not OS.has_environment("DF_SKIP_GRAPHICS_SETUP"):
                show_graphics_first()
                return
        close()
        current = "main"
        var smb: float = _safe_tb().y
        var bg: = Control.new()
        bg.set_anchors_preset(Control.PRESET_FULL_RECT)
        bg.mouse_filter = Control.MOUSE_FILTER_STOP
        root.add_child(bg)
        screen = bg

        for top: bool in [true, false]:
                var g: = Gradient.new()
                g.set_color(0, Color(0.02, 0.04, 0.12, 0.75))
                g.set_color(1, Color(0.02, 0.04, 0.12, 0.0))
                var gt: = GradientTexture2D.new()
                gt.gradient = g
                gt.fill_from = Vector2(0, 0) if top else Vector2(0, 1)
                gt.fill_to = Vector2(0, 1) if top else Vector2(0, 0)
                gt.width = 4
                gt.height = 64
                var sh: = TextureRect.new()
                sh.texture = gt
                sh.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
                sh.stretch_mode = TextureRect.STRETCH_SCALE
                sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
                sh.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
                if top:
                        sh.offset_bottom = 260
                else:
                        sh.offset_top = -330
                bg.add_child(sh)
        for i in 4:
                var c: = TextureRect.new()
                c.texture = UiKit.tex(["cloud_a", "cloud_c", "cloud_b", "cloud_a"][i])
                if c.texture == null:
                        break
                c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
                c.mouse_filter = Control.MOUSE_FILTER_IGNORE
                c.scale = Vector2(2, 2) if i % 2 == 0 else Vector2(3, 3)
                c.modulate = Color(1, 1, 1, 0.55)
                c.position = Vector2(randf_range(-200.0, root.size.x), 200.0 + float(i) * 130.0)
                bg.add_child(c)
                _clouds.append([c, 5.0 + float(i) * 2.5])
        for i in 14:
                var s: = TextureRect.new()
                s.texture = UiKit.tex("spark_%d" % (i % 3))
                if s.texture == null:
                        break
                s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
                s.mouse_filter = Control.MOUSE_FILTER_IGNORE
                s.scale = Vector2(2, 2)
                s.position = Vector2(randf_range(10.0, root.size.x - 10.0), root.size.y - randf_range(20.0, 300.0))
                s.modulate.a = randf_range(0.2, 1.0)
                bg.add_child(s)
                _sparks.append([s, Vector2(randf_range(-8.0, 8.0), - randf_range(18.0, 40.0))])
        var lt: Texture2D = UiKit.tex("logo_df")
        var logo_k: float = 1.0
        if lt != null:
                _logo = TextureRect.new()
                _logo.texture = lt
                _logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
                _logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
                var k: float = floorf(minf(3.0, (root.size.x + 40.0) / lt.get_size().x) * 2.0) / 2.0
                logo_k = k
                _logo.set_meta("k", k)
                _logo.scale = Vector2(k, k)
                _logo.pivot_offset = lt.get_size() * 0.5
                _logo.position = Vector2((root.size.x - lt.get_size().x) * 0.5, 70)
                bg.add_child(_logo)
        else:
                var tl: Label = UiKit.title("DRONE FLAMES", 34)
                tl.set_anchors_preset(Control.PRESET_TOP_WIDE)
                tl.offset_top = 110
                bg.add_child(tl)
        # REBORN: фирменный бейдж и упоминание фанатского порта под логотипом.
        # Позиция считается от ВЫСОТЫ логотипа (не ширины!) — раньше бейдж
        # уезжал за нижний край экрана (220*3+70 = 738 px при высоте 720).
        var badge_y: float = (70.0 + lt.get_size().y * logo_k + 8.0) if lt != null else 162.0
        badge_y = minf(badge_y, root.size.y * 0.40)
        var rb: Label = UiKit.title("R E B O R N", 30, UiKit.GOLD)
        rb.set_anchors_preset(Control.PRESET_TOP_WIDE)
        rb.offset_top = int(badge_y)
        bg.add_child(rb)
        var pulse: Tween = rb.create_tween().set_loops()
        pulse.tween_property(rb, "modulate:a", 0.55, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        pulse.tween_property(rb, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        var tag: Label = UiKit.lbl("Возрождено. Оптимизировано. Играй без тормозов.", 11, UiKit.MUTED, 2, 2)
        tag.set_anchors_preset(Control.PRESET_TOP_WIDE)
        tag.offset_top = int(badge_y) + 42
        bg.add_child(tag)
        var port_lbl: Label = UiKit.lbl("Фанатский ПК-порт от Reborn Team · не является официальной игрой", 9, Color(0.62, 0.66, 0.78), 1, 2)
        port_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
        port_lbl.offset_top = int(badge_y) + 62
        port_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        bg.add_child(port_lbl)

        var col: = VBoxContainer.new()
        col.add_theme_constant_override("separation", 10)
        col.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
        col.grow_horizontal = Control.GROW_DIRECTION_BOTH
        col.grow_vertical = Control.GROW_DIRECTION_BEGIN
        col.offset_bottom = -70 - smb
        col.custom_minimum_size = Vector2(250, 0)
        col.mouse_filter = Control.MOUSE_FILTER_IGNORE
        bg.add_child(col)



        var items: Array = [["ИГРАТЬ", "green", "setup", 58.0, "mi_play"], ["МУЛЬТИПЛЕЕР", "gold", "mp", 48.0, "mi_mp"], 
                ["МОДИФИКАЦИИ", "stone", "mods", 46.0, "mi_mods"],
                [["ОБУЧЕНИЕ", "stone", "tutorial", 48.0, "mi_tutorial"], ["НАСТРОЙКИ", "stone", "settings_main", 48.0, "mi_settings"]],
                ["ВЫХОД", "red", "quit", 44.0, "icon_close"]]
        var has_save: bool = Save.has_save()
        if has_save:
                items = [["ПРОДОЛЖИТЬ", "green", "load_save", 58.0, "mi_continue"], 
                        [["НОВАЯ ПАРТИЯ", "gold", "setup", 48.0, "mi_new"], ["МУЛЬТИПЛЕЕР", "gold", "mp", 48.0, "mi_mp"]], 
                        ["МОДИФИКАЦИИ", "stone", "mods", 46.0, "mi_mods"],
                        [["ОБУЧЕНИЕ", "stone", "tutorial", 48.0, "mi_tutorial"], ["НАСТРОЙКИ", "stone", "settings_main", 48.0, "mi_settings"]],
                        ["ВЫХОД", "red", "quit", 44.0, "icon_close"]]
        var i2: int = 0
        for it: Array in items:
                var b: Control = null
                if it[0] is Array:
                        var pair: = HBoxContainer.new()
                        pair.add_theme_constant_override("separation", 8)
                        pair.mouse_filter = Control.MOUSE_FILTER_IGNORE
                        col.add_child(pair)
                        for one: Array in it:


                                var locked: bool = false
                                var tut: bool = String(one[2]) == "tutorial"
                                var mpl: bool = String(one[2]) == "mp" and mp_locked()
                                var pb: Button = _ibutton(pair, String(one[0]), String(one[1]), "" if tut or mpl else String(one[2]), String(one[4]), float(one[3]))
                                if mpl:
                                        _android_mp_lock(pb, String(one[0]))
                                if tut:
                                        pb.pressed.connect( func() -> void : load("res://ui/ui24/tutorial_feed.gd").call("open", self, false))
                                pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                                pb.add_theme_font_size_override("font_size", 12)
                                if locked:
                                        pb.self_modulate = Color(0.7, 0.7, 0.7)
                                        pb.add_theme_color_override("font_color", UiKit.MUTED)
                                        pb.add_theme_color_override("font_hover_color", UiKit.MUTED)
                                        pb.add_theme_color_override("font_pressed_color", UiKit.MUTED)
                                        pb.pressed.connect( func() -> void :
                                                UiKit.snd("ui_error")
                                                pb.custom_minimum_size.x = maxf(pb.custom_minimum_size.x, pb.size.x)
                                                pb.text = "СКОРО"
                                                var tw: Tween = pb.create_tween()
                                                tw.tween_interval(1.5)
                                                tw.tween_callback( func() -> void : pb.text = String(one[0])))
                        b = pair
                else:
                        var is_mods: bool = String(it[2]) == "mods"
                        var mpl1: bool = String(it[2]) == "mp" and mp_locked()
                        var bb: Button = _ibutton(col, String(it[0]), String(it[1]), "" if mpl1 else String(it[2]), String(it[4]), float(it[3]))
                        if mpl1:
                                _android_mp_lock(bb, String(it[0]))
                        if is_mods:
                                _apply_mods_button_outline(bb)
                        if i2 == 0:
                                bb.add_theme_font_size_override("font_size", 20)
                        b = bb
                if i2 == 0:
                        SavesUI.main_strip(self, col, has_save)
                b.modulate.a = 0.0
                var tw: Tween = b.create_tween()
                tw.tween_interval(0.08 * float(i2) + 0.1)
                tw.tween_property(b, "modulate:a", 1.0, 0.25)
                i2 += 1
        var ver: Label = UiKit.lbl(VERSION, 9, UiKit.MUTED, 1, 2)
        ver.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
        ver.grow_horizontal = Control.GROW_DIRECTION_BOTH
        ver.grow_vertical = Control.GROW_DIRECTION_BEGIN
        ver.offset_bottom = -30 - smb
        ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        bg.add_child(ver)

        if has_node("/root/Updater"):
                var up: Node = get_node("/root/Updater")
                if up != null and up.has_method("has_update") and bool(up.call("has_update")):
                        var ltag: String = String(up.get("latest_tag")).trim_prefix("v").strip_edges()
                        var cur_v: String = String(up.get("current_version")).trim_prefix("v").strip_edges()
                        var is_newer: bool = true
                        if up.get_script() != null and up.get_script().has_method("compare_versions"):
                                is_newer = up.get_script().compare_versions(ltag, cur_v) > 0
                        if is_newer:
                                var up_pill: Button = UiKit.big("⚡ ОБНОВЛЕНИЕ v%s ДОСТУПНО!" % ltag, "gold", "", 32.0, 10)
                                up_pill.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
                                up_pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
                                up_pill.grow_vertical = Control.GROW_DIRECTION_BEGIN
                                up_pill.offset_bottom = -50 - smb
                                up_pill.custom_minimum_size = Vector2(250, 32)
                                up_pill.pressed.connect(func() -> void:
                                        UiKit.snd("ui_open")
                                        show_update_dialog()
                                )
                                bg.add_child(up_pill)

        var ib: = HBoxContainer.new()
        ib.add_theme_constant_override("separation", 4)
        ib.mouse_filter = Control.MOUSE_FILTER_STOP
        ib.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
        ib.grow_horizontal = Control.GROW_DIRECTION_BEGIN
        ib.grow_vertical = Control.GROW_DIRECTION_BEGIN
        ib.offset_right = -10
        ib.offset_bottom = -12 - smb
        ib.custom_minimum_size = Vector2(0, 44)
        var ii: TextureRect = UiKit.icon_rect("icon_info", 18.0)
        ii.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        ii.mouse_filter = Control.MOUSE_FILTER_IGNORE
        ib.add_child(ii)
        var it: Label = UiKit.lbl("ЧТО НОВОГО", 10, UiKit.GOLD, 2, 2)
        it.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        it.mouse_filter = Control.MOUSE_FILTER_IGNORE
        ib.add_child(it)
        ib.gui_input.connect( func(ev: InputEvent) -> void :
                if (ev is InputEventMouseButton and not (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventScreenTouch and not (ev as InputEventScreenTouch).pressed):
                        UiKit.snd("ui_open")
                        _show_whats_new())
        bg.add_child(ib)
        if not _wn_checked:
                _wn_checked = true
                if Save.seen_version() != VERSION:
                        _show_whats_new.call_deferred()





const WN_ICONS: Array = [["фронт", "icon_stance_attack"], ["окоп", "icon_trench"], ["Боты", "si_bots"], 
        ["прохода", "icon_treaty_passage"], ["карт", "si_size"], ["рек", "si_rivers"], ["РАЗРУШ", "icon_demolish"], 
        ["Бомбард", "icon_bomber"], ["ТЭЦ", "icon_power"], ["мир", "icon_rel_truce"], ["дипломат", "icon_rel_ally"], 
        ["Звук", "si_daynight"], ["вылет", "si_mode"]]


func _wn_icon(text: String) -> String:
        for it: Array in WN_ICONS:
                if text.findn(String(it[0])) >= 0 and UiKit.has(String(it[1])):
                        return String(it[1])
        return "emb_star" if UiKit.has("emb_star") else ""






const WN_FIX: Array = ["ИСПР:", "исправл", "застрева", "больше не", "не мерцает", "не перекрывают", "не уплывают", 
        "не мешают", "без абсурдных", "надёжно", "баг", "пишет, чего не хватает", "не теряет", "не пропадает"]


func _wn_group(text: String) -> int:
        if text.begins_with("ИСПР:"):
                return 2
        if text.begins_with("НОВОЕ:"):
                return 3
        for k2: String in WN_FIX:
                if text.findn(k2) >= 0:
                        return 2
        for k: String in ["карт", "рек", "озёр", "остров"]:
                if text.findn(k) >= 0:
                        return 1
        for k3: String in ["фронт", "прохода", "РАЗРУШ", "окоп", "наступ", "армий", "война", "Флот", "корабл", "Корабел", "КР ", "ПВО", "Дроны", "БПЛА", "ОТРК", "удар", "Конво", "баллист"]:
                if text.findn(k3) >= 0:
                        return 0
        return 3



func _wn_split(text: String) -> Array:
        var best: int = -1
        var bl: int = 0
        for sep: String in [" — ", ": "]:
                var i: int = text.find(sep)
                if i > 6 and (best < 0 or i < best):
                        best = i
                        bl = sep.length()
        if best < 0:
                return [text, ""]
        var rest: String = text.substr(best + bl)
        return [text.substr(0, best), rest.substr(0, 1).to_upper() + rest.substr(1)]



func _safe_tb() -> Vector2:
        if not OS.has_feature("mobile"):
                return Vector2.ZERO
        var win: Vector2 = Vector2(DisplayServer.window_get_size())
        var safe: Rect2i = DisplayServer.get_display_safe_area()
        if win.x <= 0.0 or safe.size.x <= 0 or safe.size.y <= 0:
                return Vector2.ZERO
        var s: float = root.size.x / win.x
        var t: float = maxf(0.0, float(safe.position.y) * s)
        var b: float = maxf(0.0, (win.y - float(safe.end.y)) * s)
        return Vector2.ZERO if t > 90.0 or b > 90.0 else Vector2(t, b)


func _show_whats_new() -> void :
        if current != "main" or screen == null or (_wn != null and is_instance_valid(_wn)):
                return
        Save.set_seen_version(VERSION)
        var bg: = ColorRect.new()
        bg.set_anchors_preset(Control.PRESET_FULL_RECT)
        bg.color = Color(0.02, 0.04, 0.1, 0.62)
        bg.mouse_filter = Control.MOUSE_FILTER_STOP
        root.add_child(bg)
        _wn = bg
        screen.visible = false

        _wn_drones.clear()
        _wn_frames.clear()
        for k in 4:
                var ft: Texture2D = UiKit.tex("load_drone_%d" % k)
                if ft != null:
                        _wn_frames.append(ft)
        var drone_layer: Array = []
        if _wn_frames.size() == 4:
                for d in 3:
                        var tr: = TextureRect.new()
                        tr.texture = _wn_frames[0]
                        tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
                        tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
                        tr.scale = Vector2(1.5, 1.5) if d == 0 else Vector2(1.0, 1.0)
                        drone_layer.append(tr)
                        _wn_drones.append([tr, d, float(d) * 2.1, [0.55, 0.42, 0.33][d]])
        var sm: Vector2 = _safe_tb()
        var mc: = MarginContainer.new()
        mc.set_anchors_preset(Control.PRESET_FULL_RECT)
        mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
        for side: String in ["left", "right"]:
                mc.add_theme_constant_override("margin_" + side, 10)
        mc.add_theme_constant_override("margin_top", int(10.0 + sm.x))
        mc.add_theme_constant_override("margin_bottom", int(10.0 + sm.y))
        bg.add_child(mc)
        var cc: = CenterContainer.new()
        cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
        mc.add_child(cc)
        var col: = VBoxContainer.new()
        col.add_theme_constant_override("separation", 6)
        col.custom_minimum_size = Vector2(minf(330.0, root.size.x - 20.0), 0)
        col.mouse_filter = Control.MOUSE_FILTER_IGNORE
        cc.add_child(col)

        var lt: Texture2D = UiKit.tex("logo_df")
        var logo: TextureRect = null
        if lt != null:
                logo = TextureRect.new()
                logo.texture = lt
                logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
                logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
                logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
                logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
                var k: float = 1.0 if root.size.y < 700.0 else 1.25
                logo.custom_minimum_size = lt.get_size() * k
                logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
                col.add_child(logo)
        var hr: = HBoxContainer.new()
        hr.alignment = BoxContainer.ALIGNMENT_CENTER
        hr.add_theme_constant_override("separation", 8)
        hr.mouse_filter = Control.MOUSE_FILTER_IGNORE
        col.add_child(hr)
        hr.add_child(UiKit.title("ЧТО НОВОГО", 22, UiKit.GOLD))
        var badge: = PanelContainer.new()
        badge.add_theme_stylebox_override("panel", UiKit.sb("wb_btn_gold", 8, 2, -1))
        badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var bl: Label = UiKit.lbl(VERSION, 13, UiKit.TEXT, 3, 4)
        badge.add_child(bl)
        hr.add_child(badge)

        var panel: = PanelContainer.new()
        panel.add_theme_stylebox_override("panel", UiKit.sb("wb_window", 12, 10))
        col.add_child(panel)
        var pv: = VBoxContainer.new()
        pv.add_theme_constant_override("separation", 8)
        panel.add_child(pv)
        var sc: = ScrollContainer.new()
        sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
        sc.scroll_deadzone = 8
        pv.add_child(sc)
        _wn_scroll = sc
        var list: = VBoxContainer.new()
        list.add_theme_constant_override("separation", 4)
        list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        sc.add_child(list)


        var rows: Array = []
        var groups: Array = [["ВОЙНА", "icon_stance_attack", []], ["КАРТА", "si_size", []], ["ИСПРАВЛЕНИЯ", "si_mode", []], ["НОВОЕ", "emb_star", []]]
        for it: String in WHATS_NEW:
                var g: int = _wn_group(it)
                (groups[g][2] as Array).append(it.trim_prefix("ИСПР:").trim_prefix("НОВОЕ:").strip_edges())
        for gr: Array in [groups[3], groups[0], groups[1], groups[2]]:
                if (gr[2] as Array).is_empty():
                        continue
                var hd: = HBoxContainer.new()
                hd.add_theme_constant_override("separation", 6)
                list.add_child(hd)
                if UiKit.has(String(gr[1])):
                        hd.add_child(UiKit.icon_rect(String(gr[1]), 16.0))
                var hl: Label = UiKit.lbl(String(gr[0]), 12, UiKit.GOLD, 3, 3)
                hd.add_child(hl)
                var line: = ColorRect.new()
                line.color = Color(UiKit.GOLD, 0.3)
                line.custom_minimum_size = Vector2(0, 2)
                line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
                line.mouse_filter = Control.MOUSE_FILTER_IGNORE
                hd.add_child(line)
                rows.append(hd)
                for it2: String in gr[2]:
                        var rp: = PanelContainer.new()
                        rp.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 8, 3))
                        rp.mouse_filter = Control.MOUSE_FILTER_PASS
                        list.add_child(rp)
                        var row: = HBoxContainer.new()
                        row.add_theme_constant_override("separation", 8)
                        rp.add_child(row)
                        var icn: String = _wn_icon(it2)
                        var ic: = TextureRect.new()
                        if icn != "":
                                ic = UiKit.icon_rect(icn, 20.0)
                        ic.custom_minimum_size = Vector2(maxf(ic.custom_minimum_size.x, 20.0), 20.0)
                        ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
                        row.add_child(ic)
                        var tc: = VBoxContainer.new()
                        tc.add_theme_constant_override("separation", -1)
                        tc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                        tc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
                        row.add_child(tc)
                        var parts: Array = _wn_split(Loc.t(it2))
                        var tl: Label = UiKit.lbl(String(parts[0]), 11, UiKit.TEXT, 3, 2)
                        tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
                        tc.add_child(tl)
                        if String(parts[1]) != "":
                                var sl: Label = UiKit.lbl(String(parts[1]), 9, UiKit.MUTED, 1, 1)
                                sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
                                tc.add_child(sl)
                        rows.append(rp)

        # Telegram Community Box (unofficial ports and mods)
        var tg_box: = PanelContainer.new()
        tg_box.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 8, 4))
        list.add_child(tg_box)
        var tg_row: = HBoxContainer.new()
        tg_row.add_theme_constant_override("separation", 8)
        tg_box.add_child(tg_row)
        if UiKit.has("icon_info"):
                tg_row.add_child(UiKit.icon_rect("icon_info", 20.0))
        var tg_col: = VBoxContainer.new()
        tg_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        tg_row.add_child(tg_col)
        var tg_h: Label = UiKit.lbl("ТЕЛЕГРАМ-КАНАЛ ПОРТОВ И МОДОВ", 10, UiKit.GOLD, 2)
        tg_col.add_child(tg_h)
        var tg_t: Label = UiKit.lbl("Неофициальное сообщество игроков: ПК-порты и модификации игры (не официальный канал разработчиков игры).", 9, UiKit.MUTED, 1)
        tg_t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        tg_col.add_child(tg_t)
        var tg_go: Button = UiKit.big("ОТКРЫТЬ @DRONEFLAMESMOD", "blue", "", 34.0, 10)
        tg_go.pressed.connect(func() -> void:
                UiKit.snd("ui_click")
                OS.shell_open("https://t.me/droneflamesmod")
        )
        tg_col.add_child(tg_go)
        rows.append(tg_box)
        var b: Button = UiKit.big("ПОНЯТНО", "green", "", 46.0, 15)
        b.pressed.connect( func() -> void :
                UiKit.snd("ui_close")
                _wn_drones.clear()
                if screen != null and is_instance_valid(screen):
                        screen.visible = true
                if _wn != null and is_instance_valid(_wn):
                        _wn.queue_free()
                _wn = null)
        pv.add_child(b)

        var fixed: float = (logo.custom_minimum_size.y if logo != null else 0.0) + 40.0 + 46.0 + 20.0 + 28.0 + 20.0 + sm.x + sm.y
        var fit: = func() -> void :
                if is_instance_valid(sc) and is_instance_valid(list):
                        sc.custom_minimum_size.y = clampf(list.size.y, 120.0, maxf(120.0, root.size.y - fixed - 24.0))
        list.resized.connect(fit)
        sc.custom_minimum_size.y = clampf(root.size.y - fixed - 24.0, 120.0, 520.0)
        for tr2: TextureRect in drone_layer:
                bg.add_child(tr2)

        panel.resized.connect( func() -> void : panel.pivot_offset = panel.size * 0.5)
        UiKit.pop_in(panel, 0.88, 0.26)
        if logo != null:
                logo.modulate.a = 0.0
                var tw0: Tween = logo.create_tween().set_parallel(true)
                tw0.tween_property(logo, "modulate:a", 1.0, 0.3)
                logo.pivot_offset = logo.custom_minimum_size * 0.5
                logo.scale = Vector2(1.3, 1.3)
                tw0.tween_property(logo, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        for i in rows.size():
                var r2: Control = rows[i]
                r2.modulate.a = 0.0
                var tw: Tween = r2.create_tween()
                tw.tween_interval(0.18 + 0.05 * float(i))
                tw.tween_property(r2, "modulate:a", 1.0, 0.2)
        UiKit.snd("ui_open")




func _wn_anim() -> void :
        if _wn == null or not is_instance_valid(_wn) or not _wn.is_visible_in_tree():
                if _wn == null or not is_instance_valid(_wn):
                        _wn_drones.clear()
                return
        var w: float = root.size.x
        var h: float = root.size.y
        var fr: int = int(_t * 14.0) % 4
        for d: Array in _wn_drones:
                var tr: TextureRect = d[0]
                if not is_instance_valid(tr):
                        continue
                var ph: float = _t * float(d[3]) + float(d[2])
                var p: = Vector2.ZERO
                match int(d[1]):
                        0:
                                p = Vector2(w * 0.5 + cos(ph * 1.3) * w * 0.4, 46.0 + sin(ph * 2.6) * 26.0)
                        1:
                                p = Vector2(w - 14.0 + sin(ph * 2.0) * 4.0, h * 0.5 - cos(ph * 0.9) * h * 0.36)
                        _:
                                p = Vector2(14.0 + cos(ph * 1.7) * 4.0, h * 0.55 + sin(ph * 0.8) * h * 0.34)
                var prev: Vector2 = tr.position
                tr.position = p - tr.size * tr.scale * 0.5 + Vector2(0, sin(_t * 9.0 + float(d[2])) * 1.5)
                if absf(tr.position.x - prev.x) > 0.05:
                        tr.flip_h = tr.position.x < prev.x
                tr.texture = _wn_frames[(fr + int(d[1])) % 4]


static func _speed_hint(i: int) -> String:
        return ["КАЖДЫЙ ВЫБИРАЕТ x1–x3, ИДЁТ МЕНЬШАЯ", "В ЗАТИШЬЕ ДО x3, ПРИ СОБЫТИИ СРАЗУ x1", "ВСЕГДА x1, У ВСЕХ ОДИНАКОВО"][clampi(i, 0, 2)]



func _bot_rows(vb: VBoxContainer) -> void :
        _selector(vb, "ИИ", GameConfig.AGGR_NAMES, func() -> int: return GameConfig.aggression, func(i: int) -> void : GameConfig.aggression = i, 100.0, "si_ai")
        _selector(vb, "РОСТ БОТОВ", GameConfig.EXPAND_NAMES, func() -> int: return GameConfig.expand_i, func(i: int) -> void : GameConfig.expand_i = i, 100.0, "si_size")
        _selector(vb, "ОКОПЫ БОТОВ", GameConfig.AUTODIG_NAMES, func() -> int: return GameConfig.ai_autodig, func(i: int) -> void : GameConfig.ai_autodig = i, 100.0, "si_ai")



static func _pts(v: int) -> String:
        var t: String = str(v)
        if v >= 10000:
                t = "%d %03d" % [v / 1000, v % 1000]
        return Loc.t("%s ОЧКОВ") % t


func show_setup() -> void :

        var again: bool = current in ["setup", "flag", "cbots", "cbot"]
        var keep_scroll: int = _scroll.scroll_vertical if again and _scroll != null and is_instance_valid(_scroll) else 0
        var mp_host: bool = net != null and net.is_host and net.active() and not net.in_match
        var vb: VBoxContainer = _screen("Партия по сети" if mp_host else Loc.t("Новая партия"), 0.45)
        current = "setup"
        if not again or GameConfig.map_seed < 0:
                GameConfig.map_seed = randi() % 100000000
        if PerfProbe.armed and not again:
                GameConfig.map_seed = PerfProbe.SEED
        vb.add_theme_constant_override("separation", 4)
        if not mp_host:
                _section(vb, "ВАША СТРАНА")
                FlagEditor.from_profile = false
                FlagEditor.card(vb, show_flag_editor)
                _sep(vb, 4)
        _section(vb, "КАРТА МИРА")
        _map_block(vb)
        _selector(vb, "РАЗМЕР", GameConfig.SIZE_NAMES, func() -> int: return GameConfig.size_i, func(i: int) -> void :
                GameConfig.size_i = i
                _pv_request(), 100.0, "si_size")
        _selector(vb, "РЕКИ", GameConfig.WATER_NAMES, func() -> int: return GameConfig.rivers_i, func(i: int) -> void :
                GameConfig.rivers_i = i
                _pv_request(), 100.0, "si_rivers")
        _selector(vb, "ОЗЁРА", GameConfig.WATER_NAMES, func() -> int: return GameConfig.lakes_i, func(i: int) -> void :
                GameConfig.lakes_i = i
                _pv_request(), 100.0, "si_lakes")
        if not mp_host:
                _sep(vb, 4)
                _section(vb, "ОБЛИК СТРАНЫ")
                _style_picker(vb)
        _sep(vb, 4)
        _section(vb, "ПРАВИЛА")
        if mp_host:
                var mp_bot_room: int = maxi(0, 8 - net.slots.size())
                _selector(vb, "КАСТОМНЫЕ БОТЫ", ["ВКЛ", "ВЫКЛ"], func() -> int: return 0 if GameConfig.cb_on else 1, func(i: int) -> void :
                        GameConfig.cb_on = i == 0
                        if GameConfig.cb_on:
                                CustomBots.seed_list()
                                CustomBots.sync_count()
                        Save.save_prefs()
                        show_setup.call_deferred(), 100.0, "si_bots")
                if GameConfig.cb_on:
                        CustomBots.sanitize()
                        CustomBots.card(vb, show_custom_bots, true)
                        _label(vb, Loc.t("УЧАСТНИКОВ: %d · БОТОВ В МАТЧЕ: %d ИЗ %d") % [net.slots.size(), mini(GameConfig.cb_list.size(), mp_bot_room), GameConfig.cb_list.size()], 10, UiKit.MUTED)
                else:
                        var bot_opts: Array = ["НЕТ"]
                        for bot_n in mini(6, mp_bot_room):
                                bot_opts.append(bot_n + 1)
                        _selector(vb, "БОТЫ", bot_opts, func() -> int: return clampi(GameConfig.bots, 0, bot_opts.size() - 1), func(i: int) -> void :
                                var was_none: bool = GameConfig.bots == 0
                                GameConfig.bots = i
                                if was_none != (i == 0):
                                        show_setup.call_deferred()
                                else:
                                        _pv_texts(), 100.0, "si_bots")
                        _label(vb, Loc.t("УЧАСТНИКОВ: %d ИЗ 8") % [net.slots.size() + GameConfig.bots], 10, UiKit.MUTED)

                var sp_hint: Label = null
                _selector(vb, "УСКОРЕНИЕ", NetConfig.SPEED_ORDER.map( func(k: int) -> String: return String(NetConfig.SPEED_WORDS[k])), 
                        func() -> int: return maxi(0, NetConfig.SPEED_ORDER.find(clampi(GameConfig.mp_speed, 0, 2))), func(i: int) -> void :
                        GameConfig.mp_speed = int(NetConfig.SPEED_ORDER[i])
                        if sp_hint != null and is_instance_valid(sp_hint):
                                sp_hint.text = _speed_hint(GameConfig.mp_speed), 100.0, "net_wait")
                sp_hint = _label(vb, _speed_hint(GameConfig.mp_speed), 10, UiKit.MUTED)
        else:
                GameConfig.bots = maxi(1, GameConfig.bots)

                _selector(vb, "КАСТОМНЫЕ ВРАГИ", ["ВКЛ", "ВЫКЛ"], func() -> int: return 0 if GameConfig.cb_on else 1, func(i: int) -> void :
                        GameConfig.cb_on = i == 0
                        if GameConfig.cb_on:
                                CustomBots.seed_list()
                                CustomBots.sync_count()
                        Save.save_prefs()
                        if GameConfig.cb_on:
                                show_custom_bots.call_deferred()
                        else:
                                show_setup.call_deferred(), 100.0, "si_bots")
                if GameConfig.cb_on:
                        CustomBots.sanitize()
                        CustomBots.card(vb, show_custom_bots)
                else:
                        var bots: Array = [1, 2, 3, 4, 5, 6, 7]
                        _selector(vb, "БОТЫ", bots, func() -> int: return clampi(GameConfig.bots, 1, GameConfig.CB_MAX) - 1, func(i: int) -> void :
                                GameConfig.bots = i + 1
                                _pv_texts(), 100.0, "si_bots")
                _cb_crowd = _label(vb, "", 10, UiKit.GOLD)
                _cb_crowd_paint()
        var has_bots: bool = not (mp_host and GameConfig.bots == 0)
        if has_bots and (mp_host or not GameConfig.cb_on):
                _selector(vb, "СЛОЖНОСТЬ", GameConfig.DIFF_NAMES, func() -> int: return GameConfig.difficulty, func(i: int) -> void : GameConfig.difficulty = i, 100.0, "si_diff")

        _selector(vb, "ПОБЕДА", GameConfig.VICTORY_NAMES, func() -> int: return GameConfig.victory, func(i: int) -> void :
                GameConfig.victory = i
                show_setup.call_deferred(), 100.0, "si_victory")
        if GameConfig.victory == 0:
                var tg: Array = []
                for v: int in GameConfig.TARGETS:
                        tg.append(_pts(v))
                _selector(vb, "ЦЕЛЬ", tg, func() -> int: return GameConfig.target_i, func(i: int) -> void : GameConfig.target_i = i, 100.0, "si_goal")
        var lim_hint: Array = [null]
        if GameConfig.victory != 1:

                var lm: Array = []
                for v: int in GameConfig.TIMES:
                        lm.append(Loc.t("%d МИН") % v if v > 0 else "НЕТ")
                _selector(vb, "ЛИМИТ ВРЕМЕНИ", lm, func() -> int: return GameConfig.limit_i, func(i: int) -> void :
                        GameConfig.limit_i = i
                        if lim_hint[0] != null and is_instance_valid(lim_hint[0]):
                                (lim_hint[0] as Label).text = _win_hint(false), 100.0, "si_time")
        var no_limit: bool = false
        if GameConfig.victory == 1:
                var tm: Array = []
                for v: int in GameConfig.TIMES:
                        tm.append(Loc.t("%d МИН") % v if v > 0 else "БЕЗ ЛИМИТА")
                _selector(vb, "ВРЕМЯ", tm, func() -> int: return GameConfig.time_i, func(i: int) -> void :
                        var was: bool = GameConfig.time_limit() <= 0.0
                        GameConfig.time_i = i
                        if was != (GameConfig.time_limit() <= 0.0):
                                show_setup.call_deferred(), 100.0, "si_time")
                no_limit = GameConfig.time_limit() <= 0.0
                if no_limit:
                        var tg2: Array = []
                        for v: int in GameConfig.TARGETS:
                                tg2.append(_pts(v))
                        _selector(vb, "ЦЕЛЬ", tg2, func() -> int: return GameConfig.target_i, func(i: int) -> void : GameConfig.target_i = i, 100.0, "si_goal")
        lim_hint[0] = _label(vb, _win_hint(no_limit), 10, UiKit.MUTED)
        if not mp_host:
                SavesUI.setup_block(self, vb)
        if has_node("/root/ModManager"):
                get_node("/root/ModManager").call_hook("on_setup_menu", [self, vb])

        var more_b: Button = _nav_row(vb, "ЕЩЁ ПРАВИЛА", "СКРЫТЬ" if _more_open else ("ИИ, РУДЫ, ТУМАН, РЕЖИМ" if has_bots else "РУДЫ, ТУМАН, РЕЖИМ"), func() -> void :
                _more_open = not _more_open
                show_setup.call_deferred())
        var arr: TextureRect = more_b.get_child(0).get_child(more_b.get_child(0).get_child_count() - 1) as TextureRect
        if arr != null and _more_open and arr.texture != null:
                var ai: Image = arr.texture.get_image()
                ai.rotate_90(CLOCKWISE)
                arr.texture = ImageTexture.create_from_image(ai)
        _rh = _label(vb, "", 10, UiKit.MUTED)
        _rh.visible = false
        if not _more_open:
                _finish_setup(mp_host, keep_scroll)
                return
        if has_bots:
                _bot_rows(vb)
        _selector(vb, "РУДЫ", GameConfig.ORE_PRESET_NAMES, func() -> int: return GameConfig.ore_preset, func(i: int) -> void :
                var was: int = GameConfig.ore_preset
                GameConfig.ore_preset = i
                if (i == 3) != (was == 3):
                        show_setup.call_deferred(), 100.0, "si_ore")
        if GameConfig.ore_preset == 3:
                for it: Array in [["  МЕТАЛЛ", "metal"], ["  ТИТАН", "titanium"], ["  НЕФТЬ", "oil"], ["  ДРАГМЕТ.", "precious"], ["  УРАН", "uranium"]]:
                        var key: String = String(it[1])
                        _selector(vb, String(it[0]), GameConfig.ORE_LEVEL_NAMES, func() -> int: return int(GameConfig.ore_custom.get(key, 2)), func(i: int) -> void : GameConfig.ore_custom[key] = i)
        _selector(vb, "ЗАПАСЫ", GameConfig.RESERVE_NAMES, func() -> int: return GameConfig.reserves_i, func(i: int) -> void : GameConfig.reserves_i = i, 100.0, "si_ore")
        _selector(vb, "ДЕНЬ/НОЧЬ", ["ВКЛ", "ВЫКЛ"], func() -> int: return 0 if GameConfig.night else 1, func(i: int) -> void : GameConfig.night = i == 0, 100.0, "si_daynight")
        _selector(vb, "ТУМАН", ["ВКЛ", "ВЫКЛ"], func() -> int: return 0 if GameConfig.fog else 1, func(i: int) -> void : GameConfig.fog = i == 0, 100.0, "si_fog")
        _selector(vb, "АЛЬЯНСЫ", ["ВКЛ", "ВЫКЛ"], func() -> int: return 0 if GameConfig.alliances else 1, func(i: int) -> void : GameConfig.alliances = i == 0, 100.0, "si_ai")
        _selector(vb, "РЕЖИМ", ["ОБЫЧНЫЙ", "ТВОРЧЕСКИЙ"], func() -> int: return 1 if GameConfig.creative else 0, func(i: int) -> void : GameConfig.creative = i == 1, 100.0, "si_mode")
        _finish_setup(mp_host, keep_scroll)




func show_flag_editor(bot: int = -1) -> void :
        FlagEditor.who = bot if bot >= 0 and bot < GameConfig.cb_list.size() else -1
        if FlagEditor.who >= 0:
                FlagEditor.from_profile = false
        var vb: VBoxContainer = _screen((Loc.t("Флаг страны") if FlagEditor.from_profile else Loc.t("Ваша страна")) if FlagEditor.who < 0 else Loc.t("Страна врага"), 0.45)
        current = "flag"
        FlagEditor.new(self).build(vb)



func show_mods(keep: bool = false) -> void:
        var ks: int = _scroll.scroll_vertical if keep and _scroll != null and is_instance_valid(_scroll) else 0
        var vb: VBoxContainer = _screen("Модификации", 0.55, not keep)
        current = "mods"
        ModsUI.build(self, vb)
        if keep and _scroll != null:
                _scroll.set_deferred("scroll_vertical", ks)

func show_mods_settings(from_pause: bool = false) -> void:
        _from_pause = from_pause
        var vb: VBoxContainer = _screen("Модификации", 0.45)
        current = "settings_mods"

        var banner: PanelContainer = PanelContainer.new()
        banner.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 10, 8))
        vb.add_child(banner)

        var b_col: VBoxContainer = VBoxContainer.new()
        b_col.add_theme_constant_override("separation", 6)
        banner.add_child(b_col)

        if not GameConfig.mods_enabled:
                var h_lbl: Label = UiKit.lbl("⚠️ МОДИФИКАЦИИ ВРЕМЕННО ОТКЛЮЧЕНЫ", 11, UiKit.GOLD, 2, 2)
                h_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                b_col.add_child(h_lbl)
                var d_lbl: Label = UiKit.lbl("Вкладка отключена для стабильности игры у обычных игроков. Скоро модификации вернутся в официальном обновлении.\nДля моддеров и тестирования можно включить экспериментальный режим ниже.", 9, UiKit.MUTED, 1, 1)
                d_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
                d_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                b_col.add_child(d_lbl)
        else:
                var h_lbl: Label = UiKit.lbl("⚡ ЭКСПЕРИМЕНТАЛЬНЫЙ РЕЖИМ ВКЛЮЧЁН", 11, UiKit.GREEN, 2, 2)
                h_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                b_col.add_child(h_lbl)
                var d_lbl: Label = UiKit.lbl("Модификации активны. Обратите внимание: моды могут быть крайне нестабильными, вызывать сбои или не работать вовсе.", 9, UiKit.MUTED, 1, 1)
                d_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
                d_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                b_col.add_child(d_lbl)

        _sep(vb, 6)

        # Переключатель модификаций
        var toggle_btn: Button = Button.new()
        toggle_btn.focus_mode = Control.FOCUS_NONE
        toggle_btn.custom_minimum_size = Vector2(0, 48)
        var n_sb: StyleBox = UiKit.sb("wb_panel_dark", 8, 2)
        var pr_sb: StyleBox = UiKit.sb("wb_panel", 8, 2)
        for st: String in ["normal", "hover", "disabled"]:
                toggle_btn.add_theme_stylebox_override(st, n_sb)
        toggle_btn.add_theme_stylebox_override("pressed", pr_sb)
        toggle_btn.add_theme_stylebox_override("hover_pressed", pr_sb)
        toggle_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
        vb.add_child(toggle_btn)

        var row: HBoxContainer = HBoxContainer.new()
        row.set_anchors_preset(Control.PRESET_FULL_RECT)
        row.offset_left = 12.0
        row.offset_right = -12.0
        row.mouse_filter = Control.MOUSE_FILTER_IGNORE
        row.add_theme_constant_override("separation", 6)
        toggle_btn.add_child(row)

        var t_lbl: Label = UiKit.lbl("ЭКСПЕРИМЕНТАЛЬНЫЕ МОДИФИКАЦИИ", 10, UiKit.TEXT, 2, 2)
        t_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        t_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        row.add_child(t_lbl)

        var track: PanelContainer = PanelContainer.new()
        track.add_theme_stylebox_override("panel", UiKit.sb("wb_slot", 3, 3))
        track.custom_minimum_size = Vector2(76, 32)
        track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        track.mouse_filter = Control.MOUSE_FILTER_IGNORE
        row.add_child(track)

        var tr: HBoxContainer = HBoxContainer.new()
        tr.add_theme_constant_override("separation", 2)
        tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
        track.add_child(tr)

        var word: Label = UiKit.lbl("ВКЛ" if GameConfig.mods_enabled else "ВЫКЛ", 10, UiKit.GREEN if GameConfig.mods_enabled else UiKit.MUTED, 2, 2)
        word.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        word.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

        var knob: Panel = Panel.new()
        knob.custom_minimum_size = Vector2(22, 22)
        knob.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
        knob.add_theme_stylebox_override("panel", UiKit.sb("wb_btn_green" if GameConfig.mods_enabled else "wb_btn_stone", 0, 0))

        if GameConfig.mods_enabled:
                tr.add_child(word)
                tr.add_child(knob)
        else:
                tr.add_child(knob)
                tr.add_child(word)

        UiKit.press_fx(toggle_btn)
        toggle_btn.pressed.connect(func() -> void:
                if not GameConfig.mods_enabled:
                        show_mods_disclaimer_dialog(
                                func() -> void:
                                        GameConfig.mods_enabled = true
                                        GameConfig.custom_maps_cache.clear()
                                        Save.save_prefs()
                                        if has_node("/root/ModManager"):
                                                get_node("/root/ModManager").scan_installed_mods()
                                        show_mods_settings(from_pause),
                                func() -> void:
                                        pass
                        )
                else:
                        GameConfig.mods_enabled = false
                        GameConfig.custom_maps_cache.clear()
                        Save.save_prefs()
                        if has_node("/root/ModManager"):
                                get_node("/root/ModManager").scan_installed_mods()
                        show_mods_settings(from_pause)
        )

        if GameConfig.mods_enabled:
                _sep(vb, 6)
                var open_btn: Button = UiKit.big("📦 КАТАЛОГ И УПРАВЛЕНИЕ МОДАМИ", "green", "", 44.0, 11)
                open_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                open_btn.pressed.connect(func() -> void:
                        UiKit.snd("ui_click")
                        _mods_from_settings = true
                        show_mods()
                )
                vb.add_child(open_btn)

                var folder_btn: Button = UiKit.big("📁 ОТКРЫТЬ ПАПКУ С МОДАМИ", "stone", "", 38.0, 10)
                folder_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                folder_btn.pressed.connect(func() -> void:
                        UiKit.snd("ui_click")
                        if has_node("/root/ModManager"):
                                get_node("/root/ModManager").open_mods_folder_in_os()
                )
                vb.add_child(folder_btn)

        _sep(vb, 6)
        var tg_btn: Button = UiKit.big("💬 ТЕЛЕГРАМ: ПОРТЫ И МОДЫ", "blue", "", 36.0, 10)
        tg_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        tg_btn.pressed.connect(func() -> void:
                UiKit.snd("ui_click")
                OS.shell_open("https://t.me/droneflamesmod")
        )
        vb.add_child(tg_btn)

        var back: Button = _button(_bottom_row(), "НАЗАД", "stone", "")
        back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        back.pressed.connect(func() -> void:
                UiKit.snd("ui_click")
                show_settings(from_pause)
        )

func show_mods_disclaimer_dialog(on_confirm: Callable, on_cancel: Callable = Callable()) -> void:
        var bg: = ColorRect.new()
        bg.set_anchors_preset(Control.PRESET_FULL_RECT)
        bg.color = Color(0.02, 0.03, 0.06, 0.92)
        bg.mouse_filter = Control.MOUSE_FILTER_STOP
        root.add_child(bg)
        UiKit.pop_in(bg)

        var cc: = CenterContainer.new()
        cc.set_anchors_preset(Control.PRESET_FULL_RECT)
        bg.add_child(cc)

        var panel: = PanelContainer.new()
        panel.add_theme_stylebox_override("panel", UiKit.sb("wb_window", 16, 14))
        var win_w: float = clampf(root.size.x - 30.0, 320.0, 560.0)
        panel.custom_minimum_size = Vector2(win_w, 0)
        cc.add_child(panel)

        var vbox: = VBoxContainer.new()
        vbox.add_theme_constant_override("separation", 8)
        panel.add_child(vbox)

        var title_lbl: Label = UiKit.lbl("⚠️ ВНИМАНИЕ: ДИСКЛЕЙМЕР", 13, UiKit.TITLE, 3, 3)
        title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        vbox.add_child(title_lbl)

        var sub_lbl: Label = UiKit.lbl("ЭКСПЕРИМЕНТАЛЬНЫЙ РЕЖИМ МОДИФИКАЦИЙ", 9, UiKit.GOLD, 2, 2)
        sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        vbox.add_child(sub_lbl)

        _sep(vbox, 2)

        var card: = PanelContainer.new()
        card.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 12, 10))
        vbox.add_child(card)

        var card_vbox: = VBoxContainer.new()
        card_vbox.add_theme_constant_override("separation", 6)
        card.add_child(card_vbox)

        var items: Array[String] = [
                "• Модификации в текущей версии ПК-порта крайне нестабильны, могут работать некорректно или не работать вовсе.",
                "• Использование модов может приводить к вылетам игры, нарушению логики матча и ошибкам сохранений.",
                "• Все найденные баги и проблемы будут постепенно устраняться авторами порта в будущих обновлениях.",
                "• Текущая поддержка оставлена исключительно для опытных игроков и авторов модов (моддеров) для тестирования.",
                "• Скоро ожидается официальный порт от оригинального разработчика игры, который сделает модификации максимально удобными и стабильными.",
                "• Включая модификации, вы подтверждаете понимание всех рисков нестабильности игрового процесса."
        ]

        for it_text in items:
                var lbl: Label = UiKit.lbl(it_text, 9, UiKit.TEXT, 1, 1)
                lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
                card_vbox.add_child(lbl)

        _sep(vbox, 2)

        # Чекбокс согласия
        var check_btn: = Button.new()
        check_btn.focus_mode = Control.FOCUS_NONE
        check_btn.custom_minimum_size = Vector2(0, 44)
        var n_s: StyleBox = UiKit.sb("wb_panel_dark", 8, 4)
        var h_s: StyleBox = UiKit.sb("wb_panel", 8, 4)
        check_btn.add_theme_stylebox_override("normal", n_s)
        check_btn.add_theme_stylebox_override("hover", h_s)
        check_btn.add_theme_stylebox_override("pressed", h_s)
        check_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
        vbox.add_child(check_btn)

        var check_row: = HBoxContainer.new()
        check_row.set_anchors_preset(Control.PRESET_FULL_RECT)
        check_row.offset_left = 10.0
        check_row.offset_right = -10.0
        check_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
        check_row.add_theme_constant_override("separation", 10)
        check_btn.add_child(check_row)

        var box: = PanelContainer.new()
        box.custom_minimum_size = Vector2(26, 26)
        box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        box.mouse_filter = Control.MOUSE_FILTER_IGNORE
        box.add_theme_stylebox_override("panel", UiKit.sb("wb_slot", 4, 2))
        check_row.add_child(box)

        var check_mark: Label = UiKit.lbl("", 15, UiKit.GREEN, 3, 2)
        check_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        check_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        box.add_child(check_mark)

        var check_text: Label = UiKit.lbl("Да, я согласен. Я понимаю риски и возможную нестабильность модификаций.", 10, UiKit.TEXT, 2, 2)
        check_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        check_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        check_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        check_row.add_child(check_text)

        _sep(vbox, 2)

        # Кнопки действий
        var act_row: = HBoxContainer.new()
        act_row.add_theme_constant_override("separation", 10)
        vbox.add_child(act_row)

        var cancel_btn: Button = UiKit.big("ОТМЕНА", "stone", "", 44.0, 11)
        cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        act_row.add_child(cancel_btn)

        var apply_btn: Button = UiKit.big("ПРИМЕНИТЬ", "green", "", 44.0, 12)
        apply_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        apply_btn.disabled = true
        act_row.add_child(apply_btn)

        var agreed: Array[bool] = [false]
        check_btn.pressed.connect(func() -> void:
                agreed[0] = not agreed[0]
                UiKit.snd("ui_click")
                if agreed[0]:
                        check_mark.text = "✓"
                        box.add_theme_stylebox_override("panel", UiKit.sb("wb_btn_green_p", 4, 2))
                        check_text.add_theme_color_override("font_color", UiKit.GREEN)
                        apply_btn.disabled = false
                else:
                        check_mark.text = ""
                        box.add_theme_stylebox_override("panel", UiKit.sb("wb_slot", 4, 2))
                        check_text.add_theme_color_override("font_color", UiKit.TEXT)
                        apply_btn.disabled = true
        )

        cancel_btn.pressed.connect(func() -> void:
                UiKit.snd("ui_click")
                bg.queue_free()
                if on_cancel.is_valid():
                        on_cancel.call()
        )

        apply_btn.pressed.connect(func() -> void:
                UiKit.snd("ui_build")
                bg.queue_free()
                if on_confirm.is_valid():
                        on_confirm.call()
        )



func show_custom_bots(keep: bool = false) -> void :
        var ks: int = _scroll.scroll_vertical if keep and _scroll != null and is_instance_valid(_scroll) else 0
        var vb: VBoxContainer = _screen("Кастомные враги", 0.45, not keep)
        current = "cbots"
        var multiplayer: bool = net != null and net.is_host and net.active() and not net.in_match
        CustomBots.build_list(self, vb, multiplayer)
        if keep:
                _scroll.set_deferred("scroll_vertical", ks + 64)



func show_bot_editor(i: int, keep: bool = false) -> void :
        if i < 0 or i >= GameConfig.cb_list.size():
                show_custom_bots()
                return
        var ks: int = _scroll.scroll_vertical if keep and _scroll != null and is_instance_valid(_scroll) else 0
        var vb: VBoxContainer = _screen(Loc.t("Враг %d из %d") % [i + 1, GameConfig.cb_list.size()], 0.45, not keep)
        current = "cbot"
        CustomBots.build_bot(self, vb, i)
        if keep:
                _scroll.set_deferred("scroll_vertical", ks)


func _finish_setup(mp_host: bool, keep_scroll: int) -> void :
        var row: HBoxContainer = _bottom_row()
        var back: Button = _button(row, "НАЗАД", "stone", "mp_lobby" if mp_host else "main")
        back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var go: Button = _ibutton(row, "НАЧАТЬ", "green", "mp_start" if mp_host else "start", "mi_play", 44.0)
        go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        go.size_flags_stretch_ratio = 1.6
        if not mp_host:
                SavesUI.setup_footer(self, go)
        if keep_scroll > 0:
                _scroll.set_deferred("scroll_vertical", keep_scroll)





func _style_picker(parent: Control, on_pick: Callable = Callable()) -> void :
        var tex: Texture2D = load("res://assets/sprites/style_cards31.png") as Texture2D if ResourceLoader.exists("res://assets/sprites/style_cards31.png") else null
        var grid: = GridContainer.new()
        grid.columns = 2
        grid.add_theme_constant_override("h_separation", 6)
        grid.add_theme_constant_override("v_separation", 6)
        parent.add_child(grid)
        var cards: Array = []


        var sel_sb: StyleBox = UiKit.sb("wb_slot_active", 4)
        var off_sb: StyleBox = UiKit.sb("wb_slot", 4)
        for i in ArchStyle.NAMES.size():
                var b: = Button.new()
                b.focus_mode = Control.FOCUS_NONE
                b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                b.clip_contents = true
                grid.add_child(b)
                var col: = VBoxContainer.new()
                col.add_theme_constant_override("separation", 2)
                col.mouse_filter = Control.MOUSE_FILTER_IGNORE
                col.set_anchors_preset(Control.PRESET_FULL_RECT)
                col.offset_left = 4
                col.offset_top = 4
                col.offset_right = -4
                col.offset_bottom = -4
                b.add_child(col)
                var pic: = TextureRect.new()
                pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
                pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
                pic.custom_minimum_size = Vector2(136, 112)
                pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
                pic.stretch_mode = TextureRect.STRETCH_SCALE
                if tex != null:
                        var at: = AtlasTexture.new()
                        at.atlas = tex
                        at.region = Rect2(i * 68, 0, 68, 56)
                        pic.texture = at
                var pc: = CenterContainer.new()
                pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
                pc.add_child(pic)
                col.add_child(pc)
                var nm: Label = UiKit.lbl(String(ArchStyle.NAMES[i]), 10, UiKit.TEXT, 2, 2)
                nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                col.add_child(nm)
                var hint: Label = UiKit.lbl("панельки, хрущёвки, сталинки" if i == 0 else String(["", "кирпич, высотки, пригороды", "черепица, собор, фахверк", "высотки, храм, рынок"][i]), 10, UiKit.MUTED, 1, 2)
                hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
                hint.max_lines_visible = 2
                col.add_child(hint)
                b.custom_minimum_size = Vector2(0, 164)
                cards.append([b, nm, hint])
        var paint: = func() -> void :
                for k in cards.size():
                        var on: bool = k == clampi(GameConfig.arch_i, 0, 3)
                        var bt: Button = cards[k][0]
                        for st: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
                                bt.add_theme_stylebox_override(st, sel_sb if on else off_sb)
                        (cards[k][1] as Label).add_theme_color_override("font_color", UiKit.GOLD if on else UiKit.TEXT)
                        (cards[k][2] as Label).add_theme_color_override("font_color", UiKit.TEXT if on else UiKit.MUTED)
        paint.call()
        for k in cards.size():
                (cards[k][0] as Button).pressed.connect( func() -> void :
                        GameConfig.arch_i = k
                        Save.save_prefs()
                        UiKit.snd("ui_select")
                        paint.call()
                        if on_pick.is_valid():
                                on_pick.call(k))





static var _mp_tab: int = -1
static var _mp_pub: bool = false
var _mp_list: VBoxContainer = null
var _mp_join_b: Button = null
var _mp_bar: Control = null


func _mp_online_ok() -> bool:
        NetConfig.load_cfg()
        return NetConfig.signal_url != "" and RtcLink.available()


func show_mp(msg: String = "", sev: String = "") -> void :
        if _mp_gate():
                return
        _hook_account()
        if current == "main":
                _mp_tab = 1
        if current != "mp":
                _mp_new_ok = false
                _mp_del_ok = false
        var vb: VBoxContainer = _screen("Мультиплеер", 0.45, current != "mp")
        current = "mp"
        if net == null:
                _button(vb, "НАЗАД", "stone", "main")
                return
        Account.load_state()
        if not Account.is_authenticated():
                net.browser.stop()
                _label(vb, "Играйте по интернету: создайте комнату, войдите по коду или выберите открытую игру. Аккаунт сохраняет профиль, статистику и друзей.", 12, UiKit.TEXT, false)
                MpKit.choice_card(vb, "net_globe", "ВОЙТИ", "УЖЕ ЕСТЬ АККАУНТ", false, func() -> void: _show_online_auth(false, show_mp, show_mp))
                MpKit.choice_card(vb, "net_edit", "РЕГИСТРАЦИЯ", "СОЗДАТЬ АККАУНТ С НИКОМ И ПАРОЛЕМ", false, func() -> void: _show_online_auth(true, show_mp, show_mp))
                _mp_back_button(_bottom_row())
                return
        if _mp_tab != 0 and not _social.ready:
                net.browser.stop()
                var failed: bool = _social.error_text != ""
                MpKit.placeholder(vb, "net_warn" if failed else "net_sync", _social.error_text if failed else "ПОДКЛЮЧЕНИЕ К СЕРВЕРУ", "МОЖНО ПОВТОРИТЬ ПОПЫТКУ ИЛИ ИГРАТЬ ПО WI-FI", not failed, 86.0)
                MpKit.choice_card(vb, "net_lan", "ЛОКАЛЬНАЯ СЕТЬ", "ИГРА ПО WI-FI БЕЗ ПОДКЛЮЧЕНИЯ К СЕРВЕРУ", false, func() -> void:
                        _mp_tab = 0
                        show_mp())
                var footer: HBoxContainer = _bottom_row()
                _mp_back_button(footer)
                var retry: Button = _ibutton(footer, "ПОВТОРИТЬ", "blue", "", "net_refresh", 48.0)
                retry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                retry.pressed.connect(_social.retry)
                return
        var online_ok: bool = _mp_online_ok()
        if _mp_tab < 0:
                _mp_tab = 1 if online_ok else 0
        if not net.lan.rooms_changed.is_connected(_mp_rooms_changed):
                net.lan.rooms_changed.connect(_mp_rooms_changed)
        if not net.browser.rooms_changed.is_connected(_mp_rooms_changed):
                net.browser.rooms_changed.connect(_mp_rooms_changed)
        if not net.lobby_changed.is_connected(_mp_lobby_changed):
                net.lobby_changed.connect(_mp_lobby_changed)
        if not net.active() and not net.lan.scanning:
                net.lan.browse()
                _mp_browse_ms = Time.get_ticks_msec()
                get_tree().create_timer(6.2).timeout.connect( func() -> void :
                        if current == "mp" and _mp_tab == 0:
                                _mp_fill_list())
        var rs: bool = _mp_resume_card(vb)
        var rj: bool = _mp_rejoin_card(vb)
        var relay_mode: bool = RtcLink.relay_only()
        MpKit.tabs(vb, [["net_lan", "WI-FI"], ["net_globe", "ОНЛАЙН", online_ok]], _mp_tab, func(i: int) -> void :
                if i == _mp_tab:
                        return
                _mp_tab = i
                show_mp())
        _acc_sig = _account_sig()
        if _mp_tab == 0:
                _mp_nick_row(vb)
        else:
                _mp_profile_card(vb)
                var social_bar := HBoxContainer.new()
                vb.add_child(social_bar)
                _social_button(social_bar, "Друзья", func() -> void: _show_social("friends", show_mp))
                _social_notification = _social_button(social_bar, "Уведомления", func() -> void: _show_social("notifications", show_mp))
                _update_social_notification()
        _label(vb, "БЕЗ ИНТЕРНЕТА, В ОДНОЙ СЕТИ" if _mp_tab == 0 else "ЧЕРЕЗ ИНТЕРНЕТ, ДО %d ИГРОКОВ" % NetConfig.MAX_PLAYERS, 10, UiKit.MUTED)
        var signed: bool = Account.signed_in()
        var open_ok: bool = online_ok
        if _mp_tab == 1:
                if not online_ok:
                        MpKit.placeholder(vb, "net_warn", "ОНЛАЙН НЕДОСТУПЕН В ЭТОЙ ВЕРСИИ", "ИГРАЙТЕ ПО WI-FI: ВКЛАДКА СЛЕВА", false, 96.0)
                else:
                        var top_btn: Button = MpKit.card_button(60.0)
                        vb.add_child(top_btn)
                        var tr: HBoxContainer = MpKit._hbox(top_btn, 10, 12)
                        tr.add_child(MpKit.icon("acc_ranked", true))
                        MpKit._two_lines(tr, "ТАБЛИЦА ЛИДЕРОВ (ТОПЫ)", "РЕЙТИНГ ПО ЧАСАМ И ПОБЕДАМ · ПОИСК И ПРОФИЛИ", 13, UiKit.GOLD)
                        tr.add_child(UiKit.icon_rect("acc_arrow", 16.0))
                        top_btn.pressed.connect(func() -> void:
                                UiKit.press_fx(top_btn)
                                show_leaderboard()
                        )
                        net.browser.start()
                        MpKit.section(vb, "ОТКРЫТЫЕ КОМНАТЫ", "net_refresh", net.browser.busy and net.browser.state == RoomBrowser.STATE_OK, func() -> void : net.browser.refresh())
        else:
                net.browser.stop()
                MpKit.section(vb, "КОМНАТЫ РЯДОМ", "net_sync", true)
        _mp_list = null
        if _mp_tab == 0 or open_ok:
                _mp_list = VBoxContainer.new()
                _mp_list.add_theme_constant_override("separation", 6)
                _mp_list.child_entered_tree.connect( func(ch: Node) -> void :
                        if ch is PanelContainer:
                                (ch as Control).size_flags_vertical = Control.SIZE_EXPAND_FILL)
                _mp_list.custom_minimum_size = Vector2(0, MpKit.ROW_H * maxf(1.0, (2.0 if _mp_tab == 1 else 4.0) - (1.0 if rj else 0.0) - (1.0 if rs else 0.0)) + 6.0 * 2.0)
                vb.add_child(_mp_list)
        if _mp_tab == 1 and open_ok:
                _mp_code_row(vb)
        elif _mp_tab == 0:
                _mp_lan_ip_row(vb)
        else:
                _mp_join_b = null
        _mp_fill_list()
        _mp_status_and_buttons(msg, sev, online_ok, signed)



func _mp_profile_card(vb: VBoxContainer) -> void:
        var sub: String
        if Account.is_authenticated():
                sub = "ЧАСОВ: %s · ПОБЕД: %d · МАТЧЕЙ: %d" % [
                        Account.format_hours(float(Account.info.get("playtime_s", 0.0))),
                        int(Account.info.get("wins", 0)),
                        int(Account.info.get("matches", 0))
                ]
        else:
                sub = "НЕАВТОРИЗОВАН · НАЖМИТЕ ДЛЯ ВХОДА"
        var arrow: TextureRect = UiKit.icon_rect("acc_arrow", 16.0)
        MpKit.player_card(vb, Account.username(), sub, Account.equipped(), MpKit.ROW_H, func() -> void:
                if Account.is_authenticated():
                        show_profile()
                else:
                        show_net_auth_prompt(func() -> void: show_profile(), func() -> void: show_mp())
        , arrow, Account.is_dev(), Account.avatar_b64)



func _mp_nick_row(vb: VBoxContainer) -> void :
        var nr: = HBoxContainer.new()
        nr.add_theme_constant_override("separation", 6)
        vb.add_child(nr)
        var nl: Label = UiKit.lbl("НИК", 12, UiKit.GOLD, 2, 2)
        nl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        nr.add_child(nl)
        var ne: = LineEdit.new()
        ne.text = NetConfig.nick()
        ne.max_length = NetConfig.NICK_MAX
        ne.placeholder_text = "Ваш ник"
        ne.custom_minimum_size = Vector2(0, 44)
        ne.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        ne.select_all_on_focus = true
        ne.right_icon = UiKit.tex("net_edit")
        ne.add_theme_font_size_override("font_size", 16)
        ne.text_changed.connect( func(t: String) -> void : NetConfig.set_nick(t))
        ne.text_submitted.connect( func(_t: String) -> void : ne.release_focus())
        ne.focus_exited.connect( func() -> void :
                if is_instance_valid(ne):
                        ne.text = NetConfig.nick())
        nr.add_child(ne)
        _nick_edit = ne


func _mp_back_button(footer: HBoxContainer) -> void:
        var back: Button = _button(footer, "НАЗАД", "stone", "")
        back.custom_minimum_size.x = 111
        back.pressed.connect( func() -> void :
                if net != null:
                        net.lan.stop()
                        net.browser.stop()
                        if net.reconnecting:
                                net.leave(true, true, true)
                        elif net.active() and not net.in_match:
                                net.leave()
                request.emit("main"))


func _mp_status_and_buttons(msg: String, sev: String, online_ok: bool, signed: bool) -> void :

        var st: String = msg if msg != "" else ("" if net.ranked_mode != "" else net.status_text)
        _mp_bar = null
        var slot: = Control.new()
        slot.custom_minimum_size = Vector2(0, 36)
        slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _scroll.get_parent().add_child(slot)
        if st != "":
                _mp_bar = MpKit.status_bar(slot, st, sev if sev != "" else ("alarm" if msg != "" else "info"), "icon_ok" if sev == "ok" else "")
                _mp_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
                var bar_id: int = _mp_bar.get_instance_id()
                get_tree().create_timer(2.0 if sev == "ok" else 5.0).timeout.connect( func() -> void :
                        var bar: Object = instance_from_id(bar_id)
                        if bar != null and is_instance_valid(bar):
                                (bar as Node).queue_free())
        var br: HBoxContainer = _bottom_row()
        _mp_back_button(br)
        var mk: Button = _ibutton(br, "СОЗДАТЬ", "green", "", "net_lan" if _mp_tab == 0 else "net_globe", 48.0)
        mk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var relay_mode: bool = RtcLink.relay_only()
        mk.disabled = _mp_tab == 1 and not relay_mode and ( not online_ok or (signed and not Account.mp_open()) or ( not signed and Account.device_check_missing()))
        if _mp_tab == 1 and online_ok and not signed and not relay_mode:
                mk.modulate.a = 0.6
        mk.pressed.connect( func() -> void :
                if _mp_tab == 1 and not Account.is_authenticated():
                        show_net_auth_prompt(func() -> void: show_mp_create(), func() -> void: show_mp())
                        return
                if not NetConfig.load_match().is_empty() and not _mp_new_ok:
                        _mp_new_ok = true
                        _mp_confirm_timeout()
                        show_mp("СТАРАЯ ПАРТИЯ БУДЕТ УДАЛЕНА · НАЖМИТЕ «СОЗДАТЬ» ЕЩЁ РАЗ")
                        return
                if _mp_new_ok:
                        net.drop_saved_match()
                _mp_new_ok = false
                if _mp_tab == 0:
                        var w: String = net.host_lan()
                        if w != "":
                                show_mp(w)
                        else:
                                show_lobby()
                else:
                        show_mp_create())



func _mp_rejoin_card(vb: VBoxContainer) -> bool:
        if net.active() and not net.reconnecting:
                return false
        var d: Dictionary = NetConfig.load_rejoin()
        if d.is_empty():
                return false
        var trying: bool = net.reconnecting
        var code: String = String(d.get("code", ""))
        var online: bool = String(d.get("mode", "")) == "online"
        var where: String = ("КОД %s-%s" % [code.left(3), code.substr(3)]) if online else "WI-FI"
        var gone: bool = bool(d.get("gone", false))

        var fresh: bool = _mp_peek.has(code) and Time.get_ticks_msec() - int(_mp_peek_t.get(code, 0)) < 10000
        var back: bool = gone and online and fresh and bool(_mp_peek.get(code, false))
        if gone and online and not trying and not fresh:
                if not net.browser.peeked.is_connected(_on_mp_peek):
                        net.browser.peeked.connect(_on_mp_peek)
                net.browser.peek(code)
        var b: Button = MpKit.card_button(56.0)
        var dim: bool = gone and not back
        b.add_theme_stylebox_override("normal", MpKit._flat(Color(0.12, 0.11, 0.09, 0.95) if dim else Color(0.16, 0.12, 0.07, 0.95), UiKit.MUTED if dim else UiKit.GOLD, 2, 6))
        b.disabled = trying
        vb.add_child(b)
        var row: HBoxContainer = MpKit._hbox(b, 8, 10)
        var ic: TextureRect = MpKit.icon("net_sync", true)
        row.add_child(ic)
        if trying:
                MpKit.spin(ic)
        var host_n: String = String(d.get("host", "ХОСТ")).to_upper()
        var sub: String = "%s · %s · %s" % [host_n, where, NetConfig.ago_text(int(d.get("t", 0)))]
        if back:
                sub = "ХОСТ ВЕРНУЛСЯ · ЖДЁТ ВАС"
        elif gone:
                sub = "%s · %s · %s" % ["НЕТ СВЯЗИ С ХОСТОМ" if String(d.get("why", "left")) == "lost" else "ХОСТ ВЫШЕЛ", host_n, NetConfig.ago_text(int(d.get("gone_t", d.get("t", 0))))]
        MpKit._two_lines(row, "ПОДКЛЮЧАЕМСЯ..." if trying else "ВЕРНУТЬСЯ В ПАРТИЮ", sub, 13, UiKit.MUTED if dim else UiKit.GOLD)
        if not trying:
                var x: Button = UiKit.close_btn(44.0)
                x.tooltip_text = "Забыть партию"
                x.size_flags_vertical = Control.SIZE_SHRINK_CENTER
                x.mouse_filter = Control.MOUSE_FILTER_STOP
                x.pressed.connect( func() -> void :
                        NetConfig.clear_rejoin()
                        show_mp("Партия забыта"))
                row.mouse_filter = Control.MOUSE_FILTER_PASS
                row.add_child(x)
        b.pressed.connect( func() -> void :
                UiKit.press_fx(b)
                if online and not Account.signed_in():
                        show_auth(0, "rejoin")
                        return
                var w: String = net.rejoin()
                show_mp(w))
        return true


var _mp_peek: Dictionary = {}
var _mp_peek_t: Dictionary = {}
var _mp_new_ok: bool = false
var _mp_del_ok: bool = false



func _mp_confirm_timeout() -> void :
        get_tree().create_timer(4.0).timeout.connect( func() -> void :
                if _mp_new_ok or _mp_del_ok:
                        _mp_new_ok = false
                        _mp_del_ok = false
                        if visible and current == "mp":
                                show_mp())


func _on_mp_peek(code: String, open: bool) -> void :
        var was: Variant = _mp_peek.get(code)
        _mp_peek[code] = open
        _mp_peek_t[code] = Time.get_ticks_msec()
        var on_mp: bool = visible and current == "mp" and _mp_list != null and is_instance_valid(_mp_list)
        if on_mp and (was == null or bool(was) != open or open):
                show_mp()
        if open:
                get_tree().create_timer(10.0).timeout.connect( func() -> void :
                        if visible and current == "mp" and not net.active() and String(NetConfig.load_rejoin().get("code", "")) == code:
                                net.browser.peek(code))
        if not open:
                get_tree().create_timer(8.0).timeout.connect( func() -> void :
                        if visible and current == "mp" and not net.active() and String(NetConfig.load_rejoin().get("code", "")) == code:
                                net.browser.peek(code))





func _mp_check_saved_host() -> void :
        if await net.check_saved_host() and current == "mp" and visible:
                show_mp("Хост сменился, пока вас не было · вернитесь гостем")


func _mp_resume_card(vb: VBoxContainer) -> bool:
        if net.active():
                return false
        var d: Dictionary = NetConfig.load_match()
        if d.is_empty():
                return false
        var online: bool = String(d.get("mode", "")) == "online"
        if online:
                _mp_check_saved_host()
        var b: Button = MpKit.card_button(56.0)
        b.add_theme_stylebox_override("normal", MpKit._flat(Color(0.08, 0.15, 0.08, 0.95), UiKit.GREEN, 2, 6))
        vb.add_child(b)
        var row: HBoxContainer = MpKit._hbox(b, 8, 10)
        row.add_child(MpKit.icon("net_players", true))
        var n: int = (d.get("slots", []) as Array).size()
        MpKit._two_lines(row, "УДАЛИТЬ ПАРТИЮ?" if _mp_del_ok else "ПРОДОЛЖИТЬ ПАРТИЮ", 
                "ИГРОКИ НЕ ВЕРНУТСЯ · ЕЩЁ ТАП" if _mp_del_ok else "%d ИГР. · %s · %s" % [n, "ОНЛАЙН" if online else "WI-FI", NetConfig.ago_text(int(d.get("t", 0)))], 
                13, UiKit.RED if _mp_del_ok else UiKit.GREEN)
        var x: Button = UiKit.close_btn(44.0)
        x.tooltip_text = "Удалить партию"
        x.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        x.mouse_filter = Control.MOUSE_FILTER_STOP
        x.pressed.connect( func() -> void :
                if _mp_del_ok:
                        _mp_del_ok = false
                        net.drop_saved_match()
                        show_mp("Партия удалена")
                else:
                        _mp_del_ok = true
                        _mp_confirm_timeout()
                        show_mp())
        row.mouse_filter = Control.MOUSE_FILTER_PASS
        row.add_child(x)
        b.pressed.connect( func() -> void :
                UiKit.press_fx(b)
                _mp_del_ok = false
                if online and not Account.signed_in():
                        show_auth(0, "resume")
                        return
                var w: String = net.resume_host()
                if w != "":
                        show_mp(w))
        return true



func _mp_code_row(vb: VBoxContainer) -> void :
        MpKit.section(vb, "ВХОД ПО КОДУ")
        var cr: = HBoxContainer.new()
        cr.add_theme_constant_override("separation", 6)
        vb.add_child(cr)
        var ce: = LineEdit.new()
        ce.placeholder_text = "ABC-DEF"
        ce.max_length = 7
        ce.text = _mp_code_shown(_mp_code)
        ce.custom_minimum_size = Vector2(0, 44)
        ce.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        ce.alignment = HORIZONTAL_ALIGNMENT_CENTER
        ce.add_theme_font_size_override("font_size", 20)
        ce.add_theme_color_override("font_placeholder_color", UiKit.MUTED)
        cr.add_child(ce)
        var paste: Button = UiKit.slot("net_paste", false, 44.0)
        paste.tooltip_text = "Вставить код из буфера"
        cr.add_child(paste)
        var jb: Button = UiKit.big("ВОЙТИ", "blue", "", 44.0, 13)
        jb.custom_minimum_size.x = 82
        cr.add_child(jb)
        _mp_join_b = jb
        var whole: Callable = func() -> bool: return _mp_code.length() == 6
        jb.disabled = not whole.call()
        ce.text_changed.connect( func(t: String) -> void :
                var was: bool = whole.call()
                _mp_code = NetConfig.clean_code(t).left(6)
                var shown: String = _mp_code_shown(_mp_code)
                if ce.text != shown:
                        ce.text = shown
                        ce.caret_column = shown.length()
                jb.disabled = not whole.call()
                if whole.call() and not was:
                        UiKit.pop_in(jb, 0.94, 0.2))
        ce.text_submitted.connect( func(_t: String) -> void :
                if whole.call():
                        _mp_join_code(_mp_code))
        paste.pressed.connect( func() -> void :
                var clip: String = NetConfig.clean_code(DisplayServer.clipboard_get())
                if clip.length() != 6:
                        show_mp("В буфере нет кода комнаты")
                        return
                _mp_code = clip
                ce.text = _mp_code_shown(clip)
                jb.disabled = false
                UiKit.pop_in(jb, 0.94, 0.2))
        jb.pressed.connect( func() -> void : _mp_join_code(_mp_code))



static func _mp_code_shown(c: String) -> String:
        return c if c.length() <= 3 else c.left(3) + "-" + c.substr(3)


func _mp_join_code(code: String, allow_late: bool = true) -> void :
        if not Account.is_authenticated():
                show_net_auth_prompt(func() -> void: _mp_join_code(code, allow_late), func() -> void: show_mp())
                return
        net.browser.stop()
        var w: String = net.join_online(code, allow_late)
        if w != "":
                show_mp(w)
        else:
                show_lobby()


func _mp_lan_ip_row(vb: VBoxContainer) -> void :
        MpKit.section(vb, "ПРЯМОЕ ПОДКЛЮЧЕНИЕ (RADMIN / IP)")
        var cr: = HBoxContainer.new()
        cr.add_theme_constant_override("separation", 6)
        vb.add_child(cr)
        var ce: = LineEdit.new()
        ce.placeholder_text = "26.x.x.x или 192.168.x.x"
        ce.max_length = 32
        ce.text = _mp_lan_ip
        ce.custom_minimum_size = Vector2(0, 44)
        ce.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        ce.alignment = HORIZONTAL_ALIGNMENT_CENTER
        ce.add_theme_font_size_override("font_size", 16)
        ce.add_theme_color_override("font_placeholder_color", UiKit.MUTED)
        cr.add_child(ce)
        var paste: Button = UiKit.slot("net_paste", false, 44.0)
        paste.tooltip_text = "Вставить IP из буфера"
        cr.add_child(paste)
        var jb: Button = UiKit.big("ВОЙТИ", "blue", "", 44.0, 13)
        jb.custom_minimum_size.x = 82
        cr.add_child(jb)
        var valid_ip: Callable = func() -> bool:
                var s: String = _mp_lan_ip.strip_edges()
                return s.length() >= 7 and s.contains(".")
        jb.disabled = not valid_ip.call()
        ce.text_changed.connect( func(t: String) -> void :
                _mp_lan_ip = t.strip_edges()
                jb.disabled = not valid_ip.call())
        ce.text_submitted.connect( func(_t: String) -> void :
                if valid_ip.call():
                        _connect_lan_ip(_mp_lan_ip))
        paste.pressed.connect( func() -> void :
                var clip: String = DisplayServer.clipboard_get().strip_edges()
                if clip.length() >= 7 and clip.contains("."):
                        _mp_lan_ip = clip
                        ce.text = clip
                        jb.disabled = false
                        UiKit.pop_in(jb, 0.94, 0.2)
                else:
                        show_mp("В буфере нет IP-адреса"))
        jb.pressed.connect( func() -> void :
                _connect_lan_ip(_mp_lan_ip))


func _connect_lan_ip(target: String) -> void :
        var s: String = target.strip_edges()
        var port: int = NetConfig.LAN_PORT
        if s.contains(":"):
                var parts: PackedStringArray = s.split(":")
                s = parts[0]
                if parts.size() > 1 and parts[1].is_valid_int():
                        port = int(parts[1])
        _mp_join_lan(s, port)



func _mp_fill_list() -> void :
        if _mp_list == null or not is_instance_valid(_mp_list):
                return
        for ch: Node in _mp_list.get_children():
                ch.queue_free()
        if _mp_tab == 0:
                var rooms: Dictionary = net.lan.rooms
                if rooms.is_empty():
                        if Time.get_ticks_msec() - _mp_browse_ms < 6000:
                                MpKit.placeholder(_mp_list, "net_sync", "ИЩЕМ КОМНАТЫ В ВАШЕЙ СЕТИ...", "", true)
                        else:
                                var ios: String = "\nIPHONE: НАСТРОЙКИ · DRONEFLAMES · ЛОКАЛЬНАЯ СЕТЬ" if OS.get_name() == "iOS" else ""
                                MpKit.placeholder(_mp_list, "net_warn", "КОМНАТ НЕ ВИДНО", "ВЫ С ХОСТОМ В ОДНОЙ WI-FI?" + ios, false, 96.0)
                        return
                for ip: String in rooms:
                        var r: Dictionary = rooms[ip]
                        var same: bool = String(r.get("v", "")) == NetConfig.version()
                        var port: int = int(r.get("port", NetConfig.LAN_PORT))
                        MpKit.room_row(_mp_list, String(r.get("name", "")), "" if same else "ДРУГАЯ ВЕРСИЯ ИГРЫ", int(r.get("n", 1)), NetConfig.MAX_PLAYERS, same, 
                                func() -> void :
                                        if same:
                                                _mp_join_lan(ip, port)
                                        else:
                                                show_mp("У хоста другая версия. Обновите игру"))
                return
        if not _mp_online_ok():
                return
        var b: RoomBrowser = net.browser
        match b.state:
                RoomBrowser.STATE_LOADING, RoomBrowser.STATE_OFF:
                        MpKit.placeholder(_mp_list, "net_sync", "ЗАГРУЖАЕМ СПИСОК...", "", true)
                        return
                RoomBrowser.STATE_FAIL:
                        var p: PanelContainer = MpKit.placeholder(_mp_list, "net_signal_lost", "СЕРВЕР НЕДОСТУПЕН", 
                                b.fail_why if b.fail_why != "" else "ПРОВЕРЬТЕ ИНТЕРНЕТ", false, 120.0)
                        var again: Button = UiKit.big("ПОВТОРИТЬ", "stone", "", 44.0, 12)
                        again.custom_minimum_size.x = 140
                        again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
                        again.pressed.connect( func() -> void : b.refresh())
                        (p.get_child(0) as VBoxContainer).add_child(again)
                        return
        var list: Array = b.rooms.duplicate()
        list.sort_custom( func(x: Dictionary, y: Dictionary) -> bool:
                var vx: bool = String(x.get("v", "")) == NetConfig.version()
                var vy: bool = String(y.get("v", "")) == NetConfig.version()
                if vx != vy:
                        return vx
                return int(x.get("n", 0)) > int(y.get("n", 0)))
        if list.is_empty():
                MpKit.placeholder(_mp_list, "net_public", "ОТКРЫТЫХ КОМНАТ НЕТ", "СОЗДАЙТЕ СВОЮ ИЛИ ВОЙДИТЕ ПО КОДУ", false, 96.0)
                return
        for r2: Dictionary in list:
                var code: String = String(r2.get("code", ""))
                var ok: bool = String(r2.get("v", "")) == NetConfig.version()
                MpKit.room_row(_mp_list, String(r2.get("name", "")), ("КОД %s-%s" % [code.left(3), code.substr(3)]) if ok else "ДРУГАЯ ВЕРСИЯ ИГРЫ", 
                        int(r2.get("n", 1)), int(r2.get("max", NetConfig.MAX_PLAYERS)), ok, func() -> void :
                                if ok:
                                        _mp_join_code(code)
                                else:
                                        show_mp("У хоста другая версия. Обновите игру"))



func show_mp_create(msg: String = "") -> void :
        if _mp_gate():
                return
        if RtcLink.relay_only():
                _mp_pub = true
        var vb: VBoxContainer = _screen("Новая комната", 0.45, current != "mp_create")
        current = "mp_create"
        _sheet = true
        if RtcLink.relay_only():
                MpKit.placeholder(vb, "net_public", "ОТКРЫТАЯ КОМНАТА", "ПОЯВИТСЯ В СПИСКЕ · ВОЙТИ МОЖНО И ПО КОДУ", false, 70.0)
        else:
                _label(vb, "КТО СМОЖЕТ ВОЙТИ?", 11, UiKit.GOLD)
                MpKit.choice_card(vb, "net_public", "ПУБЛИЧНАЯ", "ВИДНА ВСЕМ В СПИСКЕ КОМНАТ", _mp_pub, func() -> void :
                        _mp_pub = true
                        show_mp_create())
                MpKit.choice_card(vb, "net_lock", "ТОЛЬКО ПО КОДУ", "ВОЙДУТ ТЕ, КОМУ ВЫ ДАДИТЕ КОД", not _mp_pub, func() -> void :
                        _mp_pub = false
                        show_mp_create())
                _label(vb, "ТИП МОЖНО СМЕНИТЬ И В КОМНАТЕ", 10, UiKit.MUTED)
        if msg != "":
                MpKit.status_bar(vb, msg)
        var br: HBoxContainer = _bottom_row()
        var back: Button = _button(br, "НАЗАД", "stone", "")
        back.custom_minimum_size.x = 111
        back.pressed.connect( func() -> void :
                _mp_tab = 1
                show_mp())
        var mk: Button = _ibutton(br, "СОЗДАТЬ", "green", "", "net_globe", 48.0)
        mk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        mk.pressed.connect( func() -> void :
                mk.disabled = true
                mk.text = "СОЗДАЁМ..."
                net.browser.stop()
                var w: String = net.host_online(_mp_pub)
                if w != "":
                        show_mp_create(w)
                else:
                        show_lobby())


func _mp_join_lan(ip: String, port: int) -> void :
        if ip.strip_edges() == "":
                show_mp("Комната не найдена")
                return
        var w: String = net.join_lan(ip, port)
        if w != "":
                show_mp(w)
        else:
                show_lobby()


func _mp_rooms_changed() -> void :
        if current == "mp":
                _mp_fill_list.call_deferred()


func _mp_lobby_changed() -> void :
        if net == null or net.in_match:
                return
        if not net.rtc.ranked.is_empty() and net.active():
                show_ranked_lobby.call_deferred()
                return
        if current == "ranked_lobby" and not net.active():
                show_ranked.call_deferred("", net.status_text, "alarm")
                return
        if current == "lobby" or current == "lobby_style":
                if not net.active():
                        _lobby_chat_draft = ""
                        show_mp.call_deferred(net.status_text)
                elif current == "lobby":
                        show_lobby.call_deferred()
        elif current == "mp" and (net.reconnecting or ( not net.active() and net.status_text != "")):
                show_mp.call_deferred("" if net.reconnecting else net.status_text)
        elif current == "mp_create" and not net.active() and net.status_text != "":
                show_mp_create.call_deferred(net.status_text)
        elif current == "mp_create" and net.active() and net.room_code != "":
                show_lobby.call_deferred()



const LOBBY_CHAT_QUICK: Array[String] = [
        "Сыграем впятером?", "Давайте большую карту", "Готов к старту", "Подождите минуту"
]
var _lobby_chat_button: Button
var _lobby_chat_overlay: Control
var _lobby_chat_log: RichTextLabel
var _lobby_chat_draft: String = ""
var _lobby_chat_transport: int = 0
var _lobby_chat_unread: int = 0


func _update_lobby_chat_button() -> void:
        if not is_instance_valid(_lobby_chat_button) or not is_instance_valid(_panel):
                return
        var rect: Rect2 = _panel.get_global_rect()
        var button_size: Vector2 = _lobby_chat_button.get_combined_minimum_size()
        var right: float = rect.end.x + 12.0
        var outside: bool = right + button_size.x <= root.size.x - 8.0
        var x: float = right if outside else rect.end.x - button_size.x - 10.0
        _lobby_chat_button.global_position = Vector2(x, maxf(_sm.x + 8.0, rect.position.y + (48.0 if outside else 8.0)))


func _update_lobby_chat_label() -> void:
        if is_instance_valid(_lobby_chat_button):
                _lobby_chat_button.text = Loc.t("ЧАТ") if _lobby_chat_unread == 0 else "%s · %d" % [Loc.t("ЧАТ"), _lobby_chat_unread]


func _fill_lobby_chat() -> void:
        _lobby_chat_log.clear()
        for message: Dictionary in net.lobby_chat:
                _lobby_chat_log.add_text("%s · %s\n" % [message["name"], message["text"]])


func _refresh_lobby_chat() -> void:
        if is_instance_valid(_lobby_chat_overlay) and is_instance_valid(_lobby_chat_log):
                _fill_lobby_chat()
        else:
                _lobby_chat_unread = mini(NetSession.LOBBY_CHAT_HISTORY, _lobby_chat_unread + 1)
                _update_lobby_chat_label()


func _add_lobby_chat_button() -> void:
        var transport: int = net.multiplayer.multiplayer_peer.get_instance_id()
        if _lobby_chat_transport != transport:
                _lobby_chat_transport = transport
                _lobby_chat_draft = ""
                _lobby_chat_unread = 0
        _lobby_chat_button = UiKit.big(Loc.t("ЧАТ"), "blue", "", 38.0, 12)
        _lobby_chat_button.tooltip_text = Loc.t("Открыть чат комнаты")
        screen.add_child(_lobby_chat_button)
        _lobby_chat_button.pressed.connect(_open_lobby_chat)
        _update_lobby_chat_label()
        _update_lobby_chat_button()
        if not net.lobby_chat_received.is_connected(_refresh_lobby_chat):
                net.lobby_chat_received.connect(_refresh_lobby_chat)


func _close_lobby_chat() -> void:
        if is_instance_valid(_lobby_chat_overlay):
                _lobby_chat_overlay.queue_free()
        _lobby_chat_overlay = null
        _lobby_chat_log = null


func _open_lobby_chat(focus_input: bool = true) -> void:
        if current != "lobby" or is_instance_valid(_lobby_chat_overlay):
                return
        _lobby_chat_unread = 0
        _update_lobby_chat_label()
        var overlay := ColorRect.new()
        overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        overlay.color = Color(0.02, 0.04, 0.09, 0.78)
        screen.add_child(overlay)
        _lobby_chat_overlay = overlay
        var center := CenterContainer.new()
        center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        overlay.add_child(center)
        var panel := PanelContainer.new()
        panel.custom_minimum_size.x = minf(580.0, root.size.x - 20.0)
        panel.add_theme_stylebox_override("panel", UiKit.sb("wb_window", 16, 14))
        center.add_child(panel)
        var content := VBoxContainer.new()
        content.add_theme_constant_override("separation", 8)
        panel.add_child(content)
        var header := HBoxContainer.new()
        content.add_child(header)
        var title: Label = UiKit.title(Loc.t("ЧАТ КОМНАТЫ"), 18)
        title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        header.add_child(title)
        var close_button: Button = UiKit.close_btn(36.0)
        close_button.tooltip_text = Loc.t("Закрыть чат")
        header.add_child(close_button)
        close_button.pressed.connect(_close_lobby_chat)

        _lobby_chat_log = RichTextLabel.new()
        _lobby_chat_log.custom_minimum_size.y = clampf(root.size.y * 0.40, 85.0, 320.0)
        _lobby_chat_log.add_theme_stylebox_override("normal", UiKit.sb("wb_panel_dark", 8, 6))
        _lobby_chat_log.scroll_following = true
        _lobby_chat_log.selection_enabled = true
        content.add_child(_lobby_chat_log)
        _fill_lobby_chat()

        var quick := HFlowContainer.new()
        content.add_child(quick)
        var row := HBoxContainer.new()
        content.add_child(row)
        var input := LineEdit.new()
        input.placeholder_text = Loc.t("Сообщение…")
        input.max_length = NetSession.LOBBY_CHAT_LENGTH
        input.text = _lobby_chat_draft
        input.editable = net.local_slot >= 0
        input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(input)
        var send: Button = UiKit.big(Loc.t("ОТПРАВИТЬ"), "green", "", 40.0, 11)
        send.disabled = not input.editable
        row.add_child(send)
        input.text_changed.connect(func(value: String) -> void: _lobby_chat_draft = value)
        var submit: Callable = func() -> void:
                if net.send_lobby_chat(input.text):
                        input.clear()
                        _lobby_chat_draft = ""
        input.text_submitted.connect(func(_text: String) -> void: submit.call())
        send.pressed.connect(submit)
        for phrase: String in LOBBY_CHAT_QUICK:
                var quick_button: Button = UiKit.big(Loc.t(phrase), "stone", "", 30.0, 10)
                quick_button.disabled = not input.editable
                quick.add_child(quick_button)
                quick_button.pressed.connect(func() -> void: net.send_lobby_chat(Loc.t(phrase)))
        if focus_input and input.editable and not OS.has_feature("mobile"):
                input.grab_focus()


func show_lobby(msg: String = "") -> void :
        if _mp_gate():
                return
        if not net.active():
                show_mp(msg if msg != "" else net.status_text)
                return
        var reopen_chat: bool = current == "lobby" and is_instance_valid(_lobby_chat_overlay)
        var vb: VBoxContainer = _screen("Комната", 0.45, current != "lobby")
        current = "lobby"
        _label(vb, "МОДЫ ВРЕМЕННО ОТКЛЮЧЕНЫ В СЕТЕВОЙ ИГРЕ", 10, UiKit.MUTED)
        var online: bool = net.mode == NetSession.Mode.ONLINE
        if online:
                if net.is_host:
                        MpKit.tabs(vb, [["net_lock", "ПО КОДУ"], ["net_public", "ПУБЛИЧНАЯ"]], 1 if net.room_is_pub() else 0, func(i: int) -> void :
                                if (i == 1) != net.room_is_pub():
                                        net.set_room_pub(i == 1))
                else:
                        var tr: = HBoxContainer.new()
                        tr.add_theme_constant_override("separation", 6)
                        tr.alignment = BoxContainer.ALIGNMENT_CENTER
                        vb.add_child(tr)
                        tr.add_child(MpKit.icon("net_public" if net.room_is_pub() else "net_lock"))
                        tr.add_child(UiKit.lbl("ПУБЛИЧНАЯ КОМНАТА" if net.room_is_pub() else "КОМНАТА ПО КОДУ", 11, UiKit.MUTED, 2, 2))
                if net.room_code != "":
                        var code: String = net.room_code
                        MpKit.code_block(vb, code, func() -> void :
                                DisplayServer.clipboard_set(code)
                                UiKit.snd("ui_select"))
                        _label(vb, "КОМНАТА ЕСТЬ В СПИСКЕ ОТКРЫТЫХ" if net.room_is_pub() else "ОТПРАВЬТЕ КОД ДРУЗЬЯМ", 10, UiKit.MUTED)
                else:
                        MpKit.placeholder(vb, "net_sync", "СОЗДАЁМ КОМНАТУ...", "", true)
        else:
                var lr: = HBoxContainer.new()
                lr.add_theme_constant_override("separation", 6)
                lr.alignment = BoxContainer.ALIGNMENT_CENTER
                vb.add_child(lr)
                lr.add_child(MpKit.icon("net_lan"))
                lr.add_child(UiKit.lbl("КОМНАТА В ВАШЕЙ WI-FI / СЕТИ", 12, UiKit.GOLD, 2, 2))
                if net.is_host:
                        var lan_ips: Array[String] = NetSession.get_lan_ips()
                        var my_ip: String = lan_ips[0] if not lan_ips.is_empty() else "127.0.0.1"
                        MpKit.code_block(vb, my_ip, func() -> void :
                                DisplayServer.clipboard_set(my_ip)
                                UiKit.snd("ui_select")
                                _mp_toast("IP скопирован в буфер обмена!"))
                        _label(vb, "ОТПРАВЬТЕ IP ДРУЗЬЯМ ИЛИ ОНИ НАЙДУТ СЕРВЕР В СПИСКЕ", 10, UiKit.MUTED)
                else:
                        _label(vb, "ДРУЗЬЯ В ЭТОЙ СЕТИ НАЙДУТ ЕЁ САМИ", 10, UiKit.MUTED)
        if online and net.room_code != "":
                _social_button(vb, "Пригласить друзей", func() -> void: _show_social("invite", show_lobby))
        MpKit.section(vb, "ИГРОКИ %d/%d" % [net.slots.size(), NetConfig.MAX_PLAYERS])
        var seats: = VBoxContainer.new()
        seats.add_theme_constant_override("separation", 4)
        vb.add_child(seats)
        for i in NetConfig.MAX_PLAYERS:
                if i < net.slots.size():
                        var sl: Dictionary = net.slots[i]
                        var row := HBoxContainer.new()
                        seats.add_child(row)
                        var cosmetics: Dictionary = (sl.get("cos", {}) as Dictionary).duplicate()
                        cosmetics.erase("avatar_b64")
                        if online and _social.state.get("room", "") == net.room_code:
                                var roster: Dictionary = _social.state.get("roster", {})
                                var profile: Dictionary = roster.get(String(sl.get("name", "")), {})
                                cosmetics = (profile.get("cosmetics", cosmetics) as Dictionary).duplicate()
                                cosmetics["avatar_b64"] = profile.get("avatar", "")
                        var pl_row: PanelContainer = MpKit.slot_row(row, i, String(sl.get("name", "?")), i == 0, i == net.local_slot, String(ArchStyle.NAMES[net.slot_arch(i)]), false, cosmetics, NetSession.clean_flag(sl.get("flag", "")))
                        pl_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                        var pl_name: String = String(sl.get("name", ""))
                        if pl_name != "":
                                pl_row.mouse_filter = Control.MOUSE_FILTER_STOP
                                pl_row.gui_input.connect(func(ev: InputEvent) -> void:
                                        if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
                                                UiKit.snd("ui_click")
                                                _inspect_player(pl_name, sl.get("cos", {}) if sl.get("cos") is Dictionary else {}, func() -> void: show_lobby())
                                )
                        if net.is_host and i != net.local_slot:
                                var peer_id: int = int(sl["peer"])
                                var remove := Button.new()
                                remove.text = Loc.t("Исключить")
                                remove.tooltip_text = pl_name
                                row.add_child(remove)
                                remove.pressed.connect(func() -> void:
                                        var transport: MultiplayerPeer = net.multiplayer.multiplayer_peer
                                        var confirm := ConfirmationDialog.new()
                                        confirm.dialog_text = Loc.f("Исключить игрока {name} из комнаты?", {"name": pl_name})
                                        add_child(confirm)
                                        confirm.confirmed.connect(func() -> void:
                                                if current == "lobby" and net.multiplayer.multiplayer_peer == transport and net.slots.has(sl):
                                                        net.kick_lobby_player(peer_id)
                                                confirm.queue_free())
                                        confirm.canceled.connect(confirm.queue_free)
                                        confirm.popup_centered())

                else:
                        MpKit.slot_row(seats, i, "", false, false, "", i == net.slots.size())
        if net.local_slot >= 0:
                MpKit.style_row(vb, net.slot_arch(net.local_slot), func() -> void : show_lobby_style())
        var st: String = msg
        if st == "":
                if net.is_host:
                        st = "НУЖЕН ЕЩЁ ХОТЯ БЫ 1 ИГРОК" if net.slots.size() < 2 else "ДАЛЕЕ — НАСТРОЙКИ КАРТЫ И СТАРТ"
                else:
                        st = "ЖДЁМ ХОСТА · ОБЛИК МОЖНО СМЕНИТЬ" if not net.slots.is_empty() else "ПОДКЛЮЧАЕМСЯ..."
        var sr: = HBoxContainer.new()
        sr.add_theme_constant_override("separation", 6)
        sr.alignment = BoxContainer.ALIGNMENT_CENTER
        vb.add_child(sr)
        if not net.is_host:
                var si: TextureRect = MpKit.icon("net_sync")
                sr.add_child(si)
                MpKit.spin(si)
        sr.add_child(UiKit.lbl(st, 10, UiKit.MUTED if msg == "" else UiKit.TITLE, 1, 1))
        var br: HBoxContainer = _bottom_row()

        var lv: Button = _button(br, "ПОКИНУТЬ", "stone", "")
        var armed: Array = [false]
        lv.pressed.connect( func() -> void :
                if net.is_host and net.slots.size() > 1 and not armed[0]:
                        armed[0] = true
                        lv.text = "ЗАКРЫТЬ?"
                        _paint_big(lv, "red")
                        get_tree().create_timer(3.0).timeout.connect( func() -> void :
                                if is_instance_valid(lv):
                                        armed[0] = false
                                        lv.text = "ПОКИНУТЬ"
                                        _paint_big(lv, "stone"))
                        return
                _lobby_chat_draft = ""
                net.leave()
                show_mp())
        if net.is_host:
                lv.custom_minimum_size.x = 111
                var enough: bool = net.slots.size() >= 2
                var go: Button = _ibutton(br, "ДАЛЕЕ", "green" if enough else "stone", "", "net_players", 48.0)
                go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                if not enough:
                        go.modulate.a = 0.6
                        go.add_theme_color_override("icon_normal_color", Color(1, 1, 1, 0.45))
                go.pressed.connect( func() -> void :
                        if net.slots.size() < 2:
                                show_lobby("НУЖЕН ЕЩЁ ХОТЯ БЫ 1 ИГРОК")
                                UiKit.snd("ui_error")
                                return
                        request.emit("setup"))
        else:
                lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL

        _add_lobby_chat_button()
        if reopen_chat:
                _open_lobby_chat(false)



static func _win_hint(no_limit: bool) -> String:
        if no_limit:
                return "Без лимита времени побеждает тот, кто первым наберёт цель"
        var t: String = String(["Очки = экономика + война. Побеждает тот, кто первым наберёт цель", 
                "Очки = экономика + война. Побеждает тот, у кого больше очков к концу времени", 
                "Побеждает тот, кто возьмёт столицы всех соперников"][clampi(GameConfig.victory, 0, 2)])
        if GameConfig.victory != 1 and GameConfig.match_limit() > 0.0:
                t += ". Через %d мин — тот, у кого больше очков" % roundi(GameConfig.match_limit() / 60.0)
        return t



func _paint_big(b: Button, colour: String) -> void :
        for st: String in ["normal", "hover"]:
                b.add_theme_stylebox_override(st, UiKit.sb("wb_btn_" + colour, 12, 4, -1))
        for st2: String in ["pressed", "hover_pressed"]:
                b.add_theme_stylebox_override(st2, UiKit.sb("wb_btn_" + colour + "_p", 12, 4, 1))



func show_lobby_style() -> void :
        if not net.active():
                show_mp(net.status_text)
                return
        var vb: VBoxContainer = _screen("Облик страны", 0.45, current != "lobby_style")
        current = "lobby_style"
        _label(vb, "ТАК БУДУТ ВЫГЛЯДЕТЬ ВАШИ ГОРОДА", 10, UiKit.MUTED)
        GameConfig.arch_i = net.slot_arch(net.local_slot) if net.local_slot >= 0 else GameConfig.arch_i
        _style_picker(vb, func(k: int) -> void :
                net.set_arch(k)
                get_tree().create_timer(0.2).timeout.connect( func() -> void :
                        if current == "lobby_style":
                                show_lobby()))
        var back: Button = _button(_bottom_row(), "НАЗАД", "stone", "")
        back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        back.pressed.connect( func() -> void : show_lobby())



func _mp_toast(t: String) -> void :
        if _inner == null or not is_instance_valid(_inner):
                return
        var bar: PanelContainer = MpKit.status_bar(_inner, t, "ok")
        get_tree().create_timer(1.6).timeout.connect( func() -> void :
                if is_instance_valid(bar):
                        bar.queue_free())



func _leave_button(vb: VBoxContainer) -> void :
        var b: Button = _button(vb, "ПОКИНУТЬ ПАРТИЮ", "red", "")
        var armed: Array = [false]
        b.pressed.connect( func() -> void :
                if armed[0]:
                        request.emit("main_menu")
                        return
                armed[0] = true
                b.text = ("ВЫЙТИ? ХОСТОМ СТАНЕТ ДРУГОЙ ИГРОК" if net.can_hand_over() else "ЗАКОНЧИТЬ ДЛЯ ВСЕХ? ЕЩЁ ТАП") if net.is_host else "ВЫЙТИ? СТРАНУ ВОЗЬМЁТ ИИ"
                get_tree().create_timer(3.0).timeout.connect( func() -> void :
                        if is_instance_valid(b):
                                armed[0] = false
                                b.text = "ПОКИНУТЬ ПАРТИЮ"))


func show_settings(from_pause: bool) -> void :
        _from_pause = from_pause
        var vb: VBoxContainer = _screen("Настройки", 0.45)
        current = "settings"


        _nav_row(vb, LangPicker.row_title(), LangPicker.row_hint(), func() -> void : LangPicker.open_from(self))
        _nav_row(vb, "УПРАВЛЕНИЕ", "КЛАВИАТУРА И МЫШЬ", show_controls.bind(from_pause))
        _nav_row(vb, "ЗВУК", _sound_hint(), show_settings_sub.bind("audio"))
        _nav_row(vb, "ГРАФИКА", Loc.t("ЭФФЕКТЫ: %s") % Loc.t(String(["НИЗКО", "НОРМА", "ВЫСОКО"][clampi(GameConfig.fx_level, 0, 2)])), show_settings_sub.bind("gfx"))
        _selector(vb, "ПОДСКАЗКИ", ["ВКЛ", "ВЫКЛ"], func() -> int: return 0 if GameConfig.hints else 1, func(i: int) -> void : GameConfig.hints = i == 0, VW_SHORT)
        _selector(vb, "ПЛАН РАЗВИТИЯ", ["ВКЛ", "ВЫКЛ"], func() -> int: return 1 if Hud.plan_closed else 0, func(i: int) -> void : Hud.plan_closed = i == 1, VW_SHORT)
        _selector(vb, "ПОДТВЕРЖДЕНИЕ", ["ВКЛ", "ВЫКЛ"], func() -> int: return 0 if GameConfig.confirm_actions else 1, func(i: int) -> void : GameConfig.confirm_actions = i == 0, VW_SHORT)
        if net == null or not net.in_match:
                _selector(vb, "ТУМАН ВОЙНЫ", ["ВКЛ", "ВЫКЛ"], func() -> int: return 0 if GameConfig.fog else 1, func(i: int) -> void :
                        GameConfig.fog = i == 0
                        if gw != null and gw.vision != null:
                                gw.vision.set_enabled(GameConfig.fog), VW_SHORT)
        _selector(vb, "УВЕДОМЛЕНИЯ", ["ВСЕ", "ВАЖНЫЕ", "СКРЫТЬ"], func() -> int: return GameConfig.notif_mode, func(i: int) -> void :
                GameConfig.notif_mode = i
                get_tree().call_group("notif_lane", "refilter"), VW_SHORT)
        _selector(vb, "НОВОСТИ", ["ВКЛ", "ВЫКЛ"], func() -> int: return 0 if Hud.news_on else 1, func(i: int) -> void : Hud.news_on = i == 0, VW_SHORT)
        _nav_row(vb, "ЗАСТАВКА", Loc.t("ПРИ ЗАПУСКЕ: ВКЛ") if GameConfig.opening else Loc.t("ПРИ ЗАПУСКЕ: ВЫКЛ"), show_settings_sub.bind("opening"))
        _sep(vb, 6)
        var tg_btn: Button = UiKit.big("💬 ТЕЛЕГРАМ: ПОРТЫ И МОДЫ", "blue", "", 38.0, 11)
        tg_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        tg_btn.pressed.connect(func() -> void:
                UiKit.snd("ui_click")
                OS.shell_open("https://t.me/droneflamesmod")
        )
        tg_btn.tooltip_text = "Неофициальное сообщество ПК-портов и модов игры (не разработчики игры)"
        vb.add_child(tg_btn)
        var tg_lbl: Label = UiKit.lbl("t.me/droneflamesmod · Сообщество портов и модов (не канал игры)", 9, UiKit.MUTED, 1)
        tg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        vb.add_child(tg_lbl)
        var back: Button = _button(_bottom_row(), "НАЗАД", "stone", "pause" if from_pause else "main")
        back.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func show_controls(from_pause: bool) -> void :
        _from_pause = from_pause
        _bind_waiting_action = ""
        var vb: VBoxContainer = _screen("Управление", 0.55)
        current = "controls"
        _label(vb, Loc.t("Нажмите кнопку назначения, затем нужную клавишу или кнопку мыши.\nEsc — отмена назначения."), 10, UiKit.MUTED)
        _sep(vb, 4)

        for act: String in KeybindManager.ACTIONS:
                var row: = HBoxContainer.new()
                row.add_theme_constant_override("separation", 8)
                row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                vb.add_child(row)

                var title: String = String(KeybindManager.ACTION_TITLES.get(act, act))
                var lb: Label = UiKit.lbl(Loc.t(title), 11, UiKit.TEXT, 2)
                lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                row.add_child(lb)

                var btn: Button = Button.new()
                btn.custom_minimum_size = Vector2(170, 32)
                btn.add_theme_stylebox_override("normal", UiKit.sb("wb_btn_stone", 4, 2))
                btn.add_theme_stylebox_override("hover", UiKit.sb("wb_btn_stone", 4, 2))
                btn.add_theme_stylebox_override("pressed", UiKit.sb("wb_btn_blue_p" if UiKit.has("wb_btn_blue_p") else "wb_btn_stone", 4, 2))
                btn.text = KeybindManager.get_display_name(act)
                btn.add_theme_font_size_override("font_size", 10)
                btn.pressed.connect(func() -> void:
                        _bind_waiting_action = act
                        btn.text = Loc.t("[ Нажмите клавишу... ]")
                        btn.add_theme_color_override("font_color", UiKit.GOLD)
                        UiKit.snd("ui_click")
                )
                row.add_child(btn)

        _sep(vb, 6)
        _label(vb, Loc.t("Изменения сохраняются автоматически."), 9, UiKit.MUTED)
        _sep(vb, 4)

        var reset_btn: Button = UiKit.big("ВОССТАНОВИТЬ ПО УМОЛЧАНИЮ", "blue", "", 42.0, 12)
        reset_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        reset_btn.pressed.connect(func() -> void:
                KeybindManager.reset_to_defaults()
                UiKit.snd("ui_click")
                show_controls(from_pause)
        )
        vb.add_child(reset_btn)

        var back_btn: Button = _button(_bottom_row(), "НАЗАД", "stone", "settings_pause" if from_pause else "settings_main")
        back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        back_btn.pressed.connect(func() -> void:
                _bind_waiting_action = ""
                show_settings(from_pause)
        )


func show_update_dialog(tag: String = "", changelog: String = "", dl_url: String = "", asset_name: String = "") -> void:
        if _up_dialog != null and is_instance_valid(_up_dialog):
                return
        
        var up: Node = get_node_or_null("/root/Updater")
        if tag == "" and up != null:
                tag = String(up.get("latest_tag"))
                changelog = String(up.get("latest_changelog"))
                dl_url = String(up.get("latest_url"))
                asset_name = String(up.get("latest_asset_name"))
        elif changelog == "" and up != null:
                changelog = String(up.get("latest_changelog"))
        if tag == "":
                tag = GitHubUpdater.get_installed_version() if ResourceLoader.exists("res://net/github_updater.gd") else "0.33.4.9"
        var file_label: String = "(%s)" % asset_name.get_extension().to_upper() if not asset_name.is_empty() else ""
        var gh_url: String = "https://github.com/makkaX2/DroneFlames-PC-Port/releases/tag/v" + tag
        if dl_url.is_empty():
                dl_url = gh_url

        var bg: = ColorRect.new()
        bg.set_anchors_preset(Control.PRESET_FULL_RECT)
        bg.color = Color(0.02, 0.04, 0.1, 0.72)
        bg.mouse_filter = Control.MOUSE_FILTER_STOP
        root.add_child(bg)
        _up_dialog = bg

        var cc: = CenterContainer.new()
        cc.set_anchors_preset(Control.PRESET_FULL_RECT)
        cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
        bg.add_child(cc)

        var panel: = PanelContainer.new()
        panel.add_theme_stylebox_override("panel", UiKit.sb("wb_window", 16, 14))
        var win_w: float = minf(490.0, root.size.x - 30.0)
        panel.custom_minimum_size = Vector2(win_w, 0)
        cc.add_child(panel)

        var vb: = VBoxContainer.new()
        vb.add_theme_constant_override("separation", 10)
        panel.add_child(vb)

        var hr: = HBoxContainer.new()
        hr.add_theme_constant_override("separation", 8)
        vb.add_child(hr)

        var title_lbl: Label = UiKit.title(Loc.t("ОБНОВЛЕНИЕ ДОСТУПНО"), 18, UiKit.GOLD)
        title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        hr.add_child(title_lbl)

        var close_btn: Button = UiKit.close_btn(32.0)
        close_btn.pressed.connect(func() -> void:
                UiKit.snd("ui_close")
                if _up_dialog != null and is_instance_valid(_up_dialog):
                        _up_dialog.queue_free()
                        _up_dialog = null
        )
        hr.add_child(close_btn)

        var vr: = HBoxContainer.new()
        vr.add_theme_constant_override("separation", 8)
        vb.add_child(vr)

        var badge: = PanelContainer.new()
        badge.add_theme_stylebox_override("panel", UiKit.sb("wb_btn_gold", 8, 3, -1))
        var bl: Label = UiKit.lbl("v" + tag + " ПК-ПОРТ", 11, UiKit.TEXT, 3, 2)
        badge.add_child(bl)
        vr.add_child(badge)

        var cur_l: Label = UiKit.lbl("Текущая: " + VERSION.split(" ")[0], 10, UiKit.MUTED, 1)
        cur_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        vr.add_child(cur_l)

        var msg: Label = UiKit.lbl(Loc.t("Вышла новая версия ПК-порта DroneFlames!\nХотите загрузить и установить обновление прямо сейчас?"), 11, UiKit.TEXT, 2)
        msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        vb.add_child(msg)

        var cp: = PanelContainer.new()
        cp.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 10, 6))
        vb.add_child(cp)

        var cp_vb: = VBoxContainer.new()
        cp_vb.add_theme_constant_override("separation", 6)
        cp.add_child(cp_vb)

        var cl_title: Label = UiKit.lbl("В ЭТОМ ОБНОВЛЕНИИ:", 10, UiKit.GOLD, 2)
        cp_vb.add_child(cl_title)

        var notes: Array = []
        if changelog != "":
                var raw_lines: PackedStringArray = changelog.split("\n")
                var capturing_features: bool = false
                for rline: String in raw_lines:
                        var s: String = rline.strip_edges()
                        if s.contains("Особенности") or s.contains("обновления") or s.to_lower().contains("changelog") or s.to_lower().contains("what's new"):
                                capturing_features = true
                                continue
                        if capturing_features and (s.begins_with("###") or s.begins_with("##")):
                                break
                        if s.begins_with("- ") or s.begins_with("* ") or s.begins_with("• "):
                                if s.contains(".exe") or s.contains(".zip") or s.contains(".apk") or s.contains("t.me/"):
                                        continue
                                var clean: String = s.trim_prefix("- ").trim_prefix("* ").trim_prefix("• ").replace("**", "").replace("`", "").strip_edges()
                                if clean != "":
                                        notes.append("• " + clean)

                if notes.is_empty():
                        for rline: String in raw_lines:
                                var s: String = rline.strip_edges()
                                if s.begins_with("- ") or s.begins_with("* ") or s.begins_with("• "):
                                        if s.contains(".exe") or s.contains(".zip") or s.contains(".apk") or s.contains("t.me/"):
                                                continue
                                        var clean: String = s.trim_prefix("- ").trim_prefix("* ").trim_prefix("• ").replace("**", "").replace("`", "").strip_edges()
                                        if clean != "":
                                                notes.append("• " + clean)

        if notes.is_empty():
                notes = [
                        "• Система модов и визуальный менеджер модов (.dfmod)",
                        "• Оптимизация рендеринга территорий и кэширование тумана",
                        "• ПК-оптимизации: троттлинг в фоне (15 FPS) и многопоточность",
                        "• Все 118 предметов косметики и 19 новых титулов разблокированы",
                        "• Меню настройки управления: бинды клавиш и кнопок мыши",
                        "• Широкоформатный горизонтальный HUD 16:9 со стрелочками < и >",
                        "• Плавающие модальные окна по центру (Дипломатия, Экономика)"
                ]

        var scroll: = ScrollContainer.new()
        scroll.custom_minimum_size = Vector2(0, mini(140, notes.size() * 24 + 10))
        scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
        scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
        cp_vb.add_child(scroll)

        var cl_vb: = VBoxContainer.new()
        cl_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        cl_vb.add_theme_constant_override("separation", 4)
        scroll.add_child(cl_vb)

        for note: String in notes:
                var nl: Label = UiKit.lbl(Loc.t(note), 9, UiKit.TEXT, 1)
                nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
                cl_vb.add_child(nl)

        var linux: bool = OS.get_name() == "Linux"
        var download_title: String = "ОБНОВИТЬ В ТЕРМИНАЛЕ" if linux else "СКАЧАТЬ ОБНОВЛЕНИЕ " + file_label
        var dl_btn: Button = UiKit.big(download_title, "green", "", 44.0, 13)
        dl_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        dl_btn.pressed.connect(func() -> void:
                UiKit.snd("ui_click")
                if linux:
                        if up is GitHubUpdater and up.start_linux_update():
                                return
                        OS.shell_open(gh_url)
                        dl_btn.text = "ОТКРЫТА СТРАНИЦА УСТАНОВКИ"
                        return
                OS.shell_open(dl_url)
                dl_btn.text = "✓ СКАЧИВАНИЕ ФАЙЛА НАЧАТО В БРАУЗЕРЕ"
                dl_btn.disabled = true
        )
        vb.add_child(dl_btn)

        var br_btn: Button = UiKit.big("ОТКРЫТЬ СТРАНИЦУ НА GITHUB", "blue", "", 38.0, 11)
        br_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        br_btn.pressed.connect(func() -> void:
                UiKit.snd("ui_click")
                OS.shell_open(gh_url)
        )
        vb.add_child(br_btn)

        var later_btn: Button = UiKit.big("НАПОМНИТЬ ПОЗЖЕ", "stone", "", 38.0, 11)
        later_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        later_btn.pressed.connect(func() -> void:
                UiKit.snd("ui_close")
                if _up_dialog != null and is_instance_valid(_up_dialog):
                        _up_dialog.queue_free()
                        _up_dialog = null
        )
        vb.add_child(later_btn)


func _on_net_mods_required(required_mods: Array) -> void:
        _show_required_mods_dialog.call_deferred(required_mods)


func _show_required_mods_dialog(required_mods: Array) -> void:
        if _mp_mods_dialog != null and is_instance_valid(_mp_mods_dialog):
                _mp_mods_dialog.queue_free()
                _mp_mods_dialog = null

        var mm: Node = null
        if has_node("/root/ModManager"):
                mm = get_node("/root/ModManager")

        var missing_info: Array = []
        if mm != null and mm.has_method("check_missing_mp_mods"):
                missing_info = mm.check_missing_mp_mods(required_mods)
        else:
                missing_info = required_mods

        var bg := ColorRect.new()
        bg.set_anchors_preset(Control.PRESET_FULL_RECT)
        bg.color = Color(0.02, 0.04, 0.1, 0.78)
        bg.mouse_filter = Control.MOUSE_FILTER_STOP
        root.add_child(bg)
        _mp_mods_dialog = bg

        var cc := CenterContainer.new()
        cc.set_anchors_preset(Control.PRESET_FULL_RECT)
        cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
        bg.add_child(cc)

        var panel := PanelContainer.new()
        panel.add_theme_stylebox_override("panel", UiKit.sb("wb_window", 16, 14))
        var win_w: float = minf(490.0, root.size.x - 30.0)
        panel.custom_minimum_size = Vector2(win_w, 0)
        cc.add_child(panel)

        var vb := VBoxContainer.new()
        vb.add_theme_constant_override("separation", 10)
        panel.add_child(vb)

        var hr := HBoxContainer.new()
        hr.add_theme_constant_override("separation", 8)
        vb.add_child(hr)

        var title_lbl: Label = UiKit.title(Loc.t("ТРЕБУЮТСЯ МОДЫ ДЛЯ СЕТЕВОЙ ИГРЫ"), 18, UiKit.GOLD)
        title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        hr.add_child(title_lbl)

        var close_btn: Button = UiKit.close_btn(32.0)
        close_btn.pressed.connect(func() -> void:
                UiKit.snd("ui_close")
                if _mp_mods_dialog != null and is_instance_valid(_mp_mods_dialog):
                        _mp_mods_dialog.queue_free()
                        _mp_mods_dialog = null
                if net != null:
                        net.leave()
        )
        hr.add_child(close_btn)

        var sub_lbl: Label = UiKit.lbl(Loc.t("У хоста включены моды, изменяющие игровой мир. Без них подключение к серверу запрещено во избежание рассинхронизации:"), 10, UiKit.MUTED, 1)
        sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        vb.add_child(sub_lbl)

        # Список требуемых модов
        var list_panel: PanelContainer = PanelContainer.new()
        list_panel.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 10, 8))
        vb.add_child(list_panel)

        var sc := ScrollContainer.new()
        sc.custom_minimum_size = Vector2(0, mini(int(required_mods.size() * 52 + 10), 180))
        sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
        list_panel.add_child(sc)

        var mod_list_vb := VBoxContainer.new()
        mod_list_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        mod_list_vb.add_theme_constant_override("separation", 6)
        sc.add_child(mod_list_vb)

        for m_item in required_mods:
                if not (m_item is Dictionary):
                        continue
                var mid: String = String(m_item.get("id", ""))
                var mname: String = String(m_item.get("name", mid))
                var mver: String = String(m_item.get("version", "1.0.0"))

                var is_inst: bool = mm != null and mm.is_mod_installed(mid)
                var is_en: bool = mm != null and mm.is_mod_enabled(mid)
                var cur_v: String = String(mm.installed_mods.get(mid, {}).get("version", "")) if is_inst else ""

                var row := HBoxContainer.new()
                row.add_theme_constant_override("separation", 8)
                mod_list_vb.add_child(row)

                var info_v := VBoxContainer.new()
                info_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                row.add_child(info_v)

                var title_row := UiKit.lbl("%s (v%s)" % [mname, mver], 11, UiKit.TEXT, 1)
                info_v.add_child(title_row)

                var st_lbl: Label = null
                if is_en and (cur_v == "" or cur_v == mver):
                        st_lbl = UiKit.lbl("✓ Установлен и готов", 9, UiKit.GREEN)
                elif is_inst and (cur_v == "" or cur_v == mver):
                        st_lbl = UiKit.lbl("● Установлен (требуется включить)", 9, UiKit.GOLD)
                elif is_inst and cur_v != mver:
                        st_lbl = UiKit.lbl("⚠ Требуется обновление (у вас: v%s)" % cur_v, 9, UiKit.RED)
                else:
                        st_lbl = UiKit.lbl("↓ Не установлен (будет скачан)", 9, UiKit.RED)
                info_v.add_child(st_lbl)

        # Панель индикатора прогресса
        var pbar_vbox := VBoxContainer.new()
        pbar_vbox.add_theme_constant_override("separation", 4)
        vb.add_child(pbar_vbox)

        var status_text_lbl: Label = UiKit.lbl("Готово к установке пака модов", 10, UiKit.TEXT, 1)
        status_text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        pbar_vbox.add_child(status_text_lbl)

        var pbar: ProgressBar = ModsUI.create_styled_progress_bar()
        pbar.value = 0.0
        pbar.visible = true
        pbar_vbox.add_child(pbar)

        # Нижняя панель кнопок
        var btn_row := HBoxContainer.new()
        btn_row.add_theme_constant_override("separation", 8)
        vb.add_child(btn_row)

        var cancel_btn: Button = UiKit.big("ОТМЕНА", "stone", "", 36.0, 10)
        cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        cancel_btn.pressed.connect(func() -> void:
                UiKit.snd("ui_close")
                if _mp_mods_dialog != null and is_instance_valid(_mp_mods_dialog):
                        _mp_mods_dialog.queue_free()
                        _mp_mods_dialog = null
                if net != null:
                        net.leave()
        )
        btn_row.add_child(cancel_btn)

        var install_btn: Button = UiKit.big("СКАЧАТЬ И ВОЙТИ", "green", "", 36.0, 10)
        install_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        btn_row.add_child(install_btn)

        # Логика скачивания и входа
        install_btn.pressed.connect(func() -> void:
                install_btn.disabled = true
                cancel_btn.disabled = true
                install_btn.text = "УСТАНОВКА..."

                if mm == null:
                        status_text_lbl.text = "Ошибка: ModManager не найден"
                        status_text_lbl.modulate = UiKit.RED
                        install_btn.disabled = false
                        cancel_btn.disabled = false
                        return

                var to_process: Array = required_mods.duplicate()
                var total_count: int = to_process.size()
                var completed_count: int = 0

                for m in to_process:
                        if not (m is Dictionary):
                                continue
                        var mid: String = String(m.get("id", ""))
                        var mname: String = String(m.get("name", mid))
                        var mver: String = String(m.get("version", ""))

                        var is_installed: bool = mm.is_mod_installed(mid)
                        var cur_ver: String = String(mm.installed_mods.get(mid, {}).get("version", "")) if is_installed else ""

                        if is_installed and (cur_ver == "" or cur_ver == mver or mver == ""):
                                # Мод уже есть — просто активируем
                                status_text_lbl.text = "Активация «%s»..." % mname
                                mm.toggle_mod(mid, true)
                                completed_count += 1
                                pbar.value = clampf(float(completed_count) / float(maxi(1, total_count)) * 100.0, 0.0, 100.0)
                                await get_tree().process_frame
                        else:
                                # Нужно скачать или обновить
                                status_text_lbl.text = "Скачивание «%s»..." % mname
                                var dl_done: Array = [false]
                                var dl_err: Array = [""]

                                var on_prog = func(_id: String, rec: int, tot: int, pct: float) -> void:
                                        if _id == mid:
                                                var base_pct: float = float(completed_count) / float(maxi(1, total_count)) * 100.0
                                                var step_pct: float = (pct / 100.0) * (100.0 / float(maxi(1, total_count)))
                                                pbar.value = clampf(base_pct + step_pct, 0.0, 100.0)
                                                var rec_mb: float = float(rec) / (1024.0 * 1024.0)
                                                var tot_mb: float = float(tot) / (1024.0 * 1024.0)
                                                if tot > 0:
                                                        status_text_lbl.text = "Загрузка «%s»: %d%% (%.1f / %.1f МБ)" % [mname, int(pct), rec_mb, tot_mb]
                                                else:
                                                        status_text_lbl.text = "Загрузка «%s»: %d%%" % [mname, int(pct)]

                                var on_done = func(_id: String) -> void:
                                        if _id == mid:
                                                dl_done[0] = true

                                var on_failed = func(_id: String, err_msg: String) -> void:
                                        if _id == mid:
                                                dl_err[0] = err_msg
                                                dl_done[0] = true

                                if mm.has_signal("mod_download_progress"):
                                        mm.mod_download_progress.connect(on_prog)
                                if mm.has_signal("mod_download_completed"):
                                        mm.mod_download_completed.connect(on_done)
                                if mm.has_signal("mod_download_failed"):
                                        mm.mod_download_failed.connect(on_failed)

                                mm.download_and_install_mod(m)

                                # Ждём завершения скачивания с таймаутом
                                var wait_t: float = 0.0
                                while not dl_done[0] and wait_t < 60.0:
                                        await get_tree().create_timer(0.1).timeout
                                        wait_t += 0.1

                                if mm.has_signal("mod_download_progress") and mm.mod_download_progress.is_connected(on_prog):
                                        mm.mod_download_progress.disconnect(on_prog)
                                if mm.has_signal("mod_download_completed") and mm.mod_download_completed.is_connected(on_done):
                                        mm.mod_download_completed.disconnect(on_done)
                                if mm.has_signal("mod_download_failed") and mm.mod_download_failed.is_connected(on_failed):
                                        mm.mod_download_failed.disconnect(on_failed)

                                if dl_err[0] != "":
                                        status_text_lbl.text = "Ошибка при загрузке «%s»: %s" % [mname, dl_err[0]]
                                        status_text_lbl.modulate = UiKit.RED
                                        install_btn.disabled = false
                                        cancel_btn.disabled = false
                                        install_btn.text = "ПОВТОРИТЬ"
                                        return

                                mm.toggle_mod(mid, true)
                                completed_count += 1
                                pbar.value = clampf(float(completed_count) / float(maxi(1, total_count)) * 100.0, 0.0, 100.0)

                # Все моды установлены и активированы!
                status_text_lbl.text = "Все моды готовы! Входим на сервер..."
                status_text_lbl.modulate = UiKit.GREEN
                pbar.value = 100.0
                await get_tree().create_timer(0.4).timeout

                if _mp_mods_dialog != null and is_instance_valid(_mp_mods_dialog):
                        _mp_mods_dialog.queue_free()
                        _mp_mods_dialog = null

                if net != null and net.has_method("resend_hello_with_mods"):
                        net.resend_hello_with_mods()
        )


const PerfProbe: = preload("res://ui/perf_probe.gd")
var _dev_taps: int = 0



func show_local_workshop() -> void:
        var vb: VBoxContainer = _screen("Мастерская карт", 0.55, false)
        current = "local_workshop"
        load("res://ui/local_workshop_ui.gd").build(self, vb)


func _set_graphics_profile(i: int) -> void:
        GameConfig.performance_mode = clampi(i, 0, 4)
        if i == 4:
                return
        var economical: bool = i == 0 or i == 3
        GameConfig.fx_level = 0 if economical else (1 if i == 1 else 2)
        GameConfig.clouds = not economical
        GameConfig.ground_detail = not economical
        GameConfig.econ_fx = not economical
        GameConfig.day_grade = not economical

        match i:
                0:
                        GameConfig.chunk_culling = true
                        GameConfig.tree_batching = true
                        GameConfig.tree_sway_mode = 1
                        GameConfig.object_lod = 1
                        GameConfig.simple_cover = true
                        GameConfig.strat_lod_z = 2
                1:
                        GameConfig.chunk_culling = true
                        GameConfig.tree_batching = true
                        GameConfig.tree_sway_mode = 1
                        GameConfig.object_lod = 1
                        GameConfig.simple_cover = false
                        GameConfig.strat_lod_z = 1
                2:
                        GameConfig.chunk_culling = true
                        GameConfig.tree_batching = false
                        GameConfig.tree_sway_mode = 2
                        GameConfig.object_lod = 0
                        GameConfig.simple_cover = false
                        GameConfig.strat_lod_z = 0
                3:
                        GameConfig.chunk_culling = true
                        GameConfig.tree_batching = true
                        GameConfig.tree_sway_mode = 0
                        GameConfig.object_lod = 2
                        GameConfig.simple_cover = true
                        GameConfig.strat_lod_z = 3

        if gw != null and gw.objects != null and gw.camera != null:
                gw.objects.sway_enabled = GameConfig.tree_sway_mode != 0


func show_graphics_first() -> void:
        var vb: VBoxContainer = _screen("Выберите графику", 0.45)
        current = "graphics_first"
        _label(vb, "Настройку можно будет изменить в меню Настройки → Графика.", 11, UiKit.MUTED)
        var names: Array = ["ПРОИЗВОДИТЕЛЬНОСТЬ", "БАЛАНС", "КАЧЕСТВО", "МАКС. ПРОИЗВОДИТЕЛЬНОСТЬ"]
        for i in names.size():
                var button: Button = UiKit.big(names[i], "green" if i == 1 else "stone", "", 44.0, 11)
                vb.add_child(button)
                button.pressed.connect(func() -> void:
                        _set_graphics_profile(i)
                        GameConfig.graphics_chosen = true
                        Save.save_prefs()
                        show_main())


func show_settings_sub(kind: String) -> void :
        if kind == "mods":
                show_mods()
                return
        var vb: VBoxContainer = _screen("Графика" if kind == "gfx" else (Loc.t("Заставка") if kind == "opening" else Loc.t("Звук")), 0.45)
        current = "settings_" + kind
        _sheet = kind != "gfx"
        if kind == "gfx":
                _selector(vb, "ПРОФИЛЬ ГРАФИКИ", ["ПРОИЗВОДИТ.", "БАЛАНС", "КАЧЕСТВО", "МАКС. FPS", "СВОЙ"], func() -> int: return GameConfig.performance_mode, func(i: int) -> void:
                        _set_graphics_profile(i)
                        Save.save_prefs()
                        call_deferred("show_settings_sub", "gfx"), 110.0)
                _label(vb, "Готовые профили. Ниже можно настроить каждый параметр вручную.", 9, UiKit.MUTED)

                _selector(vb, "АВТО-FPS (АДАПТИВНО)", ["ВЫКЛ", "30 FPS", "45 FPS", "60 FPS"], func() -> int: return GameConfig.dynamic_fps_target, func(i: int) -> void:
                        GameConfig.dynamic_fps_target = i
                        Save.save_prefs()
                        call_deferred("show_settings_sub", "gfx"), VW_SHORT)
                _label(vb, "При просадках FPS ниже порога автоматически включает ступени оптимизации и возвращает графику обратно.", 9, UiKit.MUTED)

                _selector(vb, "ОТСЕЧЕНИЕ ЧАНКОВ", ["ВЫКЛ", "ВКЛ"], func() -> int: return 1 if GameConfig.chunk_culling else 0, func(i: int) -> void:
                        GameConfig.chunk_culling = i == 1
                        GameConfig.performance_mode = 4
                        Save.save_prefs()
                        call_deferred("show_settings_sub", "gfx"), VW_SHORT)
                _label(vb, "Не рендерит скрытые за экраном части карты, экономя вызовы GPU.", 9, UiKit.MUTED)

                _selector(vb, "БАТЧИНГ ДЕРЕВЬЕВ", ["ВЫКЛ", "ВКЛ"], func() -> int: return 1 if GameConfig.tree_batching else 0, func(i: int) -> void:
                        GameConfig.tree_batching = i == 1
                        GameConfig.performance_mode = 4
                        Save.save_prefs()
                        call_deferred("show_settings_sub", "gfx"), VW_SHORT)
                _label(vb, "Объединяет растительность одного атласа в единый вызов, снижая Draw Calls в 5-8 раз.", 9, UiKit.MUTED)

                _selector(vb, "ПОКАЧИВАНИЕ ДЕРЕВЬЕВ", ["ВЫКЛ", "ВБЛИЗИ", "ВСЕГДА"], func() -> int: return GameConfig.tree_sway_mode, func(i: int) -> void:
                        GameConfig.tree_sway_mode = i
                        GameConfig.performance_mode = 4
                        Save.save_prefs()
                        call_deferred("show_settings_sub", "gfx"), VW_SHORT)
                _label(vb, "Вблизи: не перерисовывает деревья при отдалении камеры.", 9, UiKit.MUTED)

                _selector(vb, "LOD РАСТИТЕЛЬНОСТИ", ["ВЫКЛ", "МЯГКИЙ", "АГРЕССИВНЫЙ"], func() -> int: return GameConfig.object_lod, func(i: int) -> void:
                        GameConfig.object_lod = i
                        GameConfig.performance_mode = 4
                        Save.save_prefs()
                        call_deferred("show_settings_sub", "gfx"), VW_SHORT)
                _label(vb, "Прореживает густые леса при общем обзоре континента.", 9, UiKit.MUTED)

                _selector(vb, "ПЕРЕХОД В СТРАТ. КАРТУ", ["СТАНДАРТ (0.17)", "БАЛАНС (0.28)", "РАННИЙ (0.40)", "МАКС (0.50)"], func() -> int: return GameConfig.strat_lod_z, func(i: int) -> void:
                        GameConfig.strat_lod_z = i
                        GameConfig.performance_mode = 4
                        Save.save_prefs()
                        call_deferred("show_settings_sub", "gfx"), 110.0)
                _label(vb, "Масштаб зума камеры, на котором включается быстрая упрощённая карта.", 9, UiKit.MUTED)

                _selector(vb, "ПЕРЕКРЫТИЕ ТЕХНИКИ", ["ТОЧНОЕ", "БЫСТРОЕ"], func() -> int: return 1 if GameConfig.simple_cover else 0, func(i: int) -> void:
                        GameConfig.simple_cover = i == 1
                        GameConfig.performance_mode = 4
                        Save.save_prefs()
                        call_deferred("show_settings_sub", "gfx"), VW_SHORT)
                _label(vb, "Быстрое: рисует технику целиком без нарезки полосками.", 9, UiKit.MUTED)
                if not GameConfig.android:
                        var resolutions: Array[Vector2i] = Save.available_display_resolutions()
                        var resolution_labels: Array[String] = Save.display_resolution_labels(resolutions)
                        _selector(vb, "РАЗРЕШЕНИЕ ИГРЫ", resolution_labels,
                                func() -> int: return Save.display_resolution_index(resolutions),
                                func(i: int) -> void:
                                        var selected: Vector2i = resolutions[clampi(i, 0, resolutions.size() - 1)]
                                        GameConfig.resolution_w = selected.x
                                        GameConfig.resolution_h = selected.y
                                        Save.apply_display_resolution()
                                        Save.apply_ui_scale()
                                        Save.save_prefs(), 108.0)
                        _label(vb, "В оконном режиме меньший размер снижает нагрузку; полный экран рендерится в нативном разрешении для чёткости.", 9, UiKit.MUTED)
                var uis: Array = ["АВТО"]
                for k347: Variant in GameConfig.UI_SCALES:
                        uis.append("%d%%" % roundi(float(k347) * 100.0))
                _selector(vb, "РАЗМЕР ИНТЕРФЕЙСА", uis, func() -> int: return 0 if GameConfig.ui_scale_auto else GameConfig.ui_scale_i + 1, func(i: int) -> void :
                        if i == 0:
                                if GameConfig.ui_scale_auto:
                                        return
                                GameConfig.ui_scale_auto = true
                        else:
                                var scale_i: int = i - 1
                                if not GameConfig.ui_scale_auto and scale_i == GameConfig.ui_scale_i:
                                        return
                                GameConfig.ui_scale_i = scale_i
                                GameConfig.ui_scale_auto = false
                        Save.apply_ui_scale()
                        Save.save_prefs(), VW_SHORT)
                _label(vb, "Авто: 150% на 4K, 200% на 5K+. Можно выбрать масштаб вручную.", 9, UiKit.MUTED)
                _selector(vb, "ДЕНЬ/НОЧЬ", ["ВКЛ", "ВЫКЛ"], func() -> int: return 0 if GameConfig.night else 1, func(i: int) -> void : GameConfig.night = i == 0, VW_SHORT)
                _selector(vb, "ЦВЕТ СУТОК", ["ВКЛ", "ВЫКЛ"], func() -> int: return 0 if GameConfig.day_grade else 1, func(i: int) -> void : GameConfig.day_grade = i == 0, VW_SHORT)
                _selector(vb, "ОБЛАКА", ["ВКЛ", "ВЫКЛ"], func() -> int: return 0 if GameConfig.clouds else 1, func(i: int) -> void : GameConfig.clouds = i == 0, VW_SHORT)
                _selector(vb, "ЭФФЕКТЫ", ["НИЗКО", "НОРМА", "ВЫСОКО"], func() -> int: return GameConfig.fx_level, func(i: int) -> void : GameConfig.fx_level = i, VW_SHORT)
                _selector(vb, "ДЕТАЛИ ЗЕМЛИ", ["ВКЛ", "ВЫКЛ"], func() -> int: return 0 if GameConfig.ground_detail else 1, func(i: int) -> void : GameConfig.ground_detail = i == 0, VW_SHORT)
                _selector(vb, "ЦИФРЫ ДОХОДА", ["ВКЛ", "ВЫКЛ"], func() -> int: return 0 if GameConfig.econ_fx else 1, func(i: int) -> void : GameConfig.econ_fx = i == 0, VW_SHORT)

                _selector(vb, "ЧАСТОТА КАДРОВ", ["30", "60", "МАКС"], func() -> int: return GameConfig.fps_i, func(i: int) -> void :
                        GameConfig.fps_i = i
                        Save.apply_power_save(), VW_SHORT)
                _selector(vb, "30 FPS НА ПАУЗЕ", ["ВЫКЛ", "ВКЛ"], func() -> int: return 1 if GameConfig.pause_fps_limit else 0, func(i: int) -> void:
                        GameConfig.pause_fps_limit = i == 1
                        Save.apply_power_save(), VW_SHORT)
                _selector(vb, "ЭНЕРГОСБЕРЕЖЕНИЕ · 30 FPS" if GameConfig.android else "ЭНЕРГОСБЕРЕЖЕНИЕ · 45 FPS", ["ВЫКЛ", "ВКЛ"], func() -> int: return 1 if GameConfig.power_save else 0, func(i: int) -> void :
                        GameConfig.power_save = i == 1
                        Save.apply_power_save(), VW_SHORT)
                _selector(vb, "СЧЁТЧИК FPS", ["ВЫКЛ", "ВКЛ"], func() -> int: return 1 if GameConfig.perf_hud else 0, func(i: int) -> void : GameConfig.perf_hud = i == 1, VW_SHORT)
                if GameConfig.dev_mode:

                        _selector(vb, "ЯЗЫК · DEV", ["RU", "UK", "EN", "ES"], func() -> int: return maxi(0, Loc.LANGS.find(Loc.cur())), func(i: int) -> void : Loc.set_lang(Loc.LANGS[i]), VW_SHORT)
                        _selector(vb, "ПСЕВДОЯЗЫК +30%", ["ВЫКЛ", "ВКЛ"], func() -> int: return 1 if Loc.pseudo_on else 0, func(i: int) -> void : Loc.set_pseudo(i == 1), VW_SHORT)

                        _selector(vb, "PERF PROBE · DEV", ["OFF", "ON"], func() -> int: return 1 if PerfProbe.armed else 0, func(i: int) -> void : PerfProbe.arm(get_tree(), i == 1), VW_SHORT)
                var ver: = Button.new()
                ver.flat = true
                ver.focus_mode = Control.FOCUS_NONE
                ver.text = VERSION + (Loc.t("  · РАЗРАБОТЧИК") if GameConfig.dev_mode else "")
                ver.add_theme_font_size_override("font_size", 9)
                ver.add_theme_color_override("font_color", UiKit.MUTED)
                ver.custom_minimum_size = Vector2(0, 30)
                ver.pressed.connect( func() -> void :
                        _dev_taps += 1
                        if _dev_taps < 7:
                                return
                        _dev_taps = 0
                        GameConfig.dev_mode = not GameConfig.dev_mode
                        if not GameConfig.dev_mode:
                                GameConfig.perf_hud = false
                                PerfProbe.arm(get_tree(), false)
                        Save.save_prefs()
                        show_settings_sub("gfx"))
                vb.add_child(ver)
        elif kind == "opening":
                _selector(vb, "ПРИ ЗАПУСКЕ", ["ВКЛ", "ВЫКЛ"], func() -> int: return 0 if GameConfig.opening else 1, func(i: int) -> void : GameConfig.opening = i == 0, VW_SHORT)
                if not _from_pause and ResourceLoader.exists(Opening.VIDEO):
                        var w: Button = UiKit.big("СМОТРЕТЬ ЗАСТАВКУ", "blue", "", 48.0, 13)
                        w.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                        w.pressed.connect( func() -> void :
                                Save.save_prefs()
                                request.emit("watch_opening"))
                        vb.add_child(w)
        else:
                _volume(vb, "ЗВУКИ", "sfx_volume")
                _volume(vb, "МУЗЫКА", "music_volume")
                _volume(vb, "ОКРУЖЕНИЕ", "ambience_volume")
                if not ResourceLoader.exists("res://core/sfx.gd"):
                        _label(vb, "Звук недоступен", 11, UiKit.MUTED)
        var back: Button = UiKit.big("НАЗАД", "stone", "", 44.0, 14)
        back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        back.pressed.connect( func() -> void : show_settings(_from_pause))
        _bottom_row().add_child(back)


func _sound_hint() -> String:
        if not ResourceLoader.exists("res://core/sfx.gd"):
                return ""
        var sfx: GDScript = load("res://core/sfx.gd") as GDScript
        return Loc.t("ЗВУКИ %d%% · МУЗЫКА %d%%") % [roundi(float(sfx.get("sfx_volume")) * 100.0), roundi(float(sfx.get("music_volume")) * 100.0)]


func show_pause() -> void :
        var online0: bool = net != null and net.in_match
        var vb: VBoxContainer = _screen("Меню" if online0 else Loc.t("Пауза"), 0.55)
        current = "pause"
        if gw.player != null and gw.session.started:
                var info: String = Loc.t("Очки: %d · место %d из %d") % [gw.player.score, _place(gw.player), gw.countries.size()]
                if RankedRules.active():
                        info = Loc.t("Рейтинговый бой · осталось %s") % Hud._mmss(maxf(0.0, float(GameConfig.ranked.get("time_limit", 600)) - gw.session.elapsed()))
                elif GameConfig.victory == 0:
                        info += Loc.t("\nЦель: %d очков") % GameConfig.score_target()
                elif GameConfig.victory == 1:
                        info += (Loc.t("\nОсталось: %s") % Hud._mmss(gw.session.time_left())) if GameConfig.time_limit() > 0.0 else Loc.t("\nБез лимита времени · цель: %d очков") % GameConfig.score_target()
                else:
                        info += Loc.t("\nЗахватите все столицы")
                if GameConfig.victory != 1 and GameConfig.match_limit() > 0.0 and not RankedRules.active():
                        info += Loc.t(" · осталось %s") % Hud._mmss(gw.session.time_left())
                info += Loc.t("\nВремя партии: %s") % Hud._mmss(gw.session.elapsed())
                _label(vb, info, 12, UiKit.TEXT)
        var online: bool = net != null and net.in_match
        if online:
                _label(vb, "Сетевая партия идёт дальше. Пауза — только когда хост сворачивает игру.", 10, UiKit.MUTED)
        _button(vb, Loc.t("В ИГРУ") if online else Loc.t("ПРОДОЛЖИТЬ"), "green", "resume", true, 50.0)
        if not online:
                SavesUI.pause_row(self, vb)
        else:
                _mp_pause_row(vb)
        var grid: = GridContainer.new()
        grid.columns = 2
        grid.add_theme_constant_override("h_separation", 8)
        grid.add_theme_constant_override("v_separation", 8)
        vb.add_child(grid)
        var keys: Array = [["РЕЙТИНГ", "gold", "scores"], ["НАСТРОЙКИ", "stone", "settings_pause"]]
        if not online:
                keys += [[Loc.t("ОБУЧЕНИЕ"), "stone", "tutorial_restart"], [Loc.t("ЗАНОВО"), "stone", "restart"]]
        for it: Array in keys:


                var lk: bool = String(it[2]) == "tutorial_restart"
                var b: Button = _ibutton(grid, String(it[0]), String(it[1]), "", "mi_tutorial", 44.0) if lk else _button(grid, String(it[0]), String(it[1]), String(it[2]))
                b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                b.add_theme_font_size_override("font_size", 12)
                if lk:
                        b.pressed.connect( func() -> void : load("res://ui/ui24/tutorial_feed.gd").call("open", self, true))
        if online and net.mode == NetSession.Mode.ONLINE:
                var rb: Button = _button(vb, "ПОЖАЛОВАТЬСЯ", "stone", "")
                rb.add_theme_font_size_override("font_size", 11)
                rb.pressed.connect( func() -> void :
                        ReportScreen.start(-1, false)
                        show_report())
                var gap: = Control.new()
                gap.custom_minimum_size.y = 12
                vb.add_child(gap)
        if online:
                if net != null and net.is_host:
                        var be: Button = _button(vb, "СОХРАНИТЬ И ВЫЙТИ", "green", "")
                        be.icon = SavesUI.icon_tex("disk")
                        be.expand_icon = false
                        be.pressed.connect(func() -> void :
                                net.host_save_and_exit()
                                request.emit("main_menu"))
                        _leave_button(vb)
                else:
                        var bg: Button = _button(vb, "ВЫЙТИ В МЕНЮ", "stone", "")
                        bg.pressed.connect(func() -> void :
                                if net != null:
                                        net.leave(true, true, true)
                                request.emit("main_menu"))
        elif GameConfig.no_save:
                SavesUI.quit_button(self, vb)
        else:
                var exit_row: = HBoxContainer.new()
                exit_row.add_theme_constant_override("separation", 8)
                vb.add_child(exit_row)
                var b_mm: Button = _button(exit_row, "ГЛАВНОЕ МЕНЮ", "stone", "main_menu")
                b_mm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                var b_q: Button = _button(exit_row, "ВЫЙТИ ИЗ ИГРЫ", "red", "quit")
                b_q.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _mp_pause_row(vb: VBoxContainer) -> void :
        if net == null or not net.in_match:
                return
        if net.is_host:
                var row: = HBoxContainer.new()
                row.add_theme_constant_override("separation", 8)
                vb.add_child(row)
                var sv: Button = UiKit.big("СОХРАНИТЬ", "stone", "", 44.0, 12)
                sv.icon = SavesUI.icon_tex("disk")
                sv.expand_icon = false
                sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                row.add_child(sv)

                var inv: Button = UiKit.big("ПРИГЛАСИТЬ", "stone", "", 44.0, 12)
                inv.icon = MpKit.icon("net_players", false).texture
                inv.expand_icon = false
                inv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                row.add_child(inv)

                var st: Label = _label(vb, _mp_pause_status(), 10, UiKit.MUTED)

                sv.pressed.connect(func() -> void :
                        net.save_match(-1, true)
                        UiKit.snd("ui_select")
                        sv.text = Loc.t("СОХРАНЕНО")
                        sv.add_theme_color_override("font_color", UiKit.GREEN)
                        st.text = Loc.t("Партия сохранена у хоста · игроки сохраняются по никнеймам")
                        var sref: WeakRef = weakref(sv)
                        sv.get_tree().create_timer(1.6).timeout.connect(func() -> void :
                                var s2: Button = sref.get_ref() as Button
                                if s2 != null:
                                        s2.text = Loc.t("СОХРАНИТЬ")
                                        s2.remove_theme_color_override("font_color")))

                inv.pressed.connect(func() -> void :
                        if net.mode == NetSession.Mode.ONLINE:
                                var code: String = net.room_code
                                DisplayServer.clipboard_set(code)
                                UiKit.snd("ui_select")
                                _mp_toast("Код комнаты скопирован: %s" % code)
                                st.text = Loc.t("Код %s скопирован в буфер обмена") % code
                        else:
                                var ips: Array[String] = NetSession.get_lan_ips()
                                var primary_ip: String = ips[0] if not ips.is_empty() else "127.0.0.1"
                                DisplayServer.clipboard_set(primary_ip)
                                UiKit.snd("ui_select")
                                _mp_toast("IP хоста скопирован: %s" % primary_ip)
                                st.text = Loc.t("IP %s скопирован в буфер обмена") % primary_ip)
        else:
                _label(vb, Loc.t("Хост: %s · прогресс сохраняется у хоста") % net.host_name(), 10, UiKit.MUTED)


func _mp_pause_status() -> String:
        var d: Dictionary = NetConfig.load_match()
        if d.is_empty():
                return Loc.t("Сетевая партия ещё не сохранялась")
        return Loc.t("Сетевая партия · сохранено %s") % NetConfig.ago_text(int(d.get("t", 0))).to_lower()



func show_report() -> void :
        var vb: VBoxContainer = _screen("Жалоба", 0.55)
        current = "report"
        ReportScreen.new(self).build(vb)


func _place(c: Country) -> int:
        var r: Array[Country] = gw.session.ranking()
        return r.find(c) + 1



func _table(vb: VBoxContainer) -> void :
        var pc: = PanelContainer.new()
        pc.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 8, 6))
        vb.add_child(pc)
        var grid: = GridContainer.new()
        grid.columns = 5
        grid.add_theme_constant_override("h_separation", 8)
        grid.add_theme_constant_override("v_separation", 4)
        pc.add_child(grid)
        for h: String in ["", "СТРАНА", "ЭКОН", "ВОЙНА", "ИТОГ"]:
                grid.add_child(UiKit.lbl(h, 9, UiKit.MUTED, 2))
        for c: Country in gw.session.ranking():
                var fl: = TextureRect.new()
                fl.texture = FlagMaker.tex_for(c, Vector2(21, 14))
                fl.custom_minimum_size = Vector2(21, 14)
                fl.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
                fl.stretch_mode = TextureRect.STRETCH_SCALE
                fl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
                fl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
                grid.add_child(fl)
                var mine: bool = gw.player != null and c == gw.player
                var col: Color = UiKit.TITLE if mine else (UiKit.DIM if c.eliminated else UiKit.TEXT)
                var nm: String = Loc.name(c.name) + (Loc.t(" (вы)") if mine else "")
                var l0: Label = UiKit.lbl(nm, 10, col, 2, 2)
                l0.custom_minimum_size = Vector2(120, 0)
                l0.clip_text = true
                l0.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
                grid.add_child(l0)
                for txt: String in [str(c.score_eco), str(c.score_mil), str(c.score)]:
                        grid.add_child(UiKit.lbl(txt, 10, col, 2, 2))



func show_saves(from_pause: bool, keep: bool = false) -> void :
        var vb: VBoxContainer = _screen("Сохранения", 0.55 if from_pause else 0.45, not keep)
        current = "saves"
        SavesUI.build(self, vb, from_pause)



func show_scores(back: String = "pause") -> void :
        var vb: VBoxContainer = _screen("Рейтинг", 0.55)
        current = "scores"
        _table(vb)
        _button(vb, "НАЗАД", "stone", back)


func show_end(winner: int) -> void :
        var win: bool = gw.player != null and winner == gw.player.id
        var vb: VBoxContainer = _screen("", 0.6)
        current = "end"
        var t: Label = UiKit.title(Loc.t("ПОБЕДА!") if win else Loc.t("ПОРАЖЕНИЕ"), 30, UiKit.TITLE if win else UiKit.RED)
        vb.add_child(t)
        t.pivot_offset = Vector2(150, 20)
        t.scale = Vector2(1.5, 1.5)
        var tw: Tween = t.create_tween()
        tw.tween_property(t, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
        var wc: Country = gw.country_by_id(winner)
        if wc != null:
                _label(vb, (Loc.t("%s побеждает") % Loc.name(wc.name)) if not win else Loc.t("Ваша страна — лидер мира"), 12, UiKit.TEXT)
        _label(vb, Loc.t("Время партии: %s") % Hud._mmss(gw.session.elapsed()), 10, UiKit.MUTED)
        _table(vb)
        if gw.player != null:
                var p: Country = gw.player
                _label(vb, Loc.t("Заработано: %d · уничтожено: %d\nЗахвачено городов: %d · потеряно: %d") % [p.earned, p.destroyed, p.captured, p.lost], 10, UiKit.MUTED)
        var gone: bool = gw.player != null and gw.player.eliminated
        _button(vb, Loc.t("СМОТРЕТЬ ДАЛЬШЕ") if gone else Loc.t("ИГРАТЬ ДАЛЬШЕ"), "stone" if gone else "green", "continue")
        var row: = HBoxContainer.new()
        row.add_theme_constant_override("separation", 8)
        vb.add_child(row)
        var a: Button = _button(row, "НОВАЯ ПАРТИЯ", "blue", "")
        a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        a.add_theme_font_size_override("font_size", 11)
        _two_taps(a, "setup")
        var m: Button = _button(row, "В МЕНЮ", "stone", "")
        m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        m.add_theme_font_size_override("font_size", 11)
        _two_taps(m, "main_menu")




func _two_taps(b: Button, req: String) -> void :
        var label: String = b.text
        var armed: Array = [false]

        var all: bool = net != null and net.in_match and net.is_host and net.slots.size() > 1
        b.pressed.connect( func() -> void :
                if armed[0]:
                        request.emit(req)
                        return
                armed[0] = true
                b.text = "ЗАКОНЧИТЬ ДЛЯ ВСЕХ? ЕЩЁ ТАП" if all else "ЕЩЁ ТАП"
                get_tree().create_timer(3.0).timeout.connect( func() -> void :
                        if is_instance_valid(b):
                                armed[0] = false
                                b.text = label))




var _top: bool = false
var _auth_tab: int = 0
var _auth_intent: String = ""
var _auth_nick: String = ""
var _auth_email: String = ""
var _auth_pw: String = ""
var _auth_busy: bool = false
var _auth_req: int = 0
var _auth_block_ms: int = 0
var _af: Dictionary = {}
var _a_submit: Button = null
var _a_slot: Control = null
var _acc_fetch_ms: int = -100000
var _acc_sig: String = ""
var _logout_ok: bool = false



func _account_sig() -> String:
        return "%s|%s|%s|%s|%s|%s|%d|%s" % [str(Account.signed_in()), Account.username(), str(Account.info.get("match_played", "")), str(Account.mp_ok()), str(Account.expired), str(Account.equipped()), Account.owned.size(), str((Account.info.get("mp_suspension") as Dictionary).get("until", "")) if Account.info.get("mp_suspension") is Dictionary else ""]


var _sus_gen: int = 0



func _sus_watch() -> void :
        _sus_gen += 1
        var g: int = _sus_gen
        var screen: String = current
        await get_tree().create_timer(minf(30.0, maxf(1.0, float(Account.suspended_s())))).timeout
        if g != _sus_gen or current != screen or not visible:
                return
        if Account.suspended_s() <= 0:
                var r: Dictionary = await Account.fetch_info()
                if current == screen:
                        show_mp()
                        if int(r["code"]) == 200 and Account.suspended_s() <= 0:
                                _mp_toast("ОНЛАЙН СНОВА ДОСТУПЕН")
                return
        if current == "mp":
                show_mp()


func _on_account_changed() -> void :
        if not visible:
                return
        var sig: String = _account_sig()
        if sig == _acc_sig:
                return
        if get_viewport().gui_get_focus_owner() is LineEdit:
                return
        if current == "mp":
                show_mp()
        elif current == "profile":
                show_profile()
        elif current == "outfit" and not _out_busy:
                show_outfit()


func _hook_account() -> void :
        if not Api.i().account_changed.is_connected(_on_account_changed):
                Api.i().account_changed.connect(_on_account_changed)



func _mp_signin_block(vb: VBoxContainer) -> void :
        if Account.device_check_missing():
                MpKit.placeholder(vb, "net_warn", "ОНЛАЙН НА ЭТОМ УСТРОЙСТВЕ НЕДОСТУПЕН", "НУЖНА ВЕРСИЯ ДЛЯ IPHONE ИЛИ ANDROID · ПО WI-FI МОЖНО", false, 120.0)
                return
        var p: PanelContainer = MpKit.placeholder(vb, "acc_pilot", "СЕССИЯ ЗАКОНЧИЛАСЬ" if Account.expired else "ВОЙДИТЕ, ЧТОБЫ ИГРАТЬ ОНЛАЙН", 
                "ВОЙДИТЕ СНОВА: ПОЧТА УЖЕ ПОДСТАВЛЕНА" if Account.expired else "НИК И СЧЁТ ПАРТИЙ ХРАНЯТСЯ НА СЕРВЕРЕ", false, 150.0)
        var v: VBoxContainer = p.get_child(0)
        v.mouse_filter = Control.MOUSE_FILTER_PASS
        p.mouse_filter = Control.MOUSE_FILTER_PASS
        var row: = HBoxContainer.new()
        row.add_theme_constant_override("separation", 8)
        v.add_child(row)
        for it: Array in [["ВОЙТИ", "blue", 0], ["РЕГИСТРАЦИЯ", "green", 1]]:
                var b: Button = UiKit.big(String(it[0]), String(it[1]), "", 44.0, 13)
                b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                var tab: int = int(it[2])
                b.pressed.connect( func() -> void : show_auth(tab, ""))
                row.add_child(b)



func _mp_account_card(vb: VBoxContainer) -> void :
        Ranked.flush_pending()
        var played: Variant = Account.info.get("match_played", null)
        var sub: String = "ЗАГРУЖАЕМ ПРОФИЛЬ..." if played == null else "СЫГРАНО ПАРТИЙ: %d" % int(played)
        var arrow: TextureRect = UiKit.icon_rect("wb_arrow_r", 20.0)
        arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        MpKit.player_card(vb, Account.username() if Account.username() != "" else "Пилот", sub, Account.equipped(), MpKit.ROW_H, func() -> void : show_profile(), arrow)
        if Time.get_ticks_msec() - _acc_fetch_ms > 30000:
                _acc_fetch_ms = Time.get_ticks_msec()
                Account.fetch_info()




func show_auth(tab: int = -1, intent: String = "-", msg: String = "", sev: String = "alarm") -> void :
        if _mp_gate():
                return
        _hook_account()
        if current != "auth":
                _auth_pw = ""
                _auth_busy = false
        if tab >= 0:
                _auth_tab = tab
        if intent != "-":
                _auth_intent = intent
        var vb: VBoxContainer = _screen("Аккаунт", 0.45, current != "auth")
        current = "auth"
        _top = true
        var reg: bool = _auth_tab == 1
        if _auth_intent != "":
                var what: String = {"create": "СОЗДАТЬ КОМНАТУ", "rejoin": "ВЕРНУТЬСЯ В ПАРТИЮ", "resume": "ПРОДОЛЖИТЬ ПАРТИЮ"}.get(_auth_intent, "ИГРАТЬ ОНЛАЙН")
                _label(vb, ("НУЖЕН АККАУНТ, ЧТОБЫ " if reg else "ВОЙДИТЕ, ЧТОБЫ ") + what, 11, UiKit.GOLD)
        MpKit.tabs(vb, [["", "ВХОД"], ["", "РЕГИСТРАЦИЯ"]], _auth_tab, func(i: int) -> void :
                if _auth_busy or i == _auth_tab:
                        return
                _auth_keep()
                _auth_tab = i
                UiKit.snd("ui_tab")
                show_auth())
        _af = {}
        _af["nick"] = MpKit.field(vb, "НИК", "Латиница и цифры", "nick")
        var ne: LineEdit = _af["nick"]["edit"]
        ne.text = _auth_nick if _auth_nick != "" else Account.username()
        ne.text_changed.connect( func(t: String) -> void :
                var r: Array = Account.filter_nick(t)
                if String(r[0]) != t:
                        var col: int = ne.caret_column
                        ne.text = String(r[0])
                        ne.caret_column = mini(col, ne.text.length())
                if bool(r[1]):
                        MpKit.set_field_error(_af["nick"], Account.NICK_RULE)
                _nick_probe(_af["nick"], ne, ""))
        _af["password"] = MpKit.field(vb, "ПАРОЛЬ", "Не меньше 4 символов" if reg else "Пароль", "password")
        (_af["password"]["edit"] as LineEdit).text = _auth_pw
        var order: Array = ["nick", "password"]
        for k in order.size():
                var e: LineEdit = _af[order[k]]["edit"]
                var nxt: String = String(order[k + 1]) if k + 1 < order.size() else ""
                e.text_submitted.connect( func(_t: String) -> void :
                        if nxt != "":
                                (_af[nxt]["edit"] as LineEdit).grab_focus()
                        else:
                                _auth_submit())
                var key: String = String(order[k])
                e.focus_exited.connect( func() -> void :
                        if is_instance_valid(e) and e.text != "" and not _auth_busy:
                                MpKit.set_field_error(_af[key], _auth_check(key, e.text)))
        _a_submit = _ibutton(vb, "СОЗДАТЬ АККАУНТ" if reg else "ВОЙТИ", "green", "", "acc_pilot" if reg else "acc_login", 48.0)
        _a_submit.pressed.connect(_auth_submit)
        _a_slot = Control.new()
        _a_slot.custom_minimum_size = Vector2(0, 36)
        _a_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
        vb.add_child(_a_slot)
        if msg != "":
                _auth_status(msg, sev)
        elif reg:
                var h: Label = _label(_a_slot, "ЗАПОМНИТЕ ПАРОЛЬ: ВОССТАНОВЛЕНИЯ ПОКА НЕТ", 10, UiKit.MUTED)
                h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
                h.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        if Account.device_check_missing():
                _auth_status(DeviceCheck.TXT_MISSING, "info")
        _auth_tick()
        var br: HBoxContainer = _bottom_row()
        var back: Button = _button(br, "НАЗАД", "stone", "")
        back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        back.pressed.connect( func() -> void :
                _auth_pw = ""
                _auth_intent = ""
                _auth_busy = false
                _auth_req += 1
                show_mp())


var _nick_gen: int = 0





func _nick_probe(f: Dictionary, e: LineEdit, same: String) -> void :
        _nick_gen += 1
        var gen: int = _nick_gen
        var t: String = e.text
        if t == same or Account.nick_error(t) != "":
                if Account.nick_error(t) == "" or t.length() < 3:
                        MpKit.set_field_error(f, "")
                return
        await get_tree().create_timer(0.6).timeout
        if gen != _nick_gen or not is_instance_valid(e) or e.text != t:
                return
        var st: String = await Account.nick_state(t)
        if gen != _nick_gen or not is_instance_valid(e) or e.text != t:
                return
        match st:
                "taken":
                        MpKit.set_field_error(f, "НИК: УЖЕ ЗАНЯТ")
                        if f.get("save") is Button and is_instance_valid(f["save"]):
                                (f["save"] as Button).disabled = true
                "invalid":
                        MpKit.set_field_error(f, Account.NICK_RULE)
                "free":
                        MpKit.set_field_error(f, "")
                        var cap: Label = f["cap"]
                        cap.text = "НИК СВОБОДЕН"
                        cap.add_theme_color_override("font_color", UiKit.GREEN)
                _:
                        MpKit.set_field_error(f, "")


func _auth_keep() -> void :
        if _af.has("nick"):
                _auth_nick = (_af["nick"]["edit"] as LineEdit).text
        if _af.has("email"):
                _auth_email = (_af["email"]["edit"] as LineEdit).text
        if _af.has("password"):
                _auth_pw = (_af["password"]["edit"] as LineEdit).text


func _auth_check(key: String, t: String) -> String:
        match key:
                "nick":
                        return Account.nick_error(t)
                "email":
                        return Account.email_error(t)
                "password":
                        return Account.password_error(t)
        return ""


func _auth_status(text: String, sev: String = "alarm", extra: Button = null) -> void :
        if _a_slot == null or not is_instance_valid(_a_slot):
                return
        for ch: Node in _a_slot.get_children():
                ch.queue_free()
        _a_slot.custom_minimum_size.y = 44.0 if extra != null else 36.0
        if text == "":
                if _auth_tab == 1:
                        var h: Label = _label(_a_slot, "ЗАПОМНИТЕ ПАРОЛЬ: ВОССТАНОВЛЕНИЯ ПОКА НЕТ", 10, UiKit.MUTED)
                        h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
                        h.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
                return
        var icon: String = {"wait": "net_sync", "ok": "icon_ok"}.get(sev, "")
        var bar: PanelContainer = MpKit.status_bar(_a_slot, text, sev, icon, sev == "wait")
        bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        if extra != null:
                (bar.get_child(0) as HBoxContainer).add_child(extra)



func _auth_tick() -> void :
        if _a_submit == null or not is_instance_valid(_a_submit):
                return
        var reg: bool = _auth_tab == 1
        var left: int = int(ceil(float(_auth_block_ms - Time.get_ticks_msec()) / 1000.0))
        if Account.device_check_missing():
                _a_submit.disabled = true
                return
        if _auth_busy:
                _a_submit.text = "СОЗДАЁМ..." if reg else "ВХОДИМ..."
                _a_submit.disabled = true
        elif left > 0:
                _a_submit.text = "ПОДОЖДИТЕ %d:%02d" % [left / 60, left % 60]
                _a_submit.disabled = true
                get_tree().create_timer(1.0).timeout.connect(_auth_tick)
        else:
                _a_submit.text = "СОЗДАТЬ АККАУНТ" if reg else "ВОЙТИ"
                _a_submit.disabled = false


func _auth_submit() -> void :
        if _auth_busy or Time.get_ticks_msec() < _auth_block_ms:
                return
        var reg: bool = _auth_tab == 1
        var first: LineEdit = null
        for key: String in ["nick", "password"]:
                var e: LineEdit = _af[key]["edit"]
                var why: String = _auth_check(key, e.text)
                MpKit.set_field_error(_af[key], why)
                if why != "" and first == null:
                        first = e
        if first != null:
                UiKit.snd("ui_error")
                first.grab_focus()
                return
        _auth_keep()
        _auth_busy = true
        _auth_req += 1
        var req: int = _auth_req
        for f: Dictionary in _af.values():
                (f["edit"] as LineEdit).editable = false
        _auth_status("")
        _auth_tick()
        var t0: int = Time.get_ticks_msec()
        var r: Dictionary
        if reg:
                r = await Account.register(_auth_nick, _auth_pw)
        else:
                r = await Account.login(_auth_nick, _auth_pw)
        if req != _auth_req:
                return
        _auth_busy = false
        if current != "auth":
                return
        print("[Account] %s: %s (%d ms)" % ["register" if reg else "login", "ok" if bool(r["ok"]) else String(r["err"]), Time.get_ticks_msec() - t0])
        for f2: Dictionary in _af.values():
                (f2["edit"] as LineEdit).editable = true
        if bool(r["ok"]):
                _auth_pw = ""
                UiKit.snd("ui_capture")
                var intent: String = _auth_intent
                _auth_intent = ""
                _mp_tab = 1
                if intent == "create" and Account.mp_ok():
                        show_mp_create()
                        _mp_toast("АККАУНТ СОЗДАН" if reg else "ВЫ ВОШЛИ")
                elif intent == "rejoin" and Account.mp_ok():
                        var w: String = net.rejoin()
                        show_mp(w if w != "" else ("АККАУНТ СОЗДАН" if reg else "ВЫ ВОШЛИ"), "" if w != "" else "ok")
                elif intent == "resume" and Account.mp_ok():
                        var w2: String = net.resume_host()
                        if w2 != "":
                                show_mp(w2)
                else:
                        show_mp("АККАУНТ СОЗДАН" if reg else "ВЫ ВОШЛИ", "ok")
                return
        UiKit.snd("ui_error")
        var code: int = int(r.get("code", 0))
        match String(r.get("field", "")):
                "nick":
                        MpKit.set_field_error(_af["nick"], "НИК: УЖЕ ЗАНЯТ")
                        (_af["nick"]["edit"] as LineEdit).grab_focus()
                        (_af["nick"]["edit"] as LineEdit).select_all()
                "email":
                        MpKit.set_field_error(_af["email"], "ПОЧТА: УЖЕ ЗАРЕГИСТРИРОВАНА")
                        var go_in: Button = UiKit.big("ВОЙТИ", "blue", "", 44.0, 12)
                        go_in.custom_minimum_size = Vector2(82, 44)
                        go_in.size_flags_vertical = Control.SIZE_SHRINK_CENTER
                        _hide_keyboard()
                        go_in.pressed.connect( func() -> void :
                                _auth_keep()
                                _auth_tab = 0
                                show_auth())
                        _auth_status("ЭТО ВАШ АККАУНТ? ВОЙДИТЕ", "info", go_in)
                "password":
                        (_af["password"]["edit"] as LineEdit).text = ""
                        _auth_pw = ""
                        _auth_status(String(r["err"]))
                        _hide_keyboard()
                _:
                        if code == 429:
                                _auth_block_ms = Time.get_ticks_msec() + 60000
                        _auth_status(String(r["err"]))
                        _hide_keyboard()
        _auth_tick()



func show_profile(msg: String = "", sev: String = "info") -> void :
        _hook_account()
        if current != "profile":
                _logout_ok = false
        var vb: VBoxContainer = _screen("Профиль", 0.45, current != "profile")
        _panel.custom_minimum_size = Vector2(minf(350.0, root.size.x - 16.0), 0)
        current = "profile"
        _top = true
        _acc_sig = _account_sig()
        if not Account.mp_ok():
                MpKit.status_bar(vb, "ОНЛАЙН-ИГРА ДЛЯ АККАУНТА ЗАКРЫТА · WI-FI ДОСТУПЕН", "alarm", "acc_ban")
        elif Account.suspended_s() > 0:
                MpKit.status_bar(vb, "ОНЛАЙН ЗАКРЫТ ДО %s · %s" % [Account.suspension_until(), Account.suspension_reason()], "alarm", "acc_ban")
        var played_s: float = float(Account.info.get("playtime_s", 0.0))
        var wins_cnt: int = int(Account.info.get("wins", 0))
        var matches_cnt: int = int(Account.info.get("matches", 0))
        var sub_prof: String = "ЧАСОВ: %s · ПОБЕД: %d · МАТЧЕЙ: %d" % [Account.format_hours(played_s), wins_cnt, matches_cnt]
        MpKit.player_card(vb, Account.username(), sub_prof, Account.equipped(), 72.0, Callable(), null, Account.is_dev(), Account.avatar_b64)
        if Account.is_dev():
                var dev_sb: PanelContainer = MpKit.status_bar(vb, "РАЗРАБОТЧИК ПОРТА DRONEFLAMES", "ok", "mod_verified")
                dev_sb.mouse_filter = Control.MOUSE_FILTER_STOP
                dev_sb.gui_input.connect(func(ev: InputEvent) -> void:
                        if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
                                UiKit.snd("ui_click")
                                MpKit.show_dev_verified_dialog(Account.username())
                )
        elif not Account.is_authenticated():
                var reg_p: Button = UiKit.big("ЗАРЕГИСТРИРОВАТЬСЯ В СЕТИ", "green", "", 44.0, 12)
                vb.add_child(reg_p)
                reg_p.pressed.connect(func() -> void:
                        show_net_auth_prompt(func() -> void: show_profile(), func() -> void: show_profile())
                )
        MpKit.section(vb, "АВАТАРКА")
        var av_row: = HBoxContainer.new()
        av_row.add_theme_constant_override("separation", 6)
        vb.add_child(av_row)
        var change_av: Button = UiKit.big("ВЫБРАТЬ ИЗ ФАЙЛА (PNG/JPG)", "blue", "", 42.0, 12)
        change_av.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        av_row.add_child(change_av)
        change_av.pressed.connect(func() -> void:
                _pick_avatar_file()
        )
        if Account.is_authenticated():
                var visibility := OptionButton.new()
                for title: String in ["Аватар: все", "Аватар: только друзья", "Аватар: никто"]:
                        visibility.add_item(Loc.t(title))
                var modes: Array[String] = ["all", "friends", "none"]
                visibility.select(maxi(0, modes.find(String(Account.info.get("avatar_visibility", "all")))))
                vb.add_child(visibility)
                visibility.item_selected.connect(func(index: int) -> void:
                        var result: Dictionary = await Account.update_profile({"avatar_visibility": modes[index]})
                        if not result.get("ok", false):
                                _mp_toast(String(result.get("err", "Настройка не сохранена")))
                                if is_instance_valid(visibility):
                                        visibility.select(maxi(0, modes.find(String(Account.info.get("avatar_visibility", "all"))))))

        if Account.is_authenticated():
                MpKit.section(vb, "КТО МОЖЕТ НАПИСАТЬ МНЕ")
                var everyone: bool = Account.info.get("message_visibility", "friends") == "all"
                MpKit.tabs(vb, [["net_players", "ДРУЗЬЯ"], ["net_globe", "ВСЕ ИГРОКИ"]], 1 if everyone else 0, func(index: int) -> void:
                        var view: Control = screen
                        var result: Dictionary = await Account.update_profile({"message_visibility": "all" if index == 1 else "friends"})
                        if screen == view:
                                show_profile("НАСТРОЙКА СОХРАНЕНА" if result.get("ok", false) else "НЕ УДАЛОСЬ СОХРАНИТЬ НАСТРОЙКУ", "ok" if result.get("ok", false) else "alarm"))

        if Account.avatar_b64 != "":
                var rst_av: Button = UiKit.big("СБРОСИТЬ", "stone", "", 42.0, 12)
                av_row.add_child(rst_av)
                rst_av.pressed.connect(func() -> void:
                        Account.avatar_b64 = ""
                        Account.save_profile()
                        show_profile("АВАТАРКА СБРОШЕНА", "ok")
                )
        var fresh: int = Account.unseen().size()
        var orow: Button = _nav_row(vb, "ОФОРМЛЕНИЕ", ("НОВОЕ: %d" % fresh) if fresh > 0 else ("ОТКРЫТО %d" % Account.owned.size() if not Account.owned.is_empty() else "РАМКА · БАННЕР · ТИТУЛ"), func() -> void : show_outfit())
        if fresh > 0:
                for l: Node in orow.get_child(0).get_children():
                        if l is Label and (l as Label).text.begins_with("НОВОЕ"):
                                (l as Label).add_theme_color_override("font_color", UiKit.GREEN)
        var searching: bool = net != null and net.ranked_mode != "" and not net.in_match and net.rtc.ranked.is_empty()
        var busy: bool = net != null and net.active() and not searching
        if Account.mp_ok():
                var f: Dictionary = MpKit.field(vb, "СМЕНИТЬ НИК", "Латиница и цифры", "nick")
                var e: LineEdit = f["edit"]
                e.text = Account.username()
                e.editable = not busy
                if Account.nick_error(Account.username()) != "":
                        MpKit.set_field_error(f, "НИК НУЖНО СМЕНИТЬ: ЛАТИНИЦА И ЦИФРЫ")
                var save: Button = UiKit.big("СОХРАНИТЬ", "blue", "", 44.0, 13)
                save.custom_minimum_size.x = 112
                save.disabled = true
                (f["row"] as HBoxContainer).add_child(save)
                f["save"] = save
                e.text_changed.connect( func(t: String) -> void :
                        var r: Array = Account.filter_nick(t)
                        if String(r[0]) != t:
                                var col: int = e.caret_column
                                e.text = String(r[0])
                                e.caret_column = mini(col, e.text.length())
                        if bool(r[1]):
                                MpKit.set_field_error(f, Account.NICK_RULE)
                        save.disabled = e.text == Account.username() or e.text.length() < 3
                        _nick_probe(f, e, Account.username()))
                var do_save: = func() -> void :
                        var why: String = Account.nick_error(e.text)
                        if why != "":
                                MpKit.set_field_error(f, why)
                                UiKit.snd("ui_error")
                                return
                        save.disabled = true
                        save.text = "..."
                        var r2: Dictionary = await Account.change_username(e.text)
                        if current != "profile" or not is_instance_valid(save) or not is_instance_valid(e):
                                return
                        if bool(r2["ok"]):
                                UiKit.snd("ui_capture")
                                show_profile("НИК ИЗМЕНЁН", "ok")
                        else:
                                save.text = "СОХРАНИТЬ"
                                save.disabled = false
                                MpKit.set_field_error(f, "НИК: УЖЕ ЗАНЯТ" if int(r2.get("code", 0)) == 409 else String(r2["err"]).to_upper())
                                UiKit.snd("ui_error")
                save.pressed.connect(do_save)
                e.text_submitted.connect( func(_t: String) -> void :
                        if not save.disabled:
                                do_save.call())
                if busy:
                        _label(vb, "НИК МЕНЯЕТСЯ ВНЕ КОМНАТЫ", 10, UiKit.MUTED)
        MpKit.section(vb, "ФЛАГ")
        var fc: Button = FlagEditor.card(vb, func() -> void :
                FlagEditor.from_profile = true
                show_flag_editor(), true)
        fc.disabled = busy
        if busy:
                _label(vb, "ФЛАГ МЕНЯЕТСЯ ВНЕ КОМНАТЫ", 10, UiKit.MUTED)
        MpKit.section(vb, "СТАТИСТИКА")
        MpKit.stat_card(vb, "ВРЕМЯ В ИГРЕ", "ЧАСЫ И МИНУТЫ", Account.format_hours(played_s), false, "icon_time")
        MpKit.stat_card(vb, "ПОБЕДЫ", "СОЛО И ОНЛАЙН", str(wins_cnt), false, "acc_ranked")
        MpKit.stat_card(vb, "СЫГРАНО МАТЧЕЙ", "ВСЕГО ПАРТИЙ", str(matches_cnt), false, "icon_stats")
        _sep(vb, 8)
        var lo: Button = _ibutton(vb, ("ВЫЙТИ МОЖНО ПОСЛЕ ПАРТИИ" if net.in_match else "СНАЧАЛА ВЫЙДИТЕ ИЗ КОМНАТЫ") if busy else ("СНАЧАЛА ОТМЕНИТЕ ПОИСК" if searching else ("ТОЧНО ВЫЙТИ? ЕЩЁ ТАП" if _logout_ok else "ВЫЙТИ ИЗ АККАУНТА")), "red" if _logout_ok else "stone", "", "acc_logout", 44.0)
        lo.disabled = busy or searching
        lo.pressed.connect( func() -> void :
                if not _logout_ok:
                        _logout_ok = true
                        show_profile()
                        get_tree().create_timer(3.0).timeout.connect( func() -> void :
                                if _logout_ok and current == "profile":
                                        _logout_ok = false
                                        show_profile())
                        return
                _logout_ok = false
                Account.logout()
                show_mp("ВЫ ВЫШЛИ ИЗ АККАУНТА", "info"))
        var slot: = Control.new()
        slot.custom_minimum_size = Vector2(0, 36)
        slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
        vb.add_child(slot)
        if msg != "":
                var bar: PanelContainer = MpKit.status_bar(slot, msg, sev, "icon_ok" if sev == "ok" else "")
                bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
                var bar_id: int = bar.get_instance_id()
                get_tree().create_timer(2.0 if sev == "ok" else 6.0).timeout.connect( func() -> void :
                        var b2: Object = instance_from_id(bar_id)
                        if b2 != null and is_instance_valid(b2):
                                (b2 as Node).queue_free())
        var br: HBoxContainer = _bottom_row()
        var back: Button = _button(br, "НАЗАД", "stone", "")
        back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        back.pressed.connect( func() -> void : show_mp())
        if Time.get_ticks_msec() - _acc_fetch_ms > 10000:
                _acc_fetch_ms = Time.get_ticks_msec()
                Account.fetch_info()



func _hide_keyboard() -> void :
        var fo: Control = get_viewport().gui_get_focus_owner()
        if fo != null:
                fo.release_focus()
        if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
                DisplayServer.virtual_keyboard_hide()




var _out_tab: int = 0
var _out_pick: String = ""
var _out_busy: bool = false
var _out_loaded: bool = false
const _OUT_KINDS: Array = ["frame", "banner", "title"]


func show_outfit(msg: String = "", sev: String = "info") -> void :
        _hook_account()
        if current != "outfit":
                _out_pick = ""
                _out_busy = false
                if not _out_loaded:
                        _out_loaded = true
                        _outfit_load()
        var vb: VBoxContainer = _screen("Оформление", 0.45, current != "outfit")
        current = "outfit"
        _top = true
        _acc_sig = _account_sig()
        var kind: String = _OUT_KINDS[_out_tab]
        var eq: Dictionary = Account.equipped().duplicate()
        if _out_pick != "":
                eq[kind] = _out_pick
        _label(vb, "ТАК ВАС ВИДЯТ ДРУГИЕ", 10, UiKit.MUTED)
        MpKit.player_card(vb, Account.username(), "", eq, MpKit.ROW_H)
        MpKit.tabs(vb, [["", "РАМКА"], ["", "БАННЕР"], ["", "ТИТУЛ"]], _out_tab, func(i: int) -> void :
                if i == _out_tab or _out_busy:
                        return
                _out_tab = i
                _out_pick = ""
                UiKit.snd("ui_tab")
                show_outfit())
        var codes: Array = Cosmetics.of_kind(kind)
        var own: Array = Account.owned
        var visible_codes: Array = codes.filter( func(c: String) -> bool:
                var it: Dictionary = Cosmetics.item(c)
                if String(it.get("exclusive", "")) == "dev" and not Account.is_dev():
                        return false
                return not it.has("exclusive") or own.has(c))
        var opened: int = visible_codes.filter( func(c: String) -> bool: return own.has(c)).size()
        _label(vb, "ОТКРЫТО %d ИЗ %d" % [opened, visible_codes.size()], 10, UiKit.MUTED)

        var rank: Dictionary = {"common": 1, "rare": 2, "epic": 3, "legendary": 4}
        visible_codes.sort_custom( func(a: String, b: String) -> bool:
                var ia: Dictionary = Cosmetics.item(a)
                var ib: Dictionary = Cosmetics.item(b)
                var ka: Array = [0 if ia.has("exclusive") else 1, int(rank.get(String(ia["rarity"]), 0)), 0 if own.has(a) else 1, codes.find(a)]
                var kb: Array = [0 if ib.has("exclusive") else 1, int(rank.get(String(ib["rarity"]), 0)), 0 if own.has(b) else 1, codes.find(b)]
                return ka < kb)
        var grid: = GridContainer.new()
        grid.columns = [3, 2, 1][_out_tab]
        grid.add_theme_constant_override("h_separation", 6)
        grid.add_theme_constant_override("v_separation", 6)
        vb.add_child(grid)
        var on: Variant = Account.equipped().get(kind)
        for c: String in visible_codes:
                _outfit_cell(grid, kind, c, own.has(c), on != null and String(on) == c)

        var slot: = Control.new()
        slot.custom_minimum_size = Vector2(0, 36)
        slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _scroll.get_parent().add_child(slot)
        var pick: String = _out_pick
        var locked: bool = pick != "" and (not own.has(pick) or (String(Cosmetics.item(pick).get("exclusive", "")) == "dev" and not Account.is_dev()))
        if msg != "" or locked:
                var it: Dictionary = Cosmetics.item(pick)
                var u: Variant = Account.catalog.get(pick, it).get("unlock")
                var bar: PanelContainer = MpKit.status_bar(slot, msg if msg != "" else Cosmetics.hint(u, String(it.get("exclusive", ""))), sev if msg != "" else "info", "icon_ok" if sev == "ok" and msg != "" else "")
                bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        var br: HBoxContainer = _bottom_row()
        var back: Button = _button(br, "НАЗАД", "stone", "")
        back.custom_minimum_size.x = 111
        back.pressed.connect( func() -> void : show_profile())
        var worn: bool = pick != "" and on != null and String(on) == pick
        var act: Button = UiKit.big("СНЯТЬ" if worn else "НАДЕТЬ", "stone" if worn else "blue", "", 56.0, 14)
        act.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        act.disabled = pick == "" or locked or _out_busy
        if _out_busy:
                act.text = "..."
        br.add_child(act)
        act.pressed.connect( func() -> void : _outfit_equip(kind, null if worn else pick))


func _outfit_load() -> void :
        var r: Dictionary = await Account.fetch_cosmetics()
        _out_loaded = false
        if current == "outfit":
                show_outfit("" if bool(r["ok"]) else String(r["err"]), "alarm")



func _outfit_cell(grid: GridContainer, kind: String, code: String, has: bool, worn: bool) -> void :
        var sz: Vector2 = [Vector2(94, 88), Vector2(146, 64), Vector2(298, 58)][_out_tab]
        var b: Button = MpKit.card_button(sz.y)
        b.custom_minimum_size = sz
        if code == _out_pick:
                var s2: StyleBox = UiKit.sb("wb_slot_active", 8, 2)
                for st: String in ["normal", "hover", "pressed"]:
                        b.add_theme_stylebox_override(st, s2)
        grid.add_child(b)
        var col: Color = Cosmetics.rarity_color(code)
        var v: = VBoxContainer.new()
        v.set_anchors_preset(Control.PRESET_FULL_RECT)
        v.offset_left = 4
        v.offset_right = -4
        v.offset_top = 4
        v.offset_bottom = -7
        v.alignment = BoxContainer.ALIGNMENT_CENTER
        v.add_theme_constant_override("separation", 2)
        v.mouse_filter = Control.MOUSE_FILTER_IGNORE
        b.add_child(v)
        match kind:
                "frame":
                        var cc: = CenterContainer.new()
                        cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
                        v.add_child(cc)
                        cc.add_child(MpKit.avatar_framed(code, 48.0))
                "banner":
                        var t: Texture2D = UiKit.tex(code)
                        if t != null:
                                var cc2: = CenterContainer.new()
                                cc2.mouse_filter = Control.MOUSE_FILTER_IGNORE
                                v.add_child(cc2)
                                var cut: = Control.new()
                                cut.custom_minimum_size = Vector2(138, 36)
                                cut.clip_contents = true
                                cut.mouse_filter = Control.MOUSE_FILTER_IGNORE
                                cc2.add_child(cut)
                                var r: = TextureRect.new()
                                r.texture = t
                                r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
                                r.position = Vector2(-6, 0)
                                r.size = t.get_size()
                                r.mouse_filter = Control.MOUSE_FILTER_IGNORE
                                cut.add_child(r)
                                if code == _out_pick or worn:
                                        MpKit.animate(r, UiKit.atlas_cosm_bn_anim, code)
                "title":
                        v.alignment = BoxContainer.ALIGNMENT_BEGIN
                        v.add_child(MpKit.title_label(code))
        if kind != "title":
                var nm: String = Cosmetics.name_of(code)
                var fs: int = 9 if kind == "frame" else 10
                var nl: Label = UiKit.lbl(nm, fs, col if String(Cosmetics.item(code).get("rarity", "")) == "legendary" else (UiKit.TEXT if has else UiKit.DIM), 2, 2)
                nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                nl.clip_text = true
                nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
                v.add_child(nl)
        else:
                var it: Dictionary = Cosmetics.item(code)
                var u: Variant = Account.catalog.get(code, it).get("unlock")
                var sl: Label = UiKit.lbl((Cosmetics.rarity_text(code) + (" · RGB" if String(it.get("fx", "")) == "rgb" else "")) if has else Cosmetics.hint(u, String(it.get("exclusive", ""))), 10, UiKit.MUTED if has else UiKit.DIM, 1, 2)
                sl.clip_text = true
                sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
                v.add_child(sl)

        var under: = ColorRect.new()
        under.color = Color("0b1430")
        under.mouse_filter = Control.MOUSE_FILTER_IGNORE
        under.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
        under.offset_top = -7
        under.offset_left = 3
        under.offset_right = -3
        under.offset_bottom = -2
        b.add_child(under)
        var stripe: = ColorRect.new()
        stripe.color = col
        stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
        stripe.set_anchors_preset(Control.PRESET_FULL_RECT)
        stripe.offset_top = 1
        stripe.offset_bottom = -1
        under.add_child(stripe)
        if has and Account.unseen().has(code):
                var nt: = PanelContainer.new()
                nt.add_theme_stylebox_override("panel", MpKit._flat(UiKit.GREEN))
                nt.mouse_filter = Control.MOUSE_FILTER_IGNORE
                nt.add_child(UiKit.lbl("НОВОЕ", 9, Color("0b1430"), 3, 0))
                nt.position = Vector2(3, 3)
                b.add_child(nt)
        if worn and UiKit.tex("icon_ok") != null:
                var ok: TextureRect = UiKit.icon_rect("icon_ok", 16.0)
                ok.position = Vector2(sz.x - 20, 4)
                b.add_child(ok)
        if not has:
                v.modulate.a = 0.5
                if UiKit.tex("net_lock") != null:
                        var lk: TextureRect = UiKit.icon_rect("net_lock", 16.0)
                        lk.position = Vector2(sz.x - 20, 4)
                        b.add_child(lk)
        b.pressed.connect( func() -> void :
                if _out_busy:
                        return
                _out_pick = "" if _out_pick == code else code
                Account.mark_seen(code)
                UiKit.snd("ui_select")
                show_outfit())


func _outfit_equip(kind: String, code: Variant) -> void :
        if _out_busy:
                return
        _out_busy = true
        show_outfit()
        var r: Dictionary = await Account.equip(kind, code)
        _out_busy = false
        if current != "outfit":
                return
        if bool(r["ok"]):
                UiKit.snd("ui_capture")
                _out_pick = ""
                show_outfit("НАДЕТО" if code != null else "СНЯТО", "ok")
        else:
                if int(r.get("code", 0)) == 403:
                        await Account.fetch_cosmetics()
                        if current != "outfit":
                                return
                show_outfit("ПРЕДМЕТ НЕДОСТУПЕН" if int(r.get("code", 0)) == 403 else String(r["err"]), "alarm")




var _rk_mode: String = "1v1"
var _rk_status: Array = []
var _rk_hooked: bool = false
var _rk_btn: Button = null
var _rc: Control = null
var _rc_d: Dictionary = {}
var _rc_t0: int = 0
var _rc_acc: bool = false
var _rc_dec_ok: bool = false
var _rc_expired: bool = false
var _rk_gen: int = 0
var _rc_prog: Array = [0, 0]
var _rc_ring: TextureRect = null
var _rc_sec: Label = null
var _rk_leave_ok: bool = false
var _lead_rows: Array = []
var _lead_mode: String = "1v1"
var _end_mid: String = ""
var _end_poll_n: int = 0


func _hook_ranked() -> void :
        if _rk_hooked or net == null:
                return
        _rk_hooked = true
        net.ranked_event.connect(_on_ranked_event)



func _mp_ranked_card(vb: VBoxContainer) -> void :
        _hook_ranked()
        var ok: bool = bool(Account.info.get("is_ranked_available", false))
        var played: int = int(Account.info.get("match_played", 0))
        var searching: bool = net.ranked_mode != "" and net.rtc.socket_open()
        var line: String = "СОПЕРНИКИ ВАШЕГО УРОВНЯ"
        if searching:
                line = "В ПОИСКЕ · %s" % Hud._mmss((Time.get_ticks_msec() - net.queue_t0) / 1000.0)
        elif not ok:
                line = ("ОТКРОЕТСЯ ПОСЛЕ 10 ОБЫЧНЫХ ПАРТИЙ · %d/10" % mini(played, 10)) if played < 10 else "ОТКРОЕТСЯ ПОЗЖЕ"
        elif not Ranked.me.is_empty():
                var parts: PackedStringArray = PackedStringArray()
                for m: String in ["1v1", "2v2"]:
                        parts.append("%s %s" % [Ranked.MODES_RU[m], Ranked.rating_text(Ranked.mode_row(m))])
                line = " · ".join(parts)
        var right: Control
        if searching:
                right = MpKit.icon("net_sync")
                MpKit.spin(right)
        else:
                right = UiKit.icon_rect("wb_arrow_r", 20.0)
                right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        var b: Button = MpKit.card_button(MpKit.ROW_H)
        vb.add_child(b)
        var row: HBoxContainer = MpKit._hbox(b, 10, 10)
        row.add_child(MpKit.icon("acc_ranked", true))
        MpKit._two_lines(row, "РЕЙТИНГОВЫЙ БОЙ", line, 13, UiKit.TEXT if ok else UiKit.MUTED)
        row.add_child(right)
        if not ok:
                b.modulate.a = 0.6
        b.pressed.connect( func() -> void :
                UiKit.press_fx(b)
                if not ok:
                        show_mp("СЫГРАЙТЕ ЕЩЁ %d ОБЫЧНЫХ ПАРТИЙ" % maxi(1, 10 - played) if played < 10 else "РЕЙТИНГ ОТКРОЕТСЯ ПОЗЖЕ", "info")
                        return
                show_ranked())



func show_ranked(mode: String = "", msg: String = "", sev: String = "info") -> void :
        if _mp_gate():
                return
        _hook_account()
        _hook_ranked()
        if mode != "":
                _rk_mode = mode
        if msg != "":
                _rk_status = [msg, sev]
        var first: bool = current != "ranked"
        var vb: VBoxContainer = _screen("Рейтинг", 0.45, first)
        current = "ranked"
        if first:
                Ranked.flush_pending()
                _rk_refresh()
        var searching: bool = net.ranked_mode != "" and net.rtc.socket_open()
        MpKit.tabs(vb, [["", "1V1"], ["", "2V2"], ["", "3V3", false]], Ranked.MODES.find(_rk_mode), func(i: int) -> void :
                if i == 2:
                        show_ranked("", "3V3 — СКОРО", "info")
                        return
                if searching:
                        show_ranked("", "СНАЧАЛА ОТМЕНИТЕ ПОИСК", "info")
                        return
                _rk_mode = Ranked.MODES[i]
                UiKit.snd("ui_tab")
                show_ranked())
        _rk_card(vb)
        _label(vb, {"1v1": "1 НА 1 · МАЛАЯ КАРТА · БЕЗ ИИ-СТРАН", "2v2": "2 НА 2 · СОЮЗНИК С ВАМИ С НАЧАЛА"}.get(_rk_mode, ""), 10, UiKit.MUTED)
        MpKit.section(vb, "ЛИДЕРЫ %s" % Ranked.MODES_RU[_rk_mode], "icon_stats", false, func() -> void : show_leaders(_rk_mode))
        var slot: = Control.new()
        slot.custom_minimum_size = Vector2(0, 36)
        slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _scroll.get_parent().add_child(slot)
        if not _rk_status.is_empty():
                var bar: PanelContainer = MpKit.status_bar(slot, String(_rk_status[0]), String(_rk_status[1]), "net_sync" if _rk_status[1] == "wait" else "", _rk_status[1] == "wait")
                bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        var br: HBoxContainer = _bottom_row()
        var back: Button = _button(br, "НАЗАД", "stone", "")
        back.custom_minimum_size.x = 96
        back.pressed.connect( func() -> void :
                _rk_status = []
                show_mp())
        _rk_btn = UiKit.big("", "green", "", 56.0, 14)
        _rk_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        _rk_btn.clip_text = true
        _rk_btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        _rk_btn.custom_minimum_size.x = 180
        br.add_child(_rk_btn)
        _rk_btn.pressed.connect( func() -> void :
                if net.ranked_mode != "" and net.rtc.socket_open():
                        net.unqueue_ranked()
                        return
                if Ranked.penalty() > 0:
                        return
                var w: String = net.queue_ranked(_rk_mode)
                if w != "":
                        show_ranked("", w, "alarm")
                        return
                UiKit.snd("ui_select")
                _rk_status = ["ПОДБИРАЕМ СОПЕРНИКОВ ВАШЕГО УРОВНЯ", "wait"]
                show_ranked())
        _rk_gen += 1
        _rk_tick(_rk_gen)


func _rk_refresh() -> void :
        var r: Dictionary = await Ranked.fetch_me()
        if current == "ranked":
                if not bool(r["ok"]):
                        _rk_status = [String(r["err"]), "alarm"]
                show_ranked()



func _rk_card(vb: VBoxContainer) -> void :
        var p: = PanelContainer.new()
        p.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 10, 8))
        p.custom_minimum_size = Vector2(0, 96)
        vb.add_child(p)
        var v: = VBoxContainer.new()
        v.add_theme_constant_override("separation", 4)
        p.add_child(v)
        if Ranked.me.is_empty():
                var l0: Label = UiKit.lbl("ЗАГРУЖАЕМ РЕЙТИНГ...", 12, UiKit.MUTED, 2, 2)
                l0.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                v.add_child(l0)
                return
        var row: Dictionary = Ranked.mode_row(_rk_mode)
        var games: int = int(row.get("games", 0))
        var cal: int = Ranked.calibration_games()
        if bool(row.get("calibrating", true)):
                var h: = HBoxContainer.new()
                h.add_theme_constant_override("separation", 8)
                v.add_child(h)
                h.add_child(UiKit.lbl("КАЛИБРОВКА", 18, UiKit.TEXT, 3, 3))
                h.add_child(UiKit.lbl("%d/%d" % [games, cal], 18, UiKit.GOLD, 3, 3))
                var seg: = HBoxContainer.new()
                seg.add_theme_constant_override("separation", 2)
                v.add_child(seg)
                for i in cal:
                        var c: = ColorRect.new()
                        c.color = UiKit.GOLD if i < games else Color(UiKit.DIM, 0.6)
                        c.custom_minimum_size = Vector2(26, 6)
                        seg.add_child(c)
                v.add_child(UiKit.lbl("ЕЩЁ %d ИГР ДО МЕСТА В ТАБЛИЦЕ · РЕЙТИНГ %d" % [maxi(0, cal - games), roundi(float(row.get("rating", 1000)))], 10, UiKit.MUTED, 1, 1))
                return
        var h2: = HBoxContainer.new()
        h2.add_theme_constant_override("separation", 10)
        v.add_child(h2)
        h2.add_child(UiKit.icon_rect("icon_trophy", 32.0))
        var rl: Label = UiKit.lbl(str(roundi(float(row.get("rating", 1000)))), 28, UiKit.GOLD, 3, 3)
        rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        h2.add_child(rl)
        var pv: = VBoxContainer.new()
        h2.add_child(pv)
        pv.add_child(UiKit.lbl("МЕСТО", 10, UiKit.DIM, 1, 1))
        pv.add_child(UiKit.lbl("#%d" % int(row["place"]) if row.get("place") != null else "—", 18, UiKit.TEXT, 3, 2))
        v.add_child(UiKit.lbl("ЛУЧШИЙ %d · %d ПОБЕД · %d ПОРАЖЕНИЙ" % [roundi(float(row.get("peak", 1000))), int(row.get("wins", 0)), int(row.get("losses", 0))], 11, UiKit.MUTED, 1, 1))



func _rk_tick(gen: int) -> void :
        if gen != _rk_gen or current != "ranked" or _rk_btn == null or not is_instance_valid(_rk_btn):
                return
        var searching: bool = net.ranked_mode != "" and net.rtc.socket_open()
        var pen: int = Ranked.penalty()
        if searching:
                _rk_btn.text = "%s · ОТМЕНИТЬ" % Hud._mmss((Time.get_ticks_msec() - net.queue_t0) / 1000.0)
                if _rk_btn.icon == null:
                        _rk_btn.icon = UiKit.tex("net_sync")
                _rk_btn.add_theme_stylebox_override("normal", UiKit.sb("wb_btn_stone", 14, 4, -1))
                _rk_btn.disabled = false
        elif pen > 0:
                _rk_btn.text = "ПОИСК ЧЕРЕЗ %s" % Hud._mmss(float(pen))
                _rk_btn.icon = null
                _rk_btn.disabled = true
                Ranked.me["penalty"] = pen - 1
                if pen - 1 <= 0:
                        _rk_refresh()
        else:
                _rk_btn.text = "НАЙТИ БОЙ"
                _rk_btn.icon = null
                _rk_btn.add_theme_stylebox_override("normal", UiKit.sb("wb_btn_green", 14, 4, -1))
                _rk_btn.disabled = false
        get_tree().create_timer(1.0).timeout.connect(_rk_tick.bind(gen))


func _on_ranked_event(d: Dictionary) -> void :
        var t: String = String(d.get("t", ""))
        match t:
                "queued":
                        if bool(d.get("requeued", false)):
                                _rc_close()
                                _rk_status = [String(_rk_status[0]) if not _rk_status.is_empty() and String(_rk_status[0]).ends_with("ПОИСКЕ") else "ВЫ СНОВА В ПОИСКЕ", "wait"]
                        else:
                                _rk_status = ["ПОДБИРАЕМ СОПЕРНИКОВ ВАШЕГО УРОВНЯ", "wait"]
                "unqueued":
                        _rk_status = ["ПОИСК ОТМЕНЁН", "ok"]
                "found":
                        _rc_open(d)
                        return
                "accept_progress":
                        _rc_prog = [int(d.get("n", 0)), int(d.get("of", 0))]
                        _rc_draw()
                        return
                "mm_cancel":
                        var why: String = Ranked.why_ru(String(d.get("why", "")))
                        _rc_close()
                        _rk_status = [why, "wait" if why.contains("ДАЛЬШЕ") or why.contains("ИЩЕМ") else "alarm"]
                        if current == "ranked_lobby":
                                show_ranked()
                                return
                "error":
                        _rk_status = [Ranked.why_ru(String(d.get("why", ""))), "alarm"]
                        if d.has("penalty"):
                                Ranked.me["penalty"] = int(d["penalty"])
        if current == "ranked":
                show_ranked()




func _rc_open(d: Dictionary) -> void :
        _rc_close()
        _rc_d = d
        _rc_t0 = Time.get_ticks_msec()
        _rc_acc = false
        _rc_dec_ok = false
        _rc_expired = false
        _rc_prog = [0, 0]
        var bg: = ColorRect.new()
        bg.color = Color(0, 0, 0, 0.6)
        bg.mouse_filter = Control.MOUSE_FILTER_STOP
        bg.set_anchors_preset(Control.PRESET_FULL_RECT)
        root.add_child(bg)
        _rc = bg
        UiKit.snd("ui_alarm")
        Input.vibrate_handheld(300)
        _rc_draw()


func _rc_close() -> void :
        if _rc != null and is_instance_valid(_rc):
                _rc.queue_free()
        _rc = null


func _rc_draw() -> void :
        if _rc == null or not is_instance_valid(_rc):
                return
        for ch: Node in _rc.get_children():
                ch.queue_free()
        var cc: = CenterContainer.new()
        cc.set_anchors_preset(Control.PRESET_FULL_RECT)
        _rc.add_child(cc)
        var p: = PanelContainer.new()
        p.add_theme_stylebox_override("panel", UiKit.sb("wb_window", 16, 14))
        p.custom_minimum_size = Vector2(minf(330.0, root.size.x - 16.0), 0)
        cc.add_child(p)
        var v: = VBoxContainer.new()
        v.add_theme_constant_override("separation", 8)
        p.add_child(v)
        v.add_child(UiKit.title("БОЙ НАЙДЕН", 22))
        var by: int = int(_rc_d.get("accept_by", 15))
        _label(v, "%s · ПРИМИТЕ ЗА %d С" % [Ranked.MODES_RU.get(String(_rc_d.get("mode", "")), ""), by], 11, UiKit.MUTED)
        var ring: = CenterContainer.new()
        v.add_child(ring)
        var rbox: = Control.new()
        rbox.custom_minimum_size = Vector2(64, 64)
        ring.add_child(rbox)
        _rc_ring = UiKit.icon_rect("icon_timer_ring_0", 64.0)
        rbox.add_child(_rc_ring)
        _rc_sec = UiKit.lbl("", 18, UiKit.GOLD, 3, 3)
        _rc_sec.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        _rc_sec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        _rc_sec.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        rbox.add_child(_rc_sec)
        var of: int = maxi(int(_rc_prog[1]), {"1v1": 2, "2v2": 4, "3v3": 6}.get(String(_rc_d.get("mode", "")), 2))
        var cells: = HBoxContainer.new()
        cells.alignment = BoxContainer.ALIGNMENT_CENTER
        cells.add_theme_constant_override("separation", 6)
        v.add_child(cells)
        for i in of:
                var ic: TextureRect = UiKit.icon_rect("icon_ok" if i < int(_rc_prog[0]) else "acc_pilot", 24.0)
                if i >= int(_rc_prog[0]):
                        ic.modulate.a = 0.4
                cells.add_child(ic)
        _label(v, "ПРИНЯЛИ %d/%d" % [int(_rc_prog[0]), of], 12, UiKit.TEXT)
        var left: float = float(by) - float(Time.get_ticks_msec() - _rc_t0) / 1000.0
        if _rc_acc:
                _label(v, "ЖДЁМ ОСТАЛЬНЫХ..." if int(_rc_prog[0]) < of else "ВСЕ ПРИНЯЛИ · СОБИРАЕМ ЛОББИ...", 11, UiKit.MUTED)
        elif left <= 0.0:
                _label(v, "ВРЕМЯ ВЫШЛО", 12, UiKit.RED)
        else:
                var dec: Button = UiKit.big("ОТКАЗАТЬСЯ? ШТРАФ · ЕЩЁ ТАП" if _rc_dec_ok else "ОТКАЗАТЬСЯ", "red" if _rc_dec_ok else "stone", "", 44.0, 12)
                v.add_child(dec)
                if not _rc_dec_ok:
                        _label(v, "ШТРАФ К ПОИСКУ", 10, UiKit.RED)
                dec.pressed.connect( func() -> void :
                        if not _rc_dec_ok:
                                _rc_dec_ok = true
                                _rc_draw()
                                get_tree().create_timer(3.0).timeout.connect( func() -> void :
                                        _rc_dec_ok = false
                                        _rc_draw())
                                return
                        net.accept_ranked(String(_rc_d.get("id", "")), false)
                        _rc_close()
                        _rk_status = ["ВЫ ОТКАЗАЛИСЬ · ШТРАФ К ПОИСКУ", "alarm"]
                        if current == "ranked":
                                show_ranked())
        _sep(v, 12)
        var acc: Button = UiKit.big("ВЫ ПРИНЯЛИ" if _rc_acc else "ПРИНЯТЬ", "green", "", 56.0, 15)
        acc.disabled = _rc_acc or left <= 0.0
        v.add_child(acc)
        acc.pressed.connect( func() -> void :
                _rc_acc = true
                UiKit.snd("ui_capture")
                net.accept_ranked(String(_rc_d.get("id", "")), true)
                _rc_draw())
        _rc_tick_once()


func _rc_tick_once() -> void :
        if _rc == null or not is_instance_valid(_rc) or _rc_ring == null or not is_instance_valid(_rc_ring):
                return
        var by: float = float(_rc_d.get("accept_by", 15))
        var left: float = maxf(0.0, by - float(Time.get_ticks_msec() - _rc_t0) / 1000.0)
        _rc_ring.texture = UiKit.tex("icon_timer_ring_%d" % clampi(int(floor((1.0 - left / by) * 8.0)), 0, 7))
        _rc_sec.text = str(ceili(left))
        var red: bool = left <= 5.0
        _rc_sec.add_theme_color_override("font_color", UiKit.RED if red else UiKit.GOLD)
        if left <= 0.0 and not _rc_acc:
                if not _rc_expired:
                        _rc_expired = true
                        _rc_draw()
                return
        get_tree().create_timer(0.5).timeout.connect(_rc_tick_once)




func show_ranked_lobby(msg: String = "") -> void :
        _hook_ranked()
        _rc_close()
        var vb: VBoxContainer = _screen("Рейтинговый бой", 0.45, current != "ranked_lobby")
        current = "ranked_lobby"
        var rk: Dictionary = net.rtc.ranked
        var st: Dictionary = rk.get("settings", {})
        _label(vb, "%s · %s · %d МИН" % [Ranked.MODES_RU.get(String(rk.get("mode", "")), ""), "МАЛАЯ КАРТА" if String(rk.get("mode", "")) == "1v1" else "СРЕДНЯЯ КАРТА", int(st.get("time_limit", 600)) / 60], 11, UiKit.MUTED)
        var mine: int = int(rk.get("team", 0))
        var teams: Array = rk.get("teams", [[], []])
        for ti: int in [mine, 1 - mine]:
                var team: Array = teams[ti] if ti < teams.size() else []
                var avg: int = 0
                for pl: Dictionary in team:
                        avg += int(pl.get("rating", 1000))
                MpKit.section(vb, ("ВАША КОМАНДА" if ti == mine else "СОПЕРНИКИ") + ("  · СР. %d" % (avg / maxi(1, team.size()))))
                for pl: Dictionary in team:
                        var nm: String = String(pl.get("name", ""))
                        var here: bool = net.slots.any( func(sl: Dictionary) -> bool: return String(sl.get("name", "")).to_lower() == nm.to_lower())
                        MpKit.ranked_row(vb, pl, int(pl.get("id", 0)) == 1, nm.to_lower() == Account.username().to_lower(), "ok" if here else "wait", "")
        var slot: = Control.new()
        slot.custom_minimum_size = Vector2(0, 36)
        slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _scroll.get_parent().add_child(slot)
        var line: String = msg if msg != "" else net.status_text
        if line != "":
                var bar: PanelContainer = MpKit.status_bar(slot, line, "wait", "net_sync", true)
                bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        var br: HBoxContainer = _bottom_row()
        var lv: Button = _button(br, "ПОКИНУТЬ? ШТРАФ К ПОИСКУ · ЕЩЁ ТАП" if _rk_leave_ok else "ПОКИНУТЬ", "red" if _rk_leave_ok else "stone", "")
        lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        lv.pressed.connect( func() -> void :
                if not _rk_leave_ok:
                        _rk_leave_ok = true
                        show_ranked_lobby()
                        get_tree().create_timer(3.0).timeout.connect( func() -> void :
                                if _rk_leave_ok and current == "ranked_lobby":
                                        _rk_leave_ok = false
                                        show_ranked_lobby())
                        return
                _rk_leave_ok = false
                net.leave()
                _rk_status = ["ВЫ ПОКИНУЛИ ЛОББИ · ШТРАФ К ПОИСКУ", "alarm"]
                show_ranked())




func show_end_ranked(team: int, mid: String) -> void :
        _end_mid = mid
        _end_poll_n = 0
        var vb: VBoxContainer = _screen("", 0.6)
        current = "end_ranked"
        var mine: int = RankedRules.my_team(gw)
        var won: bool = team >= 0 and team == mine
        var t: Label = UiKit.title("ПОБЕДА" if won else ("НИЧЬЯ" if team < 0 else "ПОРАЖЕНИЕ"), 30, UiKit.TITLE if won else (UiKit.GOLD if team < 0 else UiKit.RED))
        vb.add_child(t)
        t.pivot_offset = Vector2(150, 20)
        t.scale = Vector2(1.5, 1.5)
        t.create_tween().tween_property(t, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
        _label(vb, RankedRules.why_text(gw.session.verdict, mine), 12, UiKit.TEXT)
        _label(vb, "РЕЙТИНГОВЫЙ БОЙ %s · %s" % [Ranked.MODES_RU.get(String(GameConfig.ranked.get("mode", "")), ""), Hud._mmss(gw.session.elapsed())], 10, UiKit.MUTED)
        var slot: = Control.new()
        slot.custom_minimum_size = Vector2(0, 36)
        slot.name = "EndStatus"
        vb.add_child(slot)
        var box: = VBoxContainer.new()
        box.name = "EndTeams"
        box.add_theme_constant_override("separation", 4)
        vb.add_child(box)
        _end_status(slot, "ЖДЁМ ОТЧЁТЫ ИГРОКОВ...", "wait")
        _end_teams(box, {})
        var br: HBoxContainer = _bottom_row()
        var m: Button = _button(br, "В МЕНЮ", "stone", "")
        m.custom_minimum_size.x = 111
        m.pressed.connect( func() -> void :
                net.leave()
                request.emit("main_menu"))
        var again: Button = _ibutton(br, "ЕЩЁ БОЙ", "green", "", "acc_ranked", 56.0)
        again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        again.pressed.connect( func() -> void :
                var md: String = String(GameConfig.ranked.get("mode", "1v1"))
                net.leave()
                request.emit("main_menu")
                await get_tree().process_frame
                _mp_tab = 1
                show_ranked(md))
        _end_poll()


func _end_status(slot: Control, text: String, sev: String) -> void :
        for ch: Node in slot.get_children():
                ch.queue_free()
        var icon: String = {"wait": "net_sync", "ok": "icon_ok", "info": "net_warn", "alarm": "net_signal_lost"}.get(sev, "")
        var bar: PanelContainer = MpKit.status_bar(slot, text, sev, icon, sev == "wait")
        bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)



func _end_teams(box: VBoxContainer, info: Dictionary) -> void :
        for ch: Node in box.get_children():
                ch.queue_free()
        var mine: int = RankedRules.my_team(gw)
        var by_name: Dictionary = {}
        for pl: Dictionary in info.get("players", []):
                by_name[String(pl.get("username", "")).to_lower()] = pl
        var cos_of: Dictionary = {}
        for team: Array in net.rtc.ranked.get("teams", []):
                for pl2: Dictionary in team:
                        cos_of[String(pl2.get("name", "")).to_lower()] = pl2
        var names: Array = GameConfig.ranked.get("names", [])
        var teams: Array = GameConfig.ranked.get("teams", [])
        for ti: int in [mine, 1 - mine]:
                MpKit.section(box, "ВАША КОМАНДА" if ti == mine else "СОПЕРНИКИ")
                for i in names.size():
                        if i >= teams.size() or int(teams[i]) != ti:
                                continue
                        var nm: String = String(names[i])
                        var r: Dictionary = by_name.get(nm.to_lower(), {})
                        var pl3: Dictionary = (cos_of.get(nm.to_lower(), {"name": nm}) as Dictionary).duplicate()
                        pl3["name"] = nm
                        var d: Variant = r.get("delta")
                        if r.has("rating_after") and r["rating_after"] != null:
                                pl3["rating"] = roundi(float(r["rating_after"]))
                        var tail: String = ""
                        if d != null:
                                tail = ("+%d" if float(d) >= 0.0 else "%d") % roundi(float(d))
                        MpKit.ranked_row(box, pl3, bool(r.get("was_host", false)), nm.to_lower() == Account.username().to_lower(), 
                                "left" if bool(r.get("left_early", false)) else "", tail)


func _end_poll() -> void :
        if current != "end_ranked" or _end_mid == "":
                return
        _end_poll_n += 1
        var r: Dictionary = await Ranked.match_info(_end_mid)
        if current != "end_ranked":
                return
        var slot: Control = _inner.get_node_or_null("EndStatus")
        var box: VBoxContainer = _inner.get_node_or_null("EndTeams")
        if slot == null or box == null:
                return
        if int(r["code"]) == 200 and r["data"] is Dictionary:
                var st: String = String((r["data"] as Dictionary).get("status", "ongoing"))
                _end_teams(box, r["data"])
                match st:
                        "counted":
                                _end_status(slot, "РЕЙТИНГ ОБНОВЛЁН", "ok")
                                Account.fetch_cosmetics()
                                Ranked.fetch_me()
                                return
                        "disputed":
                                _end_status(slot, "РЕЗУЛЬТАТ ОСПОРЕН · РЕЙТИНГ НЕ ИЗМЕНЁН", "info")
                                return
                        "void":
                                _end_status(slot, "ПАРТИЯ НЕ ЗАСЧИТАНА · РЕЙТИНГ НЕ ИЗМЕНЁН", "info")
                                return
                _end_status(slot, "ЖДЁМ ОТЧЁТЫ ИГРОКОВ..." + (" · ДО 2 МИН" if _end_poll_n > 6 else ""), "wait")
        elif int(r["code"]) == 0:
                _end_status(slot, "НЕТ СВЯЗИ · ОТЧЁТ ОТПРАВИМ САМИ, МОЖНО ВЫЙТИ", "alarm")
        elif int(r["code"]) == 404:
                _end_status(slot, "ИТОГ НЕДОСТУПЕН", "alarm")
                return
        if _end_poll_n >= 36:
                _end_status(slot, "ИТОГ ЕЩЁ СЧИТАЕТСЯ · ЗАГЛЯНИТЕ В РЕЙТИНГ ПОЗЖЕ", "info")
                return
        get_tree().create_timer(5.0).timeout.connect(_end_poll)




func show_leaders(mode: String = "") -> void :
        if mode != "":
                _lead_mode = mode
        var first: bool = current != "leaders"
        var vb: VBoxContainer = _screen("Лидеры", 0.45, first)
        current = "leaders"
        MpKit.tabs(vb, [["", "1V1"], ["", "2V2"], ["", "3V3"]], Ranked.MODES.find(_lead_mode), func(i: int) -> void :
                _lead_mode = Ranked.MODES[i]
                _lead_rows = []
                UiKit.snd("ui_tab")
                show_leaders())
        var list: = VBoxContainer.new()
        list.name = "LeadList"
        list.add_theme_constant_override("separation", 2)
        vb.add_child(list)
        if _lead_rows.is_empty():
                MpKit.placeholder(list, "net_sync", "ЗАГРУЖАЕМ...", "", true, 96.0)
                _lead_load(0)
        elif (_lead_rows[0] as Array).is_empty():
                MpKit.placeholder(list, "icon_trophy", "ТАБЛИЦА ПОКА ПУСТА", "СЮДА ПОПАДАЮТ ПОСЛЕ %d ИГР" % Ranked.calibration_games(), false, 120.0)
        else:
                for e: Dictionary in _lead_rows[0]:
                        _lead_row(list, e, String(e.get("username", "")).to_lower() == Account.username().to_lower())
                if (_lead_rows[0] as Array).size() >= 50 * int(_lead_rows[1]):
                        var more: Button = UiKit.big("ЕЩЁ 50", "stone", "", 44.0, 12)
                        more.pressed.connect( func() -> void : _lead_load((_lead_rows[0] as Array).size()))
                        list.add_child(more)

        var row: Dictionary = Ranked.mode_row(_lead_mode)
        var own: = PanelContainer.new()
        own.add_theme_stylebox_override("panel", UiKit.sb("wb_slot_active", 8, 2))
        own.custom_minimum_size = Vector2(0, 52)
        _scroll.get_parent().add_child(own)
        var oh: = HBoxContainer.new()
        oh.add_theme_constant_override("separation", 8)
        own.add_child(oh)
        oh.add_child(UiKit.lbl("#%d" % int(row["place"]) if row.get("place") != null else "—", 13, UiKit.GOLD, 3, 2))
        oh.add_child(MpKit.avatar_framed(Account.equipped().get("frame"), 48.0))
        var ol: Label = UiKit.lbl(Account.username() if not bool(row.get("calibrating", true)) else "ВЫ · КАЛИБРОВКА %d/%d" % [int(row.get("games", 0)), Ranked.calibration_games()], 12, UiKit.GOLD, 3, 2)
        ol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        ol.clip_text = true
        oh.add_child(ol)
        oh.add_child(UiKit.lbl(str(roundi(float(row.get("rating", 1000)))), 13, UiKit.GOLD, 3, 2))
        var br: HBoxContainer = _bottom_row()
        var back: Button = _button(br, "НАЗАД", "stone", "")
        back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        back.pressed.connect( func() -> void :
                _lead_rows = []
                show_ranked(_lead_mode))


func _lead_load(offset: int) -> void :
        var r: Dictionary = await Ranked.leaderboard(_lead_mode, offset)
        if current != "leaders":
                return
        var got: Array = (r["data"] as Dictionary).get("entries", []) if int(r["code"]) == 200 and r["data"] is Dictionary else []
        if offset == 0:
                _lead_rows = [got, 1]
        else:
                (_lead_rows[0] as Array).append_array(got)
                _lead_rows[1] = int(_lead_rows[1]) + 1
        show_leaders()


func _lead_row(list: VBoxContainer, e: Dictionary, me: bool) -> void :
        var p: = PanelContainer.new()
        p.add_theme_stylebox_override("panel", UiKit.sb("wb_slot_active" if me else "wb_panel_dark", 8, 2))
        p.custom_minimum_size = Vector2(0, 52)
        list.add_child(p)
        var h: = HBoxContainer.new()
        h.add_theme_constant_override("separation", 8)
        p.add_child(h)
        var place: int = int(e.get("place", 0))
        var pl: Label = UiKit.lbl(str(place), 13, [UiKit.GOLD, Color("c8cdd6"), Color("c08a52")][place - 1] if place >= 1 and place <= 3 else UiKit.MUTED, 3, 2)
        pl.custom_minimum_size.x = 32
        pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        h.add_child(pl)
        var cos: Dictionary = e.get("cosmetics", {}) if e.get("cosmetics") is Dictionary else {}
        h.add_child(MpKit.avatar_framed(cos.get("frame"), 48.0))
        var v: = VBoxContainer.new()
        v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        v.alignment = BoxContainer.ALIGNMENT_CENTER
        h.add_child(v)
        var nl: Label = UiKit.lbl(String(e.get("username", "")), 13, UiKit.GOLD if me else UiKit.TEXT, 3, 2)
        nl.clip_text = true
        v.add_child(nl)
        var tc: String = Cosmetics.shown("title", cos.get("title"))
        if tc != "":
                v.add_child(MpKit.title_label(tc, 10))
        else:
                var g: int = int(e.get("games", 0))
                v.add_child(UiKit.lbl("%d ИГР · %d%% ПОБЕД" % [g, roundi(100.0 * float(e.get("wins", 0)) / maxf(1.0, float(g)))], 10, UiKit.MUTED, 1, 1))
        var rv: = VBoxContainer.new()
        rv.alignment = BoxContainer.ALIGNMENT_CENTER
        h.add_child(rv)
        rv.add_child(UiKit.lbl(str(roundi(float(e.get("rating", 0)))), 13, UiKit.GOLD, 3, 2))
        rv.add_child(UiKit.lbl("%d–%d" % [int(e.get("wins", 0)), int(e.get("losses", 0))], 10, UiKit.MUTED, 1, 1))


var _social := preload("res://net/social_link.gd").new()
var _top_presence_labels: Dictionary = {}
var _social_notification: Button
var _social_mode: String = ""
var _social_back: Callable
var _social_content: VBoxContainer
var _social_query: LineEdit
var _social_search: Array = []
var _social_signature: String = ""
var _chat_user: String = ""
var _chat_log: VBoxContainer
var _chat_send: Button
var _chat_permission: Label
var _player_actions: VBoxContainer
var _player_actions_user: Dictionary = {}
var _player_actions_back: Callable
var _chat_input: LineEdit
var _chat_before: int = 0
var _chat_count: int = -1
var _chat_pending: String = ""
var _chat_messages: Array = []
var _invite_panel: HBoxContainer
var _invite_label: Label
var _shown_invite: String = ""
var _joining_invite: bool = false


func _social_button(parent: Control, title: String, action: Callable, colour: String = "blue") -> Button:
        var button: Button = _button(parent, title, colour, "")
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.pressed.connect(action)
        return button


func _send_social(action: String, data: Dictionary = {}) -> bool:
        if _social.send(action, data):
                return true
        _mp_toast("Связь с сервером восстанавливается")
        return false


func _social_tick() -> void:
        if not _social.state_changed.is_connected(_social_state_changed):
                _social.state_changed.connect(_social_state_changed)
                _social.received.connect(_social_received)
        Account.load_state()
        NetConfig.load_cfg()
        _social.tick(net.room_code if net != null and net.mode == NetSession.Mode.ONLINE else "")
        _update_invitation()


func _update_social_notification() -> void:
        if is_instance_valid(_social_notification):
                var count: int = (_social.state.get("incoming", []) as Array).size() + (_social.state.get("invites", []) as Array).size() + int(_social.state.get("unread", 0))
                _social_notification.text = "Уведомления (%d)" % count if count > 0 else "Уведомления"


func _social_state_changed() -> void:
        if not _social.ready:
                _joining_invite = false
                _chat_pending = ""
                _chat_count = -1
        if not visible:
                return
        _update_social_notification()
        if current == "mp":
                var connection: String = "%s|%s|%s" % [_social.ready, Account.is_authenticated(), _social.error_text if _mp_tab != 0 else ""]
                if _social_signature != connection:
                        _social_signature = connection
                        show_mp()
        elif current == "leaderboard":
                var online: Array = _social.state.get("online_users", [])
                for nick: String in _top_presence_labels:
                        var label: Label = _top_presence_labels[nick]
                        if is_instance_valid(label):
                                label.visible = online.has(nick)
        elif current == "social":
                _render_social()
        elif current == "player_profile":
                _render_player_actions()
        elif current == "friend_chat":
                for friend: Dictionary in _social.state.get("conversations", []):
                        if friend["username"] == _chat_user and int(friend.get("message_count", 0)) != _chat_count:
                                _social.send("chat", {"username": _chat_user})
                        elif friend["username"] == _chat_user:
                                _chat_access(bool(friend.get("can_message", false)))
        elif current == "lobby":
                var roster_signature: String = str(hash(_social.state.get("roster", {})))
                if roster_signature != _social_signature:
                        _social_signature = roster_signature
                        show_lobby()


func _show_social(mode: String, back: Callable) -> void:
        var title: String = {"friends": "Друзья", "notifications": "Уведомления", "invite": "Пригласить друзей"}[mode]
        var vb: VBoxContainer = _screen(title, 0.45, true)
        current = "social"
        _social_mode = mode
        _social_back = back
        _social_search = []
        if mode == "friends":
                _social_query = MpKit.field(vb, "Поиск по нику", "Ник", "nick")["edit"]
                var search: Callable = func() -> void:
                        var query: String = _social_query.text.strip_edges()
                        var result: Dictionary = await Account.search_profiles(query)
                        if current == "social" and _social_mode == "friends" and is_instance_valid(_social_query) and _social_query.text.strip_edges() == query:
                                _social_search = result.get("list", [])
                                _render_social()
                _social_query.text_submitted.connect(func(_value: String) -> void: search.call())
                _social_button(vb, "Найти", search)
        _social_content = VBoxContainer.new()
        vb.add_child(_social_content)
        _social_button(_bottom_row(), "Назад", back, "stone")
        _render_social()


func _render_social() -> void:
        if not is_instance_valid(_social_content):
                return
        for child: Node in _social_content.get_children():
                _social_content.remove_child(child)
                child.queue_free()
        if not _social.ready:
                _label(_social_content, "Подключение к серверу…", 12, UiKit.MUTED)
                return
        if _social_mode == "notifications":
                for invite: Dictionary in _social.state.get("invites", []):
                        _social_button(_social_content, "Приглашение от %s" % invite["from"], func() -> void: _accept_invitation(invite["id"]))
                for friend: Dictionary in _social.state.get("conversations", []):
                        if int(friend["unread"]) > 0:
                                var nick: String = friend["username"]
                                _social_button(_social_content, "%s · Сообщения (%d)" % [nick, int(friend["unread"])], func() -> void: _inspect_player(nick, {}, func() -> void: _show_social("notifications", _social_back)))
                for player: Dictionary in _social.state.get("incoming", []):
                        var nick: String = player["username"]
                        _label(_social_content, "Заявка от %s" % nick, 13, UiKit.TEXT)
                        var row := HBoxContainer.new()
                        _social_content.add_child(row)
                        _social_button(row, "Принять", func() -> void: _send_social("accept", {"username": nick}))
                        _social_button(row, "Отклонить", func() -> void: _send_social("decline", {"username": nick}))
                if _social_content.get_child_count() == 0:
                        _label(_social_content, "Новых уведомлений нет", 12, UiKit.MUTED)
                return
        for friend: Dictionary in _social.state.get("friends", []):
                var nick: String = friend["username"]
                if _social_mode == "invite":
                        if friend["online"]:
                                _social_button(_social_content, nick, func() -> void: _send_social("invite", {"username": nick, "room": net.room_code}))
                        continue
                var subtitle: String = "В СЕТИ · ОТКРЫТЬ ПРОФИЛЬ" if friend["online"] else "ОТКРЫТЬ ПРОФИЛЬ"
                MpKit.choice_card(_social_content, "net_players", nick, subtitle, false, func() -> void:
                        _inspect_player(nick, {}, func() -> void: _show_social("friends", _social_back)))
        if _social_content.get_child_count() == 0:
                _label(_social_content, "Нет друзей в сети" if _social_mode == "invite" else "Список друзей пуст", 12, UiKit.MUTED)
        if _social_mode == "friends":
                for player: Dictionary in _social.state.get("outgoing", []):
                        var nick: String = player["username"]
                        _social_button(_social_content, "Отменить заявку · %s" % nick, func() -> void: _send_social("cancel", {"username": nick}))
                for player: Dictionary in _social_search:
                        var nick: String = player["username"]
                        if nick.nocasecmp_to(Account.username()) != 0:
                                MpKit.choice_card(_social_content, "net_players", nick, "ОТКРЫТЬ ПРОФИЛЬ", false, func() -> void: _inspect_player(nick, {}, func() -> void: _show_social("friends", _social_back)))


func _show_friend_chat(nick: String, back: Callable) -> void:
        var vb: VBoxContainer = _screen("Сообщения: " + nick, 0.45, true)
        current = "friend_chat"
        _chat_user = nick
        _chat_before = 0
        _chat_count = -1
        _chat_pending = ""
        _chat_messages = []
        _social_button(vb, "Ранние сообщения", func() -> void:
                if _chat_before > 0:
                        _send_social("chat", {"username": nick, "before": _chat_before}))
        _chat_log = VBoxContainer.new()
        vb.add_child(_chat_log)
        _chat_input = MpKit.field(vb, "Сообщение", "Сообщение", "nick")["edit"]
        _chat_input.max_length = 1000
        _chat_permission = _label(vb, "Загрузка переписки…", 11, UiKit.MUTED)
        _chat_input.editable = false
        var send: Callable = func() -> void:
                var body: String = _chat_input.text.strip_edges()
                if _chat_input.editable and body != "" and _chat_pending == "" and _send_social("message", {"username": nick, "body": body}):
                        _chat_pending = body
        _chat_input.text_submitted.connect(func(_value: String) -> void: send.call())
        var footer: HBoxContainer = _bottom_row()
        _social_button(footer, "Назад", back, "stone")
        _chat_send = _social_button(footer, "Отправить", send, "green")
        _chat_send.disabled = true
        _send_social("chat", {"username": nick})


func _chat_access(allowed: bool) -> void:
        if is_instance_valid(_chat_input) and is_instance_valid(_chat_send):
                _chat_input.editable = allowed
                _chat_send.disabled = not allowed
                _chat_permission.text = "" if allowed else "Игрок принимает сообщения только от друзей."


func _social_received(result: Dictionary) -> void:
        var action: String = result.get("action", "")
        if action == "join_invite":
                _joining_invite = false
        if action == "message" and current == "friend_chat" and result.get("username") == _chat_user:
                if result.get("ok", false) and _chat_input.text.strip_edges() == _chat_pending:
                        _chat_input.clear()
                _chat_pending = ""
        if not result.get("ok", false):
                if current == "friend_chat" and action in ["chat", "message"]:
                        _chat_access(false)
                _mp_toast(String(result.get("why", "Действие недоступно")))
                return
        match action:
                "request":
                        _mp_toast("Заявка отправлена")
                "invite":
                        _mp_toast("Приглашение отправлено")
                "join_invite":
                        if net != null and not net.go:
                                if net.active():
                                        net.leave()
                                _mp_join_code(String(result["room"]), false)
                "message":
                        if current == "friend_chat" and result.get("username") == _chat_user:
                                _social.send("chat", {"username": _chat_user})
                "chat":
                        if current == "friend_chat" and result.get("username") == _chat_user and is_instance_valid(_chat_log):
                                _chat_access(bool(result.get("can_message", false)))
                                _chat_before = int(result.get("before", 0))
                                if not result.get("older", false):
                                        _chat_count = int(result.get("message_count", 0))
                                _chat_messages = result.get("messages", []) + _chat_messages if result.get("older", false) else result.get("messages", [])
                                for child: Node in _chat_log.get_children():
                                        _chat_log.remove_child(child)
                                        child.queue_free()
                                for message: Dictionary in _chat_messages:
                                        var line: Label = _label(_chat_log, "%s  %s" % [message["from"], message["body"]], 12, UiKit.TEXT)
                                        line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _update_invitation() -> void:
        if root == null:
                return
        var invites: Array = _social.state.get("invites", [])
        var elapsed: int = (Time.get_ticks_msec() - int(_social.state.get("received_at", 0))) / 1000
        var next: Dictionary = {}
        if visible and not (net != null and net.go):
                for invite: Dictionary in invites:
                        if int(invite["seconds"]) > elapsed:
                                next = invite
                                break
        var key: String = next.get("id", "")
        if key != _shown_invite:
                _shown_invite = key
                if is_instance_valid(_invite_panel):
                        _invite_panel.queue_free()
                if key != "":
                        _invite_panel = HBoxContainer.new()
                        _invite_panel.z_index = 20
                        root.add_child(_invite_panel)
                        _invite_panel.position = Vector2(12, _safe_tb().x + 8)
                        _invite_label = _label(_invite_panel, "", 13, UiKit.TEXT)
                        _social_button(_invite_panel, "Принять", func() -> void: _accept_invitation(key))
                        _social_button(_invite_panel, "Отклонить", func() -> void: _send_social("decline_invite", {"invite": key}))
        if key != "":
                _invite_label.text = "%s приглашает в лобби · %d с" % [next["from"], int(next["seconds"]) - elapsed]


func _accept_invitation(key: String) -> void:
        if net == null or net.go or _joining_invite:
                return
        if not net.active():
                _joining_invite = _send_social("join_invite", {"invite": key})
                return
        var confirm := ConfirmationDialog.new()
        confirm.dialog_text = "Выйти из текущей комнаты и принять приглашение?"
        add_child(confirm)
        confirm.confirmed.connect(func() -> void:
                if not net.go:
                        _joining_invite = _send_social("join_invite", {"invite": key})
                confirm.queue_free())
        confirm.canceled.connect(confirm.queue_free)
        confirm.popup_centered()


func show_net_auth_prompt(on_success: Callable = Callable(), on_cancel: Callable = Callable()) -> void:
        _show_online_auth(false, on_success if on_success.is_valid() else show_mp, on_cancel if on_cancel.is_valid() else show_mp)


func _show_online_auth(registering: bool, on_success: Callable, on_cancel: Callable) -> void:
        var vb: VBoxContainer = _screen("Регистрация" if registering else "Вход", 0.55, true)
        current = "net_auth_prompt"
        var nick: LineEdit = MpKit.field(vb, "Ник", "Ник", "nick")["edit"]
        var password: LineEdit = MpKit.field(vb, "Пароль", "Пароль", "password")["edit"]
        password.secret = true
        var repeat: LineEdit
        if registering:
                repeat = MpKit.field(vb, "Повторите пароль", "Пароль", "password")["edit"]
                repeat.secret = true
        var status: Label = _label(vb, "", 12, UiKit.MUTED)
        var switch: Button = _nav_row(vb, "УЖЕ ЕСТЬ АККАУНТ" if registering else "РЕГИСТРАЦИЯ", "ВОЙТИ ПО НИКУ" if registering else "СОЗДАТЬ АККАУНТ", func() -> void: _show_online_auth(not registering, on_success, on_cancel))
        var footer: HBoxContainer = _bottom_row()
        var back: Button = _button(footer, "НАЗАД", "stone", "")
        back.custom_minimum_size.x = 111
        back.pressed.connect(on_cancel)
        var submit: Button = _ibutton(footer, "СОЗДАТЬ АККАУНТ" if registering else "ВОЙТИ", "green", "", "net_globe", 48.0)
        submit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var form: Control = screen
        submit.pressed.connect(func() -> void:
                if registering and password.text != repeat.text:
                        status.text = "Пароли не совпадают"
                        return
                submit.disabled = true
                switch.disabled = true
                status.text = "Подключение к серверу…"
                var result: Dictionary
                if registering:
                        result = await Account.register(nick.text, password.text)
                else:
                        result = await Account.login(nick.text, password.text)
                if screen != form or not is_instance_valid(submit):
                        return
                if result.get("ok", false):
                        _mp_tab = 1
                        on_success.call()
                else:
                        status.text = String(result.get("err", "Ошибка входа"))
                        submit.disabled = false
                        switch.disabled = false
        )


var _lead_metric: String = "hours"
var _lead_data: Array = []
var _lead_search: String = ""

func show_leaderboard(metric: String = "") -> void:
        _top_presence_labels.clear()
        if metric != "":
                _lead_metric = metric
        var vb: VBoxContainer = _screen("Таблица лидеров", 0.45, current != "leaderboard")
        _panel.custom_minimum_size = Vector2(minf(350.0, root.size.x - 16.0), 0)
        current = "leaderboard"
        _top = true
        
        var m_idx: int = 0
        match _lead_metric:
                "hours": m_idx = 0
                "wins": m_idx = 1
                "matches": m_idx = 2
        
        MpKit.tabs(vb, [["icon_time", "ПО ЧАСАМ"], ["acc_ranked", "ПО ПОБЕДАМ"], ["icon_stats", "ПО МАТЧАМ"]], m_idx, func(i: int) -> void:
                var metrics: Array = ["hours", "wins", "matches"]
                _lead_metric = metrics[i]
                _lead_search = ""
                show_leaderboard()
        )
        
        var sr: HBoxContainer = HBoxContainer.new()
        sr.add_theme_constant_override("separation", 6)
        vb.add_child(sr)
        
        var se: LineEdit = LineEdit.new()
        se.placeholder_text = "Поиск игрока по нику..."
        se.text = _lead_search
        se.custom_minimum_size = Vector2(0, 40)
        se.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        se.right_icon = UiKit.tex("net_search" if UiKit.tex("net_search") != null else "net_edit")
        sr.add_child(se)
        
        var list_box: VBoxContainer = VBoxContainer.new()
        list_box.add_theme_constant_override("separation", 6)
        vb.add_child(list_box)
        
        MpKit.placeholder(list_box, "net_sync", "ЗАГРУЗКА ТОПА...", "", true, 80.0)
        
        var fill_rows: Callable = func(players: Array) -> void:
                if not is_instance_valid(list_box):
                        return
                for ch in list_box.get_children():
                        ch.queue_free()
                if players.is_empty():
                        MpKit.placeholder(list_box, "net_players", "ИГРОКИ НЕ НАЙДЕНЫ", "", false, 72.0)
                        return
                for idx in players.size():
                        var p_dict: Dictionary = players[idx]
                        var rank_num: int = int(p_dict.get("rank", idx + 1))
                        _render_lead_row(list_box, rank_num, p_dict)
        
        se.text_changed.connect(func(query: String) -> void:
                _lead_search = query.strip_edges()
                if _lead_search == "":
                        fill_rows.call(_lead_data)
                else:
                        var filtered: Array = _lead_data.filter(func(u: Dictionary) -> bool:
                                return String(u.get("username", "")).to_lower().contains(_lead_search.to_lower())
                        )
                        if filtered.size() < 5 and query.length() >= 2:
                                var s_res: Dictionary = await Account.search_profiles(_lead_search)
                                if is_instance_valid(list_box) and _lead_search == query.strip_edges():
                                        var s_list: Array = s_res.get("list", s_res.get("users", []))
                                        fill_rows.call(s_list if not s_list.is_empty() else filtered)
                        else:
                                fill_rows.call(filtered)
        )
        
        var br: HBoxContainer = _bottom_row()
        var back: Button = _button(br, "НАЗАД", "stone", "")
        back.custom_minimum_size.x = 111
        back.pressed.connect(func() -> void: show_mp())

        var rf: Button = _ibutton(br, "ОБНОВИТЬ", "blue", "", "net_refresh", 46.0)
        rf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        rf.pressed.connect(func() -> void: show_leaderboard())


        # Fetch top from server
        var res: Dictionary = await Account.get_top(_lead_metric, 100)
        if not is_instance_valid(list_box) or list_box.is_queued_for_deletion() or current != "leaderboard":
                return
        if not bool(res.get("ok", false)):
                for ch in list_box.get_children():
                        ch.queue_free()
                MpKit.placeholder(list_box, "net_err", "ОШИБКА ЗАГРУЗКИ", String(res.get("err", "Не удалось связаться с сервером")), false, 72.0)
                return
        _lead_data = res.get("list", res.get("top", []))
        fill_rows.call(_lead_data)
        


func _render_lead_row(parent: Control, rank: int, u: Dictionary) -> Control:
        var b: Button = MpKit.card_button(64.0)
        parent.add_child(b)
        
        var cos: Dictionary = u.get("cosmetics", {}) if u.get("cosmetics") is Dictionary else {}
        MpKit.banner_bg(b, cos.get("banner"))
        
        var row: HBoxContainer = MpKit._hbox(b, 8, 8)
        
        var r_col: Color = UiKit.GOLD if rank == 1 else (Color("c0c0c0") if rank == 2 else (Color("cd7f32") if rank == 3 else UiKit.DIM))
        var rl: Label = UiKit.lbl("#%d" % rank, 14 if rank <= 3 else 12, r_col, 3, 2)
        rl.custom_minimum_size = Vector2(36, 0)
        rl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        row.add_child(rl)
        
        var a_b64: String = String(u.get("avatar_b64", u.get("avatar", "")))
        var a_tex: Texture2D = Account.get_avatar_texture(a_b64)
        row.add_child(MpKit.avatar_framed(cos.get("frame"), 44.0, a_tex))
        
        var v: VBoxContainer = VBoxContainer.new()
        v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        v.alignment = BoxContainer.ALIGNMENT_CENTER
        v.add_theme_constant_override("separation", 2)
        v.mouse_filter = Control.MOUSE_FILTER_IGNORE
        row.add_child(v)
        
        var nh: HBoxContainer = HBoxContainer.new()
        nh.add_theme_constant_override("separation", 4)
        nh.mouse_filter = Control.MOUSE_FILTER_IGNORE
        v.add_child(nh)
        
        var uname: String = String(u.get("username", u.get("name", u.get("nick", "Игрок"))))
        var is_dev: bool = bool(u.get("is_dev", false)) or Account.is_dev_name(uname)

        var nl: Label = UiKit.lbl(uname, 13, UiKit.GOLD if is_dev else UiKit.TEXT, 3, 2)
        nh.add_child(nl)
        
        if is_dev:
                nh.add_child(MpKit.dev_badge_button(uname))
        
        var presence: Label = UiKit.lbl("В СЕТИ", 9, UiKit.GREEN, 1, 0)
        nh.add_child(presence)
        presence.visible = bool(u.get("online", false))
        _top_presence_labels[uname] = presence

        var total_w: int = int(u.get("total_wins", int(u.get("wins", 0)) + int(u.get("solo_wins", 0))))
        var matches_cnt: int = int(u.get("matches_played", u.get("matches", 0)))
        var play_s: float = float(u.get("playtime_s", float(u.get("hours", 0.0)) * 3600.0))
        var sub: String = "Побед: %d · Матчей: %d · Часов: %s" % [
                total_w,
                matches_cnt,
                Account.format_hours(play_s)
        ]
        var sl: Label = UiKit.lbl(sub, 10, UiKit.MUTED, 1, 1)
        v.add_child(sl)
        
        var stat_text: String
        match _lead_metric:
                "hours":
                        stat_text = "%s Ч" % Account.format_hours(play_s)
                "wins":
                        stat_text = "%d ПОБЕД" % total_w
                "matches":
                        stat_text = "%d ИГР" % matches_cnt
        var stat_l: Label = UiKit.lbl(stat_text, 13, UiKit.GOLD, 3, 2)
        stat_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        row.add_child(stat_l)

        b.pressed.connect(func() -> void:
                UiKit.press_fx(b)
                _inspect_player(uname, cos, func() -> void: show_leaderboard())
        )
        return b


func show_player_profile(u: Dictionary, return_cb: Callable = Callable()) -> void:
        _player_actions = null
        var uname: String = String(u.get("username", u.get("name", u.get("nick", "Игрок"))))
        var vb: VBoxContainer = _screen("Профиль: " + uname, 0.45, true)
        _panel.custom_minimum_size = Vector2(minf(350.0, root.size.x - 16.0), 0)
        current = "player_profile"
        _top = true
        
        var is_dev: bool = bool(u.get("is_dev", false)) or Account.is_dev_name(uname)
        var registered: bool = bool(u.get("is_registered", u.get("registered", false)))
        var cos: Dictionary = u.get("cosmetics", {}) if u.get("cosmetics") is Dictionary else {}
        var a_b64: String = String(u.get("avatar_b64", u.get("avatar", "")))
        
        var sub: String = "В СЕТИ" if u.get("online", false) else "ПРОФИЛЬ ИГРОКА"
        MpKit.player_card(vb, uname, sub, cos, 72.0, Callable(), null, is_dev, a_b64)
        
        var flag: String = NetSession.clean_flag(u.get("flag", ""))
        if flag != "":
                vb.add_child(FlagEditor.flag_pic(flag, 30, 20, 2, 2))
        if u.has("load_error"):
                MpKit.status_bar(vb, String(u["load_error"]), "alarm", "net_warn")
                _nav_row(vb, "ПОВТОРИТЬ", "ЗАГРУЗИТЬ ПРОФИЛЬ", func() -> void: _inspect_player(uname, cos, return_cb))
                _social_button(_bottom_row(), "Назад", return_cb if return_cb.is_valid() else show_leaderboard, "stone")
                return
        if registered and Account.is_authenticated() and uname.nocasecmp_to(Account.username()) != 0:
                _player_actions = VBoxContainer.new()
                vb.add_child(_player_actions)
                _player_actions_user = u
                _player_actions_back = return_cb
                _render_player_actions()

        if is_dev:
                var dev_sb: PanelContainer = MpKit.status_bar(vb, "РАЗРАБОТЧИК ПОРТА DRONEFLAMES", "ok", "mod_verified")
                dev_sb.mouse_filter = Control.MOUSE_FILTER_STOP
                dev_sb.gui_input.connect(func(ev: InputEvent) -> void:
                        if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
                                UiKit.snd("ui_click")
                                MpKit.show_dev_verified_dialog(uname)
                )
        
        var total_w: int = int(u.get("total_wins", int(u.get("wins", 0)) + int(u.get("solo_wins", 0))))
        var matches_cnt: int = int(u.get("matches_played", u.get("matches", 0)))
        var play_s: float = float(u.get("playtime_s", float(u.get("hours", 0.0)) * 3600.0))
        
        MpKit.section(vb, "СТАТИСТИКА")
        MpKit.stat_card(vb, "ВРЕМЯ В ИГРЕ", "ЧАСЫ И МИНУТЫ", Account.format_hours(play_s), false, "icon_time")
        MpKit.stat_card(vb, "ПОБЕДЫ", "СОЛО И ОНЛАЙН", str(total_w), false, "acc_ranked")
        MpKit.stat_card(vb, "МАТЧЕЙ СЫГРАНО", "ВСЕГО ПАРТИЙ", str(matches_cnt), false, "icon_stats")
        
        var ls_raw: Variant = u.get("last_seen", 0)
        var ls_str: String = ""
        if ls_raw is int and int(ls_raw) > 0:
                var dt: Dictionary = Time.get_datetime_dict_from_unix_time(int(ls_raw))
                ls_str = "%02d.%02d.%04d %02d:%02d" % [dt.day, dt.month, dt.year, dt.hour, dt.minute]
        elif ls_raw is String and String(ls_raw) != "":
                ls_str = String(ls_raw).left(16)
        if ls_str != "":
                MpKit.stat_card(vb, "АКТИВНОСТЬ", "ПОСЛЕДНЯЯ ИГРА", ls_str, false, "net_sync")
        
        MpKit.section(vb, "ОФОРМЛЕНИЕ")
        var fr_name: String = Cosmetics.name_of(String(cos.get("frame", "")))
        var bn_name: String = Cosmetics.name_of(String(cos.get("banner", "")))
        var tt_name: String = Cosmetics.name_of(String(cos.get("title", "")))
        var info_p: PanelContainer = PanelContainer.new()
        info_p.add_theme_stylebox_override("panel", UiKit.sb("wb_panel_dark", 8, 4))
        vb.add_child(info_p)
        var iv: VBoxContainer = VBoxContainer.new()
        iv.add_theme_constant_override("separation", 4)
        info_p.add_child(iv)
        iv.add_child(UiKit.lbl("Рамка: %s" % (fr_name if fr_name != "" else "Стандартная"), 11, UiKit.TEXT, 2, 1))
        iv.add_child(UiKit.lbl("Баннер: %s" % (bn_name if bn_name != "" else "Стандартный"), 11, UiKit.TEXT, 2, 1))
        if tt_name != "":
                iv.add_child(UiKit.lbl("Титул: %s" % tt_name, 11, UiKit.GOLD, 2, 1))
        
        var br: HBoxContainer = _bottom_row()
        var back: Button = _button(br, "НАЗАД", "stone", "")
        back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        back.pressed.connect(func() -> void:
                if return_cb.is_valid():
                        return_cb.call()
                elif net != null and net.active():
                        show_lobby()
                else:
                        show_leaderboard()
        )


func _render_player_actions() -> void:
        if not is_instance_valid(_player_actions) or _player_actions.is_queued_for_deletion():
                return
        var nick: String = _player_actions_user["username"]
        var relation: String = ""
        var signature: Array = [_social.ready]
        var can_message: bool = bool(_player_actions_user.get("can_message", false))
        var has_chat: bool = false
        for key: String in ["friends", "incoming", "outgoing", "conversations"]:
                for player: Dictionary in _social.state.get(key, []):
                        if player["username"] == nick:
                                if key == "conversations":
                                        has_chat = true
                                        can_message = bool(player.get("can_message", can_message))
                                else:
                                        relation = key
                                break
        signature.append_array([relation, can_message, has_chat])
        if _player_actions.get_meta("signature", []) == signature:
                return
        _player_actions.set_meta("signature", signature)
        for child: Node in _player_actions.get_children():
                _player_actions.remove_child(child)
                child.queue_free()
        MpKit.section(_player_actions, "ОБЩЕНИЕ")
        if not _social.ready:
                _label(_player_actions, "Связь с сервером восстанавливается.", 11, UiKit.MUTED, false)
                return
        var target: Dictionary = {"username": nick}
        match relation:
                "friends":
                        _nav_row(_player_actions, "УДАЛИТЬ ИЗ ДРУЗЕЙ", "ВЫ УЖЕ ДРУЗЬЯ", func() -> void: _send_social("remove", target))
                "incoming":
                        _nav_row(_player_actions, "ПРИНЯТЬ ЗАЯВКУ", "ИГРОК ХОЧЕТ ДОБАВИТЬ ВАС", func() -> void: _send_social("accept", target))
                        _nav_row(_player_actions, "ОТКЛОНИТЬ ЗАЯВКУ", "", func() -> void: _send_social("decline", target))
                "outgoing":
                        _nav_row(_player_actions, "ОТМЕНИТЬ ЗАЯВКУ", "ОЖИДАЕТ ОТВЕТА", func() -> void: _send_social("cancel", target))
                _:
                        _nav_row(_player_actions, "ДОБАВИТЬ В ДРУЗЬЯ", "ОТПРАВИТЬ ЗАЯВКУ ИГРОКУ", func() -> void: _send_social("request", target))
        if can_message or relation == "friends" or has_chat:
                var back: Callable = _player_actions_back
                _nav_row(_player_actions, "НАПИСАТЬ" if can_message or relation == "friends" else "ИСТОРИЯ СООБЩЕНИЙ", "ЛИЧНАЯ ПЕРЕПИСКА", func() -> void:
                        _show_friend_chat(nick, func() -> void: _inspect_player(nick, {}, back)))
        else:
                _label(_player_actions, "Игрок принимает сообщения только от друзей.", 11, UiKit.MUTED, false)


func _inspect_player(uname: String, fallback_cos: Dictionary = {}, return_cb: Callable = Callable()) -> void:
        var on_back: Callable = return_cb
        if not on_back.is_valid():
                on_back = show_lobby if net != null and net.active() else show_leaderboard
        var vb: VBoxContainer = _screen("Профиль: " + uname, 0.45, true)
        current = "player_profile_loading"
        MpKit.placeholder(vb, "net_sync", "ЗАГРУЗКА ПРОФИЛЯ", "", true, 72.0)
        _social_button(_bottom_row(), "Назад", on_back, "stone")
        var loading: Control = screen
        var res: Dictionary = await Account.get_profile(uname)
        if screen != loading:
                return
        if res.get("ok", false):
                show_player_profile(res["user"], on_back)
        else:
                show_player_profile({"username": uname, "cosmetics": fallback_cos, "load_error": res.get("err", "Профиль недоступен")}, on_back)


func _pick_avatar_file() -> void:
        if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
                DisplayServer.file_dialog_show("Выберите картинку для аватарки", "", "", false, DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, PackedStringArray(["*.png, *.jpg, *.jpeg ; Изображения"]), func(status: bool, selected_paths: PackedStringArray, _filter_idx: int) -> void:
                        if status and not selected_paths.is_empty():
                                var res: Dictionary = await Account.save_avatar_file(selected_paths[0])
                                if bool(res.get("ok", false)):
                                        show_profile("АВАТАРКА ОБНОВЛЕНА", "ok")
                                else:
                                        show_profile(String(res.get("err", "Ошибка файла")), "alarm")
                )
        else:
                var fd: FileDialog = FileDialog.new()
                fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
                fd.access = FileDialog.ACCESS_FILESYSTEM
                fd.filters = PackedStringArray(["*.png, *.jpg, *.jpeg ; Изображения"])
                get_tree().root.add_child(fd)
                fd.popup_centered_ratio(0.7)
                fd.file_selected.connect(func(path: String) -> void:
                        var res: Dictionary = await Account.save_avatar_file(path)
                        fd.queue_free()
                        if bool(res.get("ok", false)):
                                show_profile("АВАТАРКА ОБНОВЛЕНА", "ok")
                        else:
                                show_profile(String(res.get("err", "Ошибка файла")), "alarm")
                )
                fd.canceled.connect(fd.queue_free)

