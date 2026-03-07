extends Node
class_name AudioHooks

signal sound_event_requested(event_name: String)

const PLAYER_COUNT := 8
const STREAM_PATHS := {
	"ui_click": "res://game/audio/sfx/ui_click.mp3",
	"confirm": "res://game/audio/sfx/confirm.mp3",
	"signal_delivered": "res://game/audio/sfx/signal_delivered.mp3",
	"overload": "res://game/audio/sfx/overload.mp3",
	"overload_warning": "res://game/audio/sfx/overload_warning.mp3",
	"corrupted_spawn": "res://game/audio/sfx/corrupted_spawn.mp3",
	"countdown_tick": "res://game/audio/sfx/countdown_tick.mp3",
	"level_complete": "res://game/audio/sfx/level_complete.mp3",
	"game_over": "res://game/audio/sfx/game_over.mp3",
}

const EVENT_STREAM_KEYS := {
	"menu_move": "ui_click",
	"menu_confirm": "confirm",
	"menu_back": "ui_click",
	"component_rotate": "ui_click",
	"gate_toggle": "ui_click",
	"signal_delivered": "signal_delivered",
	"corrupted_purged": "signal_delivered",
	"overload": "overload",
	"overload_warning": "overload_warning",
	"corrupted_penalty": "overload",
	"corrupted_spawn": "corrupted_spawn",
	"countdown_tick": "countdown_tick",
	"level_complete": "level_complete",
	"game_over": "game_over",
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
	_load_streams()

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

func _load_streams() -> void:
	var loaded_streams := {}
	for stream_key in STREAM_PATHS.keys():
		loaded_streams[stream_key] = _load_mp3_stream(str(STREAM_PATHS[stream_key]))

	for event_name in EVENT_STREAM_KEYS.keys():
		var stream_key := str(EVENT_STREAM_KEYS[event_name])
		_stream_cache[event_name] = loaded_streams.get(stream_key, null)

func _load_mp3_stream(path: String) -> AudioStream:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		push_warning("SFX file missing or unreadable: %s" % path)
		return null

	var stream := AudioStreamMP3.new()
	stream.data = bytes
	return stream
