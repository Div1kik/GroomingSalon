extends Control
class_name MainUI

var state: GameState
var sound: SoundManager
var world: SalonWorld
var minigame: GroomingMinigame

var _hud_lbl: Label
var _sub_lbl: Label
var _drawer_panel: Panel
var _drawer_box: VBoxContainer
var _guest_banner: PanelContainer
var _guest_lbl: Label

func setup(p_state: GameState, p_sound: SoundManager, p_world: SalonWorld, p_minigame: GroomingMinigame) -> void:
	state = p_state
	sound = p_sound
	world = p_world
	minigame = p_minigame

	state.state_changed.connect(_refresh_hud)
	state.day_passed.connect(_on_day_passed)
	state.guest_visited_changed.connect(_on_guest_visit_changed)
	minigame.session_finished.connect(_on_session_finished)
	world.inspect_pet_requested.connect(func(pet_data: Dictionary):
		if state.is_visiting_guest:
			state.exit_guest_visit()
		_show_intake_card(pet_data)
	)

	_build_hud()
	_refresh_hud()

func _on_session_finished(pet: Dictionary, calm_ratio: float, reward_money: int) -> void:
	state.record_pet_outcome(str(pet.get("id", "")), calm_ratio, reward_money, pet)
	state.advance_time(45)
	world.roll_next_pet()
	_sub_lbl.text = "Клиент %s обслужен (+%d ₽). В зал зашёл новый гость!" % [pet.get("name", ""), reward_money]

func _on_day_passed(day_num: int, month_num: int, salary_paid: int) -> void:
	if salary_paid > 0:
		_sub_lbl.text = "Наступил день %d (мес. %d). Списана зарплата: %d ₽" % [day_num, month_num, salary_paid]
	else:
		_sub_lbl.text = "Новый день %d (мес. %d). Салон готов к гостям!" % [day_num, month_num]

func _on_guest_visit_changed(visiting: bool, salon_title: String) -> void:
	_guest_banner.visible = visiting
	if visiting:
		var note: String = str(state.active_guest_salon.get("note", ""))
		_guest_lbl.text = "%s\n%s" % [salon_title, note]

func _refresh_hud() -> void:
	var mode_txt: String = "24/7" if (state.is_24h_mode and state.salon_level >= 5) else "10:00–22:00"
	_hud_lbl.text = "%d ₽  |  ★ %.1f  |  Ур. %d/5  |  %s (%s)" % [
		state.money, state.reputation, state.salon_level, state.format_clock(), mode_txt
	]
	if _sub_lbl.text.is_empty():
		_sub_lbl.text = "%s • День %d, Мес. %d • Нажми на гостя у стойки приёма!" % [
			state.salon_name, state.day_num, state.month_num
		]

func _open_drawer(title_text: String) -> void:
	_drawer_panel.visible = true
	for c in _drawer_box.get_children():
		c.queue_free()

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	_drawer_box.add_child(head)

	var t_lbl := Label.new()
	t_lbl.text = title_text
	t_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t_lbl.add_theme_font_size_override("font_size", 32)
	t_lbl.add_theme_color_override("font_color", Color("3c332b"))
	head.add_child(t_lbl)

	var close_b := Button.new()
	close_b.text = "Закрыть"
	close_b.custom_minimum_size = Vector2(140, 58)
	close_b.add_theme_font_size_override("font_size", 24)
	close_b.pressed.connect(func():
		world.set_decorate_mode(false)
		_drawer_panel.visible = false
	)
	head.add_child(close_b)

func _show_intake_card(pet: Dictionary) -> void:
	_open_drawer("Приём клиента у стойки")

	var visits: int = int(pet.get("visits", 0))
	var trust: float = float(pet.get("trust", 0.0))
	var rel_text: String = "Впервые у нас" if visits == 0 else ("Постоянный гость (визитов: %d)" % visits if trust >= 0.2 else ("Осторожничает (визитов: %d)" % visits))

	var owner_lbl := Label.new()
	owner_lbl.text = "Хозяин %s привёл: %s (%s • %s)" % [
		pet.get("owner_name", "Гость"), pet.get("name", ""), pet.get("species", ""), pet.get("breed", "")
	]
	owner_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	owner_lbl.add_theme_font_size_override("font_size", 28)
	owner_lbl.add_theme_color_override("font_color", Color("3c332b"))
	_drawer_box.add_child(owner_lbl)

	var quote_panel := PanelContainer.new()
	var q_sb := StyleBoxFlat.new()
	q_sb.bg_color = Color("fffdf9")
	q_sb.border_color = Color("d8c7b4")
	q_sb.set_border_width_all(3)
	q_sb.content_margin_left = 18.0
	q_sb.content_margin_right = 18.0
	q_sb.content_margin_top = 16.0
	q_sb.content_margin_bottom = 16.0
	quote_panel.add_theme_stylebox_override("panel", q_sb)
	_drawer_box.add_child(quote_panel)

	var quote_lbl := Label.new()
	quote_lbl.text = str(pet.get("owner_replica", ""))
	quote_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quote_lbl.add_theme_font_size_override("font_size", 25)
	quote_lbl.add_theme_color_override("font_color", Color("4a3f35"))
	quote_panel.add_child(quote_lbl)

	var details_lbl := Label.new()
	details_lbl.text = "• Шерсть: %s\n• Пожелание: %s\n• Характер: %s\n• Статус: %s • Игрушка: %s\n• Оплата: ~%d ₽" % [
		pet.get("coat", ""),
		pet.get("wish_tag", ""),
		pet.get("habit_note", ""),
		rel_text,
		pet.get("toy", ""),
		int(pet.get("base_price", 180))
	]
	details_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details_lbl.add_theme_font_size_override("font_size", 24)
	details_lbl.add_theme_color_override("font_color", Color("5c4f43"))
	_drawer_box.add_child(details_lbl)

	var start_btn := Button.new()
	start_btn.text = "Пригласить %s на стол груминга" % str(pet.get("name", "питомца"))
	start_btn.custom_minimum_size = Vector2(0, 76)
	start_btn.add_theme_font_size_override("font_size", 26)
	start_btn.pressed.connect(func():
		_drawer_panel.visible = false
		sound.play_success()
		minigame.start_new_pet(pet)
	)
	_drawer_box.add_child(start_btn)

	var next_btn := Button.new()
	next_btn.text = "Позвать следующего по записи"
	next_btn.custom_minimum_size = Vector2(0, 68)
	next_btn.add_theme_font_size_override("font_size", 24)
	next_btn.pressed.connect(func():
		world.roll_next_pet()
		_show_intake_card(world.get_current_pet())
	)
	_drawer_box.add_child(next_btn)

func _show_salon_and_staff_menu() -> void:
	_open_drawer("Салон (ур. %d/5) и команда" % state.salon_level)

	var up_cost: int = state.get_level_upgrade_cost()
	var up_btn := Button.new()
	up_btn.custom_minimum_size = Vector2(0, 68)
	up_btn.add_theme_font_size_override("font_size", 25)
	if state.salon_level < 5:
		up_btn.text = "Улучшить салон до ур. %d (%d ₽)" % [state.salon_level + 1, up_cost]
		up_btn.pressed.connect(func():
			if state.upgrade_salon_level():
				sound.play_success()
				_show_salon_and_staff_menu()
		)
	else:
		up_btn.text = "Максимальный 5-й уровень салона"
		up_btn.disabled = true
	_drawer_box.add_child(up_btn)

	if state.salon_level >= 5:
		var mode_btn := Button.new()
		mode_btn.custom_minimum_size = Vector2(0, 64)
		mode_btn.add_theme_font_size_override("font_size", 24)
		mode_btn.text = "Режим 24/7: ВКЛ" if state.is_24h_mode else "Режим 24/7: ВЫКЛ"
		mode_btn.pressed.connect(func():
			state.toggle_24h_mode()
			_show_salon_and_staff_menu()
		)
		_drawer_box.add_child(mode_btn)

	var staff_title := Label.new()
	staff_title.text = "Команда в салоне (замена выбором кандидата):"
	staff_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	staff_title.add_theme_font_size_override("font_size", 25)
	staff_title.add_theme_color_override("font_color", Color("5c4f43"))
	_drawer_box.add_child(staff_title)

	for i in range(state.hired_staff.size()):
		var s: Dictionary = state.hired_staff[i]
		var l := Label.new()
		l.text = "• %s — %s (+%d ₽/день, з/п %d ₽/мес.)" % [
			s.get("name", ""), s.get("role", ""), s.get("income_bonus", 0), s.get("salary", 0)
		]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 24)
		l.add_theme_color_override("font_color", Color("3c332b"))
		_drawer_box.add_child(l)

	var cand_title := Label.new()
	cand_title.text = "Кандидаты (часть доступна с 3-го уровня салона):"
	cand_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cand_title.add_theme_font_size_override("font_size", 25)
	cand_title.add_theme_color_override("font_color", Color("5c4f43"))
	_drawer_box.add_child(cand_title)

	for cand in state.candidate_pool:
		var min_lvl: int = int(cand.get("min_level", 1))
		var unlocked: bool = state.salon_level >= min_lvl
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 66)
		b.text = "%s (%s) • ур.%d • %d ₽/мес." % [
			cand.get("name", ""), cand.get("role", ""), min_lvl, cand.get("salary", 0)
		]
		b.add_theme_font_size_override("font_size", 24)
		b.disabled = not unlocked
		b.pressed.connect(func():
			var replace_slot: int = 0 if state.hired_staff.size() > 0 else -1
			if state.hire_or_replace_staff(cand, replace_slot):
				sound.play_success()
				_show_salon_and_staff_menu()
		)
		_drawer_box.add_child(b)

func _show_decor_menu() -> void:
	world.set_decorate_mode(true)
	_open_drawer("Декор, растения и лаунж-зоны")

	var hint := Label.new()
	hint.text = "Нажми на предмет в зале и перетащи его."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 24)
	hint.add_theme_color_override("font_color", Color("5c4f43"))
	_drawer_box.add_child(hint)

	for item in state.decor_catalog:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 68)
		b.text = "+ %s (%s) — %d ₽" % [item.get("label", ""), item.get("category", ""), item.get("price", 0)]
		b.add_theme_font_size_override("font_size", 25)
		b.pressed.connect(func():
			if state.buy_and_place_decor(item):
				sound.play_success()
				_refresh_hud()
		)
		_drawer_box.add_child(b)

func _build_hud() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var top_panel := PanelContainer.new()
	top_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_panel.offset_bottom = 148.0
	var top_sb := StyleBoxFlat.new()
	top_sb.bg_color = Color("fffdf9").lerp(Color("f2ebe1"), 0.35)
	top_sb.content_margin_left = 22.0
	top_sb.content_margin_right = 22.0
	top_sb.content_margin_top = 16.0
	top_sb.content_margin_bottom = 16.0
	top_panel.add_theme_stylebox_override("panel", top_sb)
	add_child(top_panel)

	var top_v := VBoxContainer.new()
	top_v.add_theme_constant_override("separation", 6)
	top_panel.add_child(top_v)

	var top_h := HBoxContainer.new()
	top_h.add_theme_constant_override("separation", 12)
	top_v.add_child(top_h)

	_hud_lbl = Label.new()
	_hud_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hud_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hud_lbl.add_theme_font_size_override("font_size", 28)
	_hud_lbl.add_theme_color_override("font_color", Color("3c332b"))
	top_h.add_child(_hud_lbl)

	var mute_btn := Button.new()
	mute_btn.text = "♪"
	mute_btn.custom_minimum_size = Vector2(64, 54)
	mute_btn.add_theme_font_size_override("font_size", 26)
	mute_btn.pressed.connect(func():
		sound.toggle_mute()
		mute_btn.text = "×" if sound.muted else "♪"
	)
	top_h.add_child(mute_btn)

	_sub_lbl = Label.new()
	_sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub_lbl.add_theme_font_size_override("font_size", 22)
	_sub_lbl.add_theme_color_override("font_color", Color("6e5d4f"))
	top_v.add_child(_sub_lbl)

	_guest_banner = PanelContainer.new()
	_guest_banner.visible = false
	_guest_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_guest_banner.offset_left = 22.0
	_guest_banner.offset_right = -22.0
	_guest_banner.offset_top = 160.0
	_guest_banner.offset_bottom = 276.0
	var g_sb := StyleBoxFlat.new()
	g_sb.bg_color = Color("fffdf9")
	g_sb.border_color = Color("b7cbbd")
	g_sb.set_border_width_all(3)
	g_sb.content_margin_left = 18.0
	g_sb.content_margin_right = 18.0
	g_sb.content_margin_top = 12.0
	g_sb.content_margin_bottom = 12.0
	_guest_banner.add_theme_stylebox_override("panel", g_sb)
	add_child(_guest_banner)

	var g_hbox := HBoxContainer.new()
	g_hbox.add_theme_constant_override("separation", 12)
	_guest_banner.add_child(g_hbox)

	_guest_lbl = Label.new()
	_guest_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_guest_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_guest_lbl.add_theme_font_size_override("font_size", 23)
	_guest_lbl.add_theme_color_override("font_color", Color("3c332b"))
	g_hbox.add_child(_guest_lbl)

	var exit_guest_btn := Button.new()
	exit_guest_btn.text = "Домой"
	exit_guest_btn.custom_minimum_size = Vector2(130, 56)
	exit_guest_btn.add_theme_font_size_override("font_size", 23)
	exit_guest_btn.pressed.connect(func(): state.exit_guest_visit())
	g_hbox.add_child(exit_guest_btn)

	var bot_panel := PanelContainer.new()
	bot_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bot_panel.offset_top = -126.0
	var bot_sb := StyleBoxFlat.new()
	bot_sb.bg_color = Color("fffdf9").lerp(Color("f2ebe1"), 0.35)
	bot_sb.content_margin_left = 16.0
	bot_sb.content_margin_right = 16.0
	bot_sb.content_margin_top = 16.0
	bot_sb.content_margin_bottom = 16.0
	bot_panel.add_theme_stylebox_override("panel", bot_sb)
	add_child(bot_panel)

	var bot_row := HBoxContainer.new()
	bot_row.add_theme_constant_override("separation", 12)
	bot_panel.add_child(bot_row)

	var serve_btn := Button.new()
	serve_btn.text = "Приём"
	serve_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	serve_btn.add_theme_font_size_override("font_size", 26)
	serve_btn.pressed.connect(func():
		if state.is_visiting_guest:
			state.exit_guest_visit()
		sound.play_soft_pop(1.0)
		_show_intake_card(world.get_current_pet())
	)
	bot_row.add_child(serve_btn)

	var salon_btn := Button.new()
	salon_btn.text = "Салон"
	salon_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	salon_btn.add_theme_font_size_override("font_size", 26)
	salon_btn.pressed.connect(_show_salon_and_staff_menu)
	bot_row.add_child(salon_btn)

	var decor_btn := Button.new()
	decor_btn.text = "Декор"
	decor_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	decor_btn.add_theme_font_size_override("font_size", 26)
	decor_btn.pressed.connect(_show_decor_menu)
	bot_row.add_child(decor_btn)

	var visit_btn := Button.new()
	visit_btn.text = "В гости"
	visit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	visit_btn.add_theme_font_size_override("font_size", 26)
	visit_btn.pressed.connect(func():
		sound.play_soft_pop(1.15)
		state.enter_guest_visit()
	)
	bot_row.add_child(visit_btn)

	_drawer_panel = Panel.new()
	_drawer_panel.visible = false
	_drawer_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_drawer_panel.offset_left = 22.0
	_drawer_panel.offset_right = -22.0
	_drawer_panel.offset_top = 164.0
	_drawer_panel.offset_bottom = -142.0
	var d_sb := StyleBoxFlat.new()
	d_sb.bg_color = Color("fbf7f1")
	d_sb.border_color = Color("d6c7b6")
	d_sb.set_border_width_all(3)
	_drawer_panel.add_theme_stylebox_override("panel", d_sb)
	add_child(_drawer_panel)

	var d_margin := MarginContainer.new()
	d_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	d_margin.add_theme_constant_override("margin_left", 22)
	d_margin.add_theme_constant_override("margin_right", 22)
	d_margin.add_theme_constant_override("margin_top", 22)
	d_margin.add_theme_constant_override("margin_bottom", 22)
	_drawer_panel.add_child(d_margin)

	_drawer_box = VBoxContainer.new()
	_drawer_box.add_theme_constant_override("separation", 14)
	d_margin.add_child(_drawer_box)
