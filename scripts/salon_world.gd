extends Node2D
class_name SalonWorld

signal inspect_pet_requested(pet_data: Dictionary)

var state: GameState
var sound: SoundManager

var decorate_mode: bool = false
var selected_decor_idx: int = -1
var dragging_decor_idx: int = -1

var camera_pan_x: float = 0.0
var camera_zoom: float = 1.0
var _pan_dragging: bool = false
var _press_start_pos: Vector2 = Vector2.ZERO
var _last_pointer_pos: Vector2 = Vector2.ZERO
var _moved_during_press: bool = false
var _anim_time: float = 0.0

var waiting_pet: Dictionary = {}
var _walk_progress: float = 0.0
var _tex_cache: Dictionary = {}

const DOOR_POS := Vector2(540, 1520)
const RECEPTION_POS := Vector2(540, 1280)
const GROOMING_TABLE_POS := Vector2(310, 820)
const WASH_STATION_POS := Vector2(770, 820)
const DRY_STATION_POS := Vector2(540, 1020)

func setup(p_state: GameState, p_sound: SoundManager) -> void:
	state = p_state
	sound = p_sound
	state.state_changed.connect(queue_redraw)
	state.guest_visited_changed.connect(_on_guest_changed)
	roll_next_pet()
	queue_redraw()

func roll_next_pet() -> void:
	if state != null:
		waiting_pet = state.spawn_pet_client()
		_walk_progress = 0.0
		if sound != null:
			sound.play_soft_pop(1.35)
		queue_redraw()

func get_current_pet() -> Dictionary:
	if waiting_pet.is_empty() and state != null:
		waiting_pet = state.spawn_pet_client()
		_walk_progress = 1.0
	return waiting_pet

func _process(delta: float) -> void:
	_anim_time += delta
	if _walk_progress < 1.0:
		_walk_progress = min(1.0, _walk_progress + delta * 0.85)
	queue_redraw()

func _on_guest_changed(_visiting: bool, _name: String) -> void:
	queue_redraw()

func set_decorate_mode(enabled: bool) -> void:
	decorate_mode = enabled
	dragging_decor_idx = -1
	if not decorate_mode:
		selected_decor_idx = -1
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if state == null:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var world_pos: Vector2 = _screen_to_world(mb.position)
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press_start_pos = mb.position
				_last_pointer_pos = mb.position
				_moved_during_press = false
				if not state.is_visiting_guest and decorate_mode:
					var hit_idx: int = _find_decor_at(world_pos)
					if hit_idx != -1:
						selected_decor_idx = hit_idx
						dragging_decor_idx = hit_idx
						sound.play_soft_pop(1.1)
						queue_redraw()
						return
				_pan_dragging = true
			else:
				var was_drag: bool = _moved_during_press
				_pan_dragging = false
				dragging_decor_idx = -1
				if not was_drag and not decorate_mode and not state.is_visiting_guest:
					_handle_world_tap(world_pos)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			camera_zoom = clamp(camera_zoom + 0.08, 0.85, 1.45)
			queue_redraw()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			camera_zoom = clamp(camera_zoom - 0.08, 0.85, 1.45)
			queue_redraw()

	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if mm.position.distance_to(_press_start_pos) > 8.0:
			_moved_during_press = true
		if dragging_decor_idx != -1 and not state.is_visiting_guest:
			state.update_decor_position(dragging_decor_idx, _screen_to_world(mm.position))
			queue_redraw()
		elif _pan_dragging:
			var delta_x: float = (mm.position.x - _last_pointer_pos.x) / camera_zoom
			_last_pointer_pos = mm.position
			camera_pan_x = clamp(camera_pan_x - delta_x, -260.0, 260.0)
			queue_redraw()

func _handle_world_tap(world_pos: Vector2) -> void:
	var guest_pos: Vector2 = _get_guest_group_pos()
	var guest_rect := Rect2(guest_pos - Vector2(180, 160), Vector2(360, 250))
	var reception_rect := Rect2(RECEPTION_POS - Vector2(180, 80), Vector2(360, 160))
	var table_rect := Rect2(GROOMING_TABLE_POS - Vector2(150, 80), Vector2(300, 160))

	if guest_rect.has_point(world_pos) or reception_rect.has_point(world_pos) or table_rect.has_point(world_pos):
		sound.play_soft_pop(1.05)
		inspect_pet_requested.emit(get_current_pet())

func _get_guest_group_pos() -> Vector2:
	var eased: float = 1.0 - pow(1.0 - _walk_progress, 3.0)
	return DOOR_POS.lerp(RECEPTION_POS + Vector2(0, 95), eased)

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var center := Vector2(540.0, 960.0)
	return (screen_pos - center) / camera_zoom + center + Vector2(camera_pan_x, 0.0)

func _find_decor_at(world_pos: Vector2) -> int:
	for i in range(state.placed_decor.size() - 1, -1, -1):
		var item: Dictionary = state.placed_decor[i]
		var p := Vector2(float(item["pos_x"]), float(item["pos_y"]))
		if world_pos.distance_to(p) <= 86.0:
			return i
	return -1

func _get_optional_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _tex_cache.has(path):
		return _tex_cache[path]
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		_tex_cache[path] = tex
		return tex
	_tex_cache[path] = null
	return null

func _draw() -> void:
	if state == null:
		return

	var center := Vector2(540.0, 960.0)
	draw_set_transform(center - (center - Vector2(camera_pan_x, 0.0)) * camera_zoom, 0.0, Vector2.ONE * camera_zoom)

	var wall_color := Color("fbf7f1")
	var wainscot_color := Color("f0e6d8")
	var floor_color := Color("e6d7c4")
	var line_soft := Color("d4c2ae")

	if state.is_visiting_guest:
		wall_color = Color("f2f8f4")
		wainscot_color = Color("e3efe7")
		floor_color = Color("d8e6dd")

	# Бесшовные стены и пол на всю ширину экрана (без серой пустоты по краям)
	draw_rect(Rect2(-1600, -400, 4280, 1680), wall_color)
	draw_rect(Rect2(-1600, 860, 4280, 420), wainscot_color)
	draw_line(Vector2(-1600, 860), Vector2(2680, 860), line_soft, 4.0)
	for wx_panel in range(-1440, 2560, 180):
		draw_rect(Rect2(wx_panel, 885, 145, 360), line_soft.lightened(0.35), false, 2.5)

	draw_rect(Rect2(-1600, 1280, 4280, 1200), floor_color)
	for fy in [1360.0, 1450.0, 1540.0, 1630.0, 1720.0]:
		draw_line(Vector2(-1600, fy), Vector2(2680, fy), line_soft.lightened(0.22), 2.5)

	# Уютный ковёр в центре зала
	draw_circle(Vector2(540, 1220), 290.0, Color("f6efe6"))
	draw_circle(Vector2(540, 1220), 290.0, Color("d4be9f"), false, 5.0)
	draw_circle(Vector2(540, 1220), 268.0, Color("e8d6be"), false, 2.5)

	# Большие солнечные окна
	for wx in [130.0, 670.0]:
		draw_rect(Rect2(wx, 330, 280, 380), Color("fffdf9"))
		draw_rect(Rect2(wx + 14, 344, 252, 352), Color("eaf5fa"))
		draw_colored_polygon(PackedVector2Array([
			Vector2(wx + 14, 696), Vector2(wx + 266, 696),
			Vector2(wx + 330, 860), Vector2(wx - 50, 860)
		]), Color(1.0, 0.98, 0.88, 0.38))
		draw_rect(Rect2(wx, 330, 280, 380), Color("cbb7a0"), false, 5.0)
		draw_line(Vector2(wx + 140, 330), Vector2(wx + 140, 710), Color("cbb7a0"), 3.5)
		draw_line(Vector2(wx, 520), Vector2(wx + 280, 520), Color("cbb7a0"), 3.5)
		draw_rect(Rect2(wx - 14, 708, 308, 18), Color("d6c3ad"))
		draw_rect(Rect2(wx + 46, 678, 30, 30), Color("c98e6b"))
		draw_circle(Vector2(wx + 61, 668), 20.0, Color("7da388"))

	_draw_cosmetic_shelf(Vector2(540, 545))

	_draw_grooming_table(GROOMING_TABLE_POS, state.grooming_stations)
	_draw_wash_bath(WASH_STATION_POS, state.wash_stations)
	_draw_dry_zone(DRY_STATION_POS, state.dry_stations, state.has_drying_cabinet)

	_draw_reception_desk(RECEPTION_POS)

	for i in range(state.placed_decor.size()):
		var item: Dictionary = state.placed_decor[i]
		var pos := Vector2(float(item["pos_x"]), float(item["pos_y"]))
		_draw_decor_item(pos, item, i == selected_decor_idx)

	for idx in range(state.hired_staff.size()):
		var st: Dictionary = state.hired_staff[idx]
		var sx: float = 190.0 + idx * 185.0
		var sy: float = 1045.0 + sin(_anim_time * 2.4 + idx) * 3.0
		_draw_staff_character(Vector2(sx, sy), str(st.get("name", "")), idx)

	if not state.is_visiting_guest and not waiting_pet.is_empty():
		_draw_arrived_guest_and_pet(_get_guest_group_pos(), waiting_pet)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_cosmetic_shelf(pos: Vector2) -> void:
	draw_rect(Rect2(pos - Vector2(82, 150), Vector2(164, 300)), Color("eadbc8"))
	draw_rect(Rect2(pos - Vector2(82, 150), Vector2(164, 300)), Color("bfa990"), false, 4.0)
	for sy in [-65.0, 30.0, 125.0]:
		draw_line(pos + Vector2(-78, sy), pos + Vector2(78, sy), Color("bfa990"), 5.0)
	draw_rect(Rect2(pos + Vector2(-56, -110), Vector2(28, 42)), Color("9fc4ab"))
	draw_rect(Rect2(pos + Vector2(-18, -102), Vector2(24, 34)), Color("e6b67c"))
	draw_rect(Rect2(pos + Vector2(20, -112), Vector2(30, 44)), Color("a9d3e3"))
	draw_rect(Rect2(pos + Vector2(-52, 4), Vector2(56, 24)), Color("fffdf9"))
	draw_rect(Rect2(pos + Vector2(-48, -18), Vector2(50, 22)), Color("f2dfd3"))
	draw_rect(Rect2(pos + Vector2(18, -8), Vector2(38, 34)), Color("d99b84"))

func _draw_reception_desk(pos: Vector2) -> void:
	var rect := Rect2(pos - Vector2(165, 44), Vector2(330, 88))
	draw_rect(rect, Color("e6d2bc"))
	draw_rect(Rect2(pos - Vector2(174, 54), Vector2(348, 20)), Color("f7efe4"))
	draw_rect(rect, Color("7a6858"), false, 4.0)
	draw_rect(Rect2(pos + Vector2(-95, -34), Vector2(66, 28)), Color("fffdf9"))
	draw_circle(pos + Vector2(88, -26), 12.0, Color("e7c888"))
	var font: Font = ThemeDB.fallback_font
	draw_string(font, pos + Vector2(-84, 20), "Стойка приёма", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("3c332b"))

func _draw_grooming_table(pos: Vector2, count: int) -> void:
	draw_line(pos + Vector2(-115, -55), pos + Vector2(-115, -175), Color("8d99a6"), 6.0)
	draw_line(pos + Vector2(-115, -175), pos + Vector2(15, -175), Color("8d99a6"), 6.0)
	draw_line(pos + Vector2(0, -175), pos + Vector2(0, -135), Color("d98a7e"), 3.0)
	draw_rect(Rect2(pos + Vector2(-115, 52), Vector2(18, 56)), Color("8c7765"))
	draw_rect(Rect2(pos + Vector2(97, 52), Vector2(18, 56)), Color("8c7765"))
	var rect := Rect2(pos - Vector2(142, 56), Vector2(284, 112))
	draw_rect(rect, Color("dfc6aa"))
	draw_rect(Rect2(pos - Vector2(132, 46), Vector2(264, 32)), Color("f4ebe0"))
	draw_rect(rect, Color("7a6858"), false, 4.0)
	var font: Font = ThemeDB.fallback_font
	draw_string(font, pos + Vector2(-120, 26), "Стол груминга (x%d)" % count, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("3c332b"))

func _draw_wash_bath(pos: Vector2, count: int) -> void:
	draw_line(pos + Vector2(105, -54), pos + Vector2(105, -145), Color("94a5b0"), 6.0)
	draw_line(pos + Vector2(105, -145), pos + Vector2(55, -145), Color("94a5b0"), 6.0)
	draw_circle(pos + Vector2(50, -138), 10.0, Color("b7d3dc"))
	var rect := Rect2(pos - Vector2(140, 56), Vector2(280, 112))
	draw_rect(rect, Color("c4dee6"))
	draw_rect(Rect2(pos - Vector2(128, 44), Vector2(256, 30)), Color("eef8fb"))
	draw_rect(rect, Color("6c848f"), false, 4.0)
	var font: Font = ThemeDB.fallback_font
	draw_string(font, pos + Vector2(-80, 26), "Мойка (x%d)" % count, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("34434a"))

func _draw_dry_zone(pos: Vector2, count: int, has_cabinet: bool) -> void:
	var title: String = "Сушильный шкаф" if has_cabinet else "Зона сушки"
	var col: Color = Color("c5dcd1") if has_cabinet else Color("e8d6c0")
	var rect := Rect2(pos - Vector2(145, 58), Vector2(290, 116))
	draw_rect(rect, col)
	if has_cabinet:
		draw_rect(Rect2(pos - Vector2(118, 44), Vector2(236, 62)), Color("eaf5ef"))
	draw_rect(rect, Color("7a6858"), false, 4.0)
	var font: Font = ThemeDB.fallback_font
	draw_string(font, pos + Vector2(-115, 32), "%s (x%d)" % [title, count], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("3c332b"))

func _draw_arrived_guest_and_pet(base_pos: Vector2, pet: Dictionary) -> void:
	var walk_bob: float = abs(sin(_anim_time * 8.0)) * 7.0 if _walk_progress < 1.0 else sin(_anim_time * 2.5) * 3.0

	var shirt_col: Color = pet.get("owner_shirt", Color("d69e85"))
	var hair_col: Color = pet.get("owner_hair", Color("6b4e3d"))

	var owner_pos := base_pos + Vector2(-85, -16 - walk_bob)
	draw_rect(Rect2(owner_pos + Vector2(-28, -14), Vector2(56, 78)), shirt_col)
	draw_rect(Rect2(owner_pos + Vector2(-28, -14), Vector2(56, 78)), Color("4a3f35"), false, 3.0)
	draw_circle(owner_pos + Vector2(0, -42), 28.0, Color("f2d2b6"))
	draw_circle(owner_pos + Vector2(0, -42), 28.0, Color("4a3f35"), false, 3.0)
	draw_arc(owner_pos + Vector2(0, -45), 28.0, PI, TAU, 18, hair_col, 10.0)
	draw_circle(owner_pos + Vector2(-9, -42), 3.5, Color("3c332b"))
	draw_circle(owner_pos + Vector2(9, -42), 3.5, Color("3c332b"))

	var pet_pos := base_pos + Vector2(55, 16 - walk_bob * 0.8)
	draw_line(owner_pos + Vector2(26, 16), pet_pos + Vector2(-22, -14), Color("c98a78"), 3.5)

	var tex: Texture2D = _get_optional_texture(str(pet.get("sprite_path", "")))
	if tex != null:
		var t_size := Vector2(150, 150)
		draw_texture_rect(tex, Rect2(pet_pos - t_size * 0.5, t_size), false)
	else:
		_draw_breed_miniature(pet_pos, pet)

	if _walk_progress >= 0.85:
		var pulse: float = sin(_anim_time * 4.0) * 4.0
		var bubble := Rect2(base_pos + Vector2(-210, -185 + pulse), Vector2(420, 78))
		draw_rect(bubble, Color("fffdf9"))
		draw_rect(bubble, Color("7da388"), false, 4.0)
		var font: Font = ThemeDB.fallback_font
		draw_string(font, bubble.position + Vector2(16, 32), "%s и %s (%s)" % [str(pet.get("owner_name", "Гость")), str(pet.get("name", "")), str(pet.get("breed", ""))], HORIZONTAL_ALIGNMENT_LEFT, 390, 21, Color("3c332b"))
		draw_string(font, bubble.position + Vector2(16, 62), "Нажми, чтобы принять заказ →", HORIZONTAL_ALIGNMENT_LEFT, 390, 20, Color("5a8d76"))

func _draw_breed_miniature(p: Vector2, pet: Dictionary) -> void:
	var body_col: Color = pet.get("body_color", Color("e6b67c"))
	var acc_col: Color = pet.get("accent_color", Color("fff9f0"))
	var vtype: String = str(pet.get("visual_type", "corgi"))
	var tail_swing: float = sin(_anim_time * 6.5) * 8.0

	if vtype == "persian" or vtype == "spitz":
		draw_circle(p + Vector2(42, -6 + tail_swing), 21.0, body_col)
		draw_circle(p + Vector2(48, -12 + tail_swing), 14.0, acc_col)
	elif vtype == "poodle":
		draw_circle(p + Vector2(42, -6 + tail_swing), 16.0, body_col)
	elif vtype == "british" or vtype == "lop_cat" or vtype == "dachshund":
		draw_line(p + Vector2(30, 8), p + Vector2(56, -8 + tail_swing), body_col, 11.0)
	else:
		draw_circle(p + Vector2(36, 6 + tail_swing * 0.5), 13.0, acc_col)

	var rx: float = 44.0 if vtype == "dachshund" else 36.0
	draw_circle(p + Vector2(0, 12), rx, body_col)
	draw_circle(p + Vector2(0, 12), rx, Color("5c4d40"), false, 3.0)
	if vtype == "persian" or vtype == "poodle" or vtype == "spitz":
		draw_circle(p + Vector2(-18, 4), 19.0, acc_col)
		draw_circle(p + Vector2(18, 4), 19.0, acc_col)

	var head := p + Vector2(0, -28)
	draw_circle(head, 30.0, body_col)
	draw_circle(head, 30.0, Color("5c4d40"), false, 3.0)

	match vtype:
		"persian":
			draw_colored_polygon(PackedVector2Array([head + Vector2(-24, -12), head + Vector2(-16, -36), head + Vector2(-4, -20)]), acc_col)
			draw_colored_polygon(PackedVector2Array([head + Vector2(24, -12), head + Vector2(16, -36), head + Vector2(4, -20)]), acc_col)
		"british":
			draw_colored_polygon(PackedVector2Array([head + Vector2(-24, -12), head + Vector2(-12, -40), head + Vector2(-2, -20)]), body_col)
			draw_colored_polygon(PackedVector2Array([head + Vector2(24, -12), head + Vector2(12, -40), head + Vector2(2, -20)]), body_col)
		"lop_cat":
			draw_circle(head + Vector2(-25, -16), 13.0, acc_col)
			draw_circle(head + Vector2(25, -16), 13.0, acc_col)
		"corgi", "spitz":
			draw_colored_polygon(PackedVector2Array([head + Vector2(-25, -14), head + Vector2(-19, -50), head + Vector2(-3, -22)]), body_col)
			draw_colored_polygon(PackedVector2Array([head + Vector2(25, -14), head + Vector2(19, -50), head + Vector2(3, -22)]), body_col)
			draw_rect(Rect2(head + Vector2(-6, -20), Vector2(12, 22)), acc_col)
		"poodle":
			draw_circle(head + Vector2(0, -25), 19.0, body_col)
			draw_circle(head + Vector2(-30, -3), 15.0, acc_col)
			draw_circle(head + Vector2(30, -3), 15.0, acc_col)
		"dachshund":
			draw_circle(head + Vector2(-28, 3), 14.0, acc_col)
			draw_circle(head + Vector2(28, 3), 14.0, acc_col)

	draw_circle(head + Vector2(-11, -3), 4.2, Color("3c332b"))
	draw_circle(head + Vector2(11, -3), 4.2, Color("3c332b"))
	draw_circle(head + Vector2(0, 6), 4.5, Color("d98a7e"))

func _draw_decor_item(pos: Vector2, item: Dictionary, is_selected: bool) -> void:
	var id: String = str(item.get("id", ""))
	var col: Color = item.get("color", Color("6f9e7b"))
	if id.begins_with("plant"):
		draw_rect(Rect2(pos + Vector2(-28, 8), Vector2(56, 38)), Color("c98e6b"))
		draw_rect(Rect2(pos + Vector2(-28, 8), Vector2(56, 38)), Color("6e4d3b"), false, 3.0)
		draw_circle(pos + Vector2(-20, -15), 26.0, col)
		draw_circle(pos + Vector2(20, -12), 26.0, col.lightened(0.08))
		draw_circle(pos + Vector2(0, -30), 28.0, col)
	elif id == "lounge_sofa":
		draw_rect(Rect2(pos + Vector2(-72, -30), Vector2(144, 60)), col)
		draw_rect(Rect2(pos + Vector2(-72, -30), Vector2(144, 22)), col.darkened(0.12))
		draw_rect(Rect2(pos + Vector2(-54, -15), Vector2(34, 26)), Color("fff8ef"))
		draw_rect(Rect2(pos + Vector2(20, -15), Vector2(34, 26)), Color("fff8ef"))
		draw_rect(Rect2(pos + Vector2(-72, -30), Vector2(144, 60)), Color("6e5d4f"), false, 3.0)
	elif id == "lounge_tea":
		draw_circle(pos, 44.0, col)
		draw_circle(pos, 44.0, Color("6e5d4f"), false, 3.0)
		draw_circle(pos + Vector2(-10, -5), 10.0, Color("fffdf9"))
		draw_circle(pos + Vector2(12, 8), 9.0, Color("9fc4ab"))
	elif id == "lamp_warm":
		draw_circle(pos + Vector2(0, -22), 56.0, Color(0.95, 0.85, 0.58, 0.35))
		draw_line(pos + Vector2(0, -12), pos + Vector2(0, 44), Color("6e5d4f"), 5.0)
		draw_colored_polygon(PackedVector2Array([pos + Vector2(-30, -8), pos + Vector2(30, -8), pos + Vector2(18, -44), pos + Vector2(-18, -44)]), col)
	else:
		draw_circle(pos, 46.0, col)
		draw_circle(pos, 46.0, Color("6e5d4f"), false, 3.0)

	if is_selected:
		draw_circle(pos, 68.0, Color("5a8d76"), false, 4.0)

func _draw_staff_character(pos: Vector2, staff_name: String, idx: int) -> void:
	var apron_cols := [Color("8fb39e"), Color("9ab8c9"), Color("d9a38f"), Color("b3a2c7")]
	var apron: Color = apron_cols[idx % apron_cols.size()]
	draw_rect(Rect2(pos + Vector2(-24, -12), Vector2(48, 62)), apron)
	draw_rect(Rect2(pos + Vector2(-24, -12), Vector2(48, 62)), Color("4a3f35"), false, 2.5)
	draw_circle(pos + Vector2(0, -36), 24.0, Color("f0cfb0"))
	draw_circle(pos + Vector2(0, -36), 24.0, Color("4a3f35"), false, 2.5)
	draw_circle(pos + Vector2(-8, -37), 3.2, Color("3c332b"))
	draw_circle(pos + Vector2(8, -37), 3.2, Color("3c332b"))
	var font: Font = ThemeDB.fallback_font
	draw_string(font, pos + Vector2(-30, 72), staff_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("4a3f35"))
