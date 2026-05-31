class_name LightPortData
extends Resource

@export var port_id: String = ""
@export_enum("Source", "Exit") var kind: int = LightPuzzleConstants.PortKind.SOURCE
@export var cell: Vector2i = Vector2i.ZERO
@export_enum("E", "SE", "S", "SW", "W", "NW", "N", "NE") var direction: int = LightPuzzleConstants.Direction.E
@export_flags("Red", "Green", "Blue") var color_mask: int = LightPuzzleConstants.COLOR_WHITE
@export var requires_exact_color: bool = true


func accepts_color(mask: int) -> bool:
	if requires_exact_color:
		return mask == color_mask
	return (mask & color_mask) == color_mask
