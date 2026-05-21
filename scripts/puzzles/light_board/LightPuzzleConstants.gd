class_name LightPuzzleConstants
extends RefCounted

const COLOR_RED: int = 1
const COLOR_GREEN: int = 2
const COLOR_BLUE: int = 4
const COLOR_YELLOW: int = COLOR_RED | COLOR_GREEN
const COLOR_CYAN: int = COLOR_GREEN | COLOR_BLUE
const COLOR_MAGENTA: int = COLOR_RED | COLOR_BLUE
const COLOR_WHITE: int = COLOR_RED | COLOR_GREEN | COLOR_BLUE

enum Direction { E, SE, S, SW, W, NW, N, NE }
enum PieceType {
	MIRROR_SLASH,
	MIRROR_BACKSLASH,
	PRISM_PLUS_45,
	PRISM_MINUS_45,
	FILTER_RED,
	FILTER_GREEN,
	FILTER_BLUE,
	FILTER_YELLOW,
	FILTER_CYAN,
	FILTER_MAGENTA,
	GLASS_BLOCK,
	OPAQUE_BLOCK,
}
enum MoveAxis { BOTH, HORIZONTAL, VERTICAL, LOCKED }
enum PortKind { SOURCE, EXIT }


static func direction_vector(direction: int) -> Vector2i:
	match direction:
		Direction.E:
			return Vector2i(1, 0)
		Direction.SE:
			return Vector2i(1, 1)
		Direction.S:
			return Vector2i(0, 1)
		Direction.SW:
			return Vector2i(-1, 1)
		Direction.W:
			return Vector2i(-1, 0)
		Direction.NW:
			return Vector2i(-1, -1)
		Direction.N:
			return Vector2i(0, -1)
		Direction.NE:
			return Vector2i(1, -1)
	return Vector2i.ZERO


static func vector_direction(vector: Vector2i) -> int:
	if vector == Vector2i(1, 0):
		return Direction.E
	if vector == Vector2i(1, 1):
		return Direction.SE
	if vector == Vector2i(0, 1):
		return Direction.S
	if vector == Vector2i(-1, 1):
		return Direction.SW
	if vector == Vector2i(-1, 0):
		return Direction.W
	if vector == Vector2i(-1, -1):
		return Direction.NW
	if vector == Vector2i(0, -1):
		return Direction.N
	if vector == Vector2i(1, -1):
		return Direction.NE
	return Direction.E


static func rotate_direction(direction: int, steps: int) -> int:
	return posmod(direction + steps, 8)


static func reflect_slash(direction: int) -> int:
	var vector := direction_vector(direction)
	return vector_direction(Vector2i(-vector.y, -vector.x))


static func reflect_backslash(direction: int) -> int:
	var vector := direction_vector(direction)
	return vector_direction(Vector2i(vector.y, vector.x))


static func direction_name(direction: int) -> String:
	match direction:
		Direction.E:
			return "E"
		Direction.SE:
			return "SE"
		Direction.S:
			return "S"
		Direction.SW:
			return "SW"
		Direction.W:
			return "W"
		Direction.NW:
			return "NW"
		Direction.N:
			return "N"
		Direction.NE:
			return "NE"
	return "?"


static func color_name(mask: int) -> String:
	match mask:
		COLOR_RED:
			return "Red"
		COLOR_GREEN:
			return "Green"
		COLOR_BLUE:
			return "Blue"
		COLOR_YELLOW:
			return "Yellow"
		COLOR_CYAN:
			return "Cyan"
		COLOR_MAGENTA:
			return "Magenta"
		COLOR_WHITE:
			return "White"
	return "None"


static func color_to_draw(mask: int) -> Color:
	match mask:
		COLOR_RED:
			return Color(1.0, 0.18, 0.14)
		COLOR_GREEN:
			return Color(0.2, 1.0, 0.4)
		COLOR_BLUE:
			return Color(0.18, 0.45, 1.0)
		COLOR_YELLOW:
			return Color(1.0, 0.86, 0.22)
		COLOR_CYAN:
			return Color(0.18, 0.92, 1.0)
		COLOR_MAGENTA:
			return Color(1.0, 0.32, 0.9)
		COLOR_WHITE:
			return Color(1.0, 0.96, 0.82)
	return Color(0.35, 0.35, 0.35)
