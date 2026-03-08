extends Control
class_name HUD

const SIGNAL_TYPE_LABELS := {
	"blue": "Blue",
	"red": "Red",
}

@onready var level_label: Label = %LevelLabel
@onready var speed_label: Label = %SpeedLabel
@onready var overload_label: Label = %OverloadLabel
@onready var overload_bar: ProgressBar = %OverloadBar
@onready var objective_label: Label = %ObjectiveLabel
@onready var status_label: Label = %StatusLabel
@onready var top_panel: Control = $Panel

func set_level_name(level_name: String) -> void:
	level_label.text = level_name

func set_speed_mode(mode_name: String) -> void:
	speed_label.text = "Speed: %s" % mode_name

func set_overload(current: int, maximum: int) -> void:
	overload_label.text = "Overload: %d / %d" % [current, maximum]
	overload_bar.max_value = max(maximum, 1)
	overload_bar.value = clamp(current, 0, maximum)
	var ratio := float(current) / float(max(maximum, 1))
	if ratio >= 0.8:
		overload_bar.modulate = Color(1.0, 0.55, 0.52, 1.0)
	elif ratio >= 0.5:
		overload_bar.modulate = Color(1.0, 0.83, 0.52, 1.0)
	else:
		overload_bar.modulate = Color(0.72, 0.93, 1.0, 1.0)

func set_objectives(objectives: Dictionary, delivered: Dictionary) -> void:
	var parts: Array[String] = []
	for signal_type in ["blue", "red"]:
		if not objectives.has(signal_type):
			continue
		var target: int = int(objectives[signal_type])
		if target <= 0:
			continue
		var got: int = int(delivered.get(signal_type, 0))
		var label: String = SIGNAL_TYPE_LABELS.get(signal_type, signal_type.capitalize())
		parts.append("%s %d/%d" % [label, got, target])
	objective_label.text = "Objectives: " + (" | ".join(parts) if not parts.is_empty() else "None")

func set_status(text_value: String) -> void:
	status_label.text = text_value

func get_top_bar_height() -> float:
	if top_panel == null:
		return 0.0
	return top_panel.size.y
