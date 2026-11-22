extends Node
class_name SoundManager

var muted: bool = false
var _player: AudioStreamPlayer
var _loop_player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _loop_playback: AudioStreamGeneratorPlayback

const SAMPLE_RATE := 22050.0

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = SAMPLE_RATE
	gen.buffer_length = 0.45
	_player.stream = gen
	_player.volume_db = -8.0
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback()

	_loop_player = AudioStreamPlayer.new()
	var loop_gen := AudioStreamGenerator.new()
	loop_gen.mix_rate = SAMPLE_RATE
	loop_gen.buffer_length = 0.35
	_loop_player.stream = loop_gen
	_loop_player.volume_db = -12.0
	add_child(_loop_player)
	_loop_player.play()
	_loop_playback = _loop_player.get_stream_playback()

func toggle_mute() -> void:
	muted = not muted
	_player.stream_paused = muted
	_loop_player.stream_paused = muted

func _ensure_playback() -> bool:
	if muted:
		return false
	if not _player.playing:
		_player.play()
	_playback = _player.get_stream_playback()
	return _playback != null

func _ensure_loop_playback() -> bool:
	if muted:
		return false
	if not _loop_player.playing:
		_loop_player.play()
	_loop_playback = _loop_player.get_stream_playback()
	return _loop_playback != null

func play_soft_pop(pitch_scale: float = 1.0) -> void:
	if not _ensure_playback():
		return
	var duration := 0.08
	var total := int(SAMPLE_RATE * duration)
	var freq := 420.0 * pitch_scale
	var phase := 0.0
	for i in range(min(total, _playback.get_frames_available())):
		var t := float(i) / float(total)
		var env := sin(t * PI) * (1.0 - t * 0.5)
		phase += (freq * (1.0 + t * 0.35)) / SAMPLE_RATE
		var sample := sin(phase * TAU) * env * 0.25
		_playback.push_frame(Vector2(sample, sample))

func play_brush_stroke() -> void:
	if not _ensure_loop_playback():
		return
	var total := int(SAMPLE_RATE * 0.09)
	var lp := 0.0
	for i in range(min(total, _loop_playback.get_frames_available())):
		var t := float(i) / float(total)
		var env := sin(t * PI) * 0.24
		var noise := randf_range(-1.0, 1.0)
		lp = lp * 0.72 + noise * 0.28
		var s := (noise - lp) * env
		_loop_playback.push_frame(Vector2(s, s))

func play_clipper_snip() -> void:
	if not _ensure_playback():
		return
	var total := int(SAMPLE_RATE * 0.075)
	var phase := 0.0
	for i in range(min(total, _playback.get_frames_available())):
		var t := float(i) / float(total)
		var env := pow(1.0 - t, 2.2)
		var freq := 1450.0 if t < 0.25 else 880.0
		phase += freq / SAMPLE_RATE
		var click := (1.0 if sin(phase * TAU) > 0.0 else -1.0) * 0.14
		var ring := sin(phase * TAU * 1.5) * 0.22
		var s := (click + ring) * env
		_playback.push_frame(Vector2(s, s))

func play_scissors_snip() -> void:
	if not _ensure_playback():
		return
	var total := int(SAMPLE_RATE * 0.09)
	var phase := 0.0
	for i in range(min(total, _playback.get_frames_available())):
		var t := float(i) / float(total)
		var env := sin(t * PI) * (1.0 - t * 0.6)
		var freq := 1850.0 - t * 650.0
		phase += freq / SAMPLE_RATE
		var scrape := randf_range(-0.18, 0.18) * (1.0 - t)
		var blade := sin(phase * TAU) * 0.18
		var s := (scrape + blade) * env
		_playback.push_frame(Vector2(s, s))

func play_foam_sound() -> void:
	if not _ensure_loop_playback():
		return
	var total := int(SAMPLE_RATE * 0.08)
	var phase := 0.0
	for i in range(min(total, _loop_playback.get_frames_available())):
		var t := float(i) / float(total)
		var env := sin(t * PI) * 0.22
		var pop := sin(phase * TAU) * (1.0 if randf() < 0.18 else 0.2)
		phase += randf_range(650.0, 1400.0) / SAMPLE_RATE
		var s := (pop + randf_range(-0.25, 0.25)) * env
		_loop_playback.push_frame(Vector2(s, s))

func play_water_stream() -> void:
	if not _ensure_loop_playback():
		return
	var total := int(SAMPLE_RATE * 0.07)
	var lp := 0.0
	for i in range(min(total, _loop_playback.get_frames_available())):
		var env := 0.20
		var noise := randf_range(-1.0, 1.0)
		lp = lp * 0.55 + noise * 0.45
		var s := lp * env
		_loop_playback.push_frame(Vector2(s, s))

func play_dryer_hum() -> void:
	if not _ensure_loop_playback():
		return
	var total := int(SAMPLE_RATE * 0.07)
	var phase := 0.0
	var lp := 0.0
	for i in range(min(total, _loop_playback.get_frames_available())):
		phase += 165.0 / SAMPLE_RATE
		var hum := sin(phase * TAU) * 0.12
		var air := randf_range(-1.0, 1.0)
		lp = lp * 0.65 + air * 0.35
		var s := hum + lp * 0.16
		_loop_playback.push_frame(Vector2(s, s))

func play_shiver_sound() -> void:
	if not _ensure_playback():
		return
	var total := int(SAMPLE_RATE * 0.32)
	var phase := 0.0
	for i in range(min(total, _playback.get_frames_available())):
		var t := float(i) / float(total)
		var env := sin(t * PI) * 0.28
		var wobble := sin(t * TAU * 19.0) * 95.0
		var freq := 310.0 + t * 140.0 + wobble
		phase += freq / SAMPLE_RATE
		var s := sin(phase * TAU) * env
		_playback.push_frame(Vector2(s, s))

func play_success() -> void:
	if not _ensure_playback():
		return
	var notes := [523.25, 659.25, 783.99]
	for n in notes:
		var total := int(SAMPLE_RATE * 0.09)
		var phase := 0.0
		for i in range(min(total, _playback.get_frames_available())):
			var t := float(i) / float(total)
			var env := sin(t * PI) * 0.24
			phase += n / SAMPLE_RATE
			var s := sin(phase * TAU) * env
			_playback.push_frame(Vector2(s, s))

func play_stress_tick() -> void:
	if not _ensure_playback():
		return
	var total := int(SAMPLE_RATE * 0.11)
	var phase := 0.0
	for i in range(min(total, _playback.get_frames_available())):
		var t := float(i) / float(total)
		var env := (1.0 - t) * 0.26
		phase += (240.0 - t * 65.0) / SAMPLE_RATE
		var s := (sin(phase * TAU) + sin(phase * TAU * 2.0) * 0.4) * env
		_playback.push_frame(Vector2(s, s))
