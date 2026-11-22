extends Control
class_name MainUI

signal start_grooming_requested(pet_data: Dictionary)
signal next_guest_requested
signal decorate_toggled(active: bool)

var state: GameState
var sound: SoundManager
var world: SalonWorld

var _money_lbl: Label
var _rep_lbl: Label
var _lvl_lbl: Label
var _time_lbl: Label
var _guest_banner: Label
var _mute_btn: Button

var _drawer_panel: PanelContainer
var _drawer_title: Label
var _drawer_body: VBoxContainer
var _active_tab: String = ""
var _selected_pet: Dictionary = {}

var _nav_buttons: Dictionary = {}

func setup(p_state: GameState, p_sound: SoundManager, p_world: SalonWorld, _p_minigame: Node = null) -> void:
	state = p_state
	sound = p_sound
	world = p_world
	_build_ui()
	state.state_changed.connect(_refresh_top_bar)
	state.day_passed.connect(_on_day_passed)
	state.guest_visited_changed.connect(_on_guest_changed)
	world.inspect_pet_requested.connect(open_pet_reception_card)
	world.staff_earned_money.connect(_on_staff_earned)
	_refresh_top_bar()

func _on_staff_earned(staff_name: String, pet_name: String, amount: int) -> void:
	_guest_banner.text = "%s завершил(а) уход за %s (+%d ₽)" % [staff_name, pet_name, amount]

func open_pet_reception_card(pet_data: Dictionary) -> void:
	_selected_pet = pet_data.duplicate(true)
	_active_tab = "reception"
	_drawer_panel.visible = true
	_drawer_title.text = "Запись на приём"
	_update_nav_highlight()
	_rebuild_drawer_content()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var top_panel := PanelContainer.new()
	top_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_panel.offset_bottom = 132
	var top_sb := StyleBoxFlat.new()
	top_sb.bg_color = Color(0.98, 0.96, 0.93, 0.96)
	top_sb.border_color = Color("d8c7b4")
	top_sb.border_width_bottom = 3
	top_panel.add_theme_stylebox_override("panel", top_sb)
	add_child(top_panel)

	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override("margin_left", 24)
	top_margin.add_theme_constant_override("margin_right", 24)
	top_margin.add_theme_constant_override("margin_top", 14)
	top_margin.add_theme_constant_override("margin_bottom", 10)
	top_panel.add_child(top_margin)

	var top_vbox := VBoxContainer.new()
	top_vbox.add_theme_constant_override("separation", 6)
	top_margin.add_child(top_vbox)

	var stats_row := HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 18)
	top_vbox.add_child(stats_row)

	_money_lbl = _make_top_lbl(stats_row, 28, Color("3c332b"))
	_rep_lbl = _make_top_lbl(stats_row, 28, Color("5a8d76"))
	_lvl_lbl = _make_top_lbl(stats_row, 28, Color("3c332b"))
	_time_lbl = _make_top_lbl(stats_row, 28, Color("688694"))
	_time_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_mute_btn = Button.new()
	_mute_btn.text = "Звук"
	_mute_btn.custom_minimum_size = Vector2(96, 50)
	_mute_btn.add_theme_font_size_override("font_size", 22)
	_style_cozy_btn(_mute_btn, Color("fffdf9"), Color("cbb7a0"))
	_mute_btn.pressed.connect(func():
		sound.toggle_mute()
		_mute_btn.text = "Без зв." if sound.muted else "Звук"
	)
	stats_row.add_child(_mute_btn)

	_guest_banner = Label.new()
	_guest_banner.add_theme_font_size_override("font_size", 21)
	_guest_banner.add_theme_color_override("font_color", Color("5a8d76"))
	_guest_banner.text = "Нежный Хвостик • Нажми на гостя у стойки приёма!"
	top_vbox.add_child(_guest_banner)

	_drawer_panel = PanelContainer.new()
	_drawer_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_drawer_panel.offset_top = -1020
	_drawer_panel.offset_bottom = -124
	_drawer_panel.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.99, 0.97, 0.94, 0.98)
	sb.border_color = Color("cbb7a0")
	sb.set_border_width_all(3)
	sb.corner_radius_top_left = 26
	sb.corner_radius_top_right = 26
	_drawer_panel.add_theme_stylebox_override("panel", sb)
	add_child(_drawer_panel)

	var d_margin := MarginContainer.new()
	d_margin.add_theme_constant_override("margin_left", 24)
	d_margin.add_theme_constant_override("margin_right", 24)
	d_margin.add_theme_constant_override("margin_top", 20)
	d_margin.add_theme_constant_override("margin_bottom", 20)
	_drawer_panel.add_child(d_margin)

	var d_vbox := VBoxContainer.new()
	d_vbox.add_theme_constant_override("separation", 14)
	d_margin.add_child(d_vbox)

	var d_head := HBoxContainer.new()
	d_vbox.add_child(d_head)

	_drawer_title = Label.new()
	_drawer_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_drawer_title.add_theme_font_size_override("font_size", 32)
	_drawer_title.add_theme_color_override("font_color", Color("3c332b"))
	d_head.add_child(_drawer_title)

	var x_btn := Button.new()
	x_btn.text = "Закрыть"
	x_btn.custom_minimum_size = Vector2(130, 56)
	x_btn.add_theme_font_size_override("font_size", 24)
	_style_cozy_btn(x_btn, Color("fffdf9"), Color("cbb7a0"))
	x_btn.pressed.connect(_close_drawer)
	d_head.add_child(x_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	d_vbox.add_child(scroll)

	_drawer_body = VBoxContainer.new()
	_drawer_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_drawer_body.add_theme_constant_override("separation", 14)
	scroll.add_child(_drawer_body)

	var nav_bar := PanelContainer.new()
	nav_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	nav_bar.offset_top = -124
	var nav_sb := StyleBoxFlat.new()
	nav_sb.bg_color = Color(0.98, 0.96, 0.93, 0.98)
	nav_sb.border_color = Color("d8c7b4")
	nav_sb.border_width_top = 3
	nav_bar.add_theme_stylebox_override("panel", nav_sb)
	add_child(nav_bar)

	var nav_margin := MarginContainer.new()
	nav_margin.add_theme_constant_override("margin_left", 16)
	nav_margin.add_theme_constant_override("margin_right", 16)
	nav_margin.add_theme_constant_override("margin_top", 12)
	nav_margin.add_theme_constant_override("margin_bottom", 16)
	nav_bar.add_child(nav_margin)

	var nav_hbox := HBoxContainer.new()
	nav_hbox.add_theme_constant_override("separation", 8)
	nav_margin.add_child(nav_hbox)

	var tabs := [
		{"id": "reception", "title": "Приём"},
		{"id": "gallery", "title": "Альбом"},
		{"id": "salon", "title": "Салон"},
		{"id": "decor", "title": "Декор"},
		{"id": "visit", "title": "В гости"}
	]
	for t in tabs:
		var btn := Button.new()
		btn.text = t["title"]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 84)
		btn.add_theme_font_size_override("font_size", 24)
		_style_cozy_btn(btn, Color("fffdf9"), Color("cbb7a0"))
		var tid: String = t["id"]
		btn.pressed.connect(func(): _toggle_tab(tid))
		nav_hbox.add_child(btn)
		_nav_buttons[tid] = btn

func _style_cozy_btn(btn: Button, bg: Color, bd: Color) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = bg
	n.border_color = bd
	n.set_border_width_all(3)
	n.set_corner_radius_all(14)
	var h := n.duplicate()
	h.bg_color = bg.lightened(0.04)
	btn.add_theme_stylebox_override("normal", n)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", h)
	btn.add_theme_color_override("font_color", Color("3c332b"))
	btn.add_theme_color_override("font_hover_color", Color("3c332b"))
	btn.add_theme_color_override("font_pressed_color", Color("3c332b"))

func _make_top_lbl(parent: Control, font_sz: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_sz)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l

func _refresh_top_bar() -> void:
	_money_lbl.text = "%d ₽" % state.money
	_rep_lbl.text = "★ %.1f" % state.reputation
	_lvl_lbl.text = "Ур. %d/5" % state.salon_level
	var sched := "24/7" if (state.salon_level >= 5 and state.is_24h_mode) else "10:00–22:00"
	_time_lbl.text = "%s (%s)" % [state.format_clock(), sched]

	if state.is_visiting_guest:
		_guest_banner.text = "%s • %s" % [state.active_guest_salon.get("name", ""), state.active_guest_salon.get("note", "")]
	else:
		var staff_cnt: int = state.hired_staff.size()
		var staff_txt := " • Мастеров в смене: %d" % staff_cnt if staff_cnt > 0 else " • Нажми на гостя у стойки приёма!"
		_guest_banner.text = "%s • День %d, Мес. %d%s" % [state.salon_name, state.day_num, state.month_num, staff_txt]

func _on_day_passed(day_num: int, month_num: int, salary_paid: int) -> void:
	if salary_paid > 0:
		_guest_banner.text = "Новый месяц (%d)! Выплачена зарплата мастерам: -%d ₽" % [month_num, salary_paid]
	else:
		_guest_banner.text = "Начался День %d! Салон открыт с 10:00." % day_num

func _on_guest_changed(_visiting: bool, _name: String) -> void:
	_refresh_top_bar()
	if _drawer_panel.visible and _active_tab == "visit":
		_rebuild_drawer_content()

func _toggle_tab(tab_id: String) -> void:
	sound.play_soft_pop(1.1)
	if _drawer_panel.visible and _active_tab == tab_id:
		_close_drawer()
		return

	_active_tab = tab_id
	_drawer_panel.visible = true
	decorate_toggled.emit(tab_id == "decor" and not state.is_visiting_guest)
	_update_nav_highlight()

	match tab_id:
		"reception":
			_drawer_title.text = "Стойка приёма и карточки гостей"
			if _selected_pet.is_empty():
				_selected_pet = world.get_current_pet()
		"gallery":
			_drawer_title.text = "Фотоальбом салона «До и После»"
		"salon":
			_drawer_title.text = "Управление салоном и инструменты"
		"decor":
			_drawer_title.text = "Оформление интерьера"
		"visit":
			_drawer_title.text = "В гости в соседний салон"

	_rebuild_drawer_content()

func _close_drawer() -> void:
	_drawer_panel.visible = false
	_active_tab = ""
	decorate_toggled.emit(false)
	_update_nav_highlight()

func _update_nav_highlight() -> void:
	for k in _nav_buttons.keys():
		var b: Button = _nav_buttons[k]
		var active: bool = (_drawer_panel.visible and _active_tab == k)
		_style_cozy_btn(b, Color("dcebe2") if active else Color("fffdf9"), Color("7da388") if active else Color("cbb7a0"))

func _clear_drawer_body() -> void:
	for c in _drawer_body.get_children():
		c.queue_free()

func _rebuild_drawer_content() -> void:
	_clear_drawer_body()
	match _active_tab:
		"reception":
			_build_reception_tab()
		"gallery":
			_build_gallery_tab()
		"salon":
			_build_salon_tab()
		"decor":
			_build_decor_tab()
		"visit":
			_build_visit_tab()

func _build_gallery_tab() -> void:
	if state.gallery_photos.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "В альбоме пока нет снимков. Прими первого гостя у стойки приёма и заверши уход, чтобы сохранить фото результата и отзыв хозяина!"
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_lbl.add_theme_font_size_override("font_size", 24)
		empty_lbl.add_theme_color_override("font_color", Color("4a3f35"))
		_drawer_body.add_child(empty_lbl)
		return

	var acc_names := {"bow": "Шёлковый бантик", "crown": "Мини-корона", "bandana": "Бандана", "flower": "Цветочек"}
	var scent_names := {"lavender": "Лаванда", "vanilla": "Ваниль", "apple": "Яблоко"}

	for photo in state.gallery_photos:
		var card := _make_card_panel()
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		card.add_child(box)

		var head := Label.new()
		head.text = "День %d • %s (%s) • Оплата: +%d ₽" % [int(photo.get("day", 1)), str(photo.get("name", "")), str(photo.get("breed", "")), int(photo.get("reward", 0))]
		head.add_theme_font_size_override("font_size", 25)
		head.add_theme_color_override("font_color", Color("3c332b"))
		box.add_child(head)

		var style_lbl := Label.new()
		var a_id: String = str(photo.get("chosen_acc", "bow"))
		var s_id: String = str(photo.get("chosen_scent", "lavender"))
		var a_txt: String = str(acc_names.get(a_id, a_id))
		var s_txt: String = str(scent_names.get(s_id, s_id))
		style_lbl.text = "Преображение: шёрстка вымыта и уложена • Образ: %s + аромат «%s» • Спокойствие: %d%%" % [
			a_txt, s_txt, int(photo.get("calm_pct", 80))
		]
		style_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		style_lbl.add_theme_font_size_override("font_size", 21)
		style_lbl.add_theme_color_override("font_color", Color("5a8d76"))
		box.add_child(style_lbl)

		var rev := Label.new()
		rev.text = str(photo.get("review", ""))
		rev.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rev.add_theme_font_size_override("font_size", 22)
		rev.add_theme_color_override("font_color", Color("4a3f35"))
		box.add_child(rev)

		_drawer_body.add_child(card)

func _build_reception_tab() -> void:
	if state.is_visiting_guest:
		var l := Label.new()
		l.text = "Сейчас ты в гостях. Вернись в свой салон, чтобы принимать гостей."
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 25)
		l.add_theme_color_override("font_color", Color("4a3f35"))
		_drawer_body.add_child(l)
		return

	if _selected_pet.is_empty():
		_selected_pet = world.get_current_pet()

	var p: Dictionary = _selected_pet
	var card := _make_card_panel()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)

	var header := Label.new()
	header.text = "Хозяин: %s  •  Питомец: %s (%s — %s)" % [str(p.get("owner_name", "Гость")), str(p.get("name", "")), str(p.get("species", "")), str(p.get("breed", ""))]
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_theme_font_size_override("font_size", 26)
	header.add_theme_color_override("font_color", Color("3c332b"))
	box.add_child(header)

	var speech := Label.new()
	speech.text = str(p.get("owner_replica", ""))
	speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	speech.add_theme_font_size_override("font_size", 23)
	speech.add_theme_color_override("font_color", Color("5a8d76"))
	box.add_child(speech)

	var details := Label.new()
	var trust_pct := int(round((float(p.get("trust", 0.0)) + 1.0) * 50.0))
	details.text = "Шёрстка: %s\nПожелание: %s\nХарактер: %s\nДоверие: %d%% (визитов: %d)  •  Оплата от %d ₽" % [
		str(p.get("coat", "")),
		str(p.get("wish_tag", "")),
		str(p.get("habit_note", "")),
		trust_pct,
		int(p.get("visits", 0)),
		int(p.get("base_price", state.get_service_price()))
	]
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_theme_font_size_override("font_size", 21)
	details.add_theme_color_override("font_color", Color("4a3f35"))
	box.add_child(details)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	box.add_child(btn_row)

	var start_btn := Button.new()
	start_btn.text = "Провести в кабинет"
	start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_btn.custom_minimum_size = Vector2(0, 72)
	start_btn.add_theme_font_size_override("font_size", 25)
	_style_cozy_btn(start_btn, Color("dcebe2"), Color("7da388"))
	start_btn.pressed.connect(func():
		sound.play_soft_pop(1.2)
		_close_drawer()
		start_grooming_requested.emit(p)
	)
	btn_row.add_child(start_btn)

	var next_btn := Button.new()
	next_btn.text = "Следующий гость"
	next_btn.custom_minimum_size = Vector2(230, 72)
	next_btn.add_theme_font_size_override("font_size", 23)
	_style_cozy_btn(next_btn, Color("fffdf9"), Color("cbb7a0"))
	next_btn.pressed.connect(func():
		next_guest_requested.emit()
		_selected_pet = world.get_current_pet()
		_rebuild_drawer_content()
	)
	btn_row.add_child(next_btn)

	_drawer_body.add_child(card)

func _build_salon_tab() -> void:
	var info := Label.new()
	info.text = "Уровень салона: %d/5  •  Рейтинг: ★ %.1f\nСтолов груминга: %d  •  Моек: %d  •  Зон сушки: %d%s" % [
		state.salon_level,
		state.reputation,
		state.grooming_stations,
		state.wash_stations,
		state.dry_stations,
		("  •  Сушильный шкаф" if state.has_drying_cabinet else "")
	]
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 22)
	info.add_theme_color_override("font_color", Color("3c332b"))
	_drawer_body.add_child(info)

	if state.salon_level < 5:
		var cost := state.get_level_upgrade_cost()
		var up_btn := Button.new()
		up_btn.text = "Расширить салон до Ур. %d (%d ₽)" % [state.salon_level + 1, cost]
		up_btn.custom_minimum_size = Vector2(0, 68)
		up_btn.add_theme_font_size_override("font_size", 24)
		up_btn.disabled = state.money < cost
		_style_cozy_btn(up_btn, Color("dcebe2"), Color("7da388"))
		up_btn.pressed.connect(func():
			if state.upgrade_salon_level():
				sound.play_success()
				_rebuild_drawer_content()
		)
		_drawer_body.add_child(up_btn)
	else:
		var mode_btn := Button.new()
		mode_btn.text = "Режим 24/7: %s" % ("Включён (круглосуточно)" if state.is_24h_mode else "Выключен (до 22:00)")
		mode_btn.custom_minimum_size = Vector2(0, 66)
		mode_btn.add_theme_font_size_override("font_size", 23)
		_style_cozy_btn(mode_btn, Color("dcebe2"), Color("7da388"))
		mode_btn.pressed.connect(func():
			state.toggle_24h_mode()
			_rebuild_drawer_content()
		)
		_drawer_body.add_child(mode_btn)

	var tools_hdr := Label.new()
	tools_hdr.text = "Профессиональные инструменты для работы:"
	tools_hdr.add_theme_font_size_override("font_size", 25)
	tools_hdr.add_theme_color_override("font_color", Color("3c332b"))
	_drawer_body.add_child(tools_hdr)

	var upgrades_list := [
		{"key": "soft_brush", "title": "Мягкая пуходёрка с массажем", "desc": "Ускоряет расчёсывание и успокоение питомца.", "cost": 260},
		{"key": "spa_shampoo", "title": "Гипоаллергенный СПА-шампунь", "desc": "Снимает страх воды при купании.", "cost": 340},
		{"key": "quiet_dryer", "title": "Тихий бесшумный фен", "desc": "Питомцы не боятся сушки и меньше нагреваются.", "cost": 420}
	]
	for u in upgrades_list:
		var bought := bool(state.tool_upgrades.get(u["key"], false))
		var u_card := _make_card_panel()
		var u_row := HBoxContainer.new()
		u_row.add_theme_constant_override("separation", 12)
		u_card.add_child(u_row)

		var ul := Label.new()
		ul.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ul.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ul.text = "%s\n%s" % [u["title"], u["desc"]]
		ul.add_theme_font_size_override("font_size", 21)
		ul.add_theme_color_override("font_color", Color("3c332b"))
		u_row.add_child(ul)

		var ub := Button.new()
		ub.text = "Куплено" if bought else "Купить (%d ₽)" % int(u["cost"])
		ub.custom_minimum_size = Vector2(210, 62)
		ub.add_theme_font_size_override("font_size", 22)
		ub.disabled = bought or state.money < int(u["cost"])
		_style_cozy_btn(ub, Color("dcebe2") if bought else Color("f5ebd9"), Color("7da388") if bought else Color("c99e76"))
		var ukey: String = u["key"]
		var ucost: int = int(u["cost"])
		ub.pressed.connect(func():
			if state.buy_tool_upgrade(ukey, ucost):
				sound.play_success()
				_rebuild_drawer_content()
		)
		u_row.add_child(ub)
		_drawer_body.add_child(u_card)

	var staff_hdr := Label.new()
	staff_hdr.text = "Помощники в салон (найм по желанию — сами моют и сушат гостей):"
	staff_hdr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	staff_hdr.add_theme_font_size_override("font_size", 24)
	staff_hdr.add_theme_color_override("font_color", Color("3c332b"))
	_drawer_body.add_child(staff_hdr)

	for cand in state.candidate_pool:
		var c_card := _make_card_panel()
		var c_box := VBoxContainer.new()
		c_box.add_theme_constant_override("separation", 6)
		c_card.add_child(c_box)

		var already_hired := false
		for hs in state.hired_staff:
			if hs.get("id") == cand.get("id"):
				already_hired = true
				break

		var cl := Label.new()
		cl.text = "%s — %s (с Ур. %d)\nДоход за смену: +%d ₽/питомец  •  Оклад: %d ₽/мес." % [
			cand["name"], cand["role"], int(cand["min_level"]), int(cand["service_reward"]), int(cand["salary"])
		]
		cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cl.add_theme_font_size_override("font_size", 21)
		cl.add_theme_color_override("font_color", Color("3c332b"))
		c_box.add_child(cl)

		var hb := Button.new()
		hb.text = "В команде" if already_hired else "Нанять помощника"
		hb.custom_minimum_size = Vector2(0, 60)
		hb.add_theme_font_size_override("font_size", 22)
		hb.disabled = already_hired or state.salon_level < int(cand["min_level"])
		_style_cozy_btn(hb, Color("dcebe2"), Color("7da388"))
		var cand_copy: Dictionary = cand
		hb.pressed.connect(func():
			if state.hire_or_replace_staff(cand_copy, -1):
				sound.play_success()
				_rebuild_drawer_content()
		)
		c_box.add_child(hb)
		_drawer_body.add_child(c_card)

func _build_decor_tab() -> void:
	var hint := Label.new()
	hint.text = "Режим расстановки включён: перетаскивай растения, диванчики и торшеры прямо по залу!"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 23)
	hint.add_theme_color_override("font_color", Color("5a8d76"))
	_drawer_body.add_child(hint)

	for item in state.decor_catalog:
		var card := _make_card_panel()
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)

		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.text = "%s (%s)\nЦена: %d ₽" % [item["label"], item["category"], int(item["price"])]
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.add_theme_color_override("font_color", Color("3c332b"))
		row.add_child(lbl)

		var buy_btn := Button.new()
		buy_btn.text = "Поставить"
		buy_btn.custom_minimum_size = Vector2(180, 64)
		buy_btn.add_theme_font_size_override("font_size", 23)
		buy_btn.disabled = state.money < int(item["price"])
		_style_cozy_btn(buy_btn, Color("f5ebd9"), Color("c99e76"))
		var item_copy: Dictionary = item
		buy_btn.pressed.connect(func():
			if state.buy_and_place_decor(item_copy):
				sound.play_success()
				_rebuild_drawer_content()
		)
		row.add_child(buy_btn)
		_drawer_body.add_child(card)

func _build_visit_tab() -> void:
	var desc := Label.new()
	if state.is_visiting_guest:
		desc.text = "Ты сейчас в гостях: %s. Осмотри планировку и уютные детали зала." % str(state.active_guest_salon.get("name", ""))
	else:
		desc.text = "Загляни в дружественный груминг-салон для вдохновения. Рабочие действия там отключены."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 23)
	desc.add_theme_color_override("font_color", Color("3c332b"))
	_drawer_body.add_child(desc)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 74)
	btn.add_theme_font_size_override("font_size", 25)
	_style_cozy_btn(btn, Color("dcebe2"), Color("7da388"))
	if state.is_visiting_guest:
		btn.text = "Вернуться в свой салон"
		btn.pressed.connect(func():
			state.exit_guest_visit()
			_close_drawer()
		)
	else:
		btn.text = "Посетить соседний салон"
		btn.pressed.connect(func():
			state.enter_guest_visit()
			_rebuild_drawer_content()
		)
	_drawer_body.add_child(btn)

func _make_card_panel() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("fffdf9")
	sb.border_color = Color("e2d5c5")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	p.add_theme_stylebox_override("panel", sb)
	return p
