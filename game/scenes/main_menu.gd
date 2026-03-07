extends Control

enum MenuMode {
	MAIN,
	LEVEL_SELECT,
	SETTINGS,
	HOW_TO_PLAY,
}
const VOLUME_STEP_PERCENT := 5
const VOLUME_BAR_SEGMENTS := 10

const HOW_TO_PAGES: Array[Dictionary] = [
	{
		"title": "Objective",
		"body": "- Route signals through the network.\n- Red signals go to red sinks.\n- Blue signals go to blue sinks.\n- Avoid increasing the overload meter.",
	},
	{
		"title": "Controls and Components",
		"body": "Move cursor: Arrow keys / WASD\nInteract: Space\nRestart: R\nPause: Esc\nSpeed: Y slow down, X speed up\n\nWires route signals.\nGates redirect signals.\nSplitters alternate outputs.",
	},
	{
		"title": "Corrupted Signals",
		"body": "Some sources occasionally emit corrupted packets.\nCorrupted packets must be routed to PURGE SINKS.\nIf corrupted packets enter a normal sink, a large overload spike occurs.",
	},
]

const MENU_DEFAULT_OFFSETS := {
	"left": -320.0,
	"top": -150.0,
	"right": 320.0,
	"bottom": 290.0,
}

@onready var menu_panel: MenuPanel = %MenuPanel
@onready var how_to_panel: Control = %HowToPanel
@onready var how_to_title_label: Label = %HowToTitle
@onready var how_to_page_label: Label = %HowToPage
@onready var how_to_text_label: Label = %HowToText
@onready var audio_hooks: AudioHooks = %AudioHooks

var menu_mode: MenuMode = MenuMode.MAIN
var how_to_page_index: int = 0

func _ready() -> void:
	menu_panel.item_selected.connect(_on_menu_item_selected)
	if GameSession.consume_level_select_on_main_menu():
		_show_level_select_menu()
	else:
		_show_main_menu()

func _input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return

	var confirm_pressed := event.is_action_pressed("menu_confirm") or event.is_action_pressed("ui_accept")
	var up_pressed := event.is_action_pressed("menu_up") or event.is_action_pressed("ui_up")
	var down_pressed := event.is_action_pressed("menu_down") or event.is_action_pressed("ui_down")
	var left_pressed := (
		event.is_action_pressed("move_left")
		or event.is_action_pressed("ui_left")
	)
	var right_pressed := (
		event.is_action_pressed("move_right")
		or event.is_action_pressed("ui_right")
	)
	if event is InputEventKey:
		var key_event := event as InputEventKey
		confirm_pressed = confirm_pressed or key_event.keycode in [KEY_ENTER, KEY_KP_ENTER]

	if menu_mode == MenuMode.HOW_TO_PLAY:
		if left_pressed:
			_change_how_to_page(-1)
			accept_event()
		elif right_pressed:
			_change_how_to_page(1)
			accept_event()
		elif event.is_action_pressed("menu_back"):
			audio_hooks.play_event("menu_back")
			_show_main_menu()
			accept_event()
		return

	if up_pressed:
		menu_panel.move_selection(-1)
		audio_hooks.play_event("menu_move")
		accept_event()
	elif down_pressed:
		menu_panel.move_selection(1)
		audio_hooks.play_event("menu_move")
		accept_event()
	elif left_pressed:
		if _adjust_selected_setting(-1):
			audio_hooks.play_event("menu_move")
			accept_event()
	elif right_pressed:
		if _adjust_selected_setting(1):
			audio_hooks.play_event("menu_move")
			accept_event()
	elif confirm_pressed:
		audio_hooks.play_event("menu_confirm")
		menu_panel.activate_selected()
		accept_event()
	elif event.is_action_pressed("menu_back"):
		audio_hooks.play_event("menu_back")
		if menu_mode == MenuMode.MAIN:
			get_tree().quit()
		else:
			_show_main_menu()
		accept_event()

func _on_menu_item_selected(item_id: String) -> void:
	if item_id == "start":
		GameSession.start_new_game()
		get_tree().change_scene_to_file(GameSession.GAMEPLAY_SCENE)
	elif item_id == "level_select":
		_show_level_select_menu()
	elif item_id == "settings":
		_show_settings_menu()
	elif item_id == "how_to_play":
		_show_how_to_play()
	elif item_id == "sfx_volume":
		GameSession.change_sfx_volume(VOLUME_STEP_PERCENT)
		_show_settings_menu(menu_panel.get_selected_index())
	elif item_id == "music_volume":
		GameSession.change_music_volume(VOLUME_STEP_PERCENT)
		_show_settings_menu(menu_panel.get_selected_index())
	elif item_id.begins_with("level_"):
		var level_index := item_id.trim_prefix("level_").to_int()
		GameSession.set_current_level_index(level_index)
		get_tree().change_scene_to_file(GameSession.GAMEPLAY_SCENE)
	elif item_id.begins_with("resolution_"):
		var resolution_index := item_id.trim_prefix("resolution_").to_int()
		var selected_index := menu_panel.get_selected_index()
		GameSession.apply_resolution(resolution_index)
		_show_settings_menu(selected_index)
	elif item_id == "back":
		_show_main_menu()
	elif item_id == "quit":
		get_tree().quit()

func _show_main_menu() -> void:
	menu_mode = MenuMode.MAIN
	menu_panel.visible = true
	how_to_panel.visible = false
	_set_menu_offsets(MENU_DEFAULT_OFFSETS)
	menu_panel.set_menu("", [
		{"id": "start", "label": "Start Game"},
		{"id": "level_select", "label": "Level Select"},
		{"id": "settings", "label": "Settings"},
		{"id": "how_to_play", "label": "How To Play"},
		{"id": "quit", "label": "Quit"},
	])

func _show_level_select_menu() -> void:
	menu_mode = MenuMode.LEVEL_SELECT
	menu_panel.visible = true
	how_to_panel.visible = false
	_set_menu_offsets(MENU_DEFAULT_OFFSETS)

	var items: Array[Dictionary] = []
	for index in range(GameSession.level_paths.size()):
		var level_path := GameSession.level_paths[index]
		var level_data := LevelLoader.load_level(level_path)
		var level_name := str(level_data.get("name", "Level %d" % (index + 1)))
		items.append({
			"id": "level_%d" % index,
			"label": "%d. %s" % [index + 1, level_name],
		})

	items.append({"id": "back", "label": "Back"})
	menu_panel.set_menu("Level Select", items)

func _show_settings_menu(preferred_selection_index: int = 0) -> void:
	menu_mode = MenuMode.SETTINGS
	menu_panel.visible = true
	how_to_panel.visible = false
	_set_menu_offsets(MENU_DEFAULT_OFFSETS)

	var items: Array[Dictionary] = []
	items.append({
		"id": "sfx_volume",
		"label": "SFX Volume: %s" % _format_slider(GameSession.get_sfx_volume_percent()),
	})
	items.append({
		"id": "music_volume",
		"label": "Music Volume: %s" % _format_slider(GameSession.get_music_volume_percent()),
	})

	var presets := GameSession.get_resolution_presets()
	var selected_index := GameSession.get_current_resolution_index()

	for index in range(presets.size()):
		var preset: Dictionary = presets[index]
		var marker := "[X]" if index == selected_index else "[ ]"
		items.append({
			"id": "resolution_%d" % index,
			"label": "%s %s" % [marker, str(preset.get("label", ""))],
		})

	items.append({"id": "back", "label": "Back"})
	menu_panel.set_menu("Settings", items)
	menu_panel.set_selected_index(preferred_selection_index)

func _show_how_to_play() -> void:
	menu_mode = MenuMode.HOW_TO_PLAY
	menu_panel.visible = false
	how_to_panel.visible = true
	how_to_page_index = 0
	_update_how_to_page()

func _set_menu_offsets(offsets: Dictionary) -> void:
	menu_panel.offset_left = float(offsets.get("left", -250.0))
	menu_panel.offset_top = float(offsets.get("top", -170.0))
	menu_panel.offset_right = float(offsets.get("right", 250.0))
	menu_panel.offset_bottom = float(offsets.get("bottom", 170.0))

func _adjust_selected_setting(direction: int) -> bool:
	if menu_mode != MenuMode.SETTINGS:
		return false

	var selected_id := menu_panel.get_selected_item_id()
	var selected_index := menu_panel.get_selected_index()

	if selected_id == "sfx_volume":
		GameSession.change_sfx_volume(direction * VOLUME_STEP_PERCENT)
		_show_settings_menu(selected_index)
		return true
	if selected_id == "music_volume":
		GameSession.change_music_volume(direction * VOLUME_STEP_PERCENT)
		_show_settings_menu(selected_index)
		return true
	return false

func _format_slider(percent: int) -> String:
	var clamped_percent: int = clampi(percent, 0, 100)
	var filled_segments := int(round(float(clamped_percent) / 100.0 * VOLUME_BAR_SEGMENTS))
	var bar := ""
	for i in range(VOLUME_BAR_SEGMENTS):
		bar += "#" if i < filled_segments else "-"
	return "[%s] %d%%" % [bar, clamped_percent]

func _change_how_to_page(delta: int) -> void:
	if HOW_TO_PAGES.is_empty():
		return
	var next_index := clampi(how_to_page_index + delta, 0, HOW_TO_PAGES.size() - 1)
	if next_index == how_to_page_index:
		return
	how_to_page_index = next_index
	audio_hooks.play_event("menu_move")
	_update_how_to_page()

func _update_how_to_page() -> void:
	if HOW_TO_PAGES.is_empty():
		return

	how_to_page_index = clampi(how_to_page_index, 0, HOW_TO_PAGES.size() - 1)
	var page: Dictionary = HOW_TO_PAGES[how_to_page_index]
	how_to_title_label.text = str(page.get("title", "How To Play"))
	how_to_page_label.text = "Page %d / %d" % [how_to_page_index + 1, HOW_TO_PAGES.size()]
	how_to_text_label.text = str(page.get("body", ""))
