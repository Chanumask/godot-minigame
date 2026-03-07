extends RefCounted
class_name ComponentRules

const TILE_EMPTY := "empty"
const TILE_WALL := "wall"
const TILE_STRAIGHT := "straight_wire"
const TILE_CORNER := "corner_wire"
const TILE_SOURCE := "source"
const TILE_SINK := "sink"
const TILE_PURGE_SINK := "purge_sink"
const TILE_GATE := "gate"
const TILE_SPLITTER := "splitter"

static func can_interact(tile: Dictionary) -> bool:
	var tile_type: String = tile.get("type", TILE_EMPTY)
	return tile_type in [TILE_STRAIGHT, TILE_CORNER, TILE_GATE, TILE_SPLITTER]

static func interact(tile: Dictionary) -> Dictionary:
	var updated := tile.duplicate(true)
	var tile_type: String = updated.get("type", TILE_EMPTY)

	if tile_type in [TILE_STRAIGHT, TILE_CORNER, TILE_SPLITTER]:
		updated["orientation"] = (int(updated.get("orientation", 0)) + 1) % 4
	elif tile_type == TILE_GATE:
		updated["state"] = 1 - int(updated.get("state", 0))

	return updated

static func get_ports(tile: Dictionary) -> Array[int]:
	var tile_type: String = tile.get("type", TILE_EMPTY)
	var orientation: int = int(tile.get("orientation", 0)) % 4

	match tile_type:
		TILE_STRAIGHT:
			if orientation % 2 == 0:
				return [Directions.UP, Directions.DOWN]
			return [Directions.LEFT, Directions.RIGHT]
		TILE_CORNER:
			match orientation:
				0:
					return [Directions.UP, Directions.RIGHT]
				1:
					return [Directions.RIGHT, Directions.DOWN]
				2:
					return [Directions.DOWN, Directions.LEFT]
				_:
					return [Directions.LEFT, Directions.UP]
		TILE_SOURCE:
			return [orientation]
		TILE_SINK:
			return [Directions.opposite(orientation)]
		TILE_PURGE_SINK:
			return [Directions.opposite(orientation)]
		TILE_GATE:
			return _gate_ports(orientation, int(tile.get("state", 0)))
		TILE_SPLITTER:
			return _splitter_ports(orientation)
		_:
			return []

static func route(tile: Dictionary, incoming: int, _signal_type: String) -> Dictionary:
	var tile_type: String = tile.get("type", TILE_EMPTY)
	match tile_type:
		TILE_STRAIGHT, TILE_CORNER:
			var ports := get_ports(tile)
			if not ports.has(incoming):
				return {"ok": false, "reason": "dead_end"}
			for port in ports:
				if port != incoming:
					return {"ok": true, "outgoing": port}
			return {"ok": false, "reason": "dead_end"}
		TILE_GATE:
			var gate := _route_gate(tile, incoming)
			return gate
		TILE_SPLITTER:
			return _route_splitter(tile, incoming)
		_:
			return {"ok": false, "reason": "invalid_tile"}

static func _gate_ports(orientation: int, state: int) -> Array[int]:
	var input := orientation
	var left_out := (orientation + 3) % 4
	var right_out := (orientation + 1) % 4
	var active := left_out if state == 0 else right_out
	return [input, active]

static func _splitter_ports(orientation: int) -> Array[int]:
	var input := orientation
	var left_out := (orientation + 3) % 4
	var right_out := (orientation + 1) % 4
	return [input, left_out, right_out]

static func _route_gate(tile: Dictionary, incoming: int) -> Dictionary:
	var orientation := int(tile.get("orientation", 0)) % 4
	var input := orientation
	if incoming != input:
		return {"ok": false, "reason": "invalid_gate_entry"}
	var left_out := (orientation + 3) % 4
	var right_out := (orientation + 1) % 4
	var state := int(tile.get("state", 0))
	var outgoing := left_out if state == 0 else right_out
	return {"ok": true, "outgoing": outgoing}

static func _route_splitter(tile: Dictionary, incoming: int) -> Dictionary:
	var orientation := int(tile.get("orientation", 0)) % 4
	var input := orientation
	if incoming != input:
		return {"ok": false, "reason": "invalid_splitter_entry"}
	var left_out := (orientation + 3) % 4
	var right_out := (orientation + 1) % 4
	var state := int(tile.get("state", 0))
	var outgoing := left_out if state == 0 else right_out
	return {
		"ok": true,
		"outgoing": outgoing,
		"tile_update": {"state": 1 - state}
	}
