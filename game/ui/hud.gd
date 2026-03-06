extends Control
class_name HUD

@onready var level_label: Label = %LevelLabel
@onready var overload_label: Label = %OverloadLabel
@onready var overload_bar: ProgressBar = %OverloadBar
@onready var objective_label: Label = %ObjectiveLabel
@onready var status_label: Label = %StatusLabel

func set_level_name(level_name: String) -> void:
	level_label.text = level_name

func set_overload(current: int, maximum: int) -> void:
	overload_label.text = "Overload: %d / %d" % [current, maximum]
	overload_bar.max_value = max(maximum, 1)
	overload_bar.value = clamp(current, 0, maximum)

func set_objectives(objectives: Dictionary, delivered: Dictionary) -> void:
	var parts: Array[String] = []
	for signal_type in objectives.keys():
		var target: int = int(objectives[signal_type])
		if target <= 0:
			continue
		var got: int = int(delivered.get(signal_type, 0))
		var label := "B" if signal_type == "blue" else "R"
		parts.append("%s %d/%d" % [label, got, target])
	objective_label.text = "Objectives: " + (" | ".join(parts) if not parts.is_empty() else "None")

func set_status(text_value: String) -> void:
	status_label.text = text_value
