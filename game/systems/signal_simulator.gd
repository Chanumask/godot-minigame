extends RefCounted
class_name SignalSimulator

var width: int = 0
var height: int = 0
var tiles: Array = []
var signals: Array = []
var sources: Array = []
var delivered: Dictionary = {"blue": 0, "red": 0}

func setup(level_data: Dictionary) -> void:
	width = int(level_data.get("width", 0))
	height = int(level_data.get("height", 0))
	tiles = _deep_copy_tiles(level_data.get("tiles", []))
	signals.clear()
	delivered = {"blue": 0, "red": 0}
	sources.clear()

	for y in range(height):
		for x in range(width):
			var tile: Dictionary = tiles[y][x]
			if tile.get("type", "empty") == "source":
				sources.append({
					"x": x,
					"y": y,
					"interval": int(tile.get("spawn_interval_steps", 3)),
					"timer": 0,
					"signal_type": tile.get("signal_type", "blue"),
					"direction": int(tile.get("orientation", 1))
				})

func move_cursor_interact(cursor: Vector2i) -> bool:
	if not _is_in_bounds(cursor.x, cursor.y):
		return false
	var tile: Dictionary = tiles[cursor.y][cursor.x]
	if not ComponentRules.can_interact(tile):
		return false
	tiles[cursor.y][cursor.x] = ComponentRules.interact(tile)
	return true

func step() -> Dictionary:
	var delivered_now: Dictionary = {"blue": 0, "red": 0}
	var failures_now := 0
	var feedback_events: Array = []

	for i in range(sources.size()):
		var source: Dictionary = sources[i]
		source["timer"] = int(source.get("timer", 0)) + 1
		if int(source.get("timer", 0)) >= int(source.get("interval", 1)):
			source["timer"] = 0
			signals.append({
				"x": source["x"],
				"y": source["y"],
				"dir": source["direction"],
				"signal_type": source["signal_type"],
			})
		sources[i] = source

	var next_signals: Array = []

	for packet in signals:
		var pos := Vector2i(int(packet["x"]), int(packet["y"]))
		var direction: int = int(packet["dir"])
		var target := pos + Directions.to_vector(direction)

		if not _is_in_bounds(target.x, target.y):
			failures_now += 1
			feedback_events.append({"type": "failure", "reason": "signal_lost"})
			continue

		var incoming := Directions.opposite(direction)
		var tile: Dictionary = tiles[target.y][target.x]
		var tile_type: String = tile.get("type", "empty")
		var signal_type: String = packet.get("signal_type", "blue")

		if tile_type == "sink":
			var sink_side := Directions.opposite(int(tile.get("orientation", 0)))
			var sink_type: String = tile.get("signal_type", "blue")
			if incoming == sink_side and sink_type == signal_type:
				delivered[signal_type] = int(delivered.get(signal_type, 0)) + 1
				delivered_now[signal_type] = int(delivered_now.get(signal_type, 0)) + 1
				feedback_events.append({"type": "delivered", "signal_type": signal_type})
			else:
				failures_now += 1
				feedback_events.append({"type": "failure", "reason": "incompatible_sink"})
			continue

		if tile_type in ["empty", "wall", "source"]:
			failures_now += 1
			feedback_events.append({"type": "failure", "reason": "invalid_endpoint"})
			continue

		var routed := ComponentRules.route(tile, incoming, signal_type)
		if not routed.get("ok", false):
			failures_now += 1
			feedback_events.append({"type": "failure", "reason": routed.get("reason", "routing_error")})
			continue

		if routed.has("tile_update"):
			for key in routed["tile_update"].keys():
				tiles[target.y][target.x][key] = routed["tile_update"][key]

		next_signals.append({
			"x": target.x,
			"y": target.y,
			"dir": int(routed.get("outgoing", direction)),
			"signal_type": signal_type,
		})

	signals = next_signals

	return {
		"delivered": delivered_now,
		"failures": failures_now,
		"events": feedback_events,
	}

func _is_in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height

func _deep_copy_tiles(source_tiles: Array) -> Array:
	var copy: Array = []
	for row in source_tiles:
		copy.append((row as Array).duplicate(true))
	return copy
