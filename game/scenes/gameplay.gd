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
const OVERLOAD_WARNING_THRESHOLD_RATIO := 0.8
const BOARD_HUD_GAP := 8.0
const BOARD_SIDE_GAP := 12.0
const BOARD_BOTTOM_GAP := 12.0
const BOARD_MIN_SCALE := 0.1
const BOARD_MAX_SCALE := 1.0
const SPEED_MODE_NAMES: Array[String] = ["Slow", "Normal", "Fast"]
const SPEED_MODE_MULTIPLIERS: Array[float] = [0.85, 1.0, 1.2]
const CORRUPTED_SOURCE_HIGHLIGHT_DURATION := 0.34
const CORRUPTED_PURGE_HIGHLIGHT_DURATION := 0.28
var end_title_pulse_time: float = 0.0
var corrupted_source_highlights: Array[Dictionary] = []
var corrupted_purge_highlights: Array[Dictionary] = []
var overload_warning_triggered: bool = false
var speed_mode_index: int = 1
var base_step_seconds: float = 0.35

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
	_update_corrupted_spawn_feedback(delta)
	_update_corrupted_purge_feedback(delta)

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
		var overload_spike: int = int(result.get("overload_spike", 0))
		_play_step_audio_events(result)
		if failures > 0 or overload_spike > 0:
			var previous_overload := overload_value
			overload_value = min(overload_value + failures + overload_spike, overload_max)
			flash_timer = 0.34 if overload_spike > 0 else 0.22
			audio_hooks.play_event("overload")
			if _should_trigger_overload_warning(previous_overload, overload_value):
				overload_warning_triggered = true
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

	if game_state in [GameState.RUNNING, GameState.COUNTDOWN] and event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_Y:
			_adjust_speed_mode(-1)
			accept_event()
			return
		if key_event.keycode == KEY_X:
			_adjust_speed_mode(1)
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
		cursor.x = posmod(cursor.x, max(width, 1))
		cursor.y = posmod(cursor.y, max(height, 1))
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
	base_step_seconds = float(level_data.get("sim_step_seconds", 0.35))
	_apply_speed_mode()
	step_accumulator = 0.0
	overload_max = int(level_data.get("overload_max", 20))
	overload_value = 0
	overload_warning_triggered = false
	objectives = level_data.get("objectives", {}).duplicate(true)
	cursor = Vector2i.ZERO
	flash_timer = 0.0
	corrupted_source_highlights.clear()
	board_view.set_source_highlights([])
	corrupted_purge_highlights.clear()
	board_view.set_purge_highlights([])
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

	var hud_height: float = 0.0
	if hud != null:
		hud_height = hud.get_top_bar_height()

	var available_origin_y: float = hud_height + BOARD_HUD_GAP
	var available_size := Vector2(
		maxf(viewport_size.x - BOARD_SIDE_GAP * 2.0, 1.0),
		maxf(viewport_size.y - available_origin_y - BOARD_BOTTOM_GAP, 1.0)
	)

	var width_fit_scale: float = available_size.x / maxf(board_size.x, 1.0)
	var height_fit_scale: float = available_size.y / maxf(board_size.y, 1.0)
	var fit_scale: float = minf(width_fit_scale, height_fit_scale)
	var board_scale: float = clampf(fit_scale, BOARD_MIN_SCALE, BOARD_MAX_SCALE)
	board_view.scale = Vector2.ONE * board_scale

	var scaled_board_size: Vector2 = board_size * board_scale
	var centered_x: float = (viewport_size.x - scaled_board_size.x) * 0.5
	var centered_y: float = available_origin_y + (available_size.y - scaled_board_size.y) * 0.5
	board_view.position = Vector2(round(centered_x), round(centered_y))

func _refresh_hud() -> void:
	hud.set_level_name(level_data.get("name", "Level"))
	hud.set_speed_mode(SPEED_MODE_NAMES[speed_mode_index])
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

func _should_trigger_overload_warning(previous_value: int, new_value: int) -> bool:
	if overload_warning_triggered or overload_max <= 0:
		return false

	var threshold_value: int = maxi(int(ceil(float(overload_max) * OVERLOAD_WARNING_THRESHOLD_RATIO)), 1)
	return previous_value < threshold_value and new_value >= threshold_value

func _adjust_speed_mode(delta: int) -> void:
	var next_index := clampi(speed_mode_index + delta, 0, SPEED_MODE_NAMES.size() - 1)
	if next_index == speed_mode_index:
		return
	speed_mode_index = next_index
	_apply_speed_mode()
	_refresh_hud()
	audio_hooks.play_event("menu_move")

func _apply_speed_mode() -> void:
	var multiplier: float = SPEED_MODE_MULTIPLIERS[speed_mode_index]
	step_seconds = max(base_step_seconds / multiplier, 0.01)

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
		var event_type := str(event_data.get("type", ""))
		if event_type == "delivered":
			audio_hooks.play_event("signal_delivered")
		elif event_type == "corrupted_spawn":
			audio_hooks.play_event("corrupted_spawn")
			_add_corrupted_source_highlight(
				int(event_data.get("x", -1)),
				int(event_data.get("y", -1))
			)
		elif event_type == "corrupted_purged":
			audio_hooks.play_event("corrupted_purged")
			_add_corrupted_purge_highlight(
				int(event_data.get("x", -1)),
				int(event_data.get("y", -1))
			)
		elif event_type == "corrupted_sink_penalty":
			audio_hooks.play_event("corrupted_penalty")

func _add_corrupted_source_highlight(x: int, y: int) -> void:
	if x < 0 or y < 0:
		return

	for i in range(corrupted_source_highlights.size()):
		var existing: Dictionary = corrupted_source_highlights[i]
		if int(existing.get("x", -1)) == x and int(existing.get("y", -1)) == y:
			existing["timer"] = CORRUPTED_SOURCE_HIGHLIGHT_DURATION
			corrupted_source_highlights[i] = existing
			return

	corrupted_source_highlights.append({
		"x": x,
		"y": y,
		"timer": CORRUPTED_SOURCE_HIGHLIGHT_DURATION,
	})

func _update_corrupted_spawn_feedback(delta: float) -> void:
	if corrupted_source_highlights.is_empty():
		return

	var next_highlights: Array[Dictionary] = []
	var render_highlights: Array[Dictionary] = []

	for entry in corrupted_source_highlights:
		var timer: float = max(float(entry.get("timer", 0.0)) - delta, 0.0)
		if timer <= 0.0:
			continue
		entry["timer"] = timer
		next_highlights.append(entry)
		render_highlights.append({
			"x": int(entry.get("x", -1)),
			"y": int(entry.get("y", -1)),
			"strength": timer / CORRUPTED_SOURCE_HIGHLIGHT_DURATION,
		})

	corrupted_source_highlights = next_highlights
	board_view.set_source_highlights(render_highlights)

func _add_corrupted_purge_highlight(x: int, y: int) -> void:
	if x < 0 or y < 0:
		return

	for i in range(corrupted_purge_highlights.size()):
		var existing: Dictionary = corrupted_purge_highlights[i]
		if int(existing.get("x", -1)) == x and int(existing.get("y", -1)) == y:
			existing["timer"] = CORRUPTED_PURGE_HIGHLIGHT_DURATION
			corrupted_purge_highlights[i] = existing
			return

	corrupted_purge_highlights.append({
		"x": x,
		"y": y,
		"timer": CORRUPTED_PURGE_HIGHLIGHT_DURATION,
	})

func _update_corrupted_purge_feedback(delta: float) -> void:
	if corrupted_purge_highlights.is_empty():
		return

	var next_highlights: Array[Dictionary] = []
	var render_highlights: Array[Dictionary] = []

	for entry in corrupted_purge_highlights:
		var timer: float = max(float(entry.get("timer", 0.0)) - delta, 0.0)
		if timer <= 0.0:
			continue
		entry["timer"] = timer
		next_highlights.append(entry)
		render_highlights.append({
			"x": int(entry.get("x", -1)),
			"y": int(entry.get("y", -1)),
			"strength": timer / CORRUPTED_PURGE_HIGHLIGHT_DURATION,
		})

	corrupted_purge_highlights = next_highlights
	board_view.set_purge_highlights(render_highlights)

func _objectives_met() -> bool:
	for signal_type in objectives.keys():
		var target: int = int(objectives.get(signal_type, 0))
		if target <= 0:
			continue
		var delivered_amount: int = int(simulator.delivered.get(signal_type, 0))
		if delivered_amount < target:
			return false
	return true
