class_name LightPuzzleBoard
extends CanvasLayer

const LIGHT_PIECE_VIEW_SCRIPT := preload("res://scenes/gameplay/puzzles/light_board/light_piece_view.gd")

signal puzzle_solved(puzzle_id: String)
signal puzzle_closed(puzzle_id: String)

@export var puzzle_data: LightPuzzleData
@export var cell_size: float = 88.0
@export var pause_world_while_open: bool = true
@export var open_on_ready: bool = false

@onready var _overlay: Control = $Overlay
@onready var _frame: PanelContainer = $Overlay/Center/Frame
@onready var _title_label: Label = $Overlay/Center/Frame/Margin/Layout/Header/Title
@onready var _status_label: Label = $Overlay/Center/Frame/Margin/Layout/Header/Status
@onready var _board_surface: Control = $Overlay/Center/Frame/Margin/Layout/BoardSurface
@onready var _reset_button: Button = $Overlay/Center/Frame/Margin/Layout/Header/ResetButton
@onready var _close_button: Button = $Overlay/Center/Frame/Margin/Layout/Header/CloseButton

var _runtime_placements: Array = []
var _piece_views: Array = []
var _solution: Dictionary = {}
var _drag_index: int = -1
var _drag_origin_cell: Vector2i = Vector2i.ZERO
var _drag_grab_offset: Vector2 = Vector2.ZERO
var _was_paused_before_open: bool = false
var _solved_emitted: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_reset_button.pressed.connect(reset_puzzle)
	_close_button.pressed.connect(close_puzzle)
	hide()
	if open_on_ready and puzzle_data != null:
		open_puzzle(puzzle_data)


func open_puzzle(new_puzzle_data: LightPuzzleData = null) -> void:
	if new_puzzle_data != null:
		puzzle_data = new_puzzle_data
	if puzzle_data == null:
		push_error("LightPuzzleBoard.open_puzzle called without puzzle data.")
		return

	_runtime_placements = puzzle_data.create_runtime_placements()
	_solved_emitted = false
	_title_label.text = puzzle_data.title if puzzle_data.title != "" else puzzle_data.puzzle_id
	_status_label.text = ""
	_configure_surface()
	_rebuild_piece_views()
	_recompute_solution()

	_was_paused_before_open = get_tree().paused
	if pause_world_while_open:
		get_tree().paused = true
	show()


func close_puzzle() -> void:
	if _drag_index != -1:
		end_piece_drag()
	hide()
	if pause_world_while_open:
		get_tree().paused = _was_paused_before_open
	if puzzle_data != null:
		puzzle_closed.emit(puzzle_data.puzzle_id)


func reset_puzzle() -> void:
	if puzzle_data == null:
		return
	_runtime_placements = puzzle_data.create_runtime_placements()
	_solved_emitted = false
	_status_label.text = ""
	_rebuild_piece_views()
	_recompute_solution()


func begin_piece_drag(index: int, global_mouse_position: Vector2) -> void:
	if index < 0 or index >= _runtime_placements.size():
		return
	if not _is_runtime_movable(index):
		return
	_drag_index = index
	_drag_origin_cell = _get_runtime_position(index)
	var drag_anchor := Vector2.ZERO
	if _board_surface.has_method("cell_to_local"):
		drag_anchor = _board_surface.cell_to_local(_drag_origin_cell)
	_drag_grab_offset = _surface_global_to_local(global_mouse_position) - drag_anchor
	_set_piece_selected(index, true)


func update_piece_drag(global_mouse_position: Vector2) -> void:
	if _drag_index == -1:
		return

	var piece := _get_runtime_piece(_drag_index)
	if piece == null:
		return

	var mouse_local := _surface_global_to_local(global_mouse_position)
	var anchor_local := mouse_local - _drag_grab_offset
	var current_cell := _get_runtime_position(_drag_index)
	var raw_cell := _cell_from_drag_anchor(anchor_local, piece.size)
	var target_cell := _resolve_drag_target(_drag_index, current_cell, raw_cell)

	if target_cell != current_cell:
		_set_runtime_position(_drag_index, target_cell)
		_refresh_piece_view(_drag_index)
		_recompute_solution()

	var visual_pos := _clamp_drag_visual(_drag_index, target_cell, anchor_local)
	var view: Node = _piece_views[_drag_index] if _drag_index < _piece_views.size() else null
	if is_instance_valid(view) and view.has_method("set_drag_position"):
		view.set_drag_position(visual_pos)


func _clamp_drag_visual(index: int, cell: Vector2i, anchor_local: Vector2) -> Vector2:
	var step := get_board_step()
	var cell_topleft: Vector2 = _board_surface.cell_to_local(cell)
	var piece := _get_runtime_piece(index)
	var half_step := step * 0.5
	var visual_pos := Vector2(
		clampf(anchor_local.x, cell_topleft.x - half_step, cell_topleft.x + half_step),
		clampf(anchor_local.y, cell_topleft.y - half_step, cell_topleft.y + half_step)
	)

	if piece == null:
		return visual_pos

	match piece.move_axis:
		LightPuzzleConstants.MoveAxis.HORIZONTAL:
			visual_pos.y = cell_topleft.y
		LightPuzzleConstants.MoveAxis.VERTICAL:
			visual_pos.x = cell_topleft.x
		LightPuzzleConstants.MoveAxis.LOCKED:
			visual_pos = cell_topleft

	return visual_pos


func end_piece_drag() -> void:
	if _drag_index == -1:
		return
	_set_piece_selected(_drag_index, false)
	var view: Node = _piece_views[_drag_index] if _drag_index < _piece_views.size() else null
	if is_instance_valid(view) and view.has_method("clear_drag_position"):
		view.clear_drag_position()
	_refresh_piece_view(_drag_index)
	_drag_index = -1


func is_dragging_piece(index: int) -> bool:
	return _drag_index == index


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.is_action_pressed("pause"):
		close_puzzle()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _drag_index != -1:
		update_piece_drag(event.global_position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if _drag_index != -1:
			end_piece_drag()
			get_viewport().set_input_as_handled()


func _configure_surface() -> void:
	if _board_surface.has_method("configure"):
		_board_surface.configure(puzzle_data.board_size, cell_size, puzzle_data.sources, puzzle_data.exits)
	var board_pixels := Vector2(puzzle_data.board_size) * cell_size
	_frame.custom_minimum_size = board_pixels + Vector2(48.0, 112.0)


func _rebuild_piece_views() -> void:
	for child in _board_surface.get_children():
		_board_surface.remove_child(child)
		child.queue_free()
	_piece_views.clear()

	for index in range(_runtime_placements.size()):
		var view: Node = LIGHT_PIECE_VIEW_SCRIPT.new()
		_board_surface.add_child(view)
		view.setup(index, _runtime_placements[index], self, cell_size)
		_piece_views.append(view)


func _refresh_piece_view(index: int) -> void:
	if index < 0 or index >= _piece_views.size():
		return
	var view: Node = _piece_views[index]
	if is_instance_valid(view):
		view.refresh(_runtime_placements[index])


func _recompute_solution() -> void:
	_solution = LightBeamSolver.solve(puzzle_data, _runtime_placements)
	if _board_surface.has_method("set_solution"):
		_board_surface.set_solution(_solution)

	if _solution.get("solved", false):
		_status_label.text = "Solved"
		_status_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.58))
		if not _solved_emitted:
			_solved_emitted = true
			_play_solved_flash()
			puzzle_solved.emit(puzzle_data.puzzle_id)
			EventBus.puzzle_light_solved.emit(puzzle_data.puzzle_id)
	else:
		_status_label.text = "Tracing"
		_status_label.add_theme_color_override("font_color", Color(0.88, 0.9, 0.96))


func _play_solved_flash() -> void:
	var flash_texture := load("res://assets/images/puzzle/solved_flash.png") as Texture2D
	if flash_texture == null:
		return
	var flash := TextureRect.new()
	flash.texture = flash_texture
	flash.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.modulate.a = 0.0
	_overlay.add_child(flash)
	var tween := create_tween()
	tween.tween_property(flash, "modulate:a", 1.0, 0.18)
	tween.tween_property(flash, "modulate:a", 0.0, 0.52)
	tween.tween_callback(flash.queue_free)


func _surface_global_to_local(global_position: Vector2) -> Vector2:
	return _board_surface.get_global_transform().affine_inverse() * global_position


func get_board_offset() -> Vector2:
	if _board_surface != null and "board_margin" in _board_surface:
		return _board_surface.board_margin.position
	return Vector2.ZERO


func get_board_step() -> float:
	if _board_surface != null and _board_surface.has_method("_cell_step"):
		return _board_surface._cell_step()
	return cell_size


func _cell_from_drag_anchor(anchor_local: Vector2, piece_size: Vector2i) -> Vector2i:
	var step := get_board_step()
	var piece_center := anchor_local + Vector2(piece_size) * step * 0.5
	if _board_surface != null and _board_surface.has_method("local_to_cell_centered"):
		return _board_surface.local_to_cell_centered(piece_center, piece_size)

	var centered_local := piece_center - get_board_offset()
	var half_size := Vector2(piece_size) * 0.5
	return Vector2i(
		roundi(centered_local.x / step - half_size.x),
		roundi(centered_local.y / step - half_size.y)
	)


func _resolve_drag_target(index: int, start_cell: Vector2i, raw_cell: Vector2i) -> Vector2i:
	var piece := _get_runtime_piece(index)
	if piece == null:
		return start_cell

	match piece.move_axis:
		LightPuzzleConstants.MoveAxis.HORIZONTAL:
			var horizontal_target := _clamp_anchor_to_board(index, Vector2i(raw_cell.x, start_cell.y))
			return _find_farthest_legal_cell(index, start_cell, horizontal_target)
		LightPuzzleConstants.MoveAxis.VERTICAL:
			var vertical_target := _clamp_anchor_to_board(index, Vector2i(start_cell.x, raw_cell.y))
			return _find_farthest_legal_cell(index, start_cell, vertical_target)
		LightPuzzleConstants.MoveAxis.LOCKED:
			return start_cell

	var clamped_raw := _clamp_anchor_to_board(index, raw_cell)
	if clamped_raw == start_cell:
		return start_cell
	if clamped_raw.x == start_cell.x or clamped_raw.y == start_cell.y:
		return _find_farthest_legal_cell(index, start_cell, clamped_raw)

	var horizontal_candidate := Vector2i(clamped_raw.x, start_cell.y)
	var vertical_candidate := Vector2i(start_cell.x, clamped_raw.y)
	var candidates := [horizontal_candidate, vertical_candidate]
	if abs(clamped_raw.y - start_cell.y) > abs(clamped_raw.x - start_cell.x):
		candidates = [vertical_candidate, horizontal_candidate]

	var best_cell := start_cell
	var best_distance := INF
	for candidate in candidates:
		var resolved := _find_farthest_legal_cell(index, start_cell, candidate)
		var distance : float = abs(clamped_raw.x - resolved.x) + abs(clamped_raw.y - resolved.y)
		if distance < best_distance:
			best_distance = distance
			best_cell = resolved

	return best_cell


func _clamp_anchor_to_board(index: int, cell: Vector2i) -> Vector2i:
	var piece := _get_runtime_piece(index)
	if piece == null:
		return cell
	return Vector2i(
		clampi(cell.x, 0, puzzle_data.board_size.x - piece.size.x),
		clampi(cell.y, 0, puzzle_data.board_size.y - piece.size.y)
	)


func _find_farthest_legal_cell(index: int, start_cell: Vector2i, target_cell: Vector2i) -> Vector2i:
	if target_cell == start_cell:
		return start_cell
	if target_cell.x != start_cell.x and target_cell.y != start_cell.y:
		return start_cell

	var step := Vector2i(_axis_sign(target_cell.x - start_cell.x), _axis_sign(target_cell.y - start_cell.y))
	var current := start_cell
	while current != target_cell:
		var next_cell := current + step
		if not _position_is_valid(index, next_cell):
			break
		current = next_cell
	return current


func _position_is_valid(index: int, target_cell: Vector2i) -> bool:
	var piece := _get_runtime_piece(index)
	if piece == null:
		return false
	if target_cell.x < 0 or target_cell.y < 0:
		return false
	if target_cell.x + piece.size.x > puzzle_data.board_size.x:
		return false
	if target_cell.y + piece.size.y > puzzle_data.board_size.y:
		return false

	var placement: Dictionary = _runtime_placements[index]
	var allowed_cells: Array = placement.get("allowed_cells", [])
	if not allowed_cells.is_empty() and not allowed_cells.has(target_cell):
		return false

	for other_index in range(_runtime_placements.size()):
		if other_index == index:
			continue
		var other_piece := _get_runtime_piece(other_index)
		if other_piece == null:
			continue
		if _rects_overlap(
			target_cell,
			piece.size,
			_get_runtime_position(other_index),
			other_piece.size
		):
			return false
	return true


func _rects_overlap(a_pos: Vector2i, a_size: Vector2i, b_pos: Vector2i, b_size: Vector2i) -> bool:
	return (
		a_pos.x < b_pos.x + b_size.x
		and a_pos.x + a_size.x > b_pos.x
		and a_pos.y < b_pos.y + b_size.y
		and a_pos.y + a_size.y > b_pos.y
	)


func _axis_sign(value: int) -> int:
	if value > 0:
		return 1
	if value < 0:
		return -1
	return 0


func _is_runtime_movable(index: int) -> bool:
	var placement: Dictionary = _runtime_placements[index]
	var piece := _get_runtime_piece(index)
	if piece == null:
		return false
	return piece.is_draggable and not placement.get("locked", false) and piece.move_axis != LightPuzzleConstants.MoveAxis.LOCKED


func _get_runtime_piece(index: int) -> LightPieceData:
	if index < 0 or index >= _runtime_placements.size():
		return null
	return _runtime_placements[index].get("piece", null)


func _get_runtime_position(index: int) -> Vector2i:
	if index < 0 or index >= _runtime_placements.size():
		return Vector2i.ZERO
	return _runtime_placements[index].get("grid_position", Vector2i.ZERO)


func _set_runtime_position(index: int, target_cell: Vector2i) -> void:
	var placement: Dictionary = _runtime_placements[index]
	placement["grid_position"] = target_cell
	_runtime_placements[index] = placement


func _set_piece_selected(index: int, value: bool) -> void:
	if index < 0 or index >= _piece_views.size():
		return
	var view: Node = _piece_views[index]
	if is_instance_valid(view):
		view.set_selected(value)
