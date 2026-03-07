extends RefCounted
class_name LevelLoader

static func load_level(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open level file: %s" % path)
		return {}

	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	if parse_error != OK:
		push_error("Failed to parse level JSON %s: %s" % [path, json.get_error_message()])
		return {}

	var raw: Dictionary = json.data
	var width: int = int(raw.get("width", 8))
	var height: int = int(raw.get("height", 8))
	var tiles := _create_empty_grid(width, height)

	for component in raw.get("components", []):
		if not (component is Dictionary):
			continue
		var x: int = int(component.get("x", -1))
		var y: int = int(component.get("y", -1))
		if x < 0 or y < 0 or x >= width or y >= height:
			continue
		tiles[y][x] = _normalize_component(component)

	return {
		"id": raw.get("id", "unknown"),
		"name": raw.get("name", "Unnamed Level"),
		"width": width,
		"height": height,
		"sim_step_seconds": float(raw.get("sim_step_seconds", 0.35)),
		"overload_max": int(raw.get("overload_max", 20)),
		"objectives": raw.get("objectives", {}),
		"tiles": tiles,
	}

static func _create_empty_grid(width: int, height: int) -> Array:
	var rows: Array = []
	for y in range(height):
		var row: Array = []
		for x in range(width):
			row.append({"type": "empty", "orientation": 0, "state": 0})
		rows.append(row)
	return rows

static func _normalize_component(component: Dictionary) -> Dictionary:
	var tile_type: String = component.get("type", "empty")
	var normalized := {
		"type": tile_type,
		"orientation": int(component.get("orientation", 0)) % 4,
		"state": int(component.get("state", 0)),
	}

	if tile_type in ["source", "sink"]:
		normalized["signal_type"] = component.get("signal_type", "blue")
	if tile_type == "source":
		normalized["spawn_interval_steps"] = max(int(component.get("spawn_interval_steps", 3)), 1)
		normalized["corruption_interval_steps"] = max(int(component.get("corruption_interval_steps", 0)), 0)

	return normalized
