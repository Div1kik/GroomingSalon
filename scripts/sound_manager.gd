extends Node
class_name SoundManager

var muted: bool = false
var _music_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _note_timer: float = 0.0
var _step_index: int = 0

# Мягкие ноты в тональности До-мажор / пентатоника для спокойного саундтрека
const CHORD_FREQS: Array[float] = [261.63, 329.63, 392.00, 493.88, 523.25, 392.00, 329.63, 293.66]

func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "AmbientMusic"
	_music_player.volume_db = -18.0
	add_child(_music_player)

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.name = "SfxPlayer"
	_sfx_player.volume_db = -10.0
	add_child(_sfx_player)

	_play_ambient_step()

func _process(delta: float) -> void:
	if muted:
		return
	_note_timer += delta
	if _note_timer >= 1.35:
		_note_timer = 0.0
		_step_index = (_step_index + 1) % CHORD_FREQS.size()
		_play_ambient_step()

func toggle_mute() -> void:
	muted = not muted
	_music_player.stream_paused = muted

func _play_ambient_step() -> void:
	if muted:
		return
	var freq: float = CHORD_FREQS[_step_index]
	_music_player.stream = _make_soft_tone(freq, 1.45, 0.14)
	_music_player.play()

func play_soft_pop(pitch_scale: float = 1.0) -> void:
	if muted:
		return
	_sfx_player.stream = _make_soft_tone(520.0 * pitch_scale, 0.12, 0.22)
	_sfx_player.play()

func play_success() -> void:
	if muted:
		return
	_sfx_player.stream = _make_soft_tone(659.25, 0.24, 0.25)
	_sfx_player.play()

func play_stress_tick() -> void:
	if muted:
		return
	_sfx_player.stream = _make_soft_tone(220.0, 0.10, 0.15)
	_sfx_player.play()

func _make_soft_tone(freq: float, duration: float, amp: float) -> AudioStreamWAV:
	var mix_rate: int = 22050
	var samples: int = int(mix_rate * duration)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false

	var data := PackedByteArray()
	data.resize(samples * 2)

	for i in range(samples):
		var t: float = float(i) / float(mix_rate)
		var env: float = sin(PI * clamp(t / duration, 0.0, 1.0))
		env = pow(env, 1.6)
		# Мягкий синус + лёгкий обертон
		var s: float = (sin(TAU * freq * t) * 0.78 + sin(TAU * freq * 2.0 * t) * 0.22) * env * amp
		var pcm: int = int(clamp(s, -1.0, 1.0) * 32767.0)
		data[i * 2] = pcm & 0xFF
		data[i * 2 + 1] = (pcm >> 8) & 0xFF

	wav.data = data
	return wav
