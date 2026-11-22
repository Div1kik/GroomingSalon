extends Control
class_name GroomingMinigame

signal session_finished(pet_data: Dictionary, calm_ratio: float, reward_money: int)
signal closed_early

enum Location { TABLE, BATH }
enum Step { UNPACK_CARRIER, CALM_BRUSH, TRIM_COAT, CLIP_NAILS, WASH_SOAP, WASH_RINSE, TOWEL_WRAP, BLOW_DRY, FINAL_TRIM, FINAL_STYLE, PACK_CARRIER, SUMMARY }
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

# Анимации инструментов и живого поведения питомца
var _tool_anim_timer: float = 0.0
var _towel_wrap_ratio: float = 0.0
var _fur_pile_count: int = 0
var _sound_tick_timer: float = 0.0
var _carrier_door_open: float = 0.0

var _sniff_timer: float = 0.0
var _sniff_cooldown: float = 0.0
var _resist_offset: Vector2 = Vector2.ZERO
var _head_look: Vector2 = Vector2.ZERO
var _ear_twitch: float = 0.0

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
var _fur_strands: Array[Dictionary] = []
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
	var has_carrier: bool = bool(pet.get("uses_carrier", false))
	step = Step.UNPACK_CARRIER if has_carrier else Step.CALM_BRUSH
	_carrier_door_open = 0.0 if has_carrier else 1.0

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
	_sniff_timer = 0.0
	_sniff_cooldown = 0.0
	_resist_offset = Vector2.ZERO
	_head_look = Vector2.ZERO
	chosen_accessory = str(pet.get("pref_acc", "bow"))
	chosen_scent = str(pet.get("pref_scent", "lavender"))
	_nails_done = [false, false, false, false]
	_active_nail_idx = 0
	_nail_cursor = 0.1
	_particles.clear()
	_generate_fur_texture()
	_setup_step_items()

	visible = true
	_refresh_ui()
	if _pad_panel != null:
		_pad_panel.queue_redraw()

func _generate_fur_texture() -> void:
	_fur_strands.clear()
	for i in range(38):
		var a: float = randf() * TAU
		var dist_r: float = sqrt(randf()) * 0.72
		_fur_strands.append({
			"offset": Vector2(cos(a) * dist_r, sin(a) * dist_r * 0.85 + 0.25),
			"angle": randf_range(-0.4, 0.4),
			"len": randf_range(12.0, 22.0)
		})

func _setup_step_items() -> void:
	_coat_items.clear()
	var offsets := [
		Vector2(-0.52, 0.12), Vector2(0.50, 0.16), Vector2(-0.32, 0.52),
		Vector2(0.34, 0.48), Vector2(0.0, 0.24), Vector2(-0.40, -0.24),
		Vector2(0.40, -0.22), Vector2(-0.22, 0.68), Vector2(0.24, 0.66),
		Vector2(0.0, 0.56)
	]
	match step:
		Step.CALM_BRUSH:
			# 10 участков спутанного подшёрстка — требуется основательное вычёсывание в несколько проходов
			for i in range(10):
				_coat_items.append({
					"offset": offsets[i],
					"value": 1.0,
					"foam": 0.0,
					"size": randf_range(24.0, 32.0)
				})
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
					"cuts_left": 2 if (i < 4) else 3,
					"foam": 0.0,
					"size": randf_range(28.0, 36.0),
					"is_tuft": i < 4 or i == 6
				})
		Step.CLIP_NAILS:
			_nails_done = [false, false, false, false]
			_active_nail_idx = 0
			_nail_cursor = 0.15
		Step.WASH_SOAP:
			for i in range(8):
				_coat_items.append({
					"offset": offsets[i],
					"value": 1.0,
					"foam": 0.0,
					"size": randf_range(28.0, 36.0)
				})
		Step.WASH_RINSE:
			for i in range(9):
				_coat_items.append({
					"offset": offsets[i],
					"value": 0.0,
					"foam": 1.0,
					"size": randf_range(32.0, 40.0)
				})
		Step.TOWEL_WRAP, Step.BLOW_DRY:
			for i in range(9):
				_coat_items.append({
					"offset": offsets[i],
					"value": 1.0,
					"foam": 0.0,
					"size": randf_range(22.0, 28.0)
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
					"cuts_left": 1,
					"foam": 0.0,
					"size": 24.0,
					"is_tuft": true
				})

func _vibrate_tap(ms: int = 24) -> void:
	if OS.has_feature("mobile") or OS.has_feature("web"):
		Input.vibrate_handheld(ms)

func _trigger_pet_resistance(reason_text: String) -> void:
	_resist_offset = Vector2(randf_range(-24.0, 24.0), 18.0)
	_shake_timer = 0.38
	_ear_twitch = 0.5
	sound.play_stress_tick()
	_vibrate_tap(45)
	_status_lbl.text = reason_text

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
	if _sniff_timer > 0.0:
		_sniff_timer = max(0.0, _sniff_timer - delta)
	if _sniff_cooldown > 0.0:
		_sniff_cooldown = max(0.0, _sniff_cooldown - delta)
	if _ear_twitch > 0.0:
		_ear_twitch = max(0.0, _ear_twitch - delta)

	# Плавный возврат после упирания лапками
	_resist_offset = _resist_offset.lerp(Vector2.ZERO, delta * 4.5)

	# Живое слежение взглядом за инструментом и обнюхивание у мордочки
	var center := _get_pet_center()
	var r: float = _get_pet_radius()
	var head_pos := center + Vector2(0, -r * 0.42)
	if _pointer_pos.x > 0.0 and step != Step.SUMMARY:
		var dir_to_ptr: Vector2 = (_pointer_pos - head_pos).limit_length(120.0) / 120.0
		_head_look = _head_look.lerp(dir_to_ptr, delta * 7.0)
		if active_tool != Tool.NONE and _pointer_pos.distance_to(head_pos + Vector2(0, r * 0.15)) < r * 0.45 and _sniff_cooldown <= 0.0 and not _stroking:
			_sniff_timer = 0.85
			_sniff_cooldown = 4.2
			_ear_twitch = 0.4
			calmness = clamp(calmness + 2.5, 0.0, 100.0)
			sound.play_soft_pop(1.35)
			_status_lbl.text = "%s с любопытством обнюхивает инструмент и привыкает к нему." % str(pet.get("name", ""))
	else:
		_head_look = _head_look.lerp(Vector2.ZERO, delta * 4.0)

	if step == Step.CLIP_NAILS:
		var spd: float = 1.15 + float(_active_nail_idx) * 0.16
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

		var stress_rate: float = 1.85 - float(state.equipment_tier) * 0.25
		if step == Step.UNPACK_CARRIER or step == Step.PACK_CARRIER:
			stress_rate = 0.5
		elif location == Location.BATH and bool(pet.get("fear_water", false)) and not bool(state.tool_upgrades.get("spa_shampoo", false)):
			stress_rate += 2.3
		elif step == Step.BLOW_DRY and active_tool == Tool.DRYER and bool(pet.get("fear_dryer", false)) and not bool(state.tool_upgrades.get("quiet_dryer", false)):
			stress_rate += 2.5

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
	var center := _get_pet_center()
	var r: float = _get_pet_radius()

	if step == Step.UNPACK_CARRIER:
		if pos.distance_to(center) <= r * 1.45:
			_carrier_door_open = min(1.0, _carrier_door_open + 0.36)
			step_progress = _carrier_door_open * 100.0
			calmness = clamp(calmness + 3.0, 0.0, 100.0)
			sound.play_clipper_snip()
			_vibrate_tap(22)
			_update_bars()
			if _carrier_door_open >= 0.98:
				_advance_step()
			else:
				_status_lbl.text = "Защёлка открыта! Погладь или нажми ещё раз, чтобы %s вышел на стол." % str(pet.get("name", ""))
		return

	if step == Step.PACK_CARRIER:
		if pos.distance_to(center) <= r * 1.45:
			_carrier_door_open = max(0.0, _carrier_door_open - 0.36)
			step_progress = (1.0 - _carrier_door_open) * 100.0
			calmness = clamp(calmness + 2.5, 0.0, 100.0)
			sound.play_clipper_snip()
			_vibrate_tap(22)
			_update_bars()
			if _carrier_door_open <= 0.02:
				_advance_step()
			else:
				_status_lbl.text = "%s уютно устроился внутри — защёлкни дверцу переноски!" % str(pet.get("name", ""))
		return

	if step == Step.FINAL_STYLE:
		if pos.distance_to(center) <= r * 1.25:
			_apply_final_style_finish()
		return

	var required: Tool = _get_required_tool()
	if active_tool != required:
		_status_lbl.text = "Сначала выбери нужный инструмент на панели снизу!"
		sound.play_stress_tick()
		return

	match step:
		Step.TRIM_COAT, Step.FINAL_TRIM:
			_tool_anim_timer = 0.24
			sound.play_scissors_snip()
			var hit_any: bool = false
			for item in _coat_items:
				if float(item["value"]) <= 0.05:
					continue
				var sp: Vector2 = center + Vector2(item["offset"]) * r
				if pos.distance_to(sp) <= max(64.0, r * 0.45):
					var cuts: int = int(item.get("cuts_left", 1)) - 1
					item["cuts_left"] = cuts
					item["value"] = max(0.0, float(cuts) / 2.0) if step == Step.TRIM_COAT else 0.0
					hit_any = true
					_fur_pile_count = min(18, _fur_pile_count + 1)
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
					if cuts > 0:
						_status_lbl.text = "Колтун плотный! Сделай ещё аккуратный срез ножницами."
					break
			if not hit_any and pos.distance_to(center) < r * 0.85:
				stress = clamp(stress + 6.5, 0.0, 100.0)
				_trigger_pet_resistance("Ой! %s упирается лапками — стриги только отросшие пучки и колтуны." % str(pet.get("name", "")))
			_recalc_items_progress()

		Step.CLIP_NAILS:
			_tool_anim_timer = 0.25
			if _nail_cursor >= 0.34 and _nail_cursor <= 0.66:
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
					_status_lbl.text = "Щёлк! Белый кончик срезан чисто! Осталось когтей: %d" % (4 - _active_nail_idx)
			else:
				stress = clamp(stress + 9.0, 0.0, 100.0)
				_trigger_pet_resistance("Питомец одёрнул лапку! Срезай только белый кончик, не задевая розовый сосуд.")

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
		if pos.distance_to(sp) <= max(80.0, r * 0.62):
			item["value"] = max(0.0, float(item["value"]) - 0.34)
			dried_any = true
	if dried_any or pos.distance_to(center) <= r * 1.15:
		_towel_wrap_ratio = min(1.0, _towel_wrap_ratio + 0.12)
		calmness = clamp(calmness + 2.0, 0.0, 100.0)
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
	if step == Step.UNPACK_CARRIER:
		_carrier_door_open = min(1.0, _carrier_door_open + clamp(dist * 0.004, 0.02, 0.12))
		step_progress = _carrier_door_open * 100.0
		_update_bars()
		if _carrier_door_open >= 0.98:
			_advance_step()
		return

	if step == Step.PACK_CARRIER:
		_carrier_door_open = max(0.0, _carrier_door_open - clamp(dist * 0.004, 0.02, 0.12))
		step_progress = (1.0 - _carrier_door_open) * 100.0
		_update_bars()
		if _carrier_door_open <= 0.02:
			_advance_step()
		return

	var required: Tool = _get_required_tool()
	if active_tool != required:
		return

	var center := _get_pet_center()
	var r: float = _get_pet_radius()
	var stroke_step: float = clamp(dist * 0.0042, 0.015, 0.075)
	_tool_anim_timer = 0.18

	match step:
		Step.CALM_BRUSH:
			var love_pos := _get_zone_pos(str(pet.get("love_zone", "ears")))
			var sens_pos := _get_zone_pos(str(pet.get("sensitive_zone", "paws")))

			if pos.distance_to(sens_pos) <= r * 0.34 and _sensitive_cooldown <= 0.0:
				_sensitive_cooldown = 1.2
				stress = clamp(stress + 7.5, 0.0, 100.0)
				_trigger_pet_resistance("Ой, там щекотно! %s упирается лапками — чеши по спинке и в зоне доверия." % str(pet.get("name", "")))
				return

			if dist > 72.0:
				stress = clamp(stress + 2.2, 0.0, 100.0)
				_trigger_pet_resistance("Слишком резкий рывок! Веди пуходёрку плавно по росту шерсти.")
				return

			var in_love: bool = pos.distance_to(love_pos) <= r * 0.46
			var brush_bonus: float = 1.35 if bool(state.tool_upgrades.get("soft_brush", false)) else 1.0
			var touched_fur: bool = false

			# Прочёсываем реальные участки спутавшегося подшёрстка по корпусу
			for item in _coat_items:
				if float(item["value"]) <= 0.02:
					continue
				var sp: Vector2 = center + Vector2(item["offset"]) * r
				if pos.distance_to(sp) <= max(76.0, r * 0.52):
					item["value"] = max(0.0, float(item["value"]) - stroke_step * 2.2 * brush_bonus)
					touched_fur = true

			if touched_fur or in_love:
				var zone_mult: float = 1.45 if in_love else 1.0
				calmness = clamp(calmness + stroke_step * 24.0 * zone_mult * brush_bonus, 0.0, 100.0)
				stress = clamp(stress - stroke_step * 20.0 * zone_mult * brush_bonus, 0.0, 100.0)
				if in_love:
					_status_lbl.text = "Мур-р! Подшёрсток мягко вычёсывается, а пух ложится горкой на столе!"
				else:
					_status_lbl.text = "Прочёсываем подшёрсток... Пройдись пуходёркой по всем спутанным прядям."

				if _sound_tick_timer <= 0.0:
					if in_love and randf() < 0.45:
						sound.play_purr()
					else:
						sound.play_brush_stroke()
					_sound_tick_timer = 0.13

				if touched_fur and randf() < 0.55:
					_fur_pile_count = min(18, _fur_pile_count + 1)
					var body_col: Color = pet.get("body_color", Color("e6b67c"))
					_particles.append({
						"pos": pos + Vector2(randf_range(-16, 16), 10),
						"vel": Vector2(randf_range(50, 135), randf_range(-35, 65)),
						"gravity": 240.0,
						"age": 0.0,
						"life": 0.85,
						"radius": randf_range(9.0, 15.0),
						"color": body_col.lightened(0.12)
					})
			_recalc_items_progress()

		Step.WASH_SOAP:
			if _sound_tick_timer <= 0.0:
				sound.play_foam_sound()
				_sound_tick_timer = 0.11
			for item in _coat_items:
				var sp: Vector2 = center + Vector2(item["offset"]) * r
				if pos.distance_to(sp) <= max(72.0, r * 0.55):
					item["foam"] = min(1.0, float(item["foam"]) + clamp(dist * 0.0085, 0.03, 0.15))
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
		if water_hit.distance_to(sp) <= max(80.0, r * 0.62):
			item["foam"] = max(0.0, float(item["foam"]) - delta * 1.15)

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
			_trigger_pet_resistance("Горячо! %s отворачивается от потока — води феном плавно!" % str(pet.get("name", "")))
	else:
		_last_heat_pos = _pointer_pos
		dryer_heat = max(0.0, dryer_heat - delta * 35.0)

	for item in _coat_items:
		var sp: Vector2 = center + Vector2(item["offset"]) * r
		if _pointer_pos.distance_to(sp) <= max(84.0, r * 0.65):
			item["value"] = max(0.0, float(item["value"]) - delta * 1.05)

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
		item["value"] = max(0.0, float(item["value"]) - delta * 0.34)
	_recalc_items_progress()

func _recalc_items_progress() -> void:
	if _coat_items.is_empty():
		return
	var total: float = 0.0
	for item in _coat_items:
		match step:
			Step.CALM_BRUSH, Step.TRIM_COAT, Step.FINAL_TRIM, Step.TOWEL_WRAP, Step.BLOW_DRY:
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
		Step.UNPACK_CARRIER:
			sound.play_success()
			_carrier_door_open = 1.0
			step = Step.CALM_BRUSH
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
			if bool(pet.get("fear_water", false)):
				_resist_offset = Vector2(-22.0, 14.0)
		Step.WASH_SOAP:
			sound.play_success()
			step = Step.WASH_RINSE
		Step.WASH_RINSE:
			sound.play_success()
			step = Step.TOWEL_WRAP
			_towel_wrap_ratio = 0.25
		Step.TOWEL_WRAP:
			sound.play_shiver_sound()
			_shake_timer = 0.95
			_towel_wrap_ratio = 0.0
			location = Location.TABLE
			step = Step.BLOW_DRY
			_transition_alpha = 1.0
		Step.BLOW_DRY:
			sound.play_success()
			step = Step.FINAL_TRIM
		Step.FINAL_TRIM:
			sound.play_success()
			step = Step.FINAL_STYLE
		Step.FINAL_STYLE:
			sound.play_success()
			if bool(pet.get("uses_carrier", false)):
				step = Step.PACK_CARRIER
				_carrier_door_open = 1.0
			else:
				step = Step.SUMMARY
		Step.PACK_CARRIER:
			sound.play_success()
			_carrier_door_open = 0.0
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

func _apply_cozy_button_theme(btn: Button, bg_col: Color, border_col: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg_col
	normal.border_color = border_col
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(14)
	normal.content_margin_left = 14
	normal.content_margin_right = 14

	var hover := normal.duplicate()
	hover.bg_color = bg_col.lightened(0.05)

	var pressed := normal.duplicate()
	pressed.bg_color = bg_col.darkened(0.06)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color("3c332b"))
	btn.add_theme_color_override("font_hover_color", Color("3c332b"))
	btn.add_theme_color_override("font_pressed_color", Color("3c332b"))

func _refresh_ui() -> void:
	_title_lbl.text = "%s • %s (%s)" % [pet.get("name", ""), pet.get("species", ""), pet.get("breed", "")]

	match location:
		Location.TABLE:
			_loc_lbl.text = "Основной стол груминга • Заказ: %s" % str(pet.get("wish_tag", ""))
		Location.BATH:
			_loc_lbl.text = "Ванная зона • Купание и обёртывание в полотенце"

	_heat_row.visible = (step == Step.BLOW_DRY and active_tool == Tool.DRYER)
	_style_box.visible = (step == Step.FINAL_STYLE)
	_tools_box.visible = (step != Step.UNPACK_CARRIER and step != Step.PACK_CARRIER and step != Step.FINAL_STYLE and step != Step.SUMMARY)
	_action_btn.visible = (step == Step.SUMMARY)
	_toy_btn.visible = (step != Step.SUMMARY)

	var req: Tool = _get_required_tool()
	var tool_selected: bool = (active_tool == req) or (step == Step.BLOW_DRY and active_tool == Tool.CABINET)

	match step:
		Step.UNPACK_CARRIER:
			_status_lbl.text = "Распаковка: %s приехал в переноске! Нажимай или погладь решётку, чтобы открыть дверцу." % str(pet.get("name", ""))
		Step.CALM_BRUSH:
			_status_lbl.text = "Вычёсывание подшёрстка: возьми «Пуходёрку» и плавно прочеши всю шерсть!" if not tool_selected else "Веди пуходёрку плавно по всем прядям — вычесанный пух ложится на край стола."
		Step.TRIM_COAT:
			_status_lbl.text = "Стрижка колтунов: возьми «Ножницы» и разбери плотные колтуны по контуру." if not tool_selected else "Нажимай на колтуны (плотные требуют 2–3 среза ножницами)."
		Step.CLIP_NAILS:
			_status_lbl.text = "Стрижка когтей: выбери «Щипчики» на панели снизу." if not tool_selected else "Лови бегунок в ЗЕЛЁНОЙ зоне, чтобы срезать белый кончик и не задеть сосуд!"
		Step.WASH_SOAP:
			_status_lbl.text = "Намыливание (Ванная): возьми «Шампунь» и взбей густую пену." if not tool_selected else "Води губкой с шампунем по шёрстке до густой белой пены."
		Step.WASH_RINSE:
			_status_lbl.text = "Смыв пены (Ванная): переключись на «Душ» и смой пену водой." if not tool_selected else "Зажми и води лейкой душа над пеной."
		Step.TOWEL_WRAP:
			_status_lbl.text = "Полотенце (у ванной): возьми «Полотенце», чтобы укутать питомца!" if not tool_selected else "Промокни капли и укутай питомца в тёплое полотенце!"
		Step.BLOW_DRY:
			var cab_hint: String = " или «Шкаф»" if state.has_drying_cabinet else ""
			_status_lbl.text = "Сушка на столе: выбери «Фен»%s и распуши шерсть." % cab_hint if not tool_selected else ("Сушильный шкаф бережно сушит шерсть..." if active_tool == Tool.CABINET else "Води феном плавно — поток воздуха расправляет шерсть!")
		Step.FINAL_TRIM:
			_status_lbl.text = "Подравнивание после фена: возьми «Ножницы» и подровняй торчащие волосинки!" if not tool_selected else "Щёлкни ножницами по торчащим прядям после укладки."
		Step.FINAL_STYLE:
			_status_lbl.text = "Финальный образ: выбери аксессуар и аромат (%s), затем нажми на питомца!" % str(pet.get("wish_tag", ""))
			_rebuild_style_selectors()
		Step.PACK_CARRIER:
			_status_lbl.text = "Запаковка: %s готов к выдаче! Нажимай на переноску, чтобы закрыть дверцу перед фото." % str(pet.get("name", ""))
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
		var sel: bool = (chosen_accessory == a["id"])
		b.text = ("✓ " + a["label"]) if sel else a["label"]
		_apply_cozy_button_theme(b, Color("dcebe2") if sel else Color("fffdf9"), Color("7da388") if sel else Color("cbb7a0"))
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
		var sel_s: bool = (chosen_scent == s["id"])
		sb.text = ("✓ " + s["label"]) if sel_s else s["label"]
		_apply_cozy_button_theme(sb, Color("f3e7dc") if sel_s else Color("fffdf9"), Color("c99e76") if sel_s else Color("cbb7a0"))
		sb.pressed.connect(func():
			chosen_scent = s["id"]
			sound.play_soft_pop(1.3)
			_vibrate_tap(16)
			_rebuild_style_selectors()
		)
		scent_row.add_child(sb)

	var apply_btn := Button.new()
	apply_btn.text = "Завершить образ ✨"
	apply_btn.custom_minimum_size = Vector2(0, 66)
	apply_btn.add_theme_font_size_override("font_size", 24)
	_apply_cozy_button_theme(apply_btn, Color("dcebe2"), Color("7da388"))
	apply_btn.pressed.connect(_apply_final_style_finish)
	_style_box.add_child(apply_btn)

func _rebuild_tool_buttons() -> void:
	for c in _tools_box.get_children():
		c.queue_free()

	if not _tools_box.visible:
		return

	var available: Array[Dictionary] = []
	match location:
		Location.TABLE:
			available = [
				{"tool": Tool.BRUSH, "label": "Пуходёрка"},
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
		var bg := Color("dcebe2") if is_active else (Color("f5ebd9") if is_needed else Color("fffdf9"))
		var bd := Color("7da388") if is_active else (Color("c99e76") if is_needed else Color("cbb7a0"))
		_apply_cozy_button_theme(btn, bg, bd)
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
	return Vector2(sz.x * 0.5 + wobble + shake_x, sz.y * 0.53) + _resist_offset

func _get_pet_radius() -> float:
	var sz: Vector2 = _pad_panel.size if _pad_panel != null else Vector2(800, 900)
	var base_r: float = clamp(min(sz.x * 0.34, sz.y * 0.34), 165.0, 260.0)
	return base_r * float(pet.get("size_scale", 1.0))

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

	var in_carrier_step: bool = (step == Step.UNPACK_CARRIER or step == Step.PACK_CARRIER)
	if in_carrier_step:
		_draw_carrier_back(center, r)

	# Объёмная горка вычесанной шерсти сбоку на столе
	if location == Location.TABLE and _fur_pile_count > 0:
		var pile_base := Vector2(sz.x - 145.0, sz.y * 0.74 - 10.0)
		var body_col: Color = pet.get("body_color", Color("e6b67c"))
		_draw_ellipse_shape(pile_base + Vector2(0, 10), 72.0, 15.0, Color(0.45, 0.36, 0.28, 0.22), false)
		for k in range(_fur_pile_count):
			var ox: float = ((k % 4) - 1.5) * 20.0
			var oy: float = -floor(float(k) / 4.0) * 11.0
			_draw_shaded_sphere(pile_base + Vector2(ox, oy), 16.0, body_col.lightened(0.08), true)

	if step == Step.BLOW_DRY and active_tool == Tool.CABINET:
		_pad_panel.draw_rect(Rect2(center - Vector2(r * 1.35, r * 1.35), Vector2(r * 2.7, r * 2.5)), Color(0.76, 0.89, 0.83, 0.42))
		_pad_panel.draw_rect(Rect2(center - Vector2(r * 1.35, r * 1.35), Vector2(r * 2.7, r * 2.5)), Color("6d9982"), false, 3.5)

	var tex: Texture2D = _get_optional_texture(str(pet.get("sprite_path", "")))
	if tex != null:
		var t_size := Vector2(r * 2.5, r * 2.5)
		_pad_panel.draw_texture_rect(tex, Rect2(center - t_size * 0.5, t_size), false)
	else:
		_draw_breed_character(center, r)

	# Живая текстура шёрстки (меняет вид от спутанной до шёлковой уложенной)
	_draw_coat_texture_strands(center, r)

	if step == Step.FINAL_STYLE or step == Step.PACK_CARRIER or step == Step.SUMMARY:
		_draw_chosen_accessory(center, r)

	if in_carrier_step:
		_draw_carrier_front(center, r, _carrier_door_open)

	if step == Step.TOWEL_WRAP and _towel_wrap_ratio > 0.05:
		_draw_towel_wrap_overlay(center, r, _towel_wrap_ratio)

	if step == Step.CALM_BRUSH and active_tool == Tool.BRUSH:
		var love_pos := _get_zone_pos(str(pet.get("love_zone", "ears")))
		var sens_pos := _get_zone_pos(str(pet.get("sensitive_zone", "paws")))
		var pulse: float = 0.85 + sin(_anim_time * 5.0) * 0.15
		_pad_panel.draw_circle(love_pos, r * 0.34 * pulse, Color(0.49, 0.72, 0.56, 0.28))
		_pad_panel.draw_circle(love_pos, r * 0.34 * pulse, Color("5a8d76"), false, 3.0)
		_pad_panel.draw_circle(sens_pos, r * 0.26, Color(0.85, 0.48, 0.44, 0.22))
		_pad_panel.draw_circle(sens_pos, r * 0.26, Color("d98a7e"), false, 2.5)

	if step == Step.SUMMARY:
		var frame := Rect2(center - Vector2(r * 1.45, r * 1.48), Vector2(r * 2.9, r * 2.75))
		_pad_panel.draw_rect(frame, Color("fffdf9"), false, 12.0)
		_pad_panel.draw_rect(frame, Color("c99e76"), false, 4.0)

	var body_col: Color = pet.get("body_color", Color("e6b67c"))
	for item in _coat_items:
		var sp: Vector2 = center + Vector2(item["offset"]) * r
		var sz_item: float = float(item["size"])
		match step:
			Step.CALM_BRUSH:
				# Спутанные пряди подшёрстка, которые исчезают при вычёсывании
				var val_b: float = float(item["value"])
				if val_b > 0.05:
					var tuft_b: Color = body_col.darkened(0.14)
					_draw_shaded_sphere(sp, sz_item * 0.72 * val_b, tuft_b, false)
					_pad_panel.draw_line(sp + Vector2(-12 * val_b, -8 * val_b), sp + Vector2(12 * val_b, 8 * val_b), Color("5c4d40"), 2.2)
					_pad_panel.draw_line(sp + Vector2(-10 * val_b, 10 * val_b), sp + Vector2(10 * val_b, -10 * val_b), Color("5c4d40"), 2.2)
			Step.TRIM_COAT, Step.FINAL_TRIM:
				var val: float = float(item["value"])
				if val > 0.05:
					var tuft_col: Color = body_col.lightened(0.08) if bool(item.get("is_tuft", false)) else body_col.darkened(0.24)
					_draw_shaded_sphere(sp, sz_item * val, tuft_col, true)
					# Волокна колтуна
					_pad_panel.draw_arc(sp, sz_item * 0.55 * val, 0.2, 2.6, 10, Color("5c4d40"), 2.2)
			Step.WASH_SOAP, Step.WASH_RINSE:
				var dirt: float = float(item["value"])
				var foam: float = float(item["foam"])
				if dirt > 0.05:
					_pad_panel.draw_circle(sp, sz_item * dirt, Color(0.55, 0.45, 0.35, 0.55 * dirt))
				if foam > 0.05:
					_draw_shaded_sphere(sp, sz_item * foam, Color(0.96, 0.99, 1.0, 0.94), false)
					_draw_shaded_sphere(sp + Vector2(12, -10), sz_item * 0.65 * foam, Color(1.0, 1.0, 1.0, 0.96), false)
			Step.TOWEL_WRAP, Step.BLOW_DRY:
				var drop: float = float(item["value"])
				if drop > 0.05:
					_draw_shaded_sphere(sp, sz_item * 0.78 * drop, Color(0.54, 0.81, 0.95, 0.90), false)

	if step == Step.CLIP_NAILS:
		_draw_nail_clipping_overlay(sz)

	if location == Location.BATH:
		var bath_y: float = sz.y * 0.72
		_pad_panel.draw_rect(Rect2(24, bath_y, sz.x - 48, sz.y - bath_y - 16), Color("b7d7e2"))
		_pad_panel.draw_rect(Rect2(24, bath_y + 18, sz.x - 48, sz.y - bath_y - 34), Color("9ec4d1"))
		_pad_panel.draw_rect(Rect2(18, bath_y - 12, sz.x - 36, 22), Color("eef8fb"))
		_pad_panel.draw_rect(Rect2(24, bath_y, sz.x - 48, sz.y - bath_y - 16), Color("688694"), false, 3.5)

	if toy_timer > 0.0:
		var toy_pos := center + Vector2(-r * 1.12, r * 0.35 + sin(_anim_time * 12.0) * 11.0)
		_draw_shaded_sphere(toy_pos, 26.0, Color("e68c7a"), true)

	for p in _particles:
		var age_ratio: float = clamp(1.0 - float(p["age"]) / float(p["life"]), 0.0, 1.0)
		var pc: Color = p["color"]
		pc.a = age_ratio * 0.92
		_pad_panel.draw_circle(Vector2(p["pos"]), float(p["radius"]), pc)

	if active_tool != Tool.NONE and active_tool != Tool.CABINET and step != Step.FINAL_STYLE and step != Step.SUMMARY and not in_carrier_step:
		if _stroking or _pointer_pos.x > 0.0:
			_draw_active_tool(_pointer_pos)

	if _transition_alpha > 0.01:
		_pad_panel.draw_rect(Rect2(Vector2.ZERO, sz), Color(1.0, 0.99, 0.96, _transition_alpha * 0.85))

func _draw_coat_texture_strands(center: Vector2, r: float) -> void:
	var body_col: Color = pet.get("body_color", Color("e6b67c"))
	var strand_col: Color = body_col.darkened(0.22)
	var wind_push: float = sin(_anim_time * 18.0) * 0.45 if (_stroking and step == Step.BLOW_DRY) else 0.0
	for st in _fur_strands:
		var sp: Vector2 = center + Vector2(st["offset"]) * r
		var ang: float = float(st["angle"]) + wind_push
		var slen: float = float(st["len"]) * (r / 190.0)
		var dir := Vector2(sin(ang), cos(ang)) * slen
		_pad_panel.draw_line(sp, sp + dir, strand_col, 2.2)

func _draw_shaded_sphere(pos: Vector2, rad: float, base_col: Color, with_outline: bool = true) -> void:
	_pad_panel.draw_circle(pos, rad, base_col.darkened(0.14))
	_pad_panel.draw_circle(pos + Vector2(-rad * 0.06, -rad * 0.08), rad * 0.90, base_col)
	_pad_panel.draw_circle(pos + Vector2(-rad * 0.24, -rad * 0.28), rad * 0.44, base_col.lightened(0.18))
	if with_outline:
		_pad_panel.draw_circle(pos, rad, Color("5c4d40"), false, 3.0)

func _draw_shaded_ellipse(pos: Vector2, rx: float, ry: float, base_col: Color, with_outline: bool = true) -> void:
	_draw_ellipse_shape(pos, rx, ry, base_col.darkened(0.13), false)
	_draw_ellipse_shape(pos + Vector2(-rx * 0.04, -ry * 0.07), rx * 0.93, ry * 0.91, base_col, false)
	_draw_ellipse_shape(pos + Vector2(-rx * 0.16, -ry * 0.26), rx * 0.56, ry * 0.44, base_col.lightened(0.16), false)
	if with_outline:
		_draw_ellipse_outline(pos, rx, ry, Color("5c4d40"), 3.5)

func _draw_ellipse_outline(pos: Vector2, rx: float, ry: float, col: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in range(32):
		var a := (float(i) / 32.0) * TAU
		pts.append(pos + Vector2(cos(a) * rx, sin(a) * ry))
	pts.append(pts[0])
	_pad_panel.draw_polyline(pts, col, width)

func _draw_carrier_back(center: Vector2, r: float) -> void:
	var box := Rect2(center + Vector2(-r * 1.35, -r * 1.25), Vector2(r * 2.7, r * 2.25))
	_pad_panel.draw_rect(box, Color("8fb39e"))
	_pad_panel.draw_rect(Rect2(box.position + Vector2(0, 0), Vector2(box.size.x, 32)), Color("a6c9b4"))
	_pad_panel.draw_rect(Rect2(box.position + Vector2(18, 22), box.size - Vector2(36, 36)), Color("3d4d44"))
	_pad_panel.draw_rect(Rect2(center + Vector2(-r * 0.42, -r * 1.42), Vector2(r * 0.84, 22)), Color("d69e85"))
	_pad_panel.draw_rect(box, Color("4a3f35"), false, 4.0)

func _draw_carrier_front(center: Vector2, r: float, open_ratio: float) -> void:
	var box := Rect2(center + Vector2(-r * 1.35, -r * 1.25), Vector2(r * 2.7, r * 2.25))
	var tray := Rect2(box.position + Vector2(0, box.size.y * 0.52), Vector2(box.size.x, box.size.y * 0.48))
	_pad_panel.draw_rect(tray, Color("a3c4b1"))
	_pad_panel.draw_rect(Rect2(tray.position, Vector2(tray.size.x, 16)), Color("bce0cc"))
	_pad_panel.draw_rect(tray, Color("4a3f35"), false, 4.0)

	var door_full_w: float = box.size.x - 40.0
	var door_w: float = max(24.0, door_full_w * (1.0 - open_ratio * 0.88))
	var door := Rect2(box.position + Vector2(20, 24), Vector2(door_w, box.size.y - 44))
	_pad_panel.draw_rect(door, Color(0.95, 0.97, 0.96, 0.22))
	_pad_panel.draw_rect(door, Color("6e7b82"), false, 5.0)
	for gx in range(int(door.position.x + 28), int(door.position.x + door.size.x - 10), 34):
		_pad_panel.draw_line(Vector2(gx, door.position.y), Vector2(gx, door.position.y + door.size.y), Color("6e7b82"), 4.0)
	for gy in range(int(door.position.y + 34), int(door.position.y + door.size.y - 10), 42):
		_pad_panel.draw_line(Vector2(door.position.x, gy), Vector2(door.position.x + door.size.x, gy), Color("6e7b82"), 4.0)

func _draw_towel_wrap_overlay(center: Vector2, r: float, ratio: float) -> void:
	var towel_col := Color("fffaf0")
	var trim_col := Color("9fc4ab")
	var wrap_w: float = r * 1.72 * clamp(ratio * 1.2, 0.4, 1.0)
	var wrap_rect := Rect2(center + Vector2(-wrap_w * 0.5, -r * 0.05), Vector2(wrap_w, r * 0.95))
	_pad_panel.draw_rect(wrap_rect, towel_col.darkened(0.05))
	_pad_panel.draw_rect(Rect2(wrap_rect.position, Vector2(wrap_rect.size.x, wrap_rect.size.y * 0.45)), towel_col)
	_pad_panel.draw_rect(wrap_rect, Color("bfa992"), false, 3.5)
	_pad_panel.draw_line(wrap_rect.position, wrap_rect.position + Vector2(wrap_rect.size.x * 0.75, wrap_rect.size.y * 0.7), trim_col, 5.0)
	_pad_panel.draw_line(wrap_rect.position + Vector2(wrap_rect.size.x, 0), wrap_rect.position + Vector2(wrap_rect.size.x * 0.25, wrap_rect.size.y * 0.7), trim_col, 5.0)
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
	_draw_shaded_sphere(paw_center + Vector2(0, 35), 92.0, body_col, true)

	for i in range(4):
		var nx: float = paw_center.x + (-1.5 + float(i)) * 56.0
		var ny: float = paw_center.y - 36.0
		var nail_len: float = 18.0 if _nails_done[i] else 42.0
		var col: Color = Color("9fc4ab") if _nails_done[i] else (Color("fff8f0") if i == _active_nail_idx else Color("ebe3d8"))
		_pad_panel.draw_rect(Rect2(nx - 10, ny - nail_len, 20, nail_len), col)
		# Розовый кровеносный сосуд (пульпа) у основания когтя
		_pad_panel.draw_rect(Rect2(nx - 6, ny - 15, 12, 15), Color("e6938a"))
		_pad_panel.draw_rect(Rect2(nx - 10, ny - nail_len, 20, nail_len), Color("5c4d40"), false, 2.5)
		if i == _active_nail_idx:
			_pad_panel.draw_circle(Vector2(nx, ny - nail_len - 14), 7.0, Color("7da388"))

	var bar_w: float = sz.x - 160.0
	var bar_x: float = 80.0
	var bar_y: float = paw_center.y + 82.0
	_pad_panel.draw_rect(Rect2(bar_x, bar_y, bar_w, 26), Color("eadfd2"))
	_pad_panel.draw_rect(Rect2(bar_x + bar_w * 0.34, bar_y, bar_w * 0.32, 26), Color("7da388"))
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
			_draw_shaded_sphere(top_pos, 11.0, Color("fff4e8"), false)
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
				_draw_shaded_sphere(fpos + Vector2(cos(rad), sin(rad)) * 16.0, 12.0, bow_col, false)
			_draw_shaded_sphere(fpos, 10.0, Color("f7d97e"), false)

func _draw_ellipse_shape(pos: Vector2, rx: float, ry: float, col: Color, outline: bool = true) -> void:
	var pts := PackedVector2Array()
	for i in range(32):
		var a := (float(i) / 32.0) * TAU
		pts.append(pos + Vector2(cos(a) * rx, sin(a) * ry))
	_pad_panel.draw_colored_polygon(pts, col)
	if outline:
		pts.append(pts[0])
		_pad_panel.draw_polyline(pts, Color("5c4d40"), 3.5)

func _draw_breed_character(center: Vector2, r: float) -> void:
	var body_col: Color = pet.get("body_color", Color("e6b67c"))
	var acc_col: Color = pet.get("accent_color", Color("fff9f0"))
	var eye_col: Color = pet.get("eye_color", Color("3c332b"))
	var vtype: String = str(pet.get("visual_type", "corgi"))
	var is_fluffy_done: bool = (step == Step.FINAL_TRIM or step == Step.FINAL_STYLE or step == Step.PACK_CARRIER or step == Step.SUMMARY)
	var fluff: float = 1.09 if is_fluffy_done else 1.0
	var breath: float = sin(_anim_time * 3.1) * 0.03

	var body_rx: float = r * (0.72 + breath)
	var body_ry: float = r * (0.66 - breath * 0.5)
	match vtype:
		"dachshund":
			body_rx = r * (1.12 + breath)
			body_ry = r * 0.44
		"corgi":
			body_rx = r * (0.96 + breath)
			body_ry = r * 0.54
		"mainecoon":
			body_rx = r * (0.84 + breath) * fluff
			body_ry = r * 0.72 * fluff
		"samoyed":
			body_rx = r * (0.90 + breath) * fluff
			body_ry = r * 0.78 * fluff
		"spitz":
			body_rx = r * (0.76 + breath) * fluff
			body_ry = r * 0.72 * fluff
		"poodle":
			body_rx = r * (0.58 + breath) * fluff
			body_ry = r * 0.64 * fluff
		"bobtail":
			body_rx = r * (0.68 + breath)
			body_ry = r * 0.64
		"persian":
			body_rx = r * (0.82 + breath) * fluff
			body_ry = r * 0.68 * fluff

	_draw_ellipse_shape(center + Vector2(0, body_ry + r * 0.25), body_rx * 1.12, r * 0.17, Color(0.42, 0.34, 0.26, 0.28), false)

	var tail_speed: float = 8.0 if calmness > 70.0 else 3.8
	var tail_swing: float = sin(_anim_time * tail_speed) * (20.0 if calmness > 70.0 else 10.0)
	match vtype:
		"bobtail":
			_draw_shaded_sphere(center + Vector2(body_rx * 0.96, r * 0.15 + tail_swing * 0.3), r * 0.24, acc_col, true)
		"mainecoon", "persian":
			_draw_shaded_ellipse(center + Vector2(body_rx * 1.05, r * 0.05 + tail_swing), r * 0.44 * fluff, r * 0.26 * fluff, body_col, true)
			_draw_shaded_sphere(center + Vector2(body_rx * 1.25, -r * 0.05 + tail_swing), r * 0.24 * fluff, acc_col, false)
		"samoyed", "spitz":
			_draw_shaded_sphere(center + Vector2(body_rx * 0.86, -r * 0.22 + tail_swing * 0.5), r * 0.34 * fluff, acc_col, true)
		"corgi":
			_draw_shaded_ellipse(center + Vector2(body_rx * 0.92, r * 0.12), r * 0.22, r * 0.28, acc_col, true)
		"poodle":
			_pad_panel.draw_line(center + Vector2(body_rx * 0.82, r * 0.12), center + Vector2(body_rx * 1.25, -r * 0.18 + tail_swing), body_col, 11.0)
			_draw_shaded_sphere(center + Vector2(body_rx * 1.28, -r * 0.20 + tail_swing), r * 0.22 * fluff, acc_col, true)
		"dachshund":
			_pad_panel.draw_line(center + Vector2(body_rx * 0.92, r * 0.12), center + Vector2(body_rx * 1.32, -r * 0.24 + tail_swing), body_col.darkened(0.1), 12.0)
			_pad_panel.draw_line(center + Vector2(body_rx * 0.92, r * 0.12), center + Vector2(body_rx * 1.32, -r * 0.24 + tail_swing), body_col.lightened(0.1), 6.0)
		_:
			_pad_panel.draw_line(center + Vector2(body_rx * 0.85, r * 0.2), center + Vector2(body_rx * 1.28, -r * 0.08 + tail_swing), body_col, 22.0)
			_draw_shaded_sphere(center + Vector2(body_rx * 1.28, -r * 0.08 + tail_swing), 11.0, body_col, false)

	_draw_shaded_ellipse(center + Vector2(0, r * 0.28), body_rx, body_ry, body_col, true)

	if vtype == "mainecoon" or vtype == "samoyed" or vtype == "spitz":
		for gx in [-0.36, -0.18, 0.0, 0.18, 0.36]:
			_draw_shaded_sphere(center + Vector2(r * gx, r * 0.16), r * 0.24 * fluff, acc_col, false)
	elif vtype == "poodle":
		for gx in [-0.24, 0.0, 0.24]:
			_draw_shaded_sphere(center + Vector2(r * gx, r * 0.22), r * 0.24 * fluff, acc_col, false)
	else:
		_draw_shaded_ellipse(center + Vector2(0, r * 0.34), body_rx * 0.56, body_ry * 0.62, acc_col, false)

	# Лапки (при упирании выдвигаются вперёд)
	if location != Location.BATH:
		var brace_dx: float = abs(_resist_offset.x) * 0.45
		var leg_y: float = center.y + body_ry + r * 0.14
		var leg_spread: float = body_rx * 0.56 + brace_dx
		if vtype == "dachshund" or vtype == "corgi":
			_draw_shaded_ellipse(Vector2(center.x - leg_spread, leg_y), r * 0.22, r * 0.13, acc_col, true)
			_draw_shaded_ellipse(Vector2(center.x + leg_spread, leg_y), r * 0.22, r * 0.13, acc_col, true)
		elif vtype == "poodle":
			_pad_panel.draw_line(Vector2(center.x - leg_spread, leg_y - 26), Vector2(center.x - leg_spread, leg_y + 10), body_col, 14.0)
			_pad_panel.draw_line(Vector2(center.x + leg_spread, leg_y - 26), Vector2(center.x + leg_spread, leg_y + 10), body_col, 14.0)
			_draw_shaded_sphere(Vector2(center.x - leg_spread, leg_y + 4), r * 0.17 * fluff, acc_col, true)
			_draw_shaded_sphere(Vector2(center.x + leg_spread, leg_y + 4), r * 0.17 * fluff, acc_col, true)
		else:
			_draw_shaded_ellipse(Vector2(center.x - leg_spread, leg_y), r * 0.18, r * 0.20, acc_col, true)
			_draw_shaded_ellipse(Vector2(center.x + leg_spread, leg_y), r * 0.18, r * 0.20, acc_col, true)

	# Голова с наклоном к инструменту и обнюхиванием
	var head_tilt: float = sin(_anim_time * 2.2) * 5.0 + _head_look.x * 10.0
	var sniff_forward: float = sin(_anim_time * 28.0) * 5.0 if _sniff_timer > 0.0 else 0.0
	var head_offset_x: float = -body_rx * 0.34 if vtype == "dachshund" else 0.0
	var head_pos := center + Vector2(head_tilt + head_offset_x + sniff_forward, -body_ry * 0.68 + _head_look.y * 8.0)
	var head_rx: float = r * 0.66
	var head_ry: float = r * 0.60
	match vtype:
		"persian", "british", "lop_cat":
			head_rx = r * 0.74
			head_ry = r * 0.62
		"mainecoon":
			head_rx = r * 0.68
			head_ry = r * 0.68
		"dachshund":
			head_rx = r * 0.56
			head_ry = r * 0.50
		"corgi":
			head_rx = r * 0.66
			head_ry = r * 0.58
		"poodle":
			head_rx = r * 0.54
			head_ry = r * 0.54

	_draw_shaded_ellipse(head_pos, head_rx, head_ry, body_col, true)

	var ear_droop: float = (r * 0.14 if stress > 65.0 else 0.0) + sin(_anim_time * 32.0) * 6.0 * _ear_twitch
	match vtype:
		"mainecoon":
			_pad_panel.draw_colored_polygon(PackedVector2Array([
				head_pos + Vector2(-head_rx * 0.82, -head_ry * 0.35),
				head_pos + Vector2(-head_rx * 0.52, -head_ry * 1.48 + ear_droop),
				head_pos + Vector2(-head_rx * 0.15, -head_ry * 0.72)
			]), body_col)
			_pad_panel.draw_colored_polygon(PackedVector2Array([
				head_pos + Vector2(head_rx * 0.82, -head_ry * 0.35),
				head_pos + Vector2(head_rx * 0.52, -head_ry * 1.48 + ear_droop),
				head_pos + Vector2(head_rx * 0.15, -head_ry * 0.72)
			]), body_col)
			_pad_panel.draw_line(head_pos + Vector2(-head_rx * 0.52, -head_ry * 1.48 + ear_droop), head_pos + Vector2(-head_rx * 0.62, -head_ry * 1.78 + ear_droop), acc_col, 5.0)
			_pad_panel.draw_line(head_pos + Vector2(head_rx * 0.52, -head_ry * 1.48 + ear_droop), head_pos + Vector2(head_rx * 0.62, -head_ry * 1.78 + ear_droop), acc_col, 5.0)
			_draw_shaded_ellipse(head_pos + Vector2(0, head_ry * 0.34), head_rx * 0.44, head_ry * 0.30, acc_col, false)
		"persian":
			_draw_shaded_sphere(head_pos + Vector2(-head_rx * 0.68, head_ry * 0.20), r * 0.26, body_col, false)
			_draw_shaded_sphere(head_pos + Vector2(head_rx * 0.68, head_ry * 0.20), r * 0.26, body_col, false)
			_pad_panel.draw_colored_polygon(PackedVector2Array([
				head_pos + Vector2(-head_rx * 0.82, -head_ry * 0.38),
				head_pos + Vector2(-head_rx * 0.62, -head_ry * 1.05 + ear_droop),
				head_pos + Vector2(-head_rx * 0.28, -head_ry * 0.68)
			]), acc_col)
			_pad_panel.draw_colored_polygon(PackedVector2Array([
				head_pos + Vector2(head_rx * 0.82, -head_ry * 0.38),
				head_pos + Vector2(head_rx * 0.62, -head_ry * 1.05 + ear_droop),
				head_pos + Vector2(head_rx * 0.28, -head_ry * 0.68)
			]), acc_col)
		"british", "bobtail":
			_pad_panel.draw_colored_polygon(PackedVector2Array([
				head_pos + Vector2(-head_rx * 0.72, -head_ry * 0.45),
				head_pos + Vector2(-head_rx * 0.42, -head_ry * 1.32 + ear_droop),
				head_pos + Vector2(-head_rx * 0.08, -head_ry * 0.75)
			]), body_col)
			_pad_panel.draw_colored_polygon(PackedVector2Array([
				head_pos + Vector2(head_rx * 0.72, -head_ry * 0.45),
				head_pos + Vector2(head_rx * 0.42, -head_ry * 1.32 + ear_droop),
				head_pos + Vector2(head_rx * 0.08, -head_ry * 0.75)
			]), body_col)
		"lop_cat":
			_draw_shaded_ellipse(head_pos + Vector2(-head_rx * 0.76, -head_ry * 0.42 + ear_droop * 0.5), r * 0.26, r * 0.16, acc_col, true)
			_draw_shaded_ellipse(head_pos + Vector2(head_rx * 0.76, -head_ry * 0.42 + ear_droop * 0.5), r * 0.26, r * 0.16, acc_col, true)
		"corgi":
			_draw_shaded_ellipse(head_pos + Vector2(-head_rx * 0.58, -head_ry * 1.05 + ear_droop), r * 0.24, r * 0.44, body_col, true)
			_draw_shaded_ellipse(head_pos + Vector2(head_rx * 0.58, -head_ry * 1.05 + ear_droop), r * 0.24, r * 0.44, body_col, true)
			_draw_ellipse_shape(head_pos + Vector2(-head_rx * 0.58, -head_ry * 1.02 + ear_droop), r * 0.13, r * 0.28, acc_col, false)
			_draw_ellipse_shape(head_pos + Vector2(head_rx * 0.58, -head_ry * 1.02 + ear_droop), r * 0.13, r * 0.28, acc_col, false)
			_pad_panel.draw_rect(Rect2(head_pos + Vector2(-r * 0.11, -head_ry * 0.65), Vector2(r * 0.22, head_ry * 0.85)), acc_col)
			_draw_shaded_ellipse(head_pos + Vector2(0, head_ry * 0.34), head_rx * 0.54, head_ry * 0.36, acc_col, false)
		"samoyed", "spitz":
			_draw_shaded_sphere(head_pos + Vector2(-head_rx * 0.74, head_ry * 0.08), r * 0.26 * fluff, acc_col, false)
			_draw_shaded_sphere(head_pos + Vector2(head_rx * 0.74, head_ry * 0.08), r * 0.26 * fluff, acc_col, false)
			_pad_panel.draw_colored_polygon(PackedVector2Array([
				head_pos + Vector2(-head_rx * 0.68, -head_ry * 0.42),
				head_pos + Vector2(-head_rx * 0.44, -head_ry * 1.38 + ear_droop),
				head_pos + Vector2(-head_rx * 0.10, -head_ry * 0.72)
			]), body_col)
			_pad_panel.draw_colored_polygon(PackedVector2Array([
				head_pos + Vector2(head_rx * 0.68, -head_ry * 0.42),
				head_pos + Vector2(head_rx * 0.44, -head_ry * 1.38 + ear_droop),
				head_pos + Vector2(head_rx * 0.10, -head_ry * 0.72)
			]), body_col)
			_draw_shaded_ellipse(head_pos + Vector2(0, head_ry * 0.32), head_rx * 0.44, head_ry * 0.34, acc_col, false)
		"poodle":
			for cx in [-0.26, 0.0, 0.26]:
				_draw_shaded_sphere(head_pos + Vector2(r * cx, -head_ry * 0.86), r * 0.24 * fluff, body_col, false)
			_draw_shaded_ellipse(head_pos + Vector2(-head_rx * 0.92, head_ry * 0.12 + ear_droop), r * 0.22 * fluff, r * 0.44 * fluff, acc_col, true)
			_draw_shaded_ellipse(head_pos + Vector2(head_rx * 0.92, head_ry * 0.12 + ear_droop), r * 0.22 * fluff, r * 0.44 * fluff, acc_col, true)
		"dachshund", "beagle":
			_draw_shaded_ellipse(head_pos + Vector2(-head_rx * 0.88, head_ry * 0.24 + ear_droop), r * 0.20, r * 0.46, acc_col, true)
			_draw_shaded_ellipse(head_pos + Vector2(head_rx * 0.88, head_ry * 0.24 + ear_droop), r * 0.20, r * 0.46, acc_col, true)
			_draw_shaded_ellipse(head_pos + Vector2(0, head_ry * 0.34), head_rx * 0.52, head_ry * 0.40, acc_col, true)

	# Глаза со слежением зрачков за инструментом
	var pupil_shift := _head_look * (r * 0.035)
	if _is_blinking or (calmness >= 70.0 and stress < 45.0):
		_pad_panel.draw_line(head_pos + Vector2(-head_rx * 0.46, -head_ry * 0.08), head_pos + Vector2(-head_rx * 0.20, -head_ry * 0.18), Color("3c332b"), 3.5)
		_pad_panel.draw_line(head_pos + Vector2(head_rx * 0.20, -head_ry * 0.18), head_pos + Vector2(head_rx * 0.46, -head_ry * 0.08), Color("3c332b"), 3.5)
	else:
		_pad_panel.draw_circle(head_pos + Vector2(-head_rx * 0.34, -head_ry * 0.08), r * 0.105, eye_col)
		_pad_panel.draw_circle(head_pos + Vector2(head_rx * 0.34, -head_ry * 0.08), r * 0.105, eye_col)
		_pad_panel.draw_circle(head_pos + Vector2(-head_rx * 0.34, -head_ry * 0.08) + pupil_shift, r * 0.058, Color("261f1a"))
		_pad_panel.draw_circle(head_pos + Vector2(head_rx * 0.34, -head_ry * 0.08) + pupil_shift, r * 0.058, Color("261f1a"))
		_pad_panel.draw_circle(head_pos + Vector2(-head_rx * 0.30, -head_ry * 0.12) + pupil_shift, r * 0.034, Color("ffffff"))
		_pad_panel.draw_circle(head_pos + Vector2(head_rx * 0.38, -head_ry * 0.12) + pupil_shift, r * 0.034, Color("ffffff"))

	if calmness > 60.0 or dryer_heat > 35.0:
		_pad_panel.draw_circle(head_pos + Vector2(-head_rx * 0.52, head_ry * 0.16), r * 0.085, Color(0.92, 0.56, 0.52, 0.45))
		_pad_panel.draw_circle(head_pos + Vector2(head_rx * 0.52, head_ry * 0.16), r * 0.085, Color(0.92, 0.56, 0.52, 0.45))

	var is_dog: bool = str(pet.get("species", "")) == "Пёсик"
	var nose_col := Color("3c332b") if is_dog else Color("d98a7e")
	var nose_wiggle := Vector2(sin(_anim_time * 34.0) * 3.0 if _sniff_timer > 0.0 else 0.0, 0.0)
	_pad_panel.draw_circle(head_pos + Vector2(0, head_ry * 0.22) + nose_wiggle, r * 0.08, nose_col)
	_pad_panel.draw_circle(head_pos + Vector2(-r * 0.025, head_ry * 0.19) + nose_wiggle, r * 0.025, Color("ffffff"))
	_pad_panel.draw_line(head_pos + Vector2(-r * 0.13, head_ry * 0.42), head_pos + Vector2(0, head_ry * 0.34), Color("3c332b"), 3.0)
	_pad_panel.draw_line(head_pos + Vector2(0, head_ry * 0.34), head_pos + Vector2(r * 0.13, head_ry * 0.42), Color("3c332b"), 3.0)

	if not is_dog:
		_pad_panel.draw_line(head_pos + Vector2(-head_rx * 0.38, head_ry * 0.22), head_pos + Vector2(-head_rx * 0.85, head_ry * 0.14), Color("6e5d4f"), 2.0)
		_pad_panel.draw_line(head_pos + Vector2(-head_rx * 0.38, head_ry * 0.30), head_pos + Vector2(-head_rx * 0.82, head_ry * 0.34), Color("6e5d4f"), 2.0)
		_pad_panel.draw_line(head_pos + Vector2(head_rx * 0.38, head_ry * 0.22), head_pos + Vector2(head_rx * 0.85, head_ry * 0.14), Color("6e5d4f"), 2.0)
		_pad_panel.draw_line(head_pos + Vector2(head_rx * 0.38, head_ry * 0.30), head_pos + Vector2(head_rx * 0.82, head_ry * 0.34), Color("6e5d4f"), 2.0)

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
		_pad_panel.draw_rect(Rect2(16, table_y, sz.x - 32, 18), Color("f0e2d0"))
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
			# Детализированная пуходёрка с деревянной ручкой и металлическими зубчиками
			var bp := pos + Vector2(anim_pulse, 0)
			_pad_panel.draw_line(bp + Vector2(-46, -24), bp + Vector2(-18, -6), Color("b88856"), 10.0)
			_pad_panel.draw_rect(Rect2(bp - Vector2(22, 20), Vector2(68, 38)), Color("9fc4ab"))
			_pad_panel.draw_rect(Rect2(bp - Vector2(22, 20), Vector2(68, 14)), Color("bce0c8"))
			_pad_panel.draw_rect(Rect2(bp - Vector2(22, 20), Vector2(68, 38)), Color("4a6354"), false, 3.0)
			for bx in [-12, -2, 8, 18, 28, 38]:
				_pad_panel.draw_line(bp + Vector2(bx, 18), bp + Vector2(bx - 3, 30), Color("7a8691"), 2.6)
		Tool.SCISSORS:
			# Парикмахерские ножницы с кольцами и осевым винтом
			var snip: float = 4.0 if _tool_anim_timer > 0.0 else 20.0
			_pad_panel.draw_line(pos + Vector2(-28, -snip), pos + Vector2(30, snip * 0.85), Color("b5bfc7"), 6.0)
			_pad_panel.draw_line(pos + Vector2(-28, snip), pos + Vector2(30, -snip * 0.85), Color("8b969e"), 6.0)
			_pad_panel.draw_circle(pos, 4.5, Color("4a3f35"))
			_pad_panel.draw_circle(pos + Vector2(-30, -snip), 12.0, Color("d98a7e"), false, 4.0)
			_pad_panel.draw_circle(pos + Vector2(-30, snip), 12.0, Color("d98a7e"), false, 4.0)
		Tool.CLIPPER:
			# Когтерез с пружиной и изогнутыми лезвиями
			var jaw: float = 3.0 if _tool_anim_timer > 0.0 else 16.0
			_pad_panel.draw_line(pos + Vector2(-28, 30), pos + Vector2(-6, 0), Color("e68c7a"), 8.5)
			_pad_panel.draw_line(pos + Vector2(28, 30), pos + Vector2(6, 0), Color("e68c7a"), 8.5)
			_pad_panel.draw_arc(pos + Vector2(0, 14), 10.0, 0.2, PI - 0.2, 8, Color("7a8691"), 3.0)
			_pad_panel.draw_line(pos + Vector2(-6, 0), pos + Vector2(-jaw, -26), Color("94a1ab"), 7.0)
			_pad_panel.draw_line(pos + Vector2(6, 0), pos + Vector2(jaw, -26), Color("94a1ab"), 7.0)
		Tool.SHAMPOO:
			# Флакон шампуня с дозатором
			var sq: float = 1.0 + sin(_anim_time * 18.0) * 0.10 if _tool_anim_timer > 0.0 else 1.0
			_pad_panel.draw_rect(Rect2(pos - Vector2(22 * sq, 18), Vector2(44 * sq, 52)), Color("f5e09b"))
			_pad_panel.draw_rect(Rect2(pos - Vector2(22 * sq, 18), Vector2(16 * sq, 52)), Color("fff0ba"))
			_pad_panel.draw_rect(Rect2(pos - Vector2(22 * sq, 18), Vector2(44 * sq, 52)), Color("8c7a48"), false, 3.0)
			_pad_panel.draw_rect(Rect2(pos - Vector2(8, 30), Vector2(16, 12)), Color("fffdf9"))
			_pad_panel.draw_line(pos + Vector2(0, -30), pos + Vector2(16, -34), Color("fffdf9"), 4.5)
		Tool.SHOWER:
			# Хромированная лейка душа со струями воды
			_pad_panel.draw_line(pos + Vector2(-34, 24), pos + Vector2(-8, 6), Color("7f94a1"), 9.0)
			_draw_shaded_sphere(pos, 26.0, Color("9ab8c7"), true)
			if _stroking:
				for sx in [-14, -5, 5, 14]:
					_pad_panel.draw_line(pos + Vector2(sx, 22), pos + Vector2(sx * 1.3, 62), Color("8fd0eb"), 3.5)
		Tool.TOWEL:
			var tp := pos + Vector2(0, anim_pulse)
			_pad_panel.draw_rect(Rect2(tp - Vector2(36, 24), Vector2(72, 48)), Color("fffaf2"))
			_pad_panel.draw_rect(Rect2(tp - Vector2(36, 24), Vector2(72, 48)), Color("bfa992"), false, 3.5)
			_pad_panel.draw_line(tp + Vector2(-30, 14), tp + Vector2(30, 14), Color("9fc4ab"), 4.5)
		Tool.DRYER:
			# Профессиональный фен с соплом и потоком тёплого воздуха
			var dp := pos + Vector2(0, anim_pulse * 0.5)
			_pad_panel.draw_line(dp + Vector2(-12, 10), dp + Vector2(-22, 40), Color("687c8a"), 11.0)
			_pad_panel.draw_rect(Rect2(dp - Vector2(24, 16), Vector2(46, 30)), Color("8ea6b5"))
			_pad_panel.draw_rect(Rect2(dp + Vector2(22, -12), Vector2(12, 22)), Color("566673"))
			_pad_panel.draw_rect(Rect2(dp - Vector2(24, 16), Vector2(46, 30)), Color("465a66"), false, 3.0)
			if _stroking:
				var wave: float = sin(_anim_time * 26.0) * 6.0
				_pad_panel.draw_line(dp + Vector2(38, -8), dp + Vector2(82, -18 + wave), Color("f2cf8d"), 4.5)
				_pad_panel.draw_line(dp + Vector2(38, 0), dp + Vector2(90, wave * 0.5), Color("f2cf8d"), 4.5)
				_pad_panel.draw_line(dp + Vector2(38, 8), dp + Vector2(82, 18 - wave), Color("f2cf8d"), 4.5)

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
	_apply_cozy_button_theme(close_btn, Color("fffdf9"), Color("cbb7a0"))
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
	_apply_cozy_button_theme(_toy_btn, Color("f5ebd9"), Color("c99e76"))
	_toy_btn.pressed.connect(_on_toy_pressed)
	vbox.add_child(_toy_btn)

	_action_btn = Button.new()
	_action_btn.text = "Забрать оплату и вернуться в зал"
	_action_btn.custom_minimum_size = Vector2(0, 74)
	_action_btn.visible = false
	_action_btn.add_theme_font_size_override("font_size", 25)
	_apply_cozy_button_theme(_action_btn, Color("dcebe2"), Color("7da388"))
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
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color("eadfd2")
	bg_sb.set_corner_radius_all(8)
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill_col
	sb.set_corner_radius_all(8)
	bar.add_theme_stylebox_override("background", bg_sb)
	bar.add_theme_stylebox_override("fill", sb)
	row.add_child(bar)

	parent.add_child(row)
	return bar
