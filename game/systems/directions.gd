extends RefCounted
class_name Directions

const UP := 0
const RIGHT := 1
const DOWN := 2
const LEFT := 3

static func all() -> Array[int]:
	return [UP, RIGHT, DOWN, LEFT]

static func opposite(direction: int) -> int:
	return (direction + 2) % 4

static func rotate_cw(direction: int) -> int:
	return (direction + 1) % 4

static func to_vector(direction: int) -> Vector2i:
	match direction:
		UP:
			return Vector2i(0, -1)
		RIGHT:
			return Vector2i(1, 0)
		DOWN:
			return Vector2i(0, 1)
		_:
			return Vector2i(-1, 0)
