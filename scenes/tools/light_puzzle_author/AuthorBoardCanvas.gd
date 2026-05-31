class_name AuthorBoardCanvas
extends Control

signal cell_action_requested(cell: Vector2i)
signal port_action_requested(cell: Vector2i, direction: int)
signal selection_requested(selection_kind: int, selection_index: int)
signal placement_move_requested(placement_index: int, target_cell: Vector2i)
signal placement_move_finished(placement_index: int, target_cell: Vector2i)
signal allowed_cell_toggled(cell: Vector2i)
signal status_requested(message: String, is_error: bool)

const MODE_SELECT: int = 0
const MODE_PLACE_SOURCE: int = 1
const MODE_PLACE_EXIT: int = 2
const MODE_PLACE_PIECE: int = 3
const MODE_PLACE_BLOCK: int = 4
const MODE_EDIT_ALLOWED_CELLS: int = 5

const SELECTION_NONE: int = 0
const SELECTION_PUZZLE: int = 1
const SELECTION_SOURCE: int = 2
const SELECTION_EXIT: int = 3
const SELECTION_PLACEMENT: int = 4
const PORT_MARKER_OFFSET: float = 0.58
const PORT_HIT_RADIUS_MIN: float = 18.0
const DRAG_START_DISTANCE: float = 6.0

var puzzle_data: LightPuzzleData
var solution: Dictionary = {}
var current_mode: int = MODE_SELECT
var selection_kind: int = SELECTION_PUZZLE
var selection_index: int = -1
var validation_cells: Array[Vector2i] = []
var solver_preview_positions: Array = []

var _pending_drag_placement_index: int = -1
var _pending_drag_start_position: Vector2 = Vector2.ZERO
var _pending_drag_cell_offset: Vector2i = Vector2i.ZERO
var _pending_drag_reports_overlap: bool = false
var _drag_placement_index: int = -1
var _drag_cell_offset: Vector2i = Vector2i.ZERO
var _last_drag_cell: Vector2i = Vector2i(-999, -999)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_author_state(
	new_puzzle_data: LightPuzzleData,
	new_solution: Dictionary,
	new_mode: int,
	new_selection_kind: int,
	new_selection_index: int,
	new_validation_cells: Array[Vector2i],
	new_solver_preview_positions: Array = []
) -> void:
	puzzle_data = new_puzzle_data
	solution = new_solution
	current_mode = new_mode
	selection_kind = new_selection_kind
	selection_index = new_selection_index
	validation_cells = new_validation_cells.duplicate()
	solver_preview_positions = new_solver_preview_positions.duplicate()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if puzzle_data == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_handle_mouse_pressed(event.position)
		else:
			_handle_mouse_released(event.position)
		accept_event()
	elif event is InputEventMouseMotion and _pending_drag_placement_index != -1:
		if event.position.distance_to(_pending_drag_start_position) >= DRAG_START_DISTANCE:
			_start_pending_drag(event.position)
			_handle_drag_motion(event.position)
		accept_event()
	elif event is InputEventMouseMotion and _drag_placement_index != -1:
		_handle_drag_motion(event.position)
		accept_event()


func _handle_mouse_pressed(local_position: Vector2) -> void:
	var cell := _local_to_cell(local_position)

	if current_mode == MODE_PLACE_SOURCE or current_mode == MODE_PLACE_EXIT:
		var source := current_mode == MODE_PLACE_SOURCE
		var anchor := _port_anchor_from_local(local_position, source)
		if anchor.is_empty():
			status_requested.emit("端口只能放在棋盘边框上。", true)
			return
		port_action_requested.emit(anchor["cell"], int(anchor["direction"]))
		return

	if current_mode == MODE_EDIT_ALLOWED_CELLS:
		if not _is_cell_inside(cell):
			return
		allowed_cell_toggled.emit(cell)
		return

	if current_mode != MODE_SELECT:
		if not _is_cell_inside(cell):
			return
		var placement_index := _find_placement_at(cell)
		if placement_index != -1 and (current_mode == MODE_PLACE_PIECE or current_mode == MODE_PLACE_BLOCK):
			_begin_pending_drag(placement_index, local_position, cell, true)
			return
		cell_action_requested.emit(cell)
		return

	var port_hit := _find_port_at_position(local_position)
	if not port_hit.is_empty():
		selection_requested.emit(int(port_hit["kind"]), int(port_hit["index"]))
		return

	if not _is_cell_inside(cell):
		selection_requested.emit(SELECTION_PUZZLE, -1)
		return

	var placement_index := _find_placement_at(cell)
	if placement_index != -1:
		selection_requested.emit(SELECTION_PLACEMENT, placement_index)
		_begin_drag(placement_index, cell)
		return

	var source_index := _find_port_at(cell, true)
	if source_index != -1:
		selection_requested.emit(SELECTION_SOURCE, source_index)
		return

	var exit_index := _find_port_at(cell, false)
	if exit_index != -1:
		selection_requested.emit(SELECTION_EXIT, exit_index)
		return

	selection_requested.emit(SELECTION_PUZZLE, -1)


func _handle_mouse_released(local_position: Vector2) -> void:
	if _pending_drag_placement_index != -1:
		if _pending_drag_reports_overlap:
			status_requested.emit("该位置已有棋子，未放置；拖动可移动已有棋子。", true)
		_clear_pending_drag()
		return

	if _drag_placement_index == -1:
		return
	var pointer_cell := _local_to_cell(local_position)
	var target_cell := _drag_target_cell(local_position) if _is_cell_inside(pointer_cell) else _last_drag_cell
	placement_move_finished.emit(_drag_placement_index, target_cell)
	_clear_drag()


func _begin_pending_drag(placement_index: int, local_position: Vector2, hit_cell: Vector2i, reports_overlap: bool) -> void:
	_pending_drag_placement_index = placement_index
	_pending_drag_start_position = local_position
	_pending_drag_cell_offset = _placement_cell_offset(placement_index, hit_cell)
	_pending_drag_reports_overlap = reports_overlap


func _start_pending_drag(local_position: Vector2) -> void:
	var placement_index := _pending_drag_placement_index
	var cell_offset := _pending_drag_cell_offset
	_clear_pending_drag()
	selection_requested.emit(SELECTION_PLACEMENT, placement_index)
	_begin_drag(placement_index, _local_to_cell(local_position), cell_offset)


func _begin_drag(placement_index: int, hit_cell: Vector2i, cell_offset: Vector2i = Vector2i(-999, -999)) -> void:
	_drag_placement_index = placement_index
	_drag_cell_offset = cell_offset if cell_offset != Vector2i(-999, -999) else _placement_cell_offset(placement_index, hit_cell)
	var placement := _get_placement(placement_index)
	_last_drag_cell = placement.grid_position if placement != null else _drag_target_cell_from_cell(hit_cell)


func _handle_drag_motion(local_position: Vector2) -> void:
	var pointer_cell := _local_to_cell(local_position)
	if not _is_cell_inside(pointer_cell):
		return
	var drag_cell := _drag_target_cell_from_cell(pointer_cell)
	if drag_cell != _last_drag_cell:
		_last_drag_cell = drag_cell
		placement_move_requested.emit(_drag_placement_index, drag_cell)


func _drag_target_cell(local_position: Vector2) -> Vector2i:
	return _drag_target_cell_from_cell(_local_to_cell(local_position))


func _drag_target_cell_from_cell(pointer_cell: Vector2i) -> Vector2i:
	return pointer_cell - _drag_cell_offset


func _placement_cell_offset(placement_index: int, hit_cell: Vector2i) -> Vector2i:
	var placement := _get_placement(placement_index)
	if placement == null:
		return Vector2i.ZERO
	return hit_cell - placement.grid_position


func _clear_pending_drag() -> void:
	_pending_drag_placement_index = -1
	_pending_drag_start_position = Vector2.ZERO
	_pending_drag_cell_offset = Vector2i.ZERO
	_pending_drag_reports_overlap = false


func _clear_drag() -> void:
	_drag_placement_index = -1
	_drag_cell_offset = Vector2i.ZERO
	_last_drag_cell = Vector2i(-999, -999)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.04, 0.052), true)
	if puzzle_data == null:
		return
	_draw_board()
	_draw_port_sockets()
	_draw_allowed_cells()
	_draw_validation_cells()
	_draw_solver_preview()
	_draw_beams()
	_draw_ports()
	_draw_placements()
	_draw_selection()


func _draw_board() -> void:
	var origin := _board_origin()
	var step := _cell_step()
	var board_pixels := Vector2(puzzle_data.board_size) * step
	var board_rect := Rect2(origin, board_pixels)
	var border_band := _port_band()
	draw_rect(board_rect.grow(border_band), Color(0.055, 0.068, 0.086), true)
	draw_rect(board_rect.grow(border_band), Color(0.18, 0.24, 0.31), false, 2.0)
	draw_rect(board_rect.grow(10.0), Color(0.075, 0.09, 0.115), true)
	draw_rect(board_rect.grow(10.0), Color(0.24, 0.31, 0.38), false, 2.0)
	for y in range(puzzle_data.board_size.y):
		for x in range(puzzle_data.board_size.x):
			var cell_rect := Rect2(origin + Vector2(x, y) * step, Vector2.ONE * step)
			draw_rect(cell_rect.grow(-3.0), Color(0.055, 0.07, 0.088), true)
			draw_rect(cell_rect, Color(0.34, 0.42, 0.5, 0.45), false, 1.0)
			_draw_cell_label(Vector2i(x, y), cell_rect)
	draw_rect(board_rect, Color(0.7, 0.82, 0.95, 0.55), false, 2.0)


func _draw_cell_label(cell: Vector2i, rect: Rect2) -> void:
	var font := get_theme_default_font()
	if font == null:
		return
	var text := "%d,%d" % [cell.x, cell.y]
	draw_string(font, rect.position + Vector2(6.0, 14.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color(0.55, 0.62, 0.7, 0.8))


func _draw_allowed_cells() -> void:
	if current_mode != MODE_EDIT_ALLOWED_CELLS or selection_kind != SELECTION_PLACEMENT:
		return
	var placement := _get_placement(selection_index)
	if placement == null:
		return
	for cell in placement.allowed_cells:
		if _is_cell_inside(cell):
			draw_rect(_cell_rect(cell).grow(-5.0), Color(0.2, 0.75, 1.0, 0.24), true)


func _draw_validation_cells() -> void:
	for cell in validation_cells:
		if _is_cell_inside(cell):
			draw_rect(_cell_rect(cell).grow(-4.0), Color(1.0, 0.2, 0.18, 0.32), true)
			draw_rect(_cell_rect(cell).grow(-4.0), Color(1.0, 0.3, 0.24, 0.95), false, 2.0)


func _draw_solver_preview() -> void:
	if solver_preview_positions.is_empty() or puzzle_data == null:
		return
	var font := get_theme_default_font()
	for index in range(mini(puzzle_data.placements.size(), solver_preview_positions.size())):
		var placement := puzzle_data.placements[index]
		if placement == null or placement.piece == null:
			continue
		if not placement.is_movable():
			continue
		if not (solver_preview_positions[index] is Vector2i):
			continue
		var target_cell: Vector2i = solver_preview_positions[index]
		if not _is_cell_inside(target_cell):
			continue
		var target_rect := Rect2(
			_board_origin() + Vector2(target_cell) * _cell_step(),
			Vector2(placement.piece.size) * _cell_step()
		)
		draw_rect(target_rect.grow(-9.0), Color(0.22, 1.0, 0.72, 0.16), true)
		draw_rect(target_rect.grow(-9.0), Color(0.32, 1.0, 0.78, 0.92), false, 3.0)
		if target_cell != placement.grid_position:
			draw_line(_cell_center(placement.grid_position), _cell_center(target_cell), Color(0.32, 1.0, 0.78, 0.45), 2.0, true)
		if font != null:
			draw_string(
				font,
				target_rect.position + Vector2(9.0, 20.0),
				str(index + 1),
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				14,
				Color(0.86, 1.0, 0.94)
			)


func _draw_port_sockets() -> void:
	if current_mode != MODE_PLACE_SOURCE and current_mode != MODE_PLACE_EXIT:
		return
	var source := current_mode == MODE_PLACE_SOURCE
	var socket_color := Color(0.78, 0.88, 1.0, 0.36) if source else Color(1.0, 0.72, 0.42, 0.36)
	var outline_color := Color(socket_color.r, socket_color.g, socket_color.b, 0.68)
	for anchor in _port_candidates(source):
		var center: Vector2 = anchor["center"]
		draw_circle(center, 10.0, socket_color)
		draw_circle(center, 12.0, outline_color, false, 1.5)


func _draw_beams() -> void:
	var segments: Array = solution.get("segments", [])
	for segment in segments:
		var color_mask: int = segment.get("color_mask", LightPuzzleConstants.COLOR_WHITE)
		var color := LightPuzzleConstants.color_to_draw(color_mask)
		var from_cell: Vector2i = segment.get("from", Vector2i.ZERO)
		var to_cell: Vector2i = segment.get("to", Vector2i.ZERO)
		var direction: int = segment.get("direction", LightPuzzleConstants.Direction.E)
		var from_pos := _beam_start_position(segment, from_cell)
		var to_pos := _beam_end_position(from_cell, to_cell, direction)
		draw_line(from_pos, to_pos, Color(color.r, color.g, color.b, 0.26), 12.0, true)
		draw_line(from_pos, to_pos, Color(color.r, color.g, color.b, 0.95), 4.0, true)


func _draw_ports() -> void:
	for index in range(puzzle_data.sources.size()):
		var port := puzzle_data.sources[index]
		if port != null:
			_draw_port(port, true, selection_kind == SELECTION_SOURCE and selection_index == index)
	for index in range(puzzle_data.exits.size()):
		var port := puzzle_data.exits[index]
		if port != null:
			_draw_port(port, false, selection_kind == SELECTION_EXIT and selection_index == index)


func _draw_port(port: LightPortData, is_source: bool, selected: bool) -> void:
	var center := _port_marker_center(port, is_source)
	var inner := _cell_center(port.cell)
	var direction := Vector2(LightPuzzleConstants.direction_vector(port.direction))
	var color := LightPuzzleConstants.color_to_draw(port.color_mask)
	var label := "源" if is_source else "出"
	if not is_source:
		var exit_hits: Dictionary = solution.get("exit_hits", {})
		var active: bool = exit_hits.get(_port_key(port), false)
		if not active:
			color = color.darkened(0.45)
	var line_from := center if is_source else inner
	var line_to := inner if is_source else center
	draw_line(line_from, line_to, color, 4.0, true)
	draw_circle(center, 16.0, Color(color.r, color.g, color.b, 0.32))
	draw_circle(center, 9.0, color)
	draw_line(center, center + direction * (_cell_step() * 0.22), color, 3.0, true)
	if selected:
		draw_circle(center, 21.0, Color(1.0, 1.0, 1.0, 0.95), false, 3.0)
	var font := get_theme_default_font()
	if font != null:
		draw_string(font, center + Vector2(-8.0, 5.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color.BLACK)


func _draw_placements() -> void:
	for index in range(puzzle_data.placements.size()):
		var placement := puzzle_data.placements[index]
		if placement == null or placement.piece == null:
			continue
		var rect := _piece_rect(placement)
		var color := _piece_color(placement.piece)
		draw_rect(rect.grow(-5.0), Color(0.0, 0.0, 0.0, 0.32), true)
		draw_rect(rect.grow(-7.0), color, true)
		draw_rect(rect.grow(-7.0), Color(1.0, 1.0, 1.0, 0.36), false, 2.0)
		_draw_piece_label(placement, rect)
		if placement.solution_position != Vector2i(-1, -1):
			_draw_solution_marker(placement.solution_position)


func _draw_piece_label(placement: LightPiecePlacement, rect: Rect2) -> void:
	var font := get_theme_default_font()
	if font == null or placement.piece == null:
		return
	var label := _author_piece_label(placement.piece)
	var label_pos := rect.position + Vector2(12.0, rect.size.y * 0.58)
	draw_string(font, label_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color(0.98, 0.99, 1.0))


func _draw_solution_marker(cell: Vector2i) -> void:
	if not _is_cell_inside(cell):
		return
	var center := _cell_center(cell)
	var points: PackedVector2Array = [
		center + Vector2(0.0, -8.0),
		center + Vector2(8.0, 0.0),
		center + Vector2(0.0, 8.0),
		center + Vector2(-8.0, 0.0),
	]
	draw_colored_polygon(points, Color(1.0, 0.9, 0.22, 0.9))


func _draw_selection() -> void:
	if selection_kind != SELECTION_PLACEMENT:
		return
	var placement := _get_placement(selection_index)
	if placement == null:
		return
	draw_rect(_piece_rect(placement).grow(-2.0), Color(1.0, 0.95, 0.42, 1.0), false, 4.0)


func _find_placement_at(cell: Vector2i) -> int:
	for index in range(puzzle_data.placements.size() - 1, -1, -1):
		var placement := puzzle_data.placements[index]
		if placement == null or placement.piece == null:
			continue
		var pos := placement.grid_position
		var piece_size := placement.piece.size
		if cell.x >= pos.x and cell.x < pos.x + piece_size.x and cell.y >= pos.y and cell.y < pos.y + piece_size.y:
			return index
	return -1


func _find_port_at(cell: Vector2i, source: bool) -> int:
	var ports: Array[LightPortData] = puzzle_data.sources if source else puzzle_data.exits
	for index in range(ports.size()):
		var port := ports[index]
		if port != null and port.cell == cell:
			return index
	return -1


func _find_port_at_position(local_position: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := 1.0e20
	for index in range(puzzle_data.sources.size()):
		var port := puzzle_data.sources[index]
		if port == null:
			continue
		var distance := local_position.distance_to(_port_marker_center(port, true))
		if distance < best_distance:
			best_distance = distance
			best = {"kind": SELECTION_SOURCE, "index": index}
	for index in range(puzzle_data.exits.size()):
		var port := puzzle_data.exits[index]
		if port == null:
			continue
		var distance := local_position.distance_to(_port_marker_center(port, false))
		if distance < best_distance:
			best_distance = distance
			best = {"kind": SELECTION_EXIT, "index": index}
	if best_distance <= _port_hit_radius():
		return best
	return {}


func _get_placement(index: int) -> LightPiecePlacement:
	if puzzle_data == null or index < 0 or index >= puzzle_data.placements.size():
		return null
	return puzzle_data.placements[index]


func _piece_rect(placement: LightPiecePlacement) -> Rect2:
	var piece_size := Vector2i.ONE
	if placement.piece != null:
		piece_size = placement.piece.size
	return Rect2(_board_origin() + Vector2(placement.grid_position) * _cell_step(), Vector2(piece_size) * _cell_step())


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(_board_origin() + Vector2(cell) * _cell_step(), Vector2.ONE * _cell_step())


func _cell_center(cell: Vector2i) -> Vector2:
	return _board_origin() + (Vector2(cell) + Vector2(0.5, 0.5)) * _cell_step()


func _port_marker_center(port: LightPortData, is_source: bool) -> Vector2:
	return _port_marker_center_for(port.cell, port.direction, is_source)


func _port_marker_center_for(cell: Vector2i, direction: int, is_source: bool) -> Vector2:
	var dir_vec := Vector2(LightPuzzleConstants.direction_vector(direction))
	var sign := -1.0 if is_source else 1.0
	return _cell_center(cell) + dir_vec * (_cell_step() * PORT_MARKER_OFFSET * sign)


func _beam_start_position(segment: Dictionary, from_cell: Vector2i) -> Vector2:
	var source_key := str(segment.get("source", ""))
	for source in puzzle_data.sources:
		if source != null and _port_key(source) == source_key and source.cell == from_cell:
			return _port_marker_center(source, true)
	return _cell_center(from_cell)


func _beam_end_position(from_cell: Vector2i, to_cell: Vector2i, direction: int) -> Vector2:
	if _is_cell_inside(to_cell):
		return _cell_center(to_cell)
	var dir_vec := Vector2(LightPuzzleConstants.direction_vector(direction))
	for exit_port in puzzle_data.exits:
		if exit_port != null and exit_port.cell == from_cell and exit_port.direction == direction:
			return _port_marker_center(exit_port, false)
	return _cell_center(from_cell) + dir_vec * (_cell_step() * PORT_MARKER_OFFSET)


func _local_to_cell(local_position: Vector2) -> Vector2i:
	var local := local_position - _board_origin()
	var step := _cell_step()
	return Vector2i(floori(local.x / step), floori(local.y / step))


func _is_cell_inside(cell: Vector2i) -> bool:
	if puzzle_data == null:
		return false
	return cell.x >= 0 and cell.y >= 0 and cell.x < puzzle_data.board_size.x and cell.y < puzzle_data.board_size.y


func _port_anchor_from_local(local_position: Vector2, source: bool) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := 1.0e20
	for anchor in _port_candidates(source):
		var center: Vector2 = anchor["center"]
		var distance := local_position.distance_to(center)
		if distance < best_distance:
			best_distance = distance
			best = anchor
	if best_distance <= _port_hit_radius():
		return best
	return {}


func _port_candidates(source: bool) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	if puzzle_data == null:
		return candidates
	var last_x := puzzle_data.board_size.x - 1
	var last_y := puzzle_data.board_size.y - 1
	for y in range(puzzle_data.board_size.y):
		_add_port_candidate(candidates, Vector2i(0, y), LightPuzzleConstants.Direction.E if source else LightPuzzleConstants.Direction.W, source)
		_add_port_candidate(candidates, Vector2i(last_x, y), LightPuzzleConstants.Direction.W if source else LightPuzzleConstants.Direction.E, source)
	for x in range(puzzle_data.board_size.x):
		_add_port_candidate(candidates, Vector2i(x, 0), LightPuzzleConstants.Direction.S if source else LightPuzzleConstants.Direction.N, source)
		_add_port_candidate(candidates, Vector2i(x, last_y), LightPuzzleConstants.Direction.N if source else LightPuzzleConstants.Direction.S, source)
	_add_port_candidate(candidates, Vector2i(0, 0), LightPuzzleConstants.Direction.SE if source else LightPuzzleConstants.Direction.NW, source)
	_add_port_candidate(candidates, Vector2i(last_x, 0), LightPuzzleConstants.Direction.SW if source else LightPuzzleConstants.Direction.NE, source)
	_add_port_candidate(candidates, Vector2i(0, last_y), LightPuzzleConstants.Direction.NE if source else LightPuzzleConstants.Direction.SW, source)
	_add_port_candidate(candidates, Vector2i(last_x, last_y), LightPuzzleConstants.Direction.NW if source else LightPuzzleConstants.Direction.SE, source)
	return candidates


func _add_port_candidate(candidates: Array[Dictionary], cell: Vector2i, direction: int, source: bool) -> void:
	candidates.append({
		"cell": cell,
		"direction": direction,
		"center": _port_marker_center_for(cell, direction, source),
	})


func _board_origin() -> Vector2:
	if puzzle_data == null:
		return Vector2.ZERO
	var board_pixels := Vector2(puzzle_data.board_size) * _cell_step()
	return (size - board_pixels) * 0.5


func _cell_step() -> float:
	if puzzle_data == null or puzzle_data.board_size.x <= 0 or puzzle_data.board_size.y <= 0:
		return 64.0
	var available := size - Vector2(150.0, 150.0)
	var step := minf(available.x / float(puzzle_data.board_size.x), available.y / float(puzzle_data.board_size.y))
	return clampf(floorf(step), 42.0, 92.0)


func _port_hit_radius() -> float:
	return maxf(PORT_HIT_RADIUS_MIN, _cell_step() * 0.28)


func _port_band() -> float:
	return _cell_step() * PORT_MARKER_OFFSET + _port_hit_radius() * 0.55


func _piece_color(piece: LightPieceData) -> Color:
	match piece.piece_type:
		LightPuzzleConstants.PieceType.MIRROR_SLASH, LightPuzzleConstants.PieceType.MIRROR_BACKSLASH, LightPuzzleConstants.PieceType.PLANE_MIRROR_HORIZONTAL, LightPuzzleConstants.PieceType.PLANE_MIRROR_VERTICAL:
			return Color(0.48, 0.66, 0.88)
		LightPuzzleConstants.PieceType.PRISM_PLUS_45, LightPuzzleConstants.PieceType.PRISM_MINUS_45:
			return Color(0.55, 0.42, 0.92)
		LightPuzzleConstants.PieceType.FILTER_RED:
			return LightPuzzleConstants.color_to_draw(LightPuzzleConstants.COLOR_RED)
		LightPuzzleConstants.PieceType.FILTER_GREEN:
			return LightPuzzleConstants.color_to_draw(LightPuzzleConstants.COLOR_GREEN)
		LightPuzzleConstants.PieceType.FILTER_BLUE:
			return LightPuzzleConstants.color_to_draw(LightPuzzleConstants.COLOR_BLUE)
		LightPuzzleConstants.PieceType.FILTER_YELLOW:
			return LightPuzzleConstants.color_to_draw(LightPuzzleConstants.COLOR_YELLOW)
		LightPuzzleConstants.PieceType.FILTER_CYAN:
			return LightPuzzleConstants.color_to_draw(LightPuzzleConstants.COLOR_CYAN)
		LightPuzzleConstants.PieceType.FILTER_MAGENTA:
			return LightPuzzleConstants.color_to_draw(LightPuzzleConstants.COLOR_MAGENTA)
		LightPuzzleConstants.PieceType.GLASS_BLOCK:
			return Color(0.56, 0.88, 1.0, 0.72)
		LightPuzzleConstants.PieceType.OPAQUE_BLOCK:
			return Color(0.08, 0.08, 0.1)
	return Color(0.5, 0.5, 0.5)


func _author_piece_label(piece: LightPieceData) -> String:
	match piece.piece_type:
		LightPuzzleConstants.PieceType.MIRROR_SLASH:
			return "/"
		LightPuzzleConstants.PieceType.MIRROR_BACKSLASH:
			return "\\"
		LightPuzzleConstants.PieceType.PLANE_MIRROR_HORIZONTAL:
			return "-"
		LightPuzzleConstants.PieceType.PLANE_MIRROR_VERTICAL:
			return "|"
		LightPuzzleConstants.PieceType.PRISM_PLUS_45:
			return "+45"
		LightPuzzleConstants.PieceType.PRISM_MINUS_45:
			return "-45"
		LightPuzzleConstants.PieceType.FILTER_RED:
			return "红"
		LightPuzzleConstants.PieceType.FILTER_GREEN:
			return "绿"
		LightPuzzleConstants.PieceType.FILTER_BLUE:
			return "蓝"
		LightPuzzleConstants.PieceType.FILTER_YELLOW:
			return "黄"
		LightPuzzleConstants.PieceType.FILTER_CYAN:
			return "青"
		LightPuzzleConstants.PieceType.FILTER_MAGENTA:
			return "品"
		LightPuzzleConstants.PieceType.GLASS_BLOCK:
			return "透"
		LightPuzzleConstants.PieceType.OPAQUE_BLOCK:
			return "挡"
	return "？"


func _port_key(port: LightPortData) -> String:
	if port.port_id != "":
		return port.port_id
	return "%d,%d,%d" % [port.cell.x, port.cell.y, port.direction]


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
