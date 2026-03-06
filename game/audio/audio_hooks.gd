extends Node
class_name AudioHooks

signal sound_event_requested(event_name: String)

const SAMPLE_RATE := 44100
const PLAYER_COUNT := 8
const MENU_MOVE_SFX_PATH := "res://game/audio/sfx/ui_click.mp3"
const MENU_CONFIRM_SFX_PATH := "res://game/audio/sfx/confirm.mp3"

const EVENT_CONFIG := {
	"menu_back": {"freq": 420.0, "duration": 0.08, "amp": 0.22},
	"countdown_tick": {"freq": 680.0, "duration": 0.07, "amp": 0.24},
	"signal_delivered": {"freq": 900.0, "duration": 0.06, "amp": 0.24},
	"overload_warning": {"freq": 190.0, "duration": 0.12, "amp": 0.27},
	"level_complete": {"freq": 980.0, "duration": 0.20, "amp": 0.28},
	"game_over": {"freq": 140.0, "duration": 0.25, "amp": 0.30},
	"component_rotate": {"freq": 610.0, "duration": 0.05, "amp": 0.20},
	"gate_toggle": {"freq": 500.0, "duration": 0.07, "amp": 0.22},
}

var _players: Array[AudioStreamPlayer] = []
var _next_player_index: int = 0
var _stream_cache: Dictionary = {}

func _ready() -> void:
	GameSession.ensure_audio_buses()

	for i in range(PLAYER_COUNT):
		var player := AudioStreamPlayer.new()
		player.name = "SfxPlayer%d" % i
		player.bus = GameSession.SFX_BUS
		add_child(player)
		_players.append(player)

	_load_menu_ui_streams()

	for event_name in EVENT_CONFIG.keys():
		var cfg: Dictionary = EVENT_CONFIG[event_name]
		_stream_cache[event_name] = _create_beep_stream(
			float(cfg.get("freq", 440.0)),
			float(cfg.get("duration", 0.08)),
			float(cfg.get("amp", 0.2))
		)

func play_event(event_name: String) -> void:
	sound_event_requested.emit(event_name)

	if not _stream_cache.has(event_name) or _players.is_empty():
		return

	var stream: AudioStream = _stream_cache[event_name]
	if stream == null:
		return

	var player := _players[_next_player_index]
	_next_player_index = (_next_player_index + 1) % _players.size()
	player.stream = stream
	player.play()

func _load_menu_ui_streams() -> void:
	_stream_cache["menu_move"] = _load_mp3_stream(MENU_MOVE_SFX_PATH)
	_stream_cache["menu_confirm"] = _load_mp3_stream(MENU_CONFIRM_SFX_PATH)

func _load_mp3_stream(path: String) -> AudioStream:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		push_warning("SFX file missing or unreadable: %s" % path)
		return null

	var stream := AudioStreamMP3.new()
	stream.data = bytes
	return stream

func _create_beep_stream(freq: float, duration: float, amplitude: float) -> AudioStreamWAV:
	var sample_count: int = max(int(SAMPLE_RATE * duration), 1)
	var data := PackedByteArray()
	data.resize(sample_count * 2)

	for i in range(sample_count):
		var t := float(i) / SAMPLE_RATE
		var wave := sin(TAU * freq * t)
		var envelope := _envelope(i, sample_count)
		var value := int(clamp(wave * amplitude * envelope, -1.0, 1.0) * 32767.0)
		data[i * 2] = value & 0xFF
		data[i * 2 + 1] = (value >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = data
	return stream

func _envelope(index: int, total: int) -> float:
	if total <= 1:
		return 1.0
	var edge: int = max(int(total * 0.10), 1)
	if index < edge:
		return float(index) / float(edge)
	if index > total - edge:
		return float(total - index) / float(edge)
	return 1.0
