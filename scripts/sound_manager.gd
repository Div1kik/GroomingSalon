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
	gen.buffer_length = 0.5
	_player.stream = gen
	_player.volume_db = -6.0
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback()

	_loop_player = AudioStreamPlayer.new()
	var loop_gen := AudioStreamGenerator.new()
	loop_gen.mix_rate = SAMPLE_RATE
	loop_gen.buffer_length = 0.4
	_loop_player.stream = loop_gen
	_loop_player.volume_db = -10.0
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

func play_door_bell() -> void:
	if not _ensure_playback():
		return
	var notes := [987.77, 1318.51]
	for idx in range(notes.size()):
		var freq: float = notes[idx]
		var total := int(SAMPLE_RATE * 0.16)
		var phase := 0.0
		for i in range(min(total, _playback.get_frames_available())):
			var t := float(i) / float(total)
			var env := exp(-t * 4.5) * sin(min(1.0, t * 18.0) * PI * 0.5) * 0.24
			phase += freq / SAMPLE_RATE
			var s := (sin(phase * TAU) + sin(phase * TAU * 2.0) * 0.28) * env
			_playback.push_frame(Vector2(s, s))

func play_purr() -> void:
	if not _ensure_loop_playback():
		return
	var total := int(SAMPLE_RATE * 0.14)
	var phase := 0.0
	for i in range(min(total, _loop_playback.get_frames_available())):
		var t := float(i) / float(total)
		var env := sin(t * PI) * 0.22
		var rumble := sin(t * TAU * 26.0) * 0.5 + 0.5
		phase += 58.0 / SAMPLE_RATE
		var s := sin(phase * TAU) * (0.4 + rumble * 0.6) * env
		_loop_playback.push_frame(Vector2(s, s))

func play_soft_pop(pitch_scale: float = 1.0) -> void:
	if not _ensure_playback():
		return
	var duration := 0.085
	var total := int(SAMPLE_RATE * duration)
	var freq := 440.0 * pitch_scale
	var phase := 0.0
	for i in range(min(total, _playback.get_frames_available())):
		var t := float(i) / float(total)
		var env := sin(t * PI) * (1.0 - t * 0.45)
		phase += (freq * (1.0 + t * 0.42)) / SAMPLE_RATE
		var sample := sin(phase * TAU) * env * 0.24
		_playback.push_frame(Vector2(sample, sample))

func play_brush_stroke() -> void:
	if not _ensure_loop_playback():
		return
	var total := int(SAMPLE_RATE * 0.10)
	var lp := 0.0
	for i in range(min(total, _loop_playback.get_frames_available())):
		var t := float(i) / float(total)
		var env := sin(t * PI) * 0.26
		var noise := randf_range(-1.0, 1.0)
		lp = lp * 0.76 + noise * 0.24
		var s := (noise - lp) * env
		_loop_playback.push_frame(Vector2(s, s))

func play_clipper_snip() -> void:
	if not _ensure_playback():
		return
	var total := int(SAMPLE_RATE * 0.085)
	var phase := 0.0
	for i in range(min(total, _playback.get_frames_available())):
		var t := float(i) / float(total)
		var env := pow(1.0 - t, 2.0)
		var freq := 1620.0 if t < 0.22 else 920.0
		phase += freq / SAMPLE_RATE
		var snap := (1.0 if sin(phase * TAU) > 0.0 else -1.0) * 0.14
		var body := sin(phase * TAU * 1.5) * 0.24
		var s := (snap + body) * env
		_playback.push_frame(Vector2(s, s))

func play_scissors_snip() -> void:
	if not _ensure_playback():
		return
	var total := int(SAMPLE_RATE * 0.10)
	var phase := 0.0
	for i in range(min(total, _playback.get_frames_available())):
		var t := float(i) / float(total)
		var env := sin(t * PI) * (1.0 - t * 0.5)
		var freq := 2100.0 - t * 850.0
		phase += freq / SAMPLE_RATE
		var steel := randf_range(-0.18, 0.18) * (1.0 - t)
		var ring := sin(phase * TAU) * 0.20
		var s := (steel + ring) * env
		_playback.push_frame(Vector2(s, s))

func play_foam_sound() -> void:
	if not _ensure_loop_playback():
		return
	var total := int(SAMPLE_RATE * 0.09)
	var phase := 0.0
	for i in range(min(total, _loop_playback.get_frames_available())):
		var t := float(i) / float(total)
		var env := sin(t * PI) * 0.24
		var bubble := sin(phase * TAU) * (1.0 if randf() < 0.24 else 0.15)
		phase += randf_range(750.0, 1650.0) / SAMPLE_RATE
		var s := (bubble + randf_range(-0.22, 0.22)) * env
		_loop_playback.push_frame(Vector2(s, s))

func play_water_stream() -> void:
	if not _ensure_loop_playback():
		return
	var total := int(SAMPLE_RATE * 0.08)
	var lp1 := 0.0
	var lp2 := 0.0
	for i in range(min(total, _loop_playback.get_frames_available())):
		var noise := randf_range(-1.0, 1.0)
		lp1 = lp1 * 0.62 + noise * 0.38
		lp2 = lp2 * 0.85 + lp1 * 0.15
		var s := (lp1 * 0.65 + lp2 * 0.35) * 0.24
		_loop_playback.push_frame(Vector2(s, s))

func play_dryer_hum() -> void:
	if not _ensure_loop_playback():
		return
	var total := int(SAMPLE_RATE * 0.08)
	var phase := 0.0
	var lp := 0.0
	for i in range(min(total, _loop_playback.get_frames_available())):
		phase += 155.0 / SAMPLE_RATE
		var turbine := (sin(phase * TAU) + sin(phase * TAU * 2.0) * 0.45) * 0.11
		var air := randf_range(-1.0, 1.0)
		lp = lp * 0.68 + air * 0.32
		var s := turbine + lp * 0.18
		_loop_playback.push_frame(Vector2(s, s))

func play_shiver_sound() -> void:
	if not _ensure_playback():
		return
	var total := int(SAMPLE_RATE * 0.36)
	var phase := 0.0
	for i in range(min(total, _playback.get_frames_available())):
		var t := float(i) / float(total)
		var env := sin(t * PI) * 0.30
		var wobble := sin(t * TAU * 21.0) * 105.0
		var freq := 290.0 + t * 160.0 + wobble
		phase += freq / SAMPLE_RATE
		var s := sin(phase * TAU) * env
		_playback.push_frame(Vector2(s, s))

func play_success() -> void:
	if not _ensure_playback():
		return
	var notes := [523.25, 659.25, 783.99, 1046.50]
	for n in notes:
		var total := int(SAMPLE_RATE * 0.08)
		var phase := 0.0
		for i in range(min(total, _playback.get_frames_available())):
			var t := float(i) / float(total)
			var env := sin(t * PI) * 0.22
			phase += n / SAMPLE_RATE
			var s := sin(phase * TAU) * env
			_playback.push_frame(Vector2(s, s))

func play_stress_tick() -> void:
	if not _ensure_playback():
		return
	var total := int(SAMPLE_RATE * 0.12)
	var phase := 0.0
	for i in range(min(total, _playback.get_frames_available())):
		var t := float(i) / float(total)
		var env := (1.0 - t) * 0.26
		phase += (235.0 - t * 65.0) / SAMPLE_RATE
		var s := (sin(phase * TAU) + sin(phase * TAU * 2.0) * 0.4) * env
		_playback.push_frame(Vector2(s, s))
