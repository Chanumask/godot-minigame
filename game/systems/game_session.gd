extends Node

const GAMEPLAY_SCENE := "res://game/scenes/gameplay.tscn"
const MAIN_MENU_SCENE := "res://game/scenes/main_menu.tscn"
const SFX_BUS := "SFX"
const MUSIC_BUS := "Music"
const MIN_VOLUME_PERCENT := 0
const MAX_VOLUME_PERCENT := 100
const MUTE_DB := -80.0
const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION_DISPLAY := "display"
const SETTINGS_SECTION_AUDIO := "audio"
const SETTINGS_KEY_RESOLUTION_INDEX := "resolution_index"
const SETTINGS_KEY_SFX_VOLUME := "sfx_volume"
const SETTINGS_KEY_MUSIC_VOLUME := "music_volume"

static var level_paths: Array[String] = [
	"res://game/levels/level_01.json",
	"res://game/levels/level_02.json",
	"res://game/levels/level_03.json",
	"res://game/levels/level_04.json",
	"res://game/levels/level_05.json",
	"res://game/levels/level_06.json",
	"res://game/levels/level_07.json",
]

static var current_level_index: int = 0
static var resolution_presets: Array[Dictionary] = [
	{"label": "1024 x 576", "size": Vector2i(1024, 576)},
	{"label": "1280 x 720", "size": Vector2i(1280, 720)},
	{"label": "1600 x 900", "size": Vector2i(1600, 900)},
]
static var current_resolution_index: int = 1
static var sfx_volume_percent: int = 75
static var music_volume_percent: int = 35
static var _audio_buses_initialized: bool = false
static var _settings_loaded: bool = false
static var _open_level_select_on_menu: bool = false

func _ready() -> void:
	load_settings()

static func start_new_game() -> void:
	current_level_index = 0

static func get_current_level_path() -> String:
	if current_level_index < 0 or current_level_index >= level_paths.size():
		return level_paths[0]
	return level_paths[current_level_index]

static func set_current_level_index(index: int) -> void:
	current_level_index = clampi(index, 0, level_paths.size() - 1)

static func has_next_level() -> bool:
	return current_level_index < level_paths.size() - 1

static func advance_level() -> void:
	if has_next_level():
		current_level_index += 1

static func restart_level() -> void:
	current_level_index = clampi(current_level_index, 0, level_paths.size() - 1)

static func get_resolution_presets() -> Array[Dictionary]:
	return resolution_presets

static func get_current_resolution_index() -> int:
	return clampi(current_resolution_index, 0, resolution_presets.size() - 1)

static func get_sfx_volume_percent() -> int:
	return clampi(sfx_volume_percent, MIN_VOLUME_PERCENT, MAX_VOLUME_PERCENT)

static func get_music_volume_percent() -> int:
	return clampi(music_volume_percent, MIN_VOLUME_PERCENT, MAX_VOLUME_PERCENT)

static func change_sfx_volume(delta_percent: int) -> void:
	set_sfx_volume(get_sfx_volume_percent() + delta_percent)

static func change_music_volume(delta_percent: int) -> void:
	set_music_volume(get_music_volume_percent() + delta_percent)

static func set_sfx_volume(percent: int) -> void:
	sfx_volume_percent = clampi(percent, MIN_VOLUME_PERCENT, MAX_VOLUME_PERCENT)
	ensure_audio_buses()
	_apply_bus_volume(SFX_BUS, sfx_volume_percent)
	save_settings()

static func set_music_volume(percent: int) -> void:
	music_volume_percent = clampi(percent, MIN_VOLUME_PERCENT, MAX_VOLUME_PERCENT)
	ensure_audio_buses()
	_apply_bus_volume(MUSIC_BUS, music_volume_percent)
	save_settings()

static func apply_resolution(index: int) -> void:
	current_resolution_index = clampi(index, 0, resolution_presets.size() - 1)
	_apply_resolution_windowed(true)
	save_settings()

static func _apply_resolution_windowed(show_unavailable_warning: bool) -> void:
	if OS.has_feature("editor") or _is_embedded_editor_window():
		if show_unavailable_warning:
			push_warning("Resolution changes are unavailable while running from the editor. Use a standalone game run.")
		return

	var target_size: Vector2i = resolution_presets[get_current_resolution_index()]["size"]
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(target_size)

	var screen := DisplayServer.window_get_current_screen()
	var screen_size := DisplayServer.screen_get_size(screen)
	var target_pos := (screen_size - target_size) / 2
	DisplayServer.window_set_position(target_pos)

static func _is_embedded_editor_window() -> bool:
	var main_loop := Engine.get_main_loop()
	if not (main_loop is SceneTree):
		return false

	var scene_tree := main_loop as SceneTree
	if scene_tree.root == null:
		return false

	var main_window := scene_tree.root.get_window()
	return main_window != null and main_window.is_embedded()

static func ensure_audio_buses() -> void:
	if _audio_buses_initialized:
		return

	_ensure_bus_exists(SFX_BUS)
	_ensure_bus_exists(MUSIC_BUS)
	_audio_buses_initialized = true

	_apply_bus_volume(SFX_BUS, sfx_volume_percent)
	_apply_bus_volume(MUSIC_BUS, music_volume_percent)

static func _ensure_bus_exists(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return

	var new_index := AudioServer.get_bus_count()
	AudioServer.add_bus(new_index)
	AudioServer.set_bus_name(new_index, bus_name)
	AudioServer.set_bus_send(new_index, "Master")

static func _apply_bus_volume(bus_name: String, percent: int) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		return

	var clamped_percent: int = clampi(percent, MIN_VOLUME_PERCENT, MAX_VOLUME_PERCENT)
	if clamped_percent <= MIN_VOLUME_PERCENT:
		AudioServer.set_bus_volume_db(bus_index, MUTE_DB)
		return

	var linear := float(clamped_percent) / float(MAX_VOLUME_PERCENT)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(linear))

static func load_settings() -> void:
	if _settings_loaded:
		return

	var cfg := ConfigFile.new()
	var err := cfg.load(SETTINGS_PATH)

	if err == OK:
		current_resolution_index = clampi(
			int(cfg.get_value(SETTINGS_SECTION_DISPLAY, SETTINGS_KEY_RESOLUTION_INDEX, current_resolution_index)),
			0,
			resolution_presets.size() - 1
		)
		sfx_volume_percent = clampi(
			int(cfg.get_value(SETTINGS_SECTION_AUDIO, SETTINGS_KEY_SFX_VOLUME, sfx_volume_percent)),
			MIN_VOLUME_PERCENT,
			MAX_VOLUME_PERCENT
		)
		music_volume_percent = clampi(
			int(cfg.get_value(SETTINGS_SECTION_AUDIO, SETTINGS_KEY_MUSIC_VOLUME, music_volume_percent)),
			MIN_VOLUME_PERCENT,
			MAX_VOLUME_PERCENT
		)
	elif err != ERR_FILE_NOT_FOUND:
		push_warning("Failed to load settings file: %s (error %d)" % [SETTINGS_PATH, err])

	ensure_audio_buses()
	_apply_bus_volume(SFX_BUS, sfx_volume_percent)
	_apply_bus_volume(MUSIC_BUS, music_volume_percent)
	_apply_resolution_windowed(false)

	_settings_loaded = true
	if err == ERR_FILE_NOT_FOUND:
		save_settings()

static func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SETTINGS_SECTION_DISPLAY, SETTINGS_KEY_RESOLUTION_INDEX, get_current_resolution_index())
	cfg.set_value(SETTINGS_SECTION_AUDIO, SETTINGS_KEY_SFX_VOLUME, get_sfx_volume_percent())
	cfg.set_value(SETTINGS_SECTION_AUDIO, SETTINGS_KEY_MUSIC_VOLUME, get_music_volume_percent())

	var err := cfg.save(SETTINGS_PATH)
	if err != OK:
		push_warning("Failed to save settings file: %s (error %d)" % [SETTINGS_PATH, err])

static func request_level_select_on_main_menu() -> void:
	_open_level_select_on_menu = true

static func consume_level_select_on_main_menu() -> bool:
	var should_open_level_select := _open_level_select_on_menu
	_open_level_select_on_menu = false
	return should_open_level_select
