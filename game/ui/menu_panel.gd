extends Panel
class_name MenuPanel

signal item_selected(item_id: String)

const SELECTED_TEXT_COLOR := Color(1.0, 0.95, 0.72)
const NORMAL_TEXT_COLOR := Color(0.90, 0.93, 0.98)
const OUTLINE_COLOR := Color(0.03, 0.04, 0.06, 0.95)

@onready var title_label: Label = %TitleLabel
@onready var items_box: VBoxContainer = %ItemsBox

var items: Array = []
var selected_index: int = 0

func set_menu(title: String, entries: Array) -> void:
	title_label.text = title
	items = entries.duplicate(true)
	selected_index = 0
	_redraw_items()

func set_selected_index(index: int) -> void:
	if items.is_empty():
		selected_index = 0
		return
	selected_index = clampi(index, 0, items.size() - 1)
	_redraw_items()

func move_selection(delta: int) -> void:
	if items.is_empty():
		return
	selected_index = posmod(selected_index + delta, items.size())
	_redraw_items()

func activate_selected() -> void:
	if selected_index < 0 or selected_index >= items.size():
		return
	item_selected.emit(str(items[selected_index].get("id", "")))

func get_selected_index() -> int:
	return selected_index

func get_selected_item_id() -> String:
	if selected_index < 0 or selected_index >= items.size():
		return ""
	return str(items[selected_index].get("id", ""))

func _redraw_items() -> void:
	for child in items_box.get_children():
		child.queue_free()

	for i in range(items.size()):
		var entry: Dictionary = items[i]
		var selected := i == selected_index
		var row := PanelContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.custom_minimum_size = Vector2(0.0, 46.0)
		row.add_theme_stylebox_override("panel", _make_row_style(selected))

		var label := Label.new()
		var prefix := "> " if selected else "  "
		label.text = prefix + str(entry.get("label", ""))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 24)
		label.add_theme_color_override("font_color", SELECTED_TEXT_COLOR if selected else NORMAL_TEXT_COLOR)
		label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
		label.add_theme_constant_override("outline_size", 2)

		row.add_child(label)
		items_box.add_child(row)

func _make_row_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_right = 7
	style.corner_radius_bottom_left = 7
	style.content_margin_left = 8.0
	style.content_margin_top = 4.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 4.0

	if selected:
		style.bg_color = Color(0.19, 0.24, 0.32, 0.95)
		style.border_color = Color(1.0, 0.86, 0.42, 0.95)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
	else:
		style.bg_color = Color(0.10, 0.13, 0.18, 0.70)
		style.border_color = Color(0.38, 0.44, 0.56, 0.55)
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1

	return style
