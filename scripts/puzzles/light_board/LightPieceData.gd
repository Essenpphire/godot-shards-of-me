class_name LightPieceData
extends Resource

@export var piece_id: String = ""
@export var display_name: String = ""
@export_enum(
	"Mirror Slash",
	"Mirror Backslash",
	"Prism +45",
	"Prism -45",
	"Filter Red",
	"Filter Green",
	"Filter Blue",
	"Filter Yellow",
	"Filter Cyan",
	"Filter Magenta",
	"Glass Block",
	"Opaque Block"
) var piece_type: int = LightPuzzleConstants.PieceType.MIRROR_SLASH
@export var size: Vector2i = Vector2i.ONE
@export_enum("Both", "Horizontal", "Vertical", "Locked") var move_axis: int = LightPuzzleConstants.MoveAxis.BOTH
@export var is_draggable: bool = true
@export_flags("Red", "Green", "Blue") var filter_mask: int = LightPuzzleConstants.COLOR_WHITE
@export var asset_key: String = ""


func blocks_light() -> bool:
	return piece_type == LightPuzzleConstants.PieceType.OPAQUE_BLOCK


func is_filter() -> bool:
	return piece_type in [
		LightPuzzleConstants.PieceType.FILTER_RED,
		LightPuzzleConstants.PieceType.FILTER_GREEN,
		LightPuzzleConstants.PieceType.FILTER_BLUE,
		LightPuzzleConstants.PieceType.FILTER_YELLOW,
		LightPuzzleConstants.PieceType.FILTER_CYAN,
		LightPuzzleConstants.PieceType.FILTER_MAGENTA,
	]


func get_filter_mask() -> int:
	match piece_type:
		LightPuzzleConstants.PieceType.FILTER_RED:
			return LightPuzzleConstants.COLOR_RED
		LightPuzzleConstants.PieceType.FILTER_GREEN:
			return LightPuzzleConstants.COLOR_GREEN
		LightPuzzleConstants.PieceType.FILTER_BLUE:
			return LightPuzzleConstants.COLOR_BLUE
		LightPuzzleConstants.PieceType.FILTER_YELLOW:
			return LightPuzzleConstants.COLOR_YELLOW
		LightPuzzleConstants.PieceType.FILTER_CYAN:
			return LightPuzzleConstants.COLOR_CYAN
		LightPuzzleConstants.PieceType.FILTER_MAGENTA:
			return LightPuzzleConstants.COLOR_MAGENTA
	return filter_mask


func get_short_label() -> String:
	match piece_type:
		LightPuzzleConstants.PieceType.MIRROR_SLASH:
			return "/"
		LightPuzzleConstants.PieceType.MIRROR_BACKSLASH:
			return "\\"
		LightPuzzleConstants.PieceType.PRISM_PLUS_45:
			return "+45"
		LightPuzzleConstants.PieceType.PRISM_MINUS_45:
			return "-45"
		LightPuzzleConstants.PieceType.FILTER_RED:
			return "R"
		LightPuzzleConstants.PieceType.FILTER_GREEN:
			return "G"
		LightPuzzleConstants.PieceType.FILTER_BLUE:
			return "B"
		LightPuzzleConstants.PieceType.FILTER_YELLOW:
			return "Y"
		LightPuzzleConstants.PieceType.FILTER_CYAN:
			return "C"
		LightPuzzleConstants.PieceType.FILTER_MAGENTA:
			return "M"
		LightPuzzleConstants.PieceType.GLASS_BLOCK:
			return "T"
		LightPuzzleConstants.PieceType.OPAQUE_BLOCK:
			return "X"
	return "?"
