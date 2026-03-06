extends Control

enum GameState {
	COUNTDOWN,
	RUNNING,
	PAUSED,
	LEVEL_COMPLETE,
	GAME_OVER,
}

@onready var board_view: BoardView = %BoardView
@onready var hud: HUD = %HUD
@onready var flash_overlay: ColorRect = %FlashOverlay
@onready var dim_overlay: ColorRect = %DimOverlay
@onready var menu_panel: MenuPanel = %MenuPanel
@onready var countdown_label: Label = %CountdownLabel
@onready var end_state_panel: Panel = %EndStatePanel
@onready var end_title_label: Label = %EndTitle
@onready var end_message_label: Label = %EndMessage
@onready var end_actions_label: Label = %EndActions
@onready var audio_hooks: AudioHooks = %AudioHooks

var cursor: Vector2i = Vector2i.ZERO
var level_data: Dictionary = {}
var simulator := SignalSimulator.new()
var step_seconds: float = 0.35
var step_accumulator: float = 0.0
var overload_value: int = 0
var overload_max: int = 20
var objectives: Dictionary = {}
var flash_timer: float = 0.0
var game_state: GameState = GameState.COUNTDOWN
var countdown_remaining: float = 0.0
var countdown_last_tick_second: int = -1
const COUNTDOWN_SECONDS := 3.0
const END_TITLE_PULSE_SPEED := 2.2
const END_TITLE_PULSE_AMOUNT := 0.06
var end_title_pulse_time: float = 0.0

func _ready() -> void:
	menu_panel.item_selected.connect(_on_menu_item_selected)
	_load_current_level()
	_update_board_view()
	_refresh_hud()
	call_deferred("_center_board_in_view")

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		call_deferred("_center_board_in_view")

func _process(delta: float) -> void:
	_update_flash(delta)
	_update_end_state_emphasis(delta)

	if game_state == GameState.COUNTDOWN:
		countdown_remaining = max(countdown_remaining - delta, 0.0)
		_play_countdown_tick_if_needed()
		_update_countdown_visual()
		if countdown_remaining <= 0.0:
			_set_state(GameState.RUNNING)
		_refresh_hud()
		return

	if game_state != GameState.RUNNING:
		return

	step_accumulator += delta
	while step_accumulator >= step_seconds:
		step_accumulator -= step_seconds
		var result: Dictionary = simulator.step()
		var failures: int = int(result.get("failures", 0))
		_play_step_audio_events(result)
		if failures > 0:
			overload_value = min(overload_value + failures, overload_max)
			flash_timer = 0.22
			audio_hooks.play_event("overload_warning")

		if overload_value >= overload_max:
			_set_state(GameState.GAME_OVER)
			audio_hooks.play_event("game_over")
		elif _objectives_met():
			_set_state(GameState.LEVEL_COMPLETE)
			audio_hooks.play_event("level_complete")

		_update_board_view()
		_refresh_hud()

func _input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return

	if event.is_action_pressed("restart_level"):
		GameSession.restart_level()
		_load_current_level()
		accept_event()
		return

	if event.is_action_pressed("pause"):
		if game_state in [GameState.RUNNING, GameState.COUNTDOWN]:
			_set_state(GameState.PAUSED)
		elif game_state == GameState.PAUSED:
			audio_hooks.play_event("menu_back")
			if countdown_remaining > 0.0:
				_set_state(GameState.COUNTDOWN)
			else:
				_set_state(GameState.RUNNING)
		elif game_state in [GameState.LEVEL_COMPLETE, GameState.GAME_OVER]:
			audio_hooks.play_event("menu_back")
			_return_to_level_select()
		accept_event()
		return

	if game_state == GameState.PAUSED:
		_handle_pause_menu_input(event)
		return

	if game_state in [GameState.LEVEL_COMPLETE, GameState.GAME_OVER]:
		_handle_end_state_input(event)
		return

	if game_state not in [GameState.RUNNING, GameState.COUNTDOWN]:
		return

	var moved := false
	if event.is_action_pressed("move_up"):
		cursor.y -= 1
		moved = true
	elif event.is_action_pressed("move_down"):
		cursor.y += 1
		moved = true
	elif event.is_action_pressed("move_left"):
		cursor.x -= 1
		moved = true
	elif event.is_action_pressed("move_right"):
		cursor.x += 1
		moved = true
	elif event.is_action_pressed("interact"):
		var tile_before: Dictionary = simulator.tiles[cursor.y][cursor.x]
		if simulator.move_cursor_interact(cursor):
			var tile_type: String = tile_before.get("type", "empty")
			if tile_type == "gate":
				audio_hooks.play_event("gate_toggle")
			else:
				audio_hooks.play_event("component_rotate")
			_update_board_view()
			_refresh_hud()
		accept_event()
		return

	if moved:
		var width: int = int(level_data.get("width", 1))
		var height: int = int(level_data.get("height", 1))
		cursor.x = clamp(cursor.x, 0, width - 1)
		cursor.y = clamp(cursor.y, 0, height - 1)
		board_view.set_cursor(cursor)
		_refresh_hud()
		accept_event()

func _handle_pause_menu_input(event: InputEvent) -> void:
	var up_pressed := event.is_action_pressed("menu_up") or event.is_action_pressed("ui_up")
	var down_pressed := event.is_action_pressed("menu_down") or event.is_action_pressed("ui_down")
	var confirm_pressed := event.is_action_pressed("menu_confirm") or event.is_action_pressed("ui_accept")
	if event is InputEventKey:
		var key_event := event as InputEventKey
		confirm_pressed = confirm_pressed or key_event.keycode in [KEY_ENTER, KEY_KP_ENTER]

	if up_pressed:
		menu_panel.move_selection(-1)
		audio_hooks.play_event("menu_move")
		accept_event()
	elif down_pressed:
		menu_panel.move_selection(1)
		audio_hooks.play_event("menu_move")
		accept_event()
	elif confirm_pressed:
		audio_hooks.play_event("menu_confirm")
		menu_panel.activate_selected()
		accept_event()
	elif event.is_action_pressed("menu_back"):
		audio_hooks.play_event("menu_back")
		_set_state(GameState.RUNNING)
		accept_event()

func _handle_end_state_input(event: InputEvent) -> void:
	var confirm_pressed := event.is_action_pressed("menu_confirm") or event.is_action_pressed("ui_accept")
	if event is InputEventKey:
		var key_event := event as InputEventKey
		confirm_pressed = confirm_pressed or key_event.keycode in [KEY_ENTER, KEY_KP_ENTER]

	if confirm_pressed:
		audio_hooks.play_event("menu_confirm")
		if game_state == GameState.LEVEL_COMPLETE:
			if GameSession.has_next_level():
				GameSession.advance_level()
				_load_current_level()
			else:
				GameSession.start_new_game()
				_load_current_level()
		elif game_state == GameState.GAME_OVER:
			GameSession.restart_level()
			_load_current_level()
		accept_event()
	elif event.is_action_pressed("menu_back"):
		audio_hooks.play_event("menu_back")
		_return_to_level_select()
		accept_event()

func _load_current_level() -> void:
	var path := GameSession.get_current_level_path()
	level_data = LevelLoader.load_level(path)
	simulator.setup(level_data)
	step_seconds = float(level_data.get("sim_step_seconds", 0.35))
	step_accumulator = 0.0
	overload_max = int(level_data.get("overload_max", 20))
	overload_value = 0
	objectives = level_data.get("objectives", {}).duplicate(true)
	cursor = Vector2i.ZERO
	flash_timer = 0.0
	countdown_remaining = COUNTDOWN_SECONDS
	countdown_last_tick_second = -1
	flash_overlay.color.a = 0.0

	var width: int = int(level_data.get("width", 8))
	var height: int = int(level_data.get("height", 8))
	board_view.configure(width, height)

	_set_state(GameState.COUNTDOWN)
	_play_countdown_tick_if_needed()
	_update_board_view()
	_center_board_in_view()
	_update_countdown_visual()
	_refresh_hud()
	audio_hooks.play_event("level_start")

func _set_state(new_state: GameState) -> void:
	game_state = new_state

	dim_overlay.visible = game_state in [GameState.PAUSED, GameState.LEVEL_COMPLETE, GameState.GAME_OVER]
	menu_panel.visible = game_state == GameState.PAUSED
	end_state_panel.visible = game_state in [GameState.LEVEL_COMPLETE, GameState.GAME_OVER]
	countdown_label.visible = game_state == GameState.COUNTDOWN

	if game_state == GameState.PAUSED:
		menu_panel.set_menu("Paused", [
			{"id": "resume", "label": "Resume"},
			{"id": "restart", "label": "Restart Level"},
			{"id": "main_menu", "label": "Main Menu"},
		])
	elif game_state == GameState.LEVEL_COMPLETE:
		end_title_label.text = "LEVEL COMPLETE"
		end_title_label.modulate = Color(0.98, 1.0, 0.92, 1.0)
		end_message_label.text = "All objectives achieved."
		if GameSession.has_next_level():
			end_actions_label.text = "Enter -> Next Level\nR -> Retry Level\nEsc -> Level Select"
		else:
			end_actions_label.text = "Enter -> Play Again\nR -> Retry Level\nEsc -> Level Select"
		end_title_pulse_time = 0.0
	elif game_state == GameState.GAME_OVER:
		end_title_label.text = "SYSTEM FAILURE"
		end_title_label.modulate = Color(1.0, 0.72, 0.66, 1.0)
		end_message_label.text = "Overload reached maximum."
		end_actions_label.text = "R -> Retry Level\nEsc -> Level Select"
		end_title_pulse_time = 0.0
	elif game_state == GameState.COUNTDOWN:
		_update_countdown_visual()
	else:
		end_state_panel.visible = false

	_refresh_hud()

func _on_menu_item_selected(item_id: String) -> void:
	match item_id:
		"resume":
			_set_state(GameState.RUNNING)
		"restart":
			GameSession.restart_level()
			_load_current_level()
		"next_level":
			GameSession.advance_level()
			_load_current_level()
		"restart_game":
			GameSession.start_new_game()
			_load_current_level()
		"main_menu":
			_return_to_main_menu()

func _return_to_main_menu() -> void:
	get_tree().change_scene_to_file(GameSession.MAIN_MENU_SCENE)

func _return_to_level_select() -> void:
	GameSession.request_level_select_on_main_menu()
	_return_to_main_menu()

func _update_board_view() -> void:
	board_view.set_tiles(simulator.tiles)
	board_view.set_signals(simulator.signals)
	board_view.set_cursor(cursor)

func _center_board_in_view() -> void:
	if board_view == null:
		return

	var board_size := Vector2(
		float(board_view.grid_width * board_view.cell_size),
		float(board_view.grid_height * board_view.cell_size)
	)
	board_view.size = board_size

	var viewport_size: Vector2 = size
	if viewport_size == Vector2.ZERO:
		return

	var centered_position := ((viewport_size - board_size) * 0.5).round()
	board_view.position = centered_position

func _refresh_hud() -> void:
	hud.set_level_name(level_data.get("name", "Level"))
	hud.set_overload(overload_value, overload_max)
	hud.set_objectives(objectives, simulator.delivered)

	var tile: Dictionary = simulator.tiles[cursor.y][cursor.x]
	var status := "Cursor (%d,%d) %s | Space interact | R restart | Esc pause" % [
		cursor.x,
		cursor.y,
		tile.get("type", "empty")
	]
	if game_state == GameState.PAUSED:
		status = "Paused"
	elif game_state == GameState.GAME_OVER:
		status = "System Overload"
	elif game_state == GameState.LEVEL_COMPLETE:
		status = "Level Complete"
	elif game_state == GameState.COUNTDOWN:
		status = "Starting in %d..." % int(ceil(countdown_remaining))
	hud.set_status(status)

func _update_flash(delta: float) -> void:
	if flash_timer > 0.0:
		flash_timer = max(flash_timer - delta, 0.0)
		flash_overlay.color.a = 0.20 * (flash_timer / 0.22)
	else:
		flash_overlay.color.a = 0.0

func _update_end_state_emphasis(delta: float) -> void:
	if not end_state_panel.visible:
		end_title_label.scale = Vector2.ONE
		return

	end_title_pulse_time += delta
	var pulse := 1.0 + END_TITLE_PULSE_AMOUNT * sin(end_title_pulse_time * TAU * END_TITLE_PULSE_SPEED)
	end_title_label.scale = Vector2.ONE * pulse
	end_title_label.pivot_offset = end_title_label.size * 0.5

func _update_countdown_visual() -> void:
	if game_state != GameState.COUNTDOWN:
		countdown_label.visible = false
		return

	var seconds := int(ceil(countdown_remaining))
	seconds = max(seconds, 1)
	var fractional: float = countdown_remaining - floor(countdown_remaining)
	countdown_label.text = str(seconds)
	countdown_label.modulate.a = 0.55 + 0.45 * fractional
	var scale: float = 1.0 + 0.14 * (1.0 - fractional)
	countdown_label.scale = Vector2.ONE * scale
	countdown_label.pivot_offset = countdown_label.size * 0.5
	countdown_label.visible = true

func _play_countdown_tick_if_needed() -> void:
	if game_state != GameState.COUNTDOWN:
		return
	var current_second := int(ceil(countdown_remaining))
	if current_second < 1:
		return
	if current_second != countdown_last_tick_second:
		countdown_last_tick_second = current_second
		audio_hooks.play_event("countdown_tick")

func _play_step_audio_events(result: Dictionary) -> void:
	var events: Array = result.get("events", [])
	for event_data in events:
		if not (event_data is Dictionary):
			continue
		if str(event_data.get("type", "")) == "delivered":
			audio_hooks.play_event("signal_delivered")

func _objectives_met() -> bool:
	for signal_type in objectives.keys():
		var target: int = int(objectives.get(signal_type, 0))
		if target <= 0:
			continue
		var delivered_amount: int = int(simulator.delivered.get(signal_type, 0))
		if delivered_amount < target:
			return false
	return true
