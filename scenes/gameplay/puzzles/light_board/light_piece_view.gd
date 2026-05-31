extends Control

const ASSET_ROOT := "res://assets/images/puzzle/"

var board: Node
var placement_index: int = -1
var runtime_placement: Dictionary = {}
var cell_size: float = 88.0
var selected: bool = false
var _piece_texture: Texture2D
var _hover_texture: Texture2D
var _drag_raw_position: Variant = null


static var _texture_cache: Dictionary = {}


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
		_piece_texture = _get_texture_for_piece(piece)
		_hover_texture = _load_texture("piece_hover_glow.png")
	var step := _cell_step()
	var board_offset := Vector2.ZERO
	if board != null and board.has_method("get_board_offset"):
		board_offset = board.get_board_offset()
	if _drag_raw_position != null:
		position = _drag_raw_position as Vector2
	else:
		position = board_offset + Vector2(grid_position) * step
	size = Vector2(piece_size) * step
	custom_minimum_size = size
	queue_redraw()


func set_drag_position(raw_position: Vector2) -> void:
	_drag_raw_position = raw_position
	position = _drag_raw_position


func clear_drag_position() -> void:
	_drag_raw_position = null


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
	draw_rect(rect, Color(0.0, 0.0, 0.0, 0.16), true)
	if _piece_texture != null:
		draw_texture_rect(_piece_texture, rect, false)
	else:
		_draw_fallback_piece(piece, rect)
	if selected and _hover_texture != null:
		draw_texture_rect(_hover_texture, rect, false)


func _draw_fallback_piece(piece: LightPieceData, rect: Rect2) -> void:
	draw_rect(rect.grow(-6.0), Color(0.23, 0.15, 0.08, 0.92), true)
	draw_rect(rect.grow(-8.0), Color(0.72, 0.86, 1.0, 0.72), false, 4.0, true)
	var center := rect.get_center()
	match piece.piece_type:
		LightPuzzleConstants.PieceType.PLANE_MIRROR_HORIZONTAL:
			draw_line(
				Vector2(rect.position.x + rect.size.x * 0.2, center.y),
				Vector2(rect.position.x + rect.size.x * 0.8, center.y),
				Color(0.92, 0.96, 1.0),
				6.0,
				true
			)
		LightPuzzleConstants.PieceType.PLANE_MIRROR_VERTICAL:
			draw_line(
				Vector2(center.x, rect.position.y + rect.size.y * 0.2),
				Vector2(center.x, rect.position.y + rect.size.y * 0.8),
				Color(0.92, 0.96, 1.0),
				6.0,
				true
			)
		_:
			var font := get_theme_default_font()
			if font != null:
				draw_string(font, center + Vector2(-12.0, 7.0), piece.get_short_label(), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color.WHITE)


func _get_texture_for_piece(piece: LightPieceData) -> Texture2D:
	var file_name := ""
	match piece.piece_type:
		LightPuzzleConstants.PieceType.MIRROR_SLASH:
			file_name = "piece_mirror_slash.png"
		LightPuzzleConstants.PieceType.MIRROR_BACKSLASH:
			file_name = "piece_mirror_backslash.png"
		LightPuzzleConstants.PieceType.PLANE_MIRROR_HORIZONTAL:
			file_name = "piece_plane_mirror_horizontal.png"
		LightPuzzleConstants.PieceType.PLANE_MIRROR_VERTICAL:
			file_name = "piece_plane_mirror_vertical.png"
		LightPuzzleConstants.PieceType.PRISM_PLUS_45:
			file_name = "piece_prism_plus_45.png"
		LightPuzzleConstants.PieceType.PRISM_MINUS_45:
			file_name = "piece_prism_minus_45.png"
		LightPuzzleConstants.PieceType.FILTER_RED:
			file_name = "piece_filter_red.png"
		LightPuzzleConstants.PieceType.FILTER_GREEN:
			file_name = "piece_filter_green.png"
		LightPuzzleConstants.PieceType.FILTER_BLUE:
			file_name = "piece_filter_blue.png"
		LightPuzzleConstants.PieceType.FILTER_YELLOW:
			file_name = "piece_filter_yellow.png"
		LightPuzzleConstants.PieceType.GLASS_BLOCK:
			file_name = "piece_glass_block.png"
		LightPuzzleConstants.PieceType.OPAQUE_BLOCK:
			file_name = "piece_opaque_block.png"
		LightPuzzleConstants.PieceType.FILTER_CYAN:
			file_name = "piece_filter_blue.png"
		LightPuzzleConstants.PieceType.FILTER_MAGENTA:
			file_name = "piece_filter_red.png"
	if file_name == "":
		return null
	return _load_texture(file_name)


func _load_texture(file_name: String) -> Texture2D:
	if _texture_cache.has(file_name):
		return _texture_cache[file_name]
	var path := ASSET_ROOT + file_name
	if not ResourceLoader.exists(path):
		return null
	var texture := load(path) as Texture2D
	_texture_cache[file_name] = texture
	return texture


func _cell_step() -> float:
	if board != null and board.has_method("get_board_step"):
		return board.get_board_step()
	return cell_size
