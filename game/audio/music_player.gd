extends Node

const MUSIC_PATH := "res://game/audio/music/gameaudio.mp3"
const DEFAULT_VOLUME_DB := 0.0

var _player: AudioStreamPlayer
var _stream: AudioStream

func _ready() -> void:
	GameSession.ensure_audio_buses()

	if _player == null:
		_player = AudioStreamPlayer.new()
		_player.name = "BackgroundMusicPlayer"
		_player.volume_db = DEFAULT_VOLUME_DB
		_player.bus = GameSession.MUSIC_BUS
		add_child(_player)

	_ensure_stream_loaded()
	_play_if_needed()

func _ensure_stream_loaded() -> void:
	if _stream != null:
		return

	var bytes := FileAccess.get_file_as_bytes(MUSIC_PATH)
	if bytes.is_empty():
		push_warning("Music track could not be loaded: %s" % MUSIC_PATH)
		return
	var mp3_stream := AudioStreamMP3.new()
	mp3_stream.data = bytes
	_stream = mp3_stream

	_enable_loop(_stream)
	_player.stream = _stream

func _enable_loop(stream: AudioStream) -> void:
	if stream is AudioStreamMP3:
		var mp3_stream := stream as AudioStreamMP3
		mp3_stream.loop = true
	elif stream is AudioStreamOggVorbis:
		var ogg_stream := stream as AudioStreamOggVorbis
		ogg_stream.loop = true
	elif stream is AudioStreamWAV:
		var wav_stream := stream as AudioStreamWAV
		wav_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD

func _play_if_needed() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if _player == null or _player.stream == null:
		return
	if _player.playing:
		return
	_player.play()

func _exit_tree() -> void:
	if _player != null:
		_player.stop()
		_player.stream = null
	_stream = null
