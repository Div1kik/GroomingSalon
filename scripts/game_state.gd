extends Control
class_name GroomingMinigame

signal session_finished(pet_data: Dictionary, calm_ratio: float, reward_money: int)
signal closed_early

enum Location { TABLE, BATH }
enum Step { CALM_BRUSH, TRIM_COAT, CLIP_NAILS, WASH_SOAP, WASH_RINSE, TOWEL_WRAP, BLOW_DRY, FINAL_TRIM, FINAL_STYLE, SUMMARY }
enum Tool { NONE, BRUSH, SCISSORS, CLIPPER, SHAMPOO, SHOWER, TOWEL, DRYER, CABINET }

var state: GameState
var sound: SoundManager

var pet: Dictionary = {}
var location: Location = Location.TABLE
var step: Step = Step.CALM_BRUSH
var active_tool: Tool = Tool.NONE

var stress: float = 18.0
var calmness: float = 40.0
var step_progress: float = 0.0
var dryer_heat: float = 0.0

var chosen_accessory: String = "bow"
var chosen_scent: String = "lavender"

# Анимации инструментов и состояний
var _tool_anim_timer: float = 0.0
var _towel_wrap_ratio: float = 0.0
var _fur_pile_count: int = 0
var _sound_tick_timer: float = 0.0

# Тайминг для стрижки когтей
var _nail_cursor: float = 0.0
var _nail_dir: float = 1.0
var _nails_done: Array[bool] = [false, false, false, false]
var _active_nail_idx: int = 0

var toy_cooldown: float = 0.0
var toy_timer: float = 0.0
var _anim_time: float = 0.0
var _transition_alpha: float = 0.0
var _shake_timer: float = 0.0
var _sensitive_cooldown: float = 0.0
var _blink_timer: float = 2.5
var _is_blinking: bool = false

var _stroking: bool = false
var _pointer_pos: Vector2 = Vector2(-200, -200)
var _last_stroke_pos: Vector2 = Vector2.ZERO
var _last_heat_pos: Vector2 = Vector2.ZERO

var _particles: Array[Dictionary] = []
var _coat_items: Array[Dictionary] = []
var _tex_cache: Dictionary = {}

var _title_lbl: Label
var _loc_lbl: Label
var _status_lbl: Label
var _stress_bar: ProgressBar
var _calm_bar: ProgressBar
var _prog_bar: ProgressBar
var _heat_row: VBoxContainer
var _heat_bar: ProgressBar
var _pad_panel: Control
var _tools_box: HBoxContainer
var _style_box: VBoxContainer
var _toy_btn: Button
var _action_btn: Button

func setup(p_state: GameState, p_sound: SoundManager) -> void:
	state = p_state
	sound = p_sound
	_build_ui()
	visible = false

func start_new_pet(preset_pet: Dictionary = {}) -> void:
	if preset_pet.is_empty():
		pet = state.spawn_pet_client()
	else:
		pet = preset_pet.duplicate(true)

	location = Location.TABLE
	step = Step.CALM_BRUSH
	active_tool = Tool.NONE
	stress = clamp(22.0 - float(pet.get("trust", 0.0)) * 12.0, 5.0, 45.0)
	calmness = clamp(42.0 + float(pet.get("trust", 0.0)) * 20.0, 15.0, 85.0)
	step_progress = 0.0
	dryer_heat = 0.0
	toy_cooldown = 0.0
	toy_timer = 0.0
	_transition_alpha = 1.0
	_shake_timer = 0.0
	_sensitive_cooldown = 0.0
	_tool_anim_timer = 0.0
	_towel_wrap_ratio = 0.0
	_fur_pile_count = 0
	chosen_accessory = str(pet.get("pref_acc", "bow"))
	chosen_scent = str(pet.get("pref_scent", "lavender"))
	_nails_done = [false, false, false, false]
	_active_nail_idx = 0
	_nail_cursor = 0.1
	_particles.clear()
	_setup_step_items()

	visible = true
	_refresh_ui()
	if _pad_panel != null:
		_pad_panel.queue_redraw()

func _setup_step_items() -> void:
	_coat_items.clear()
	var offsets := [
		Vector2(-0.46, 0.14), Vector2(0.44, 0.18), Vector2(-0.26, 0.54),
		Vector2(0.28, 0.50), Vector2(0.0, 0.24), Vector2(-0.36, -0.26),
		Vector2(0.36, -0.24), Vector2(-0.20, 0.72), Vector2(0.22, 0.70)
	]
	match step:
		Step.TRIM_COAT:
			var rim_offsets := [
				Vector2(-0.76, 0.18), Vector2(0.76, 0.18),
				Vector2(-0.68, 0.54), Vector2(0.68, 0.54),
				Vector2(-0.32, 0.28), Vector2(0.32, 0.28),
				Vector2(0.0, -0.98)
			]
			for i in range(rim_offsets.size()):
				_coat_items.append({
					"offset": rim_offsets[i],
					"value": 1.0,
					"foam": 0.0,
					"size": randf_range(26.0, 34.0),
					"is_tuft": i < 4 or i == 6
				})
		Step.CLIP_NAILS:
			_nails_done = [false, false, false, false]
			_active_nail_idx = 0
			_nail_cursor = 0.15
		Step.WASH_SOAP:
			for i in range(7):
				_coat_items.append({
					"offset": offsets[i],
					"value": 1.0,
					"foam": 0.0,
					"size": randf_range(26.0, 34.0)
				})
		Step.WASH_RINSE:
			for i in range(8):
				_coat_items.append({
					"offset": offsets[i],
					"value": 0.0,
					"foam": 1.0,
					"size": randf_range(30.0, 38.0)
				})
		Step.TOWEL_WRAP, Step.BLOW_DRY:
			for i in range(8):
				_coat_items.append({
					"offset": offsets[i],
					"value": 1.0,
					"foam": 0.0,
					"size": randf_range(20.0, 26.0)
				})
		Step.FINAL_TRIM:
			var stray_offsets := [
				Vector2(-0.74, 0.12), Vector2(0.74, 0.15),
				Vector2(-0.62, -0.52), Vector2(0.62, -0.52)
			]
			for off in stray_offsets:
				_coat_items.append({
					"offset": off,
					"value": 1.0,
					"foam": 0.0,
					"size": 22.0,
					"is_tuft": true
				})

func _vibrate_tap(ms: int = 24) -> void:
	if OS.has_feature("mobile") or OS.has_feature("web"):
		Input.vibrate_handheld(ms)

func _process(delta: float) -> void:
	if not visible:
		return

	_anim_time += delta
	if _transition_alpha > 0.0:
		_transition_alpha = max(0.0, _transition_alpha - delta * 2.2)
	if _shake_timer > 0.0:
		_shake_timer = max(0.0, _shake_timer - delta)
	if _sensitive_cooldown > 0.0:
		_sensitive_cooldown = max(0.0, _sensitive_cooldown - delta)
	if _tool_anim_timer > 0.0:
		_tool_anim_timer = max(0.0, _tool_anim_timer - delta)
	if _sound_tick_timer > 0.0:
		_sound_tick_timer = max(0.0, _sound_tick_timer - delta)
	if toy_timer > 0.0:
		toy_timer = max(0.0, toy_timer - delta)

	if step == Step.CLIP_NAILS:
		var spd: float = 1.25 + float(_active_nail_idx) * 0.18
		_nail_cursor += _nail_dir * delta * spd
		if _nail_cursor >= 1.0:
			_nail_cursor = 1.0
			_nail_dir = -1.0
		elif _nail_cursor <= 0.0:
			_nail_cursor = 0.0
			_nail_dir = 1.0

	_blink_timer -= delta
	if _blink_timer <= 0.0:
		if _is_blinking:
			_is_blinking = false
			_blink_timer = randf_range(2.2, 4.2)
		else:
			_is_blinking = true
			_blink_timer = 0.14

	for i in range(_particles.size() - 1, -1, -1):
		var p: Dictionary = _particles[i]
		p["age"] = float(p["age"]) + delta
		if float(p["age"]) >= float(p["life"]):
			_particles.remove_at(i)
		else:
			p["pos"] = Vector2(p["pos"]) + Vector2(p["vel"]) * delta
			p["vel"] = Vector2(p["vel"]) + Vector2(0, float(p.get("gravity", 0.0))) * delta

	if step != Step.SUMMARY:
		if toy_cooldown > 0.0:
			toy_cooldown = max(0.0, toy_cooldown - delta)

		if _stroking:
			if step == Step.WASH_RINSE and active_tool == Tool.SHOWER:
				_apply_shower_stream(delta)
			elif step == Step.BLOW_DRY and active_tool == Tool.DRYER:
				_apply_dryer_stream(delta)
		else:
			dryer_heat = max(0.0, dryer_heat - delta * 28.0)

		if step == Step.BLOW_DRY and active_tool == Tool.CABINET:
			_apply_cabinet_dry(delta)

		var stress_rate: float = 2.1 - float(state.equipment_tier) * 0.25
		if location == Location.BATH and bool(pet.get("fear_water", false)) and not bool(state.tool_upgrades.get("spa_shampoo", false)):
			stress_rate += 2.6
		elif step == Step.BLOW_DRY and active_tool == Tool.DRYER and bool(pet.get("fear_dryer", false)) and not bool(state.tool_upgrades.get("quiet_dryer", false)):
			stress_rate += 2.9

		if calmness > 65.0:
			stress_rate -= 1.4

		stress = clamp(stress + stress_rate * delta, 0.0, 100.0)
		if stress > 75.0:
			calmness = clamp(calmness - 3.2 * delta, 0.0, 100.0)

		if randf() < delta * 0.85 and stress > 58.0:
			sound.play_stress_tick()

		_update_bars()

	if _pad_panel != null:
		_pad_panel.queue_redraw()

func _select_tool(t: Tool) -> void:
	active_tool = t
	_stroking = false
	_tool_anim_timer = 0.25
	sound.play_soft_pop(1.15)
	_vibrate_tap(16)
	_refresh_ui()

func _on_pad_gui_input(event: InputEvent) -> void:
	if not visible or step == Step.SUMMARY:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_stroking = mb.pressed
			_pointer_pos = mb.position
			_last_stroke_pos = mb.position
			_last_heat_pos = mb.position
			if mb.pressed:
				_handle_tap_action(mb.position)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		_pointer_pos = mm.position
		if _stroking:
			var dist: float = mm.position.distance_to(_last_stroke_pos)
			_last_stroke_pos = mm.position
			if dist >= 2.0:
				_handle_drag_action(mm.position, dist)

func _get_zone_pos(zone_name: String) -> Vector2:
	var center := _get_pet_center()
	var r: float = _get_pet_radius()
	var head_pos := center + Vector2(0, -r * 0.42)
	match zone_name:
		"ears": return head_pos + Vector2(-r * 0.44, -r * 0.56)
		"chin": return head_pos + Vector2(0, r * 0.34)
		"back": return center + Vector2(r * 0.45, r * 0.15)
		"paws": return center + Vector2(0, r * 0.90)
		"belly": return center + Vector2(0, r * 0.48)
	return center

func _handle_tap_action(pos: Vector2) -> void:
	if step == Step.FINAL_STYLE:
		var center := _get_pet_center()
		var r: float = _get_pet_radius()
		if pos.distance_to(center) <= r * 1.15:
			_apply_final_style_finish()
		return

	var required: Tool = _get_required_tool()
	if active_tool != required:
		_status_lbl.text = "Сначала выбери нужный инструмент на панели снизу!"
		sound.play_stress_tick()
		return

	var center := _get_pet_center()
	var r: float = _get_pet_radius()

	match step:
		Step.TRIM_COAT, Step.FINAL_TRIM:
			_tool_anim_timer = 0.24
			sound.play_scissors_snip()
			var hit_any: bool = false
			for item in _coat_items:
				if float(item["value"]) <= 0.05:
					continue
				var sp: Vector2 = center + Vector2(item["offset"]) * r
				if pos.distance_to(sp) <= max(58.0, r * 0.44):
					item["value"] = 0.0
					hit_any = true
					_fur_pile_count = min(14, _fur_pile_count + 1)
					_vibrate_tap(28)
					for _k in range(6):
						_particles.append({
							"pos": sp,
							"vel": Vector2(randf_range(-80, 80), randf_range(-100, -20)),
							"gravity": 260.0,
							"age": 0.0,
							"life": 0.85,
							"radius": randf_range(7.0, 12.0),
							"color": pet.get("body_color", Color("e6b67c")).darkened(0.12)
						})
					break
			if not hit_any and pos.distance_to(center) < r * 0.85:
				stress = clamp(stress + 6.5, 0.0, 100.0)
				sound.play_stress_tick()
				_vibrate_tap(45)
				_status_lbl.text = "Ой! Стрижём только отросшие пучки и колтуны."
			_recalc_items_progress()

		Step.CLIP_NAILS:
			_tool_anim_timer = 0.25
			if _nail_cursor >= 0.33 and _nail_cursor <= 0.67:
				_nails_done[_active_nail_idx] = true
				calmness = clamp(calmness + 6.0, 0.0, 100.0)
				sound.play_clipper_snip()
				_vibrate_tap(30)
				var paw_center := _get_nail_paw_center()
				var nail_x: float = paw_center.x + (-1.5 + float(_active_nail_idx)) * 56.0
				for _k in range(7):
					_particles.append({
						"pos": Vector2(nail_x, paw_center.y - 45.0),
						"vel": Vector2(randf_range(-70, 70), randf_range(-110, -30)),
						"gravity": 220.0,
						"age": 0.0,
						"life": 0.75,
						"radius": 7.5,
						"color": Color("9fc4ab")
					})
				_active_nail_idx += 1
				step_progress = (float(_active_nail_idx) / 4.0) * 100.0
				_update_bars()
				if _active_nail_idx >= 4:
					_advance_step()
				else:
					_status_lbl.text = "Щёлк! Идеальный срез! Осталось когтей: %d" % (4 - _active_nail_idx)
			else:
				stress = clamp(stress + 9.0, 0.0, 100.0)
				_shake_timer = 0.45
				sound.play_stress_tick()
				_vibrate_tap(60)
				_status_lbl.text = "Слишком близко к сосуду! Лови бегунок строго в зелёной зоне."

		Step.TOWEL_WRAP:
			_apply_towel_action(pos)

func _apply_towel_action(pos: Vector2) -> void:
	var center := _get_pet_center()
	var r: float = _get_pet_radius()
	_tool_anim_timer = 0.22
	var dried_any: bool = false
	for item in _coat_items:
		if float(item["value"]) <= 0.05:
			continue
		var sp: Vector2 = center + Vector2(item["offset"]) * r
		if pos.distance_to(sp) <= max(76.0, r * 0.62):
			item["value"] = max(0.0, float(item["value"]) - 0.55)
			dried_any = true
	if dried_any or pos.distance_to(center) <= r * 1.1:
		_towel_wrap_ratio = min(1.0, _towel_wrap_ratio + 0.18)
		calmness = clamp(calmness + 2.2, 0.0, 100.0)
		if _sound_tick_timer <= 0.0:
			sound.play_brush_stroke()
			_sound_tick_timer = 0.14
		_vibrate_tap(18)
		for _k in range(4):
			_particles.append({
				"pos": pos + Vector2(randf_range(-25, 25), randf_range(-25, 25)),
				"vel": Vector2(randf_range(-55, 55), randf_range(-75, -20)),
				"gravity": 110.0,
				"age": 0.0,
				"life": 0.6,
				"radius": 8.0,
				"color": Color("fffdf9")
			})
	_recalc_items_progress()

func _handle_drag_action(pos: Vector2, dist: float) -> void:
	var required: Tool = _get_required_tool()
	if active_tool != required:
		return

	var center := _get_pet_center()
	var r: float = _get_pet_radius()
	var gain: float = clamp(dist * 0.22, 0.5, 4.5)
	_tool_anim_timer = 0.18

	match step:
		Step.CALM_BRUSH:
			var love_pos := _get_zone_pos(str(pet.get("love_zone", "ears")))
			var sens_pos := _get_zone_pos(str(pet.get("sensitive_zone", "paws")))

			if pos.distance_to(sens_pos) <= r * 0.34 and _sensitive_cooldown <= 0.0:
				_sensitive_cooldown = 1.2
				stress = clamp(stress + 7.5, 0.0, 100.0)
				_shake_timer = 0.4
				sound.play_stress_tick()
				_vibrate_tap(50)
				_status_lbl.text = "Ой, там щекотно! Погладь в подсвеченной зелёным зоне доверия."
				return

			if dist > 68.0:
				stress = clamp(stress + 2.0, 0.0, 100.0)
				_status_lbl.text = "Помедленнее! Веди расчёску плавно, чтобы не тянуть шерсть."
			else:
				var in_love: bool = pos.distance_to(love_pos) <= r * 0.46
				var zone_mult: float = 1.75 if in_love else 1.0
				var brush_bonus: float = 1.4 if bool(state.tool_upgrades.get("soft_brush", false)) else 1.0
				calmness = clamp(calmness + gain * 1.3 * zone_mult * brush_bonus, 0.0, 100.0)
				stress = clamp(stress - gain * 1.1 * zone_mult * brush_bonus, 0.0, 100.0)
				step_progress = clamp(step_progress + gain * 1.35 * zone_mult * brush_bonus, 0.0, 100.0)
				if in_love:
					_status_lbl.text = "Мур-р! Шерсть ложится мягко, а пушок собирается рядом на столе!"
				if _sound_tick_timer <= 0.0:
					sound.play_brush_stroke()
					_sound_tick_timer = 0.12
				# Вычесанная шерсть падает рядом на стол
				if randf() < 0.55:
					_fur_pile_count = min(14, _fur_pile_count + 1)
					var body_col: Color = pet.get("body_color", Color("e6b67c"))
					_particles.append({
						"pos": pos + Vector2(randf_range(-16, 16), 10),
						"vel": Vector2(randf_range(40, 120), randf_range(-40, 60)),
						"gravity": 240.0,
						"age": 0.0,
						"life": 0.85,
						"radius": randf_range(9.0, 15.0),
						"color": body_col.lightened(0.12)
					})
			if step_progress >= 100.0:
				_advance_step()

		Step.WASH_SOAP:
			if _sound_tick_timer <= 0.0:
				sound.play_foam_sound()
				_sound_tick_timer = 0.11
			for item in _coat_items:
				var sp: Vector2 = center + Vector2(item["offset"]) * r
				if pos.distance_to(sp) <= max(68.0, r * 0.55):
					item["foam"] = min(1.0, float(item["foam"]) + clamp(dist * 0.012, 0.04, 0.22))
					item["value"] = max(0.0, 1.0 - float(item["foam"]))
			if randf() < 0.65:
				_particles.append({
					"pos": pos + Vector2(randf_range(-20, 20), randf_range(-20, 20)),
					"vel": Vector2(randf_range(-25, 25), randf_range(-65, -20)),
					"gravity": -20.0,
					"age": 0.0,
					"life": 0.9,
					"radius": randf_range(10.0, 18.0),
					"color": Color("ffffff")
				})
			_recalc_items_progress()

		Step.TOWEL_WRAP:
			_apply_towel_action(pos)

func _apply_shower_stream(delta: float) -> void:
	_tool_anim_timer = 0.15
	if _sound_tick_timer <= 0.0:
		sound.play_water_stream()
		_sound_tick_timer = 0.08
	var center := _get_pet_center()
	var r: float = _get_pet_radius()
	var water_hit := _pointer_pos + Vector2(0, 52.0)
	for item in _coat_items:
		var sp: Vector2 = center + Vector2(item["offset"]) * r
		if water_hit.distance_to(sp) <= max(76.0, r * 0.62):
			item["foam"] = max(0.0, float(item["foam"]) - delta * 1.45)

	if randf() < delta * 36.0:
		_particles.append({
			"pos": _pointer_pos + Vector2(randf_range(-18, 18), 20),
			"vel": Vector2(randf_range(-35, 35), randf_range(220, 320)),
			"gravity": 320.0,
			"age": 0.0,
			"life": 0.45,
			"radius": 6.5,
			"color": Color("8fd0eb")
		})
	_recalc_items_progress()

func _apply_dryer_stream(delta: float) -> void:
	_tool_anim_timer = 0.15
	if _sound_tick_timer <= 0.0:
		sound.play_dryer_hum()
		_sound_tick_timer = 0.08
	var center := _get_pet_center()
	var r: float = _get_pet_radius()
	var heat_gain: float = 22.0 if bool(state.tool_upgrades.get("quiet_dryer", false)) else 46.0

	if _pointer_pos.distance_to(_last_heat_pos) < 16.0:
		dryer_heat = clamp(dryer_heat + delta * heat_gain, 0.0, 100.0)
		if dryer_heat > 75.0:
			stress = clamp(stress + delta * 14.0, 0.0, 100.0)
			_vibrate_tap(25)
			_status_lbl.text = "Горячо! Води феном плавно, не держи на одном месте!"
	else:
		_last_heat_pos = _pointer_pos
		dryer_heat = max(0.0, dryer_heat - delta * 35.0)

	for item in _coat_items:
		var sp: Vector2 = center + Vector2(item["offset"]) * r
		if _pointer_pos.distance_to(sp) <= max(78.0, r * 0.65):
			item["value"] = max(0.0, float(item["value"]) - delta * 1.35)

	if randf() < delta * 26.0:
		_particles.append({
			"pos": _pointer_pos + Vector2(20, randf_range(-12, 12)),
			"vel": Vector2(randf_range(130, 210), randf_range(-30, 30)),
			"gravity": 0.0,
			"age": 0.0,
			"life": 0.38,
			"radius": 8.0,
			"color": Color("f5d293")
		})
	_recalc_items_progress()

func _apply_cabinet_dry(delta: float) -> void:
	stress = max(0.0, stress - delta * 4.5)
	calmness = min(100.0, calmness + delta * 3.0)
	for item in _coat_items:
		item["value"] = max(0.0, float(item["value"]) - delta * 0.38)
	_recalc_items_progress()

func _recalc_items_progress() -> void:
	if _coat_items.is_empty():
		return
	var total: float = 0.0
	for item in _coat_items:
		match step:
			Step.TRIM_COAT, Step.FINAL_TRIM, Step.TOWEL_WRAP, Step.BLOW_DRY:
				total += (1.0 - float(item["value"]))
			Step.WASH_SOAP:
				total += float(item["foam"])
			Step.WASH_RINSE:
				total += (1.0 - float(item["foam"]))
	step_progress = clamp((total / float(_coat_items.size())) * 100.0, 0.0, 100.0)
	_update_bars()
	if step_progress >= 99.5:
		step_progress = 100.0
		_advance_step()

func _apply_final_style_finish() -> void:
	var center := _get_pet_center()
	var scent_col := Color("c7a6d9") if chosen_scent == "lavender" else (Color("f5dfa6") if chosen_scent == "vanilla" else Color("a8d9a6"))
	for _i in range(28):
		_particles.append({
			"pos": center + Vector2(randf_range(-85, 85), randf_range(-95, 45)),
			"vel": Vector2(randf_range(-110, 110), randf_range(-170, -40)),
			"gravity": 160.0,
			"age": 0.0,
			"life": 1.35,
			"radius": 10.5,
			"color": scent_col
		})
	_advance_step()

func _advance_step() -> void:
	_stroking = false
	active_tool = Tool.NONE
	step_progress = 0.0
	dryer_heat = 0.0
	_vibrate_tap(40)

	match step:
		Step.CALM_BRUSH:
			sound.play_success()
			step = Step.TRIM_COAT
		Step.TRIM_COAT:
			sound.play_success()
			step = Step.CLIP_NAILS
		Step.CLIP_NAILS:
			sound.play_success()
			location = Location.BATH
			step = Step.WASH_SOAP
			_transition_alpha = 1.0
		Step.WASH_SOAP:
			sound.play_success()
			step = Step.WASH_RINSE
		Step.WASH_RINSE:
			sound.play_success()
			# Полотенце используется прямо в зоне ванной!
			step = Step.TOWEL_WRAP
			_towel_wrap_ratio = 0.25
		Step.TOWEL_WRAP:
			# Забавная дрожь-отряхивание при переходе из ванной на основной стол!
			sound.play_shiver_sound()
			_shake_timer = 0.95
			_towel_wrap_ratio = 0.0
			location = Location.TABLE
			step = Step.BLOW_DRY
			_transition_alpha = 1.0
		Step.BLOW_DRY:
			sound.play_success()
			# После сушки феном на основном столе — финальное подравнивание ножничками
			step = Step.FINAL_TRIM
		Step.FINAL_TRIM:
			sound.play_success()
			step = Step.FINAL_STYLE
		Step.FINAL_STYLE:
			sound.play_success()
			step = Step.SUMMARY

	_setup_step_items()
	_refresh_ui()

func _get_required_tool() -> Tool:
	match step:
		Step.CALM_BRUSH: return Tool.BRUSH
		Step.TRIM_COAT, Step.FINAL_TRIM: return Tool.SCISSORS
		Step.CLIP_NAILS: return Tool.CLIPPER
		Step.WASH_SOAP: return Tool.SHAMPOO
		Step.WASH_RINSE: return Tool.SHOWER
		Step.TOWEL_WRAP: return Tool.TOWEL
		Step.BLOW_DRY: return Tool.CABINET if active_tool == Tool.CABINET else Tool.DRYER
	return Tool.NONE

func _on_toy_pressed() -> void:
	if toy_cooldown > 0.0:
		return
	toy_cooldown = 4.5
	toy_timer = 2.4
	calmness = clamp(calmness + 26.0, 0.0, 100.0)
	stress = clamp(stress - 22.0, 0.0, 100.0)
	sound.play_success()
	_vibrate_tap(25)
	_status_lbl.text = "Питомец играет с «%s» и успокаивается!" % str(pet.get("toy", "игрушкой"))
	_update_bars()

func _calc_final_reward() -> Dictionary:
	var calm_ratio: float = clamp((calmness / 100.0) * 0.65 + (1.0 - stress / 100.0) * 0.35, 0.0, 1.0)
	var acc_match: bool = (chosen_accessory == str(pet.get("pref_acc", "bow")))
	var scent_match: bool = (chosen_scent == str(pet.get("pref_scent", "lavender")))
	var style_bonus: float = 0.0
	if acc_match:
		style_bonus += 0.20
	if scent_match:
		style_bonus += 0.15
	var reward: int = int(round(float(pet.get("base_price", 180)) * (0.65 + calm_ratio * 0.65 + style_bonus)))
	return {
		"calm_ratio": calm_ratio,
		"reward": reward,
		"acc_match": acc_match,
		"scent_match": scent_match
	}

func _on_action_pressed() -> void:
	if step == Step.SUMMARY:
		var res := _calc_final_reward()
		visible = false
		emit_signal("session_finished", pet, float(res["calm_ratio"]), int(res["reward"]))

func _refresh_ui() -> void:
	_title_lbl.text = "%s • %s (%s)" % [pet.get("name", ""), pet.get("species", ""), pet.get("breed", "")]

	match location:
		Location.TABLE:
			_loc_lbl.text = "Основной стол груминга • Заказ: %s" % str(pet.get("wish_tag", ""))
		Location.BATH:
			_loc_lbl.text = "Ванная зона • Купание и обёртывание в полотенце"

	_heat_row.visible = (step == Step.BLOW_DRY and active_tool == Tool.DRYER)
	_style_box.visible = (step == Step.FINAL_STYLE)
	_tools_box.visible = (step != Step.FINAL_STYLE and step != Step.SUMMARY)
	_action_btn.visible = (step == Step.SUMMARY)
	_toy_btn.visible = (step != Step.SUMMARY)

	var req: Tool = _get_required_tool()
	var tool_selected: bool = (active_tool == req) or (step == Step.BLOW_DRY and active_tool == Tool.CABINET)

	match step:
		Step.CALM_BRUSH:
			_status_lbl.text = "1/9 Вычёсывание: возьми «Расчёску» и погладь в зелёной зоне доверия!" if not tool_selected else "Веди расчёску плавно — пушок собирается рядом на столе!"
		Step.TRIM_COAT:
			_status_lbl.text = "2/9 Стрижка колтунов: возьми «Ножницы» и состриги пучки по контуру." if not tool_selected else "Нажимай на колтуны и торчащие пучки."
		Step.CLIP_NAILS:
			_status_lbl.text = "3/9 Стрижка когтей: выбери «Щипчики» на панели снизу." if not tool_selected else "Нажми по экрану, когда бегунок в ЗЕЛЁНОЙ зоне!"
		Step.WASH_SOAP:
			_status_lbl.text = "4/9 Намыливание (Ванная): возьми «Шампунь» и взбей густую пену." if not tool_selected else "Води губкой с шампунем по пятнышкам до белой пены."
		Step.WASH_RINSE:
			_status_lbl.text = "5/9 Смыв пены (Ванная): переключись на «Душ» и смой пену водой." if not tool_selected else "Зажми и води лейкой душа над пеной."
		Step.TOWEL_WRAP:
			_status_lbl.text = "6/9 Полотенце (у ванной): возьми «Полотенце», чтобы укутать питомца!" if not tool_selected else "Промокни капли и укутай питомца в тёплое полотенце!"
		Step.BLOW_DRY:
			var cab_hint: String = " или «Шкаф»" if state.has_drying_cabinet else ""
			_status_lbl.text = "7/9 Сушка на столе: выбери «Фен»%s и распуши шерсть." % cab_hint if not tool_selected else ("Сушильный шкаф бережно сушит шерсть..." if active_tool == Tool.CABINET else "Води феном плавно, следи за температурой!")
		Step.FINAL_TRIM:
			_status_lbl.text = "8/9 Подравнивание после фена: возьми «Ножницы» и подровняй торчащие волосинки!" if not tool_selected else "Щёлкни ножницами по торчащим прядям после укладки."
		Step.FINAL_STYLE:
			_status_lbl.text = "9/9 Финальный образ: выбери аксессуар и аромат (%s), затем нажми на питомца!" % str(pet.get("wish_tag", ""))
			_rebuild_style_selectors()
		Step.SUMMARY:
			var res := _calc_final_reward()
			var bonus_txt := " • Чаевые за стиль!" if (bool(res["acc_match"]) or bool(res["scent_match"])) else ""
			_status_lbl.text = "Готово! Спокойствие: %d%%%s • Итого: +%d ₽" % [int(float(res["calm_ratio"]) * 100), bonus_txt, int(res["reward"])]
			_action_btn.text = "Забрать оплату (+%d ₽) и вернуться в зал" % int(res["reward"])

	_rebuild_tool_buttons()
	_update_bars()

func _rebuild_style_selectors() -> void:
	for c in _style_box.get_children():
		c.queue_free()

	var acc_row := HBoxContainer.new()
	acc_row.add_theme_constant_override("separation", 8)
	_style_box.add_child(acc_row)

	var acc_items := [
		{"id": "bow", "label": "Бантик"},
		{"id": "crown", "label": "Корона"},
		{"id": "bandana", "label": "Бандана"},
		{"id": "flower", "label": "Цветочек"}
	]
	for a in acc_items:
		var b := Button.new()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 58)
		b.add_theme_font_size_override("font_size", 21)
		b.text = ("✓ " + a["label"]) if chosen_accessory == a["id"] else a["label"]
		b.pressed.connect(func():
			chosen_accessory = a["id"]
			sound.play_soft_pop(1.2)
			_vibrate_tap(16)
			_rebuild_style_selectors()
		)
		acc_row.add_child(b)

	var scent_row := HBoxContainer.new()
	scent_row.add_theme_constant_override("separation", 8)
	_style_box.add_child(scent_row)

	var scent_items := [
		{"id": "lavender", "label": "Лаванда"},
		{"id": "vanilla", "label": "Ваниль"},
		{"id": "apple", "label": "Яблоко"}
	]
	for s in scent_items:
		var sb := Button.new()
		sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sb.custom_minimum_size = Vector2(0, 56)
		sb.add_theme_font_size_override("font_size", 21)
		sb.text = ("✓ " + s["label"]) if chosen_scent == s["id"] else s["label"]
		sb.pressed.connect(func():
			chosen_scent = s["id"]
			sound.play_soft_pop(1.3)
			_vibrate_tap(16)
			_rebuild_style_selectors()
		)
		scent_row.add_child(sb)

	var apply_btn := Button.new()
	apply_btn.text = "Завершить образ и сделать фото ✨"
	apply_btn.custom_minimum_size = Vector2(0, 66)
	apply_btn.add_theme_font_size_override("font_size", 24)
	apply_btn.pressed.connect(_apply_final_style_finish)
	_style_box.add_child(apply_btn)

func _rebuild_tool_buttons() -> void:
	for c in _tools_box.get_children():
		c.queue_free()

	if step == Step.FINAL_STYLE or step == Step.SUMMARY:
		return

	var available: Array[Dictionary] = []
	match location:
		Location.TABLE:
			available = [
				{"tool": Tool.BRUSH, "label": "Расчёска"},
				{"tool": Tool.SCISSORS, "label": "Ножницы"},
				{"tool": Tool.CLIPPER, "label": "Щипчики"},
				{"tool": Tool.DRYER, "label": "Фен"}
			]
			if state.has_drying_cabinet:
				available.append({"tool": Tool.CABINET, "label": "Шкаф"})
		Location.BATH:
			available = [
				{"tool": Tool.SHAMPOO, "label": "Шампунь"},
				{"tool": Tool.SHOWER, "label": "Душ"},
				{"tool": Tool.TOWEL, "label": "Полотенце"}
			]

	var req: Tool = _get_required_tool()
	for entry in available:
		var t: Tool = entry["tool"]
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 74)
		btn.add_theme_font_size_override("font_size", 23)
		var is_active: bool = (active_tool == t)
		var is_needed: bool = (t == req) or (step == Step.BLOW_DRY and t == Tool.CABINET)
		btn.text = ("✓ " + entry["label"]) if is_active else (("• " + entry["label"]) if is_needed else entry["label"])
		btn.pressed.connect(func(): _select_tool(t))
		_tools_box.add_child(btn)

func _update_bars() -> void:
	_stress_bar.value = stress
	_calm_bar.value = calmness
	_prog_bar.value = step_progress
	if _heat_bar != null:
		_heat_bar.value = dryer_heat

func _get_pet_center() -> Vector2:
	var sz: Vector2 = _pad_panel.size if _pad_panel != null else Vector2(800, 900)
	var shake_x: float = sin(_anim_time * 42.0) * 16.0 if _shake_timer > 0.0 else 0.0
	var wobble: float = sin(_anim_time * (7.5 if stress > 65.0 else 2.8)) * (8.0 if stress > 65.0 else 3.0)
	return Vector2(sz.x * 0.5 + wobble + shake_x, sz.y * 0.52)

func _get_pet_radius() -> float:
	var sz: Vector2 = _pad_panel.size if _pad_panel != null else Vector2(800, 900)
	return clamp(min(sz.x, sz.y) * 0.27, 130.0, 225.0)

func _get_nail_paw_center() -> Vector2:
	var sz: Vector2 = _pad_panel.size if _pad_panel != null else Vector2(800, 900)
	return Vector2(sz.x * 0.5, sz.y * 0.68)

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

func _draw_pet_pad() -> void:
	if _pad_panel == null:
		return
	var sz: Vector2 = _pad_panel.size
	if sz.x <= 10.0 or sz.y <= 10.0:
		return

	_draw_location_background(sz)

	var center := _get_pet_center()
	var r: float = _get_pet_radius()

	# Горка вычесанной шерсти сбоку на основном столе
	if location == Location.TABLE and _fur_pile_count > 0:
		var pile_base := Vector2(sz.x - 135.0, sz.y * 0.74 - 8.0)
		var body_col: Color = pet.get("body_color", Color("e6b67c"))
		for k in range(_fur_pile_count):
			var ox: float = ((k % 4) - 1.5) * 18.0
			var oy: float = -floor(float(k) / 4.0) * 11.0
			_pad_panel.draw_circle(pile_base + Vector2(ox, oy), 15.0, body_col.lightened(0.08))
			_pad_panel.draw_circle(pile_base + Vector2(ox, oy), 15.0, Color("7a6858"), false, 2.0)

	if step == Step.BLOW_DRY and active_tool == Tool.CABINET:
		_pad_panel.draw_rect(Rect2(center - Vector2(r * 1.35, r * 1.35), Vector2(r * 2.7, r * 2.5)), Color(0.76, 0.89, 0.83, 0.42))
		_pad_panel.draw_rect(Rect2(center - Vector2(r * 1.35, r * 1.35), Vector2(r * 2.7, r * 2.5)), Color("6d9982"), false, 3.5)

	var tex: Texture2D = _get_optional_texture(str(pet.get("sprite_path", "")))
	if tex != null:
		var t_size := Vector2(r * 2.5, r * 2.5)
		_pad_panel.draw_texture_rect(tex, Rect2(center - t_size * 0.5, t_size), false)
	else:
		_draw_breed_character(center, r)

	# Уютное обёртывание в пушистое полотенце в зоне ванной!
	if step == Step.TOWEL_WRAP and _towel_wrap_ratio > 0.05:
		_draw_towel_wrap_overlay(center, r, _towel_wrap_ratio)

	# Подсветка тактильных зон на этапе 1
	if step == Step.CALM_BRUSH and active_tool == Tool.BRUSH:
		var love_pos := _get_zone_pos(str(pet.get("love_zone", "ears")))
		var sens_pos := _get_zone_pos(str(pet.get("sensitive_zone", "paws")))
		var pulse: float = 0.85 + sin(_anim_time * 5.0) * 0.15
		_pad_panel.draw_circle(love_pos, r * 0.34 * pulse, Color(0.49, 0.72, 0.56, 0.32))
		_pad_panel.draw_circle(love_pos, r * 0.34 * pulse, Color("5a8d76"), false, 3.0)
		_pad_panel.draw_circle(sens_pos, r * 0.28, Color(0.85, 0.48, 0.44, 0.24))
		_pad_panel.draw_circle(sens_pos, r * 0.28, Color("d98a7e"), false, 2.5)

	if step == Step.FINAL_STYLE or step == Step.SUMMARY:
		_draw_chosen_accessory(center, r)

	if step == Step.SUMMARY:
		var frame := Rect2(center - Vector2(r * 1.35, r * 1.42), Vector2(r * 2.7, r * 2.65))
		_pad_panel.draw_rect(frame, Color("fffdf9"), false, 10.0)
		_pad_panel.draw_rect(frame, Color("c99e76"), false, 3.5)

	var body_col: Color = pet.get("body_color", Color("e6b67c"))
	for item in _coat_items:
		var sp: Vector2 = center + Vector2(item["offset"]) * r
		var sz_item: float = float(item["size"])
		match step:
			Step.TRIM_COAT, Step.FINAL_TRIM:
				var val: float = float(item["value"])
				if val > 0.05:
					var tuft_col: Color = body_col.lightened(0.08) if bool(item.get("is_tuft", false)) else body_col.darkened(0.24)
					_pad_panel.draw_circle(sp, sz_item * val, tuft_col)
					_pad_panel.draw_circle(sp, sz_item * val, Color("5c4d40"), false, 3.0)
			Step.WASH_SOAP, Step.WASH_RINSE:
				var dirt: float = float(item["value"])
				var foam: float = float(item["foam"])
				if dirt > 0.05:
					_pad_panel.draw_circle(sp, sz_item * dirt, Color(0.55, 0.45, 0.35, 0.55 * dirt))
				if foam > 0.05:
					_pad_panel.draw_circle(sp, sz_item * foam, Color(1.0, 1.0, 1.0, 0.92))
					_pad_panel.draw_circle(sp + Vector2(10, -8), sz_item * 0.65 * foam, Color(0.92, 0.98, 1.0, 0.92))
			Step.TOWEL_WRAP, Step.BLOW_DRY:
				var drop: float = float(item["value"])
				if drop > 0.05:
					_pad_panel.draw_circle(sp, sz_item * 0.78 * drop, Color(0.54, 0.81, 0.95, 0.88))

	if step == Step.CLIP_NAILS:
		_draw_nail_clipping_overlay(sz)

	if location == Location.BATH:
		var bath_y: float = sz.y * 0.72
		_pad_panel.draw_rect(Rect2(24, bath_y, sz.x - 48, sz.y - bath_y - 16), Color("b7d7e2"))
		_pad_panel.draw_rect(Rect2(18, bath_y - 12, sz.x - 36, 22), Color("eef8fb"))
		_pad_panel.draw_rect(Rect2(24, bath_y, sz.x - 48, sz.y - bath_y - 16), Color("688694"), false, 3.5)

	if toy_timer > 0.0:
		var toy_pos := center + Vector2(-r * 1.12, r * 0.35 + sin(_anim_time * 12.0) * 11.0)
		_pad_panel.draw_circle(toy_pos, 26.0, Color("e68c7a"))
		_pad_panel.draw_circle(toy_pos, 26.0, Color("5c4d40"), false, 3.0)

	for p in _particles:
		var age_ratio: float = clamp(1.0 - float(p["age"]) / float(p["life"]), 0.0, 1.0)
		var pc: Color = p["color"]
		pc.a = age_ratio * 0.9
		_pad_panel.draw_circle(Vector2(p["pos"]), float(p["radius"]), pc)

	if active_tool != Tool.NONE and active_tool != Tool.CABINET and step != Step.FINAL_STYLE and step != Step.SUMMARY:
		if _stroking or _pointer_pos.x > 0.0:
			_draw_active_tool(_pointer_pos)

	if _transition_alpha > 0.01:
		_pad_panel.draw_rect(Rect2(Vector2.ZERO, sz), Color(1.0, 0.99, 0.96, _transition_alpha * 0.85))

func _draw_towel_wrap_overlay(center: Vector2, r: float, ratio: float) -> void:
	var towel_col := Color("fffaf0")
	var trim_col := Color("9fc4ab")
	var wrap_w: float = r * 1.72 * clamp(ratio * 1.2, 0.4, 1.0)
	var wrap_rect := Rect2(center + Vector2(-wrap_w * 0.5, -r * 0.05), Vector2(wrap_w, r * 0.95))
	_pad_panel.draw_rect(wrap_rect, towel_col)
	_pad_panel.draw_rect(wrap_rect, Color("bfa992"), false, 3.5)
	# Запах полотенца по диагонали
	_pad_panel.draw_line(wrap_rect.position, wrap_rect.position + Vector2(wrap_rect.size.x * 0.75, wrap_rect.size.y * 0.7), trim_col, 5.0)
	_pad_panel.draw_line(wrap_rect.position + Vector2(wrap_rect.size.x, 0), wrap_rect.position + Vector2(wrap_rect.size.x * 0.25, wrap_rect.size.y * 0.7), trim_col, 5.0)
	# Уголок полотенца на макушке (как капюшон после купания)
	if ratio > 0.55:
		var head_top := center + Vector2(0, -r * 1.15)
		var hood := PackedVector2Array([
			head_top + Vector2(-r * 0.58, r * 0.45),
			head_top + Vector2(0, -r * 0.12),
			head_top + Vector2(r * 0.58, r * 0.45)
		])
		_pad_panel.draw_colored_polygon(hood, towel_col)
		_pad_panel.draw_polyline(hood, Color("bfa992"), 3.5)

func _draw_nail_clipping_overlay(sz: Vector2) -> void:
	var paw_center := _get_nail_paw_center()
	var card := Rect2(Vector2(40, paw_center.y - 135), Vector2(sz.x - 80, 250))
	_pad_panel.draw_rect(card, Color("fffdf9"))
	_pad_panel.draw_rect(card, Color("c99e76"), false, 4.0)

	var body_col: Color = pet.get("body_color", Color("e6b67c"))
	_pad_panel.draw_circle(paw_center + Vector2(0, 35), 92.0, body_col)
	_pad_panel.draw_circle(paw_center + Vector2(0, 35), 92.0, Color("5c4d40"), false, 3.0)

	for i in range(4):
		var nx: float = paw_center.x + (-1.5 + float(i)) * 56.0
		var ny: float = paw_center.y - 36.0
		var nail_len: float = 16.0 if _nails_done[i] else 38.0
		var col: Color = Color("9fc4ab") if _nails_done[i] else (Color("f2d5b8") if i == _active_nail_idx else Color("e6dfd5"))
		_pad_panel.draw_rect(Rect2(nx - 10, ny - nail_len, 20, nail_len), col)
		_pad_panel.draw_rect(Rect2(nx - 10, ny - nail_len, 20, nail_len), Color("5c4d40"), false, 2.5)
		if i == _active_nail_idx:
			_pad_panel.draw_circle(Vector2(nx, ny - nail_len - 14), 7.0, Color("7da388"))

	var bar_w: float = sz.x - 160.0
	var bar_x: float = 80.0
	var bar_y: float = paw_center.y + 82.0
	_pad_panel.draw_rect(Rect2(bar_x, bar_y, bar_w, 26), Color("eadfd2"))
	_pad_panel.draw_rect(Rect2(bar_x + bar_w * 0.33, bar_y, bar_w * 0.34, 26), Color("7da388"))
	_pad_panel.draw_rect(Rect2(bar_x, bar_y, bar_w, 26), Color("5c4d40"), false, 3.0)
	var cur_x: float = bar_x + bar_w * _nail_cursor
	_pad_panel.draw_rect(Rect2(cur_x - 6, bar_y - 6, 12, 38), Color("3c332b"))

func _draw_chosen_accessory(center: Vector2, r: float) -> void:
	var head_pos := center + Vector2(0, -r * 0.42)
	var bow_col: Color = pet.get("bow_color", Color("e68c7a"))
	var top_pos := head_pos + Vector2(0, -r * 0.68)

	match chosen_accessory:
		"bow":
			var bow_l := PackedVector2Array([top_pos, top_pos + Vector2(-34, -20), top_pos + Vector2(-34, 20)])
			var bow_r := PackedVector2Array([top_pos, top_pos + Vector2(34, -20), top_pos + Vector2(34, 20)])
			_pad_panel.draw_colored_polygon(bow_l, bow_col)
			_pad_panel.draw_colored_polygon(bow_r, bow_col)
			_pad_panel.draw_circle(top_pos, 10.0, Color("fff4e8"))
		"crown":
			var crown := PackedVector2Array([
				top_pos + Vector2(-30, 14), top_pos + Vector2(-34, -18),
				top_pos + Vector2(-12, -2), top_pos + Vector2(0, -24),
				top_pos + Vector2(12, -2), top_pos + Vector2(34, -18),
				top_pos + Vector2(30, 14)
			])
			_pad_panel.draw_colored_polygon(crown, Color("f0c665"))
			_pad_panel.draw_polyline(crown, Color("7a6128"), 3.0)
		"bandana":
			var neck := center + Vector2(0, r * 0.08)
			var band := PackedVector2Array([
				neck + Vector2(-r * 0.48, -10),
				neck + Vector2(r * 0.48, -10),
				neck + Vector2(0, r * 0.44)
			])
			_pad_panel.draw_colored_polygon(band, bow_col)
			_pad_panel.draw_polyline(band, Color("4a3f35"), 3.0)
		"flower":
			var fpos := head_pos + Vector2(r * 0.42, -r * 0.48)
			for ang in range(0, 360, 72):
				var rad := deg_to_rad(float(ang))
				_pad_panel.draw_circle(fpos + Vector2(cos(rad), sin(rad)) * 16.0, 12.0, bow_col)
			_pad_panel.draw_circle(fpos, 10.0, Color("f7d97e"))

func _draw_breed_character(center: Vector2, r: float) -> void:
	var body_col: Color = pet.get("body_color", Color("e6b67c"))
	var acc_col: Color = pet.get("accent_color", Color("fff9f0"))
	var eye_col: Color = pet.get("eye_color", Color("3c332b"))
	var vtype: String = str(pet.get("visual_type", "corgi"))
	var is_fluffy_done: bool = (step == Step.FINAL_TRIM or step == Step.FINAL_STYLE or step == Step.SUMMARY)
	var fluff_scale: float = 1.09 if is_fluffy_done else 1.0

	_pad_panel.draw_circle(center + Vector2(0, r * 0.92), r * 0.85, Color(0.45, 0.38, 0.32, 0.28))

	var tail_speed: float = 8.0 if calmness > 70.0 else 3.8
	var tail_swing: float = sin(_anim_time * tail_speed) * (20.0 if calmness > 70.0 else 10.0)
	match vtype:
		"persian", "spitz":
			_pad_panel.draw_circle(center + Vector2(r * 0.96, r * 0.15 + tail_swing), r * 0.36 * fluff_scale, body_col)
			_pad_panel.draw_circle(center + Vector2(r * 1.06, r * 0.05 + tail_swing), r * 0.26 * fluff_scale, acc_col)
		"poodle":
			_pad_panel.draw_line(center + Vector2(r * 0.65, r * 0.35), center + Vector2(r * 1.0, r * 0.12 + tail_swing), body_col, 12.0)
			_pad_panel.draw_circle(center + Vector2(r * 1.02, r * 0.10 + tail_swing), r * 0.24 * fluff_scale, acc_col)
		"british", "lop_cat":
			_pad_panel.draw_line(center + Vector2(r * 0.6, r * 0.4), center + Vector2(r * 1.08, r * 0.18 + tail_swing), body_col, 24.0)
			_pad_panel.draw_circle(center + Vector2(r * 1.08, r * 0.18 + tail_swing), 12.0, body_col)
		"dachshund":
			_pad_panel.draw_line(center + Vector2(r * 0.72, r * 0.36), center + Vector2(r * 1.15, r * 0.08 + tail_swing), body_col, 13.0)
		"corgi":
			_pad_panel.draw_circle(center + Vector2(r * 0.85, r * 0.28 + tail_swing * 0.6), r * 0.22, acc_col)

	var body_rx: float = r * 0.88 if vtype == "dachshund" else r * 0.78 * fluff_scale
	_pad_panel.draw_circle(center + Vector2(0, r * 0.35), body_rx, body_col)
	_pad_panel.draw_circle(center + Vector2(0, r * 0.35), body_rx, Color("5c4d40"), false, 3.5)

	if vtype == "persian" or vtype == "spitz":
		for gx in [-0.38, -0.18, 0.0, 0.18, 0.38]:
			_pad_panel.draw_circle(center + Vector2(r * gx, r * 0.26), r * 0.24 * fluff_scale, acc_col)
	elif vtype == "poodle":
		for gx in [-0.28, 0.0, 0.28]:
			_pad_panel.draw_circle(center + Vector2(r * gx, r * 0.32), r * 0.26 * fluff_scale, acc_col)
	else:
		_pad_panel.draw_circle(center + Vector2(0, r * 0.42), r * 0.44, acc_col)

	if location != Location.BATH:
		var paw_w: float = r * 0.24 if (vtype == "corgi" or vtype == "dachshund") else r * 0.20
		_pad_panel.draw_circle(center + Vector2(-r * 0.38, r * 0.92), paw_w, acc_col)
		_pad_panel.draw_circle(center + Vector2(-r * 0.38, r * 0.92), paw_w, Color("5c4d40"), false, 3.0)
		_pad_panel.draw_circle(center + Vector2(r * 0.38, r * 0.92), paw_w, acc_col)
		_pad_panel.draw_circle(center + Vector2(r * 0.38, r * 0.92), paw_w, Color("5c4d40"), false, 3.0)

	var head_tilt: float = sin(_anim_time * 2.2) * 5.0
	var head_pos := center + Vector2(head_tilt, -r * 0.42)
	var head_rx: float = r * 0.74 if (vtype == "british" or vtype == "lop_cat") else r * 0.68
	_pad_panel.draw_circle(head_pos, head_rx, body_col)
	_pad_panel.draw_circle(head_pos, head_rx, Color("5c4d40"), false, 3.5)

	var ear_droop: float = r * 0.14 if stress > 65.0 else 0.0
	match vtype:
		"persian":
			_pad_panel.draw_circle(head_pos + Vector2(-r * 0.48, r * 0.12), r * 0.28, body_col)
			_pad_panel.draw_circle(head_pos + Vector2(r * 0.48, r * 0.12), r * 0.28, body_col)
			_pad_panel.draw_colored_polygon(PackedVector2Array([
				head_pos + Vector2(-r * 0.56, -r * 0.26),
				head_pos + Vector2(-r * 0.38, -r * 0.78 + ear_droop),
				head_pos + Vector2(-r * 0.16, -r * 0.44)
			]), acc_col)
			_pad_panel.draw_colored_polygon(PackedVector2Array([
				head_pos + Vector2(r * 0.56, -r * 0.26),
				head_pos + Vector2(r * 0.38, -r * 0.78 + ear_droop),
				head_pos + Vector2(r * 0.16, -r * 0.44)
			]), acc_col)
		"british":
			_pad_panel.draw_circle(head_pos + Vector2(-r * 0.44, r * 0.16), r * 0.32, body_col)
			_pad_panel.draw_circle(head_pos + Vector2(r * 0.44, r * 0.16), r * 0.32, body_col)
			_pad_panel.draw_colored_polygon(PackedVector2Array([
				head_pos + Vector2(-r * 0.50, -r * 0.34),
				head_pos + Vector2(-r * 0.26, -r * 0.92 + ear_droop),
				head_pos + Vector2(-r * 0.05, -r * 0.48)
			]), acc_col)
			_pad_panel.draw_colored_polygon(PackedVector2Array([
				head_pos + Vector2(r * 0.50, -r * 0.34),
				head_pos + Vector2(r * 0.26, -r * 0.92 + ear_droop),
				head_pos + Vector2(r * 0.05, -r * 0.48)
			]), acc_col)
		"lop_cat":
			_pad_panel.draw_circle(head_pos + Vector2(-r * 0.44, r * 0.16), r * 0.32, body_col)
			_pad_panel.draw_circle(head_pos + Vector2(r * 0.44, r * 0.16), r * 0.32, body_col)
			_pad_panel.draw_circle(head_pos + Vector2(-r * 0.52, -r * 0.34 + ear_droop * 0.5), r * 0.24, acc_col)
			_pad_panel.draw_circle(head_pos + Vector2(r * 0.52, -r * 0.34 + ear_droop * 0.5), r * 0.24, acc_col)
		"corgi", "spitz":
			if vtype == "spitz":
				_pad_panel.draw_circle(head_pos + Vector2(-r * 0.54, r * 0.06), r * 0.28 * fluff_scale, acc_col)
				_pad_panel.draw_circle(head_pos + Vector2(r * 0.54, r * 0.06), r * 0.28 * fluff_scale, acc_col)
			_pad_panel.draw_colored_polygon(PackedVector2Array([
				head_pos + Vector2(-r * 0.54, -r * 0.24),
				head_pos + Vector2(-r * 0.42, -r * 1.12 + ear_droop),
				head_pos + Vector2(-r * 0.06, -r * 0.46)
			]), body_col)
			_pad_panel.draw_colored_polygon(PackedVector2Array([
				head_pos + Vector2(r * 0.54, -r * 0.24),
				head_pos + Vector2(r * 0.42, -r * 1.12 + ear_droop),
				head_pos + Vector2(r * 0.06, -r * 0.46)
			]), body_col)
			_pad_panel.draw_rect(Rect2(head_pos + Vector2(-r * 0.12, -r * 0.45), Vector2(r * 0.24, r * 0.52)), acc_col)
			_pad_panel.draw_circle(head_pos + Vector2(0, r * 0.20), r * 0.34, acc_col)
		"poodle":
			for cx in [-0.26, 0.0, 0.26]:
				_pad_panel.draw_circle(head_pos + Vector2(r * cx, -r * 0.56), r * 0.26 * fluff_scale, body_col)
			_pad_panel.draw_circle(head_pos + Vector2(-r * 0.66, -r * 0.04 + ear_droop), r * 0.30 * fluff_scale, acc_col)
			_pad_panel.draw_circle(head_pos + Vector2(-r * 0.64, r * 0.22 + ear_droop), r * 0.24 * fluff_scale, acc_col)
			_pad_panel.draw_circle(head_pos + Vector2(r * 0.66, -r * 0.04 + ear_droop), r * 0.30 * fluff_scale, acc_col)
			_pad_panel.draw_circle(head_pos + Vector2(r * 0.64, r * 0.22 + ear_droop), r * 0.24 * fluff_scale, acc_col)
		"dachshund":
			_pad_panel.draw_circle(head_pos + Vector2(-r * 0.62, r * 0.04 + ear_droop), r * 0.26, acc_col)
			_pad_panel.draw_circle(head_pos + Vector2(-r * 0.60, r * 0.28 + ear_droop), r * 0.22, acc_col)
			_pad_panel.draw_circle(head_pos + Vector2(r * 0.62, r * 0.04 + ear_droop), r * 0.26, acc_col)
			_pad_panel.draw_circle(head_pos + Vector2(r * 0.60, r * 0.28 + ear_droop), r * 0.22, acc_col)
			_pad_panel.draw_circle(head_pos + Vector2(0, r * 0.20), r * 0.30, acc_col)

	if _is_blinking or (calmness >= 70.0 and stress < 45.0):
		_pad_panel.draw_line(head_pos + Vector2(-r * 0.32, -r * 0.06), head_pos + Vector2(-r * 0.14, -r * 0.13), Color("3c332b"), 3.5)
		_pad_panel.draw_line(head_pos + Vector2(r * 0.14, -r * 0.13), head_pos + Vector2(r * 0.32, -r * 0.06), Color("3c332b"), 3.5)
	else:
		_pad_panel.draw_circle(head_pos + Vector2(-r * 0.24, -r * 0.06), r * 0.11, eye_col)
		_pad_panel.draw_circle(head_pos + Vector2(r * 0.24, -r * 0.06), r * 0.11, eye_col)
		_pad_panel.draw_circle(head_pos + Vector2(-r * 0.24, -r * 0.06), r * 0.06, Color("261f1a"))
		_pad_panel.draw_circle(head_pos + Vector2(r * 0.24, -r * 0.06), r * 0.06, Color("261f1a"))
		_pad_panel.draw_circle(head_pos + Vector2(-r * 0.21, -r * 0.09), r * 0.035, Color("ffffff"))
		_pad_panel.draw_circle(head_pos + Vector2(r * 0.27, -r * 0.09), r * 0.035, Color("ffffff"))

	if calmness > 60.0 or dryer_heat > 35.0:
		_pad_panel.draw_circle(head_pos + Vector2(-r * 0.36, r * 0.10), r * 0.09, Color(0.92, 0.56, 0.52, 0.45))
		_pad_panel.draw_circle(head_pos + Vector2(r * 0.36, r * 0.10), r * 0.09, Color(0.92, 0.56, 0.52, 0.45))

	var is_dog: bool = (vtype == "corgi" or vtype == "poodle" or vtype == "spitz" or vtype == "dachshund")
	var nose_col := Color("3c332b") if is_dog else Color("d98a7e")
	_pad_panel.draw_circle(head_pos + Vector2(0, r * 0.12), r * 0.085, nose_col)
	_pad_panel.draw_line(head_pos + Vector2(-r * 0.12, r * 0.26), head_pos + Vector2(0, r * 0.20), Color("3c332b"), 3.0)
	_pad_panel.draw_line(head_pos + Vector2(0, r * 0.20), head_pos + Vector2(r * 0.12, r * 0.26), Color("3c332b"), 3.0)

	if not is_dog:
		_pad_panel.draw_line(head_pos + Vector2(-r * 0.26, r * 0.14), head_pos + Vector2(-r * 0.56, r * 0.08), Color("6e5d4f"), 2.0)
		_pad_panel.draw_line(head_pos + Vector2(-r * 0.26, r * 0.20), head_pos + Vector2(-r * 0.54, r * 0.22), Color("6e5d4f"), 2.0)
		_pad_panel.draw_line(head_pos + Vector2(r * 0.26, r * 0.14), head_pos + Vector2(r * 0.56, r * 0.08), Color("6e5d4f"), 2.0)
		_pad_panel.draw_line(head_pos + Vector2(r * 0.26, r * 0.20), head_pos + Vector2(r * 0.54, r * 0.22), Color("6e5d4f"), 2.0)

func _draw_location_background(sz: Vector2) -> void:
	var bg_col := Color("f6ede2")
	var border_col := Color("d8c7b4")
	if location == Location.BATH:
		bg_col = Color("eaf4f7")
		border_col = Color("a7c6d1")

	var pad_bg := StyleBoxFlat.new()
	pad_bg.bg_color = bg_col
	pad_bg.border_color = border_col
	pad_bg.set_border_width_all(3)
	pad_bg.set_corner_radius_all(20)
	_pad_panel.draw_style_box(pad_bg, Rect2(Vector2.ZERO, sz))

	if location == Location.TABLE:
		_pad_panel.draw_rect(Rect2(44, 34, 180, 155), Color("fffdf9"))
		_pad_panel.draw_rect(Rect2(44, 34, 180, 155), Color("d4c4b2"), false, 3.0)
		var table_y: float = sz.y * 0.74
		_pad_panel.draw_rect(Rect2(16, table_y, sz.x - 32, sz.y - table_y - 14), Color("e4d2bc"))
		_pad_panel.draw_line(Vector2(16, table_y), Vector2(sz.x - 16, table_y), Color("bfa78c"), 4.0)
	elif location == Location.BATH:
		for tx in range(36, int(sz.x - 36), 64):
			_pad_panel.draw_line(Vector2(tx, 16), Vector2(tx, sz.y * 0.72), Color("d5e7ed"), 2.0)
		for ty in range(32, int(sz.y * 0.72), 56):
			_pad_panel.draw_line(Vector2(16, ty), Vector2(sz.x - 16, ty), Color("d5e7ed"), 2.0)
		_pad_panel.draw_line(Vector2(sz.x - 70, sz.y * 0.72), Vector2(sz.x - 70, 80), Color("94a5b0"), 8.0)
		_pad_panel.draw_line(Vector2(sz.x - 70, 80), Vector2(sz.x - 140, 80), Color("94a5b0"), 8.0)

func _draw_active_tool(pos: Vector2) -> void:
	var anim_pulse: float = sin(_anim_time * 24.0) * 6.0 if _tool_anim_timer > 0.0 else 0.0
	match active_tool:
		Tool.BRUSH:
			var bp := pos + Vector2(anim_pulse, 0)
			_pad_panel.draw_rect(Rect2(bp - Vector2(30, 18), Vector2(60, 36)), Color("9fc4ab"))
			_pad_panel.draw_rect(Rect2(bp - Vector2(30, 18), Vector2(60, 36)), Color("4a6354"), false, 3.0)
			# Щетинки расчёски
			for bx in [-20, -10, 0, 10, 20]:
				_pad_panel.draw_line(bp + Vector2(bx, 18), bp + Vector2(bx, 28), Color("4a6354"), 3.0)
		Tool.SCISSORS:
			var snip: float = 4.0 if _tool_anim_timer > 0.0 else 18.0
			_pad_panel.draw_line(pos + Vector2(-24, -snip), pos + Vector2(24, snip), Color("5c5c5c"), 5.0)
			_pad_panel.draw_line(pos + Vector2(-24, snip), pos + Vector2(24, -snip), Color("5c5c5c"), 5.0)
			_pad_panel.draw_circle(pos + Vector2(-24, -snip), 10.0, Color("d98a7e"), false, 3.5)
			_pad_panel.draw_circle(pos + Vector2(-24, snip), 10.0, Color("d98a7e"), false, 3.5)
		Tool.CLIPPER:
			var jaw: float = 3.0 if _tool_anim_timer > 0.0 else 15.0
			# Ручки щипчиков
			_pad_panel.draw_line(pos + Vector2(-26, 26), pos + Vector2(-6, 0), Color("e68c7a"), 7.0)
			_pad_panel.draw_line(pos + Vector2(26, 26), pos + Vector2(6, 0), Color("e68c7a"), 7.0)
			# Лезвия когтереза
			_pad_panel.draw_line(pos + Vector2(-6, 0), pos + Vector2(-jaw, -24), Color("7a8691"), 6.0)
			_pad_panel.draw_line(pos + Vector2(6, 0), pos + Vector2(jaw, -24), Color("7a8691"), 6.0)
		Tool.SHAMPOO:
			var sq: float = 1.0 + sin(_anim_time * 18.0) * 0.12 if _tool_anim_timer > 0.0 else 1.0
			_pad_panel.draw_rect(Rect2(pos - Vector2(28 * sq, 18), Vector2(56 * sq, 36)), Color("f5e09b"))
			_pad_panel.draw_rect(Rect2(pos - Vector2(28 * sq, 18), Vector2(56 * sq, 36)), Color("8c7a48"), false, 3.0)
		Tool.SHOWER:
			_pad_panel.draw_circle(pos, 26.0, Color("9ab8c7"))
			_pad_panel.draw_circle(pos, 26.0, Color("506b78"), false, 3.5)
			for sx in [-12, 0, 12]:
				_pad_panel.draw_circle(pos + Vector2(sx, 8), 3.0, Color("eef8fb"))
		Tool.TOWEL:
			var tp := pos + Vector2(0, anim_pulse)
			_pad_panel.draw_rect(Rect2(tp - Vector2(34, 22), Vector2(68, 44)), Color("fffaf2"))
			_pad_panel.draw_rect(Rect2(tp - Vector2(34, 22), Vector2(68, 44)), Color("bfa992"), false, 3.5)
			_pad_panel.draw_line(tp + Vector2(-28, 12), tp + Vector2(28, 12), Color("9fc4ab"), 4.0)
		Tool.DRYER:
			var dp := pos + Vector2(0, anim_pulse * 0.5)
			_pad_panel.draw_circle(dp, 24.0, Color("8ea6b5"))
			_pad_panel.draw_line(dp + Vector2(18, 0), dp + Vector2(48, -14), Color("f2cf8d"), 5.0)
			_pad_panel.draw_line(dp + Vector2(18, 6), dp + Vector2(48, 18), Color("f2cf8d"), 5.0)

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color("fbf7f1")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	vbox.add_child(top_row)

	_title_lbl = Label.new()
	_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_lbl.add_theme_font_size_override("font_size", 32)
	_title_lbl.add_theme_color_override("font_color", Color("3c332b"))
	top_row.add_child(_title_lbl)

	var close_btn := Button.new()
	close_btn.text = "В зал"
	close_btn.custom_minimum_size = Vector2(120, 56)
	close_btn.add_theme_font_size_override("font_size", 24)
	close_btn.pressed.connect(func():
		visible = false
		closed_early.emit()
	)
	top_row.add_child(close_btn)

	_loc_lbl = Label.new()
	_loc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_loc_lbl.add_theme_font_size_override("font_size", 23)
	_loc_lbl.add_theme_color_override("font_color", Color("688694"))
	vbox.add_child(_loc_lbl)

	_stress_bar = _make_bar(vbox, "Стресс", Color("d98a7e"))
	_calm_bar = _make_bar(vbox, "Спокойствие", Color("7da388"))
	_prog_bar = _make_bar(vbox, "Прогресс этапа", Color("c99e76"))

	_heat_row = VBoxContainer.new()
	_heat_row.visible = false
	_heat_bar = _make_bar(_heat_row, "Температура фена (води плавно!)", Color("e69d6c"))
	vbox.add_child(_heat_row)

	_status_lbl = Label.new()
	_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_lbl.add_theme_font_size_override("font_size", 23)
	_status_lbl.add_theme_color_override("font_color", Color("3c332b"))
	vbox.add_child(_status_lbl)

	_pad_panel = Control.new()
	_pad_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pad_panel.custom_minimum_size = Vector2(0, 300)
	_pad_panel.gui_input.connect(_on_pad_gui_input)
	_pad_panel.draw.connect(_draw_pet_pad)
	vbox.add_child(_pad_panel)

	_tools_box = HBoxContainer.new()
	_tools_box.add_theme_constant_override("separation", 10)
	vbox.add_child(_tools_box)

	_style_box = VBoxContainer.new()
	_style_box.visible = false
	_style_box.add_theme_constant_override("separation", 8)
	vbox.add_child(_style_box)

	_toy_btn = Button.new()
	_toy_btn.text = "Дать любимую игрушку"
	_toy_btn.custom_minimum_size = Vector2(0, 66)
	_toy_btn.add_theme_font_size_override("font_size", 24)
	_toy_btn.pressed.connect(_on_toy_pressed)
	vbox.add_child(_toy_btn)

	_action_btn = Button.new()
	_action_btn.text = "Забрать оплату и вернуться в зал"
	_action_btn.custom_minimum_size = Vector2(0, 74)
	_action_btn.visible = false
	_action_btn.add_theme_font_size_override("font_size", 25)
	_action_btn.pressed.connect(_on_action_pressed)
	vbox.add_child(_action_btn)

func _make_bar(parent: VBoxContainer, label_text: String, fill_col: Color) -> ProgressBar:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color("5c4f43"))
	row.add_child(lbl)

	var bar := ProgressBar.new()
	bar.max_value = 100.0
	bar.custom_minimum_size = Vector2(0, 24)
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill_col
	bar.add_theme_stylebox_override("fill", sb)
	row.add_child(bar)

	parent.add_child(row)
	return bar
