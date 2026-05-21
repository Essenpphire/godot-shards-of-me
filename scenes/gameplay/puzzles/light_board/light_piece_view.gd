class_name LightPieceView
extends Control

var board: Node
var placement_index: int = -1
var runtime_placement: Dictionary = {}
var cell_size: float = 88.0
var selected: bool = false


func setup(
	new_index: int,
	new_runtime_placement: Dictionary,
	new_board: Node,
	new_cell_size: float
) -> void:
	placement_index = new_index
	board = new_board
	cell_size = new_cell_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	refresh(new_runtime_placement)


func refresh(new_runtime_placement: Dictionary) -> void:
	runtime_placement = new_runtime_placement
	var piece := get_piece()
	var grid_position := get_grid_position()
	var piece_size := Vector2i.ONE
	if piece != null:
		piece_size = piece.size
	position = Vector2(grid_position) * cell_size
	size = Vector2(piece_size) * cell_size
	custom_minimum_size = size
	queue_redraw()


func get_piece() -> LightPieceData:
	return runtime_placement.get("piece", null)


func get_grid_position() -> Vector2i:
	return runtime_placement.get("grid_position", Vector2i.ZERO)


func set_selected(value: bool) -> void:
	selected = value
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if board == null:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if board.has_method("begin_piece_drag"):
				board.begin_piece_drag(placement_index, event.global_position)
				accept_event()
		else:
			if board.has_method("end_piece_drag"):
				board.end_piece_drag()
				accept_event()
	elif event is InputEventMouseMotion:
		if board.has_method("is_dragging_piece") and board.is_dragging_piece(placement_index):
			board.update_piece_drag(event.global_position)
			accept_event()


func _draw() -> void:
	var piece := get_piece()
	if piece == null:
		return

	var rect := Rect2(Vector2.ZERO, size)
	var base_color := _piece_color(piece)
	draw_rect(rect.grow(-5.0), Color(0.0, 0.0, 0.0, 0.28), true)
	draw_rect(rect.grow(-8.0), base_color, true)
	var border_color := Color(0.88, 0.9, 0.92, 0.58)
	if selected:
		border_color = Color(1.0, 0.88, 0.28, 0.95)
	draw_rect(rect.grow(-8.0), border_color, false, 3.0)

	match piece.piece_type:
		LightPuzzleConstants.PieceType.MIRROR_SLASH:
			_draw_mirror(true)
		LightPuzzleConstants.PieceType.MIRROR_BACKSLASH:
			_draw_mirror(false)
		LightPuzzleConstants.PieceType.PRISM_PLUS_45:
			_draw_prism(true)
		LightPuzzleConstants.PieceType.PRISM_MINUS_45:
			_draw_prism(false)
		LightPuzzleConstants.PieceType.GLASS_BLOCK:
			_draw_glass_lines()
		LightPuzzleConstants.PieceType.OPAQUE_BLOCK:
			_draw_opaque_core()
		_:
			if piece.is_filter():
				_draw_filter(piece)

	_draw_label(piece)


func _piece_color(piece: LightPieceData) -> Color:
	match piece.piece_type:
		LightPuzzleConstants.PieceType.MIRROR_SLASH, LightPuzzleConstants.PieceType.MIRROR_BACKSLASH:
			return Color(0.23, 0.28, 0.34, 0.94)
		LightPuzzleConstants.PieceType.PRISM_PLUS_45, LightPuzzleConstants.PieceType.PRISM_MINUS_45:
			return Color(0.18, 0.2, 0.31, 0.94)
		LightPuzzleConstants.PieceType.FILTER_RED:
			return Color(0.42, 0.1, 0.09, 0.92)
		LightPuzzleConstants.PieceType.FILTER_GREEN:
			return Color(0.08, 0.32, 0.16, 0.92)
		LightPuzzleConstants.PieceType.FILTER_BLUE:
			return Color(0.08, 0.16, 0.38, 0.92)
		LightPuzzleConstants.PieceType.FILTER_YELLOW:
			return Color(0.4, 0.33, 0.08, 0.92)
		LightPuzzleConstants.PieceType.FILTER_CYAN:
			return Color(0.06, 0.32, 0.36, 0.92)
		LightPuzzleConstants.PieceType.FILTER_MAGENTA:
			return Color(0.34, 0.1, 0.32, 0.92)
		LightPuzzleConstants.PieceType.GLASS_BLOCK:
			return Color(0.28, 0.48, 0.58, 0.42)
		LightPuzzleConstants.PieceType.OPAQUE_BLOCK:
			return Color(0.04, 0.04, 0.05, 0.96)
	return Color(0.2, 0.22, 0.25, 0.95)


func _draw_mirror(slash: bool) -> void:
	var padding := 20.0
	var start := Vector2(padding, size.y - padding)
	var end := Vector2(size.x - padding, padding)
	if not slash:
		start = Vector2(padding, padding)
		end = Vector2(size.x - padding, size.y - padding)
	draw_line(start, end, Color(0.62, 0.88, 1.0, 0.48), 12.0, true)
	draw_line(start, end, Color(0.92, 0.98, 1.0, 0.95), 5.0, true)


func _draw_prism(positive: bool) -> void:
	var points := PackedVector2Array([
		Vector2(size.x * 0.5, size.y * 0.18),
		Vector2(size.x * 0.18, size.y * 0.76),
		Vector2(size.x * 0.82, size.y * 0.76),
	])
	draw_colored_polygon(points, Color(0.72, 0.9, 1.0, 0.32))
	for i in range(points.size()):
		draw_line(points[i], points[(i + 1) % points.size()], Color(0.84, 0.96, 1.0, 0.82), 3.0, true)

	var center := size * 0.5
	var sign := 1.0 if positive else -1.0
	draw_arc(center, 18.0, -PI * 0.25 * sign, PI * 0.25 * sign, 16, Color(1.0, 0.86, 0.28), 3.0, true)


func _draw_filter(piece: LightPieceData) -> void:
	var color := LightPuzzleConstants.color_to_draw(piece.get_filter_mask())
	draw_rect(Rect2(Vector2(18.0, 18.0), size - Vector2(36.0, 36.0)), Color(color.r, color.g, color.b, 0.38), true)
	draw_rect(Rect2(Vector2(18.0, 18.0), size - Vector2(36.0, 36.0)), Color(color.r, color.g, color.b, 0.95), false, 4.0)


func _draw_glass_lines() -> void:
	for x in range(1, 4):
		var px := size.x * float(x) / 4.0
		draw_line(Vector2(px, 16.0), Vector2(px, size.y - 16.0), Color(0.75, 0.95, 1.0, 0.34), 2.0, true)
	for y in range(1, 4):
		var py := size.y * float(y) / 4.0
		draw_line(Vector2(16.0, py), Vector2(size.x - 16.0, py), Color(0.75, 0.95, 1.0, 0.26), 2.0, true)


func _draw_opaque_core() -> void:
	draw_rect(Rect2(Vector2(20.0, 20.0), size - Vector2(40.0, 40.0)), Color(0.0, 0.0, 0.0, 0.75), true)


func _draw_label(piece: LightPieceData) -> void:
	var font := get_theme_default_font()
	var font_size := 18
	var text := piece.get_short_label()
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var pos := size * 0.5 - text_size * 0.5 + Vector2(0.0, text_size.y * 0.75)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size, Color(0.98, 0.98, 0.98, 0.96))
