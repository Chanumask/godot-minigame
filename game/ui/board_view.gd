extends Control
class_name BoardView

const TYPE_COLORS := {
	"empty": Color(0.10, 0.11, 0.14),
	"wall": Color(0.20, 0.20, 0.23),
	"straight_wire": Color(0.13, 0.15, 0.20),
	"corner_wire": Color(0.13, 0.15, 0.20),
	"source": Color(0.11, 0.16, 0.19),
	"sink": Color(0.14, 0.12, 0.18),
	"purge_sink": Color(0.18, 0.11, 0.08),
	"gate": Color(0.17, 0.14, 0.10),
	"splitter": Color(0.10, 0.16, 0.12),
}
const SIGNAL_COLORS := {
	"blue": Color(0.20, 0.72, 1.0),
	"red": Color(1.0, 0.35, 0.35),
	"corrupted": Color(1.0, 0.64, 0.20),
}
const SYMBOL_DARK := Color(0.06, 0.07, 0.09, 0.96)
const SYMBOL_LIGHT := Color(0.96, 0.97, 1.0, 0.96)

var grid_width: int = 8
var grid_height: int = 8
var cell_size: int = 64
var cursor_pos: Vector2i = Vector2i.ZERO
var tiles: Array = []
var signals: Array = []
var source_highlights: Array = []
var purge_highlights: Array = []

func configure(width: int, height: int, new_cell_size: int = 64) -> void:
	grid_width = max(width, 1)
	grid_height = max(height, 1)
	cell_size = max(new_cell_size, 16)
	custom_minimum_size = Vector2(grid_width * cell_size, grid_height * cell_size)
	queue_redraw()

func set_tiles(new_tiles: Array) -> void:
	tiles = new_tiles
	grid_height = tiles.size()
	if grid_height > 0:
		grid_width = (tiles[0] as Array).size()
	custom_minimum_size = Vector2(grid_width * cell_size, grid_height * cell_size)
	queue_redraw()

func set_signals(new_signals: Array) -> void:
	signals = new_signals
	queue_redraw()

func set_source_highlights(new_highlights: Array) -> void:
	source_highlights = new_highlights
	queue_redraw()

func set_purge_highlights(new_highlights: Array) -> void:
	purge_highlights = new_highlights
	queue_redraw()

func set_cursor(new_cursor: Vector2i) -> void:
	cursor_pos = Vector2i(
		clamp(new_cursor.x, 0, grid_width - 1),
		clamp(new_cursor.y, 0, grid_height - 1)
	)
	queue_redraw()

func _draw() -> void:
	var board_rect := Rect2(Vector2.ZERO, Vector2(grid_width * cell_size, grid_height * cell_size))
	draw_rect(board_rect, Color(0.05, 0.06, 0.08), true)

	for y in range(grid_height):
		for x in range(grid_width):
			var tile := _get_tile(x, y)
			_draw_tile(tile, x, y)

	_draw_signals()

	var cursor_rect := Rect2(cursor_pos.x * cell_size, cursor_pos.y * cell_size, cell_size, cell_size)
	draw_rect(cursor_rect, Color(1.0, 0.9, 0.2, 0.22), true)
	draw_rect(cursor_rect, Color(1.0, 0.9, 0.2), false, 3.0)

func _draw_tile(tile: Dictionary, x: int, y: int) -> void:
	var tile_type: String = tile.get("type", "empty")
	var tile_rect := Rect2(x * cell_size, y * cell_size, cell_size, cell_size)
	var tile_color: Color = TYPE_COLORS.get(tile_type, TYPE_COLORS["empty"])
	draw_rect(tile_rect, tile_color, true)
	draw_rect(tile_rect, Color(0.20, 0.21, 0.25), false, 1.0)

	if tile_type == "wall":
		var inset := tile_rect.grow(-10)
		draw_rect(inset, Color(0.38, 0.39, 0.43), true)
		return

	if tile_type in ["straight_wire", "corner_wire", "gate", "splitter"]:
		_draw_ports(tile, tile_rect)
		if tile_type == "gate":
			_draw_gate_marker(tile, tile_rect)
		elif tile_type == "splitter":
			_draw_splitter_marker(tile, tile_rect)

	if tile_type == "source":
		_draw_source(tile, tile_rect)
	elif tile_type == "sink":
		_draw_sink(tile, tile_rect)
	elif tile_type == "purge_sink":
		_draw_purge_sink(tile, tile_rect, x, y)

func _draw_ports(tile: Dictionary, tile_rect: Rect2) -> void:
	var center := tile_rect.position + tile_rect.size * 0.5
	draw_circle(center, 8.0, Color(0.83, 0.84, 0.88))
	for port in ComponentRules.get_ports(tile):
		var end_point := center + Vector2(Directions.to_vector(port)) * (cell_size * 0.34)
		draw_line(center, end_point, Color(0.88, 0.90, 0.95), 5.0)

func _draw_source(tile: Dictionary, tile_rect: Rect2) -> void:
	var center := tile_rect.position + tile_rect.size * 0.5
	var source_cell := Vector2i(int(tile_rect.position.x / cell_size), int(tile_rect.position.y / cell_size))
	var source_color := _signal_color(tile.get("signal_type", "blue"))
	draw_circle(center, 15.0, source_color)
	draw_circle(center, 7.0, source_color.darkened(0.45))
	_draw_signal_symbol(_signal_token(tile.get("signal_type", "blue")), center, 14, SYMBOL_DARK)
	var corruption_interval: int = int(tile.get("corruption_interval_steps", 0))
	if corruption_interval > 0:
		draw_circle(center, 19.0, SIGNAL_COLORS["corrupted"], false, 2.0)
	var direction: int = int(tile.get("orientation", 1))
	var arrow_tip := center + Vector2(Directions.to_vector(direction)) * (cell_size * 0.32)
	draw_line(center, arrow_tip, Color(0.95, 0.95, 0.98), 3.0)

	var highlight_strength: float = _source_highlight_strength(source_cell.x, source_cell.y)
	if highlight_strength > 0.0:
		var glow_color := SIGNAL_COLORS["corrupted"]
		glow_color.a = 0.22 * highlight_strength
		draw_circle(center, 22.0, glow_color)
		draw_circle(center, 23.0, Color(1.0, 0.74, 0.35, 0.80 * highlight_strength), false, 3.0 + 2.0 * highlight_strength)

func _draw_sink(tile: Dictionary, tile_rect: Rect2) -> void:
	var center := tile_rect.position + tile_rect.size * 0.5
	var sink_color := _signal_color(tile.get("signal_type", "blue"))
	draw_circle(center, 16.0, sink_color, false, 5.0)
	draw_circle(center, 9.0, sink_color.darkened(0.55))
	_draw_signal_symbol(_signal_token(tile.get("signal_type", "blue")), center, 14, SYMBOL_LIGHT)
	var accepted_from: int = Directions.opposite(int(tile.get("orientation", 0)))
	var intake := center + Vector2(Directions.to_vector(accepted_from)) * (cell_size * 0.30)
	draw_circle(intake, 5.0, sink_color)

func _draw_purge_sink(tile: Dictionary, tile_rect: Rect2, x: int, y: int) -> void:
	var center := tile_rect.position + tile_rect.size * 0.5
	var purge_color := SIGNAL_COLORS["corrupted"]
	var highlight_strength: float = _purge_highlight_strength(x, y)

	if highlight_strength > 0.0:
		var pulse_radius := 22.0 + 4.0 * (1.0 - highlight_strength)
		draw_circle(center, pulse_radius, Color(1.0, 0.76, 0.36, 0.18 * highlight_strength))
		draw_circle(
			center,
			pulse_radius + 1.5,
			Color(1.0, 0.84, 0.52, 0.90 * highlight_strength),
			false,
			3.0
		)

	draw_circle(center, 17.0, purge_color, false, 5.0)
	draw_circle(center, 9.5, Color(0.16, 0.08, 0.06, 1.0))
	_draw_signal_symbol("!", center, 18, Color(1.0, 0.94, 0.82, 1.0))
	var accepted_from: int = Directions.opposite(int(tile.get("orientation", 0)))
	var intake := center + Vector2(Directions.to_vector(accepted_from)) * (cell_size * 0.30)
	draw_circle(intake, 5.0, purge_color)
	draw_circle(intake, 2.0, Color(0.13, 0.06, 0.04, 1.0))
	if highlight_strength > 0.0:
		draw_circle(intake, 7.5, Color(1.0, 0.82, 0.48, 0.72 * highlight_strength), false, 2.2)

func _draw_gate_marker(tile: Dictionary, tile_rect: Rect2) -> void:
	var center := tile_rect.position + tile_rect.size * 0.5
	var orientation := int(tile.get("orientation", 0))
	var state := int(tile.get("state", 0))
	var chosen := (orientation + 3) % 4 if state == 0 else (orientation + 1) % 4
	var marker := center + Vector2(Directions.to_vector(chosen)) * (cell_size * 0.22)
	draw_line(center, marker, Color(1.0, 0.82, 0.43, 0.94), 3.5)
	draw_circle(marker, 6.0, Color(0.98, 0.66, 0.18))
	_draw_signal_symbol("G", center, 12, SYMBOL_DARK)

func _draw_splitter_marker(tile: Dictionary, tile_rect: Rect2) -> void:
	var center := tile_rect.position + tile_rect.size * 0.5
	var orientation := int(tile.get("orientation", 0))
	var state := int(tile.get("state", 0))
	var next_out := (orientation + 3) % 4 if state == 0 else (orientation + 1) % 4
	var marker := center + Vector2(Directions.to_vector(next_out)) * (cell_size * 0.22)
	draw_circle(center, 6.0, Color(0.38, 0.99, 0.56, 0.50))
	draw_circle(marker, 5.0, Color(0.40, 1.0, 0.55))
	_draw_signal_symbol("S", center + Vector2(0.0, 1.0), 11, Color(0.08, 0.12, 0.09, 0.96))

func _draw_signals() -> void:
	for packet in signals:
		var sx: int = int(packet.get("x", 0))
		var sy: int = int(packet.get("y", 0))
		if sx < 0 or sy < 0 or sx >= grid_width or sy >= grid_height:
			continue
		var center := Vector2((sx + 0.5) * cell_size, (sy + 0.5) * cell_size)
		var signal_type: String = packet.get("signal_type", "blue")
		var is_corrupted: bool = bool(packet.get("is_corrupted", false))
		if is_corrupted:
			# Corrupted packets use a warning shape + symbol so they are readable even in peripheral vision.
			var diamond := _diamond_points(center, 14.0)
			draw_colored_polygon(diamond, SIGNAL_COLORS["corrupted"])
			draw_polyline(diamond + PackedVector2Array([diamond[0]]), Color(0.10, 0.04, 0.03), 2.0)
			_draw_signal_symbol("!", center, 18, Color(0.10, 0.04, 0.03))
			var age_steps: int = int(packet.get("age_steps", 0))
			if age_steps <= 1:
				draw_circle(center, 17.0, Color(1.0, 0.92, 0.62, 0.85), false, 3.0)
		elif signal_type == "red":
			var rect := Rect2(center - Vector2(11.5, 11.5), Vector2(23.0, 23.0))
			draw_rect(rect, SIGNAL_COLORS["red"], true)
			draw_rect(rect, Color(0.95, 0.96, 0.98), false, 2.0)
			_draw_signal_symbol("R", center, 13, SYMBOL_DARK)
		else:
			var color := _signal_color(signal_type)
			draw_circle(center, 12.0, color)
			draw_circle(center, 12.0, Color(0.95, 0.96, 0.98), false, 2.0)
			_draw_signal_symbol("B", center, 13, SYMBOL_DARK)

func _signal_color(signal_type: String) -> Color:
	return SIGNAL_COLORS.get(signal_type, SIGNAL_COLORS["blue"])

func _signal_token(signal_type: String) -> String:
	return "B" if signal_type == "blue" else "R"

func _draw_signal_symbol(symbol: String, center: Vector2, font_size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var text_size := font.get_string_size(symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	for offset in PackedVector2Array([
		Vector2(-1.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(0.0, -1.0),
		Vector2(0.0, 1.0),
	]):
		draw_string(
			font,
			center - Vector2(text_size.x * 0.5, -text_size.y * 0.33) + offset,
			symbol,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			Color(0.02, 0.02, 0.03, 0.72)
		)
	draw_string(
		font,
		center - Vector2(text_size.x * 0.5, -text_size.y * 0.33),
		symbol,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		color
	)

func _diamond_points(center: Vector2, radius: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(0.0, -radius),
		center + Vector2(radius, 0.0),
		center + Vector2(0.0, radius),
		center + Vector2(-radius, 0.0),
	])

func _source_highlight_strength(x: int, y: int) -> float:
	for highlight in source_highlights:
		if not (highlight is Dictionary):
			continue
		if int(highlight.get("x", -1)) == x and int(highlight.get("y", -1)) == y:
			return clampf(float(highlight.get("strength", 0.0)), 0.0, 1.0)
	return 0.0

func _purge_highlight_strength(x: int, y: int) -> float:
	for highlight in purge_highlights:
		if not (highlight is Dictionary):
			continue
		if int(highlight.get("x", -1)) == x and int(highlight.get("y", -1)) == y:
			return clampf(float(highlight.get("strength", 0.0)), 0.0, 1.0)
	return 0.0

func _get_tile(x: int, y: int) -> Dictionary:
	if y >= 0 and y < tiles.size():
		var row: Array = tiles[y]
		if x >= 0 and x < row.size():
			return row[x]
	return {"type": "empty", "orientation": 0}
