class_name LightPuzzleAuthor
extends Control

const SAVE_ROOT: String = "res://resources/puzzles/light_board/"
const GENERATED_SCENE_ROOT: String = "res://scenes/gameplay/puzzles/"
const LIGHT_BOARD_SCENE_PATH: String = "res://scenes/gameplay/puzzles/light_board/light_puzzle_board.tscn"

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
const PIECE_TYPE_MAX: int = 13
const MOVE_AXIS_MAX: int = 3

@onready var _new_button: Button = %NewButton
@onready var _load_button: Button = %LoadButton
@onready var _save_button: Button = %SaveButton
@onready var _save_as_button: Button = %SaveAsButton
@onready var _validate_button: Button = %ValidateButton
@onready var _test_solution_button: Button = %TestSolutionButton
@onready var _solve_button: Button = %SolveButton
@onready var _apply_first_solution_button: Button = %ApplyFirstSolutionButton
@onready var _write_solution_button: Button = %WriteSolutionButton
@onready var _generate_scene_button: Button = %GenerateSceneButton
@onready var _load_path_edit: LineEdit = %LoadPathEdit
@onready var _palette: AuthorPalette = %Palette
@onready var _board_canvas: AuthorBoardCanvas = %BoardCanvas
@onready var _properties: AuthorPropertiesPanel = %PropertiesPanel
@onready var _status_label: Label = %StatusLabel
@onready var _solution_label: Label = %SolutionLabel

var draft_puzzle: LightPuzzleData
var save_path: String = SAVE_ROOT + "new_light_puzzle.tres"
var current_mode: int = MODE_SELECT
var current_payload: Dictionary = {}
var selection_kind: int = SELECTION_PUZZLE
var selection_index: int = -1
var solution: Dictionary = {}
var validation_cells: Array[Vector2i] = []
var solver_result: Dictionary = {}
var solver_preview_positions: Array = []
var solver_preview_solution: Dictionary = {}
var _suppressed_ui_layer: CanvasLayer
var _ui_layer_was_visible: bool = false
var _ui_layer_process_mode: int = Node.PROCESS_MODE_INHERIT


func _ready() -> void:
	_suppress_global_ui_layer()
	_new_button.pressed.connect(new_puzzle)
	_load_button.pressed.connect(_load_from_path_field)
	_save_button.pressed.connect(save_puzzle)
	_save_as_button.pressed.connect(_save_as_from_path_field)
	_validate_button.pressed.connect(validate_puzzle)
	_test_solution_button.pressed.connect(test_solution_positions)
	_solve_button.pressed.connect(solve_current_puzzle)
	_apply_first_solution_button.pressed.connect(apply_first_solution)
	_write_solution_button.pressed.connect(write_first_solution_positions)
	_generate_scene_button.pressed.connect(generate_test_scene)
	_palette.tool_selected.connect(_on_tool_selected)
	_palette.select_puzzle_requested.connect(_select_puzzle)
	_properties.property_changed.connect(_on_property_changed)
	_properties.action_requested.connect(_on_property_action_requested)
	_board_canvas.cell_action_requested.connect(_on_board_cell_action_requested)
	_board_canvas.port_action_requested.connect(_on_board_port_action_requested)
	_board_canvas.selection_requested.connect(_set_selection)
	_board_canvas.placement_move_requested.connect(_on_placement_move_requested)
	_board_canvas.placement_move_finished.connect(_on_placement_move_finished)
	_board_canvas.allowed_cell_toggled.connect(_on_allowed_cell_toggled)
	_board_canvas.status_requested.connect(_set_status)
	new_puzzle()


func _exit_tree() -> void:
	_restore_global_ui_layer()


func _suppress_global_ui_layer() -> void:
	var ui_layer := get_node_or_null("/root/UiLayer") as CanvasLayer
	if ui_layer == null:
		return
	_suppressed_ui_layer = ui_layer
	_ui_layer_was_visible = ui_layer.visible
	_ui_layer_process_mode = ui_layer.process_mode
	ui_layer.hide()
	ui_layer.process_mode = Node.PROCESS_MODE_DISABLED


func _restore_global_ui_layer() -> void:
	if _suppressed_ui_layer == null or not is_instance_valid(_suppressed_ui_layer):
		return
	_suppressed_ui_layer.process_mode = _ui_layer_process_mode
	_suppressed_ui_layer.visible = _ui_layer_was_visible
	_suppressed_ui_layer = null


func new_puzzle() -> void:
	draft_puzzle = LightPuzzleData.new()
	draft_puzzle.puzzle_id = "new_light_puzzle"
	draft_puzzle.title = "新建光板谜题"
	draft_puzzle.board_size = Vector2i(5, 5)
	draft_puzzle.max_beam_steps = 64
	save_path = _path_for_puzzle_id(draft_puzzle.puzzle_id)
	_load_path_edit.text = save_path
	current_mode = MODE_SELECT
	current_payload.clear()
	_clear_solver_result()
	_palette.set_active_tool(current_mode, current_payload)
	_set_selection(SELECTION_PUZZLE, -1)
	_refresh_all("已创建新的谜题草稿。")


func load_puzzle(path: String) -> void:
	var normalized_path := _normalize_save_path(path)
	var loaded := load(normalized_path)
	if loaded == null or not (loaded is LightPuzzleData):
		_set_status("无法载入光板谜题资源：%s" % normalized_path, true)
		return
	draft_puzzle = (loaded as LightPuzzleData).duplicate(true) as LightPuzzleData
	save_path = normalized_path
	_load_path_edit.text = save_path
	current_mode = MODE_SELECT
	current_payload.clear()
	_clear_solver_result()
	_palette.set_active_tool(current_mode, current_payload)
	_set_selection(SELECTION_PUZZLE, -1)
	_refresh_all("已从 %s 载入草稿副本。" % save_path)


func save_puzzle() -> void:
	if draft_puzzle == null:
		_set_status("没有可保存的谜题草稿。", true)
		return
	_apply_default_save_path()
	var validation := _validate()
	if not validation["ok"]:
		validation_cells = _cells_from_validation(validation)
		_refresh_canvas()
		_set_status("保存被阻止：%s" % _errors_from_validation(validation), true)
		return
	var error := ResourceSaver.save(draft_puzzle, save_path)
	if error != OK:
		_set_status("保存失败，错误码 %d：%s" % [error, save_path], true)
		return
	_set_status("已保存：%s" % save_path)
	_refresh_all()


func validate_puzzle() -> void:
	var validation := _validate()
	validation_cells = _cells_from_validation(validation)
	_refresh_canvas()
	if validation["ok"]:
		_set_status("验证通过。")
	else:
		_set_status("验证失败：%s" % _errors_from_validation(validation), true)


func test_solution_positions() -> void:
	if draft_puzzle == null:
		return
	var runtime := draft_puzzle.create_runtime_placements()
	for index in range(runtime.size()):
		var placement: Dictionary = runtime[index]
		var solution_position: Vector2i = placement.get("solution_position", Vector2i(-1, -1))
		if solution_position != Vector2i(-1, -1):
			placement["grid_position"] = solution_position
			runtime[index] = placement
	var result := LightBeamSolver.solve(draft_puzzle, runtime)
	if result.get("solved", false):
		_set_status("答案位置可以解开这个谜题。")
	else:
		_set_status("答案位置还不能解开这个谜题。", true)


func solve_current_puzzle() -> void:
	if draft_puzzle == null:
		return
	var validation := _validate()
	validation_cells = _cells_from_validation(validation)
	if not validation["ok"]:
		_refresh_canvas()
		_set_status("求解被阻止：%s" % _errors_from_validation(validation), true)
		return

	_set_status("正在求解...")
	solver_result = LightPuzzleVisualSolver.solve_visual(draft_puzzle, 1, 5.0)
	if int(solver_result.get("layout_solution_count", 0)) == 0:
		var visual_result := solver_result
		solver_result = LightPuzzleStateSolver.solve_reachable(draft_puzzle, 1, 250000, 10.0)
		solver_result["visual_solver_result"] = visual_result
	solver_preview_positions = solver_result.get("first_solution_positions", [])
	solver_preview_solution = _solution_for_positions(solver_preview_positions)
	_refresh_canvas()
	_refresh_properties()
	_update_solver_buttons()
	_set_status(_solver_status_text(), bool(solver_result.get("truncated", false)))


func apply_first_solution() -> void:
	if draft_puzzle == null or solver_preview_positions.is_empty():
		_set_status("没有可应用的求解结果。", true)
		return
	for index in range(mini(draft_puzzle.placements.size(), solver_preview_positions.size())):
		var placement := draft_puzzle.placements[index]
		if placement != null and placement.is_movable() and solver_preview_positions[index] is Vector2i:
			placement.grid_position = solver_preview_positions[index]
	_clear_solver_result()
	_refresh_all("已将首个求解结果应用到当前棋盘。")


func write_first_solution_positions() -> void:
	if draft_puzzle == null or solver_preview_positions.is_empty():
		_set_status("没有可写入的求解结果。", true)
		return
	for index in range(mini(draft_puzzle.placements.size(), solver_preview_positions.size())):
		var placement := draft_puzzle.placements[index]
		if placement != null and placement.is_movable() and solver_preview_positions[index] is Vector2i:
			placement.solution_position = solver_preview_positions[index]
	_refresh_all("已将首个求解结果写入答案位置。")


func generate_test_scene() -> void:
	if draft_puzzle == null:
		_set_status("没有可生成场景的谜题草稿。", true)
		return
	_apply_default_save_path()
	var validation := _validate()
	if not validation["ok"]:
		validation_cells = _cells_from_validation(validation)
		_refresh_canvas()
		_set_status("生成场景被阻止：%s" % _errors_from_validation(validation), true)
		return

	var save_error := ResourceSaver.save(draft_puzzle, save_path)
	if save_error != OK:
		_set_status("生成场景前保存资源失败，错误码 %d：%s" % [save_error, save_path], true)
		return

	var scene_path := _scene_path_for_resource(save_path)
	var scene_text := _build_test_scene_text(scene_path, save_path)
	var file := FileAccess.open(scene_path, FileAccess.WRITE)
	if file == null:
		_set_status("无法写入场景：%s，错误码 %d" % [scene_path, FileAccess.get_open_error()], true)
		return
	file.store_string(scene_text)
	file.close()

	_set_status("已生成测试场景：%s" % scene_path)
	_load_path_edit.text = save_path
	_refresh_all()


func _load_from_path_field() -> void:
	load_puzzle(_load_path_edit.text)


func _save_as_from_path_field() -> void:
	save_path = _normalize_save_path(_load_path_edit.text)
	save_puzzle()


func _on_tool_selected(mode: int, payload: Dictionary) -> void:
	current_mode = mode
	current_payload = payload.duplicate()
	_palette.set_active_tool(current_mode, current_payload)
	_refresh_all()
	if current_mode == MODE_EDIT_ALLOWED_CELLS and selection_kind != SELECTION_PLACEMENT:
		_set_status("请先选择一个棋子，再编辑可移动格。", true)


func _select_puzzle() -> void:
	_set_selection(SELECTION_PUZZLE, -1)


func _set_selection(kind: int, index: int) -> void:
	selection_kind = kind
	selection_index = index
	_refresh_all()


func _on_board_cell_action_requested(cell: Vector2i) -> void:
	_clear_solver_result()
	match current_mode:
		MODE_PLACE_PIECE, MODE_PLACE_BLOCK:
			_add_placement(cell, int(current_payload.get("piece_type", LightPuzzleConstants.PieceType.MIRROR_SLASH)))
	_refresh_all()


func _on_board_port_action_requested(cell: Vector2i, direction: int) -> void:
	_clear_solver_result()
	match current_mode:
		MODE_PLACE_SOURCE:
			_add_port(cell, true, int(current_payload.get("color_mask", LightPuzzleConstants.COLOR_WHITE)), direction)
		MODE_PLACE_EXIT:
			_add_port(cell, false, int(current_payload.get("color_mask", LightPuzzleConstants.COLOR_RED)), direction)
	_refresh_all()


func _on_placement_move_requested(placement_index: int, target_cell: Vector2i) -> void:
	_clear_solver_result()
	_move_placement(placement_index, target_cell, false)


func _on_placement_move_finished(placement_index: int, target_cell: Vector2i) -> void:
	_clear_solver_result()
	_move_placement(placement_index, target_cell, false)
	_set_selection(SELECTION_PLACEMENT, placement_index)


func _on_allowed_cell_toggled(cell: Vector2i) -> void:
	if selection_kind != SELECTION_PLACEMENT:
		_set_status("请先选择一个棋子，再编辑可移动格。", true)
		return
	var placement := _get_selected_placement()
	if placement == null:
		return
	if placement.allowed_cells.has(cell):
		placement.allowed_cells.erase(cell)
	else:
		placement.allowed_cells.append(cell)
	_clear_solver_result()
	_refresh_all()


func _on_property_changed(field: String, value: Variant) -> void:
	if draft_puzzle == null:
		return
	match selection_kind:
		SELECTION_PUZZLE:
			_apply_puzzle_property(field, value)
		SELECTION_SOURCE:
			_apply_port_property(_get_selected_port(true), field, value)
		SELECTION_EXIT:
			_apply_port_property(_get_selected_port(false), field, value)
		SELECTION_PLACEMENT:
			_apply_placement_property(_get_selected_placement(), field, value)
	validation_cells.clear()
	_clear_solver_result()
	_refresh_all()


func _on_property_action_requested(action: String) -> void:
	match action:
		"delete_selected":
			_delete_selected()
		"clear_allowed_cells":
			var placement := _get_selected_placement()
			if placement != null:
				placement.allowed_cells.clear()
	_clear_solver_result()
	_refresh_all()


func _apply_puzzle_property(field: String, value: Variant) -> void:
	match field:
		"puzzle_id":
			draft_puzzle.puzzle_id = str(value).strip_edges()
			if save_path == "" or save_path == SAVE_ROOT + "new_light_puzzle.tres":
				save_path = _path_for_puzzle_id(draft_puzzle.puzzle_id)
				_load_path_edit.text = save_path
		"title":
			draft_puzzle.title = str(value)
		"board_size":
			draft_puzzle.board_size = _clamp_board_size(_to_vector2i(value))
		"max_beam_steps":
			draft_puzzle.max_beam_steps = max(1, int(value))
		"designer_notes":
			draft_puzzle.designer_notes = str(value)
		"save_path":
			save_path = _normalize_save_path(str(value))
			_load_path_edit.text = save_path


func _apply_port_property(port: LightPortData, field: String, value: Variant) -> void:
	if port == null:
		return
	match field:
		"port_id":
			port.port_id = str(value).strip_edges()
		"cell":
			port.cell = _clamp_cell(_to_vector2i(value))
		"direction":
			port.direction = clampi(int(value), 0, 7)
		"color_mask":
			port.color_mask = int(value)
		"requires_exact_color":
			port.requires_exact_color = bool(value)


func _apply_placement_property(placement: LightPiecePlacement, field: String, value: Variant) -> void:
	if placement == null:
		return
	var piece := placement.piece
	match field:
		"placement_id":
			placement.placement_id = str(value).strip_edges()
			if piece != null:
				piece.piece_id = placement.placement_id
		"grid_position":
			var move_target_cell := _clamp_piece_cell(placement, _to_vector2i(value))
			var move_placement_index := draft_puzzle.placements.find(placement)
			if _placement_overlaps_at(placement, move_target_cell, move_placement_index):
				_set_status("目标位置已有棋子，未移动。", true)
			else:
				placement.grid_position = move_target_cell
		"locked":
			placement.locked = bool(value)
		"solution_position":
			placement.solution_position = _to_vector2i(value)
		"piece_type":
			if piece != null:
				piece.piece_type = clampi(int(value), 0, PIECE_TYPE_MAX)
				_apply_piece_defaults(piece)
		"size":
			if piece != null:
				var original_size := piece.size
				var target_size := _clamp_piece_size(_to_vector2i(value))
				piece.size = target_size
				var resize_target_cell := _clamp_piece_cell(placement, placement.grid_position)
				var resize_placement_index := draft_puzzle.placements.find(placement)
				if _placement_overlaps_at(placement, resize_target_cell, resize_placement_index):
					piece.size = original_size
					_set_status("调整尺寸会与其他棋子重叠，已取消。", true)
				else:
					placement.grid_position = resize_target_cell
		"move_axis":
			if piece != null:
				piece.move_axis = clampi(int(value), 0, MOVE_AXIS_MAX)
		"is_draggable":
			if piece != null:
				piece.is_draggable = bool(value)
		"filter_mask":
			if piece != null:
				piece.filter_mask = int(value)


func _add_port(cell: Vector2i, source: bool, color_mask: int, direction: int = -1) -> void:
	var port := LightPortData.new()
	port.kind = LightPuzzleConstants.PortKind.SOURCE if source else LightPuzzleConstants.PortKind.EXIT
	port.cell = _clamp_cell(cell)
	port.color_mask = color_mask
	port.requires_exact_color = true
	port.direction = clampi(direction, 0, 7) if direction != -1 else _default_direction_for_port(port.cell, source)
	port.port_id = _unique_id(_default_port_id(port, source), _all_ids())
	if source:
		draft_puzzle.sources.append(port)
		_set_selection(SELECTION_SOURCE, draft_puzzle.sources.size() - 1)
	else:
		draft_puzzle.exits.append(port)
		_set_selection(SELECTION_EXIT, draft_puzzle.exits.size() - 1)


func _add_placement(cell: Vector2i, piece_type: int) -> void:
	var piece := LightPieceData.new()
	piece.piece_type = piece_type
	_apply_piece_defaults(piece)

	var placement := LightPiecePlacement.new()
	placement.piece = piece
	placement.grid_position = _clamp_piece_cell(placement, cell)
	if _placement_overlaps_at(placement, placement.grid_position):
		_set_status("该位置已有棋子，未放置；拖动可移动已有棋子。", true)
		return
	var base_id := _piece_base_id(piece_type)
	placement.placement_id = _unique_id(base_id, _all_ids())
	piece.piece_id = placement.placement_id
	piece.display_name = _piece_display_name(piece_type)
	piece.asset_key = base_id
	if piece_type == LightPuzzleConstants.PieceType.GLASS_BLOCK or piece_type == LightPuzzleConstants.PieceType.OPAQUE_BLOCK:
		placement.locked = true
	draft_puzzle.placements.append(placement)
	_set_selection(SELECTION_PLACEMENT, draft_puzzle.placements.size() - 1)


func _move_placement(placement_index: int, target_cell: Vector2i, refresh_properties: bool = true) -> void:
	if draft_puzzle == null or placement_index < 0 or placement_index >= draft_puzzle.placements.size():
		return
	var placement := draft_puzzle.placements[placement_index]
	if placement == null:
		return
	var clamped_cell := _clamp_piece_cell(placement, target_cell)
	if _placement_overlaps_at(placement, clamped_cell, placement_index):
		_set_status("目标位置已有棋子，未移动。", true)
		return
	placement.grid_position = clamped_cell
	_recompute_solution()
	_refresh_canvas()
	_update_solution_label()
	if refresh_properties:
		_refresh_properties()


func _delete_selected() -> void:
	match selection_kind:
		SELECTION_SOURCE:
			if selection_index >= 0 and selection_index < draft_puzzle.sources.size():
				draft_puzzle.sources.remove_at(selection_index)
		SELECTION_EXIT:
			if selection_index >= 0 and selection_index < draft_puzzle.exits.size():
				draft_puzzle.exits.remove_at(selection_index)
		SELECTION_PLACEMENT:
			if selection_index >= 0 and selection_index < draft_puzzle.placements.size():
				draft_puzzle.placements.remove_at(selection_index)
	selection_kind = SELECTION_PUZZLE
	selection_index = -1
	_clear_solver_result()


func _refresh_all(status_text: String = "") -> void:
	_recompute_solution()
	_refresh_properties()
	_refresh_canvas()
	_update_solver_buttons()
	if status_text != "":
		_set_status(status_text)
	else:
		_update_solution_label()


func _refresh_canvas() -> void:
	_board_canvas.set_author_state(
		draft_puzzle,
		_solution_for_canvas(),
		current_mode,
		selection_kind,
		selection_index,
		validation_cells,
		solver_preview_positions
	)


func _refresh_properties() -> void:
	_properties.show_context(selection_kind, selection_index, draft_puzzle, save_path)


func _recompute_solution() -> void:
	if draft_puzzle == null:
		solution = {}
		return
	solution = LightBeamSolver.solve(draft_puzzle, draft_puzzle.create_runtime_placements())


func _solution_for_canvas() -> Dictionary:
	if not solver_preview_solution.is_empty():
		return solver_preview_solution
	return solution


func _solution_for_positions(positions: Array) -> Dictionary:
	if draft_puzzle == null or positions.is_empty():
		return {}
	var runtime := draft_puzzle.create_runtime_placements()
	for index in range(mini(runtime.size(), positions.size())):
		if not (positions[index] is Vector2i):
			continue
		var placement: Dictionary = runtime[index]
		placement["grid_position"] = positions[index]
		runtime[index] = placement
	return LightBeamSolver.solve(draft_puzzle, runtime)


func _update_solution_label() -> void:
	var preview_solved := bool(solver_preview_solution.get("solved", false))
	var state := "首解预览" if preview_solved else ("已解开" if solution.get("solved", false) else "追踪中")
	_solution_label.text = state
	_solution_label.add_theme_color_override(
		"font_color",
		Color(0.55, 1.0, 0.62) if preview_solved or solution.get("solved", false) else Color(0.86, 0.89, 0.95)
	)


func _set_status(message: String, is_error: bool = false) -> void:
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.38) if is_error else Color(0.78, 0.88, 1.0))
	_update_solution_label()


func _clear_solver_result() -> void:
	solver_result = {}
	solver_preview_positions.clear()
	solver_preview_solution = {}
	_update_solver_buttons()


func _update_solver_buttons() -> void:
	if not is_inside_tree():
		return
	var has_solution_preview := not solver_preview_positions.is_empty()
	_apply_first_solution_button.disabled = not has_solution_preview
	_write_solution_button.disabled = not has_solution_preview


func _solver_status_text() -> String:
	if solver_result.is_empty():
		return ""
	if solver_result.has("visited_routes"):
		return _visual_solver_status_text()
	var visited := int(solver_result.get("visited_states", 0))
	var labelled := int(solver_result.get("labelled_solution_count", 0))
	var visual := int(solver_result.get("visual_solution_count", 0))
	if bool(solver_result.get("truncated", false)):
		return "求解未完成：%s，已搜索 %d 个状态，当前 %d 个视觉解 / %d 个标号解" % [
			str(solver_result.get("truncated_reason", "")),
			visited,
			visual,
			labelled,
		]
	if visual == 0:
		return "求解完成：无解，已搜索 %d 个状态" % visited
	if visual == 1:
		return "求解完成：唯一解，%d 个标号解，已搜索 %d 个状态" % [labelled, visited]
	return "求解完成：非唯一，%d 个视觉解 / %d 个标号解，已搜索 %d 个状态" % [visual, labelled, visited]


func _visual_solver_status_text() -> String:
	var visited := int(solver_result.get("visited_routes", 0))
	var optical := int(solver_result.get("optical_solution_count", 0))
	var layouts := int(solver_result.get("layout_solution_count", 0))
	if bool(solver_result.get("truncated", false)):
		return "视觉求解未完成：%s，已搜索 %d 条视觉路线，当前 %d 个光学解 / %d 个完整摆法" % [
			str(solver_result.get("truncated_reason", "")),
			visited,
			optical,
			layouts,
		]
	if layouts == 0:
		return "视觉求解完成：无完整摆法，找到 %d 个光学路线，已搜索 %d 条视觉路线" % [optical, visited]
	if optical == 1:
		return "视觉求解完成：唯一视觉解，%d 个完整摆法，已搜索 %d 条视觉路线" % [layouts, visited]
	return "视觉求解完成：非唯一，%d 个光学解 / %d 个完整摆法，已搜索 %d 条视觉路线" % [optical, layouts, visited]


func _validate() -> Dictionary:
	var errors: Array[String] = []
	var cells: Array[Vector2i] = []
	if draft_puzzle == null:
		return {"ok": false, "errors": ["没有谜题草稿"], "cells": cells}

	if draft_puzzle.puzzle_id.strip_edges() == "":
		errors.append("必须填写谜题 ID")
	if draft_puzzle.sources.is_empty():
		errors.append("至少需要一个光源")
	if draft_puzzle.exits.is_empty():
		errors.append("至少需要一个出口")
	if not save_path.begins_with(SAVE_ROOT):
		errors.append("保存路径必须位于 %s 内" % SAVE_ROOT)
	if not save_path.ends_with(".tres"):
		errors.append("保存路径必须以 .tres 结尾")

	for port in draft_puzzle.sources:
		if port == null:
			errors.append("光源列表包含空数据")
			continue
		if not _is_cell_inside(port.cell):
			errors.append("光源 %s 超出棋盘范围" % port.port_id)
			cells.append(port.cell)
		elif not _source_points_inside(port):
			errors.append("光源 %s 必须位于边框，并且方向从边框射入棋盘" % port.port_id)
			cells.append(port.cell)

	for port in draft_puzzle.exits:
		if port == null:
			errors.append("出口列表包含空数据")
			continue
		if not _is_cell_inside(port.cell):
			errors.append("出口 %s 超出棋盘范围" % port.port_id)
			cells.append(port.cell)
		elif not _exit_points_outside(port):
			errors.append("出口 %s 必须位于边框，并且方向指向棋盘外" % port.port_id)
			cells.append(port.cell)

	var occupied: Dictionary = {}
	for index in range(draft_puzzle.placements.size()):
		var placement := draft_puzzle.placements[index]
		if placement == null or placement.piece == null:
			errors.append("第 %d 个放置项缺少棋子数据" % index)
			continue
		if not _piece_inside_board(placement):
			errors.append("棋子 %s 超出棋盘范围" % placement.placement_id)
			cells.append(placement.grid_position)
		if not placement.allowed_cells.is_empty() and not placement.allowed_cells.has(placement.grid_position):
			errors.append("棋子 %s 的可移动格必须包含初始位置" % placement.placement_id)
			cells.append(placement.grid_position)
		for y in range(placement.piece.size.y):
			for x in range(placement.piece.size.x):
				var cell := placement.grid_position + Vector2i(x, y)
				var key := _cell_key(cell)
				if occupied.has(key):
					errors.append("棋子 %s 在 %s 与其他棋子重叠" % [placement.placement_id, key])
					cells.append(cell)
				occupied[key] = true

	return {"ok": errors.is_empty(), "errors": errors, "cells": cells}


func _apply_default_save_path() -> void:
	if save_path.strip_edges() == "":
		save_path = _path_for_puzzle_id(draft_puzzle.puzzle_id)
	_load_path_edit.text = save_path


func _normalize_save_path(path: String) -> String:
	var stripped := path.strip_edges()
	if stripped == "":
		return _path_for_puzzle_id(draft_puzzle.puzzle_id if draft_puzzle != null else "new_light_puzzle")
	if not stripped.begins_with("res://"):
		stripped = SAVE_ROOT + stripped.get_file()
	if not stripped.ends_with(".tres"):
		stripped += ".tres"
	return stripped


func _scene_path_for_resource(resource_path: String) -> String:
	return GENERATED_SCENE_ROOT + resource_path.get_basename().get_file() + ".tscn"


func _build_test_scene_text(scene_path: String, puzzle_resource_path: String) -> String:
	var board_uid := ResourceLoader.get_resource_uid(LIGHT_BOARD_SCENE_PATH)
	var puzzle_uid := ResourceLoader.get_resource_uid(puzzle_resource_path)
	var scene_uid := ResourceLoader.get_resource_uid(scene_path)
	var scene_header := "[gd_scene load_steps=3 format=3"
	if scene_uid != ResourceUID.INVALID_ID:
		scene_header += ' uid="%s"' % ResourceUID.id_to_text(scene_uid)
	scene_header += "]"

	var board_resource := '[ext_resource type="PackedScene"'
	if board_uid != ResourceUID.INVALID_ID:
		board_resource += ' uid="%s"' % ResourceUID.id_to_text(board_uid)
	board_resource += ' path="%s" id="1_board"]' % LIGHT_BOARD_SCENE_PATH

	var puzzle_resource := '[ext_resource type="Resource"'
	if puzzle_uid != ResourceUID.INVALID_ID:
		puzzle_resource += ' uid="%s"' % ResourceUID.id_to_text(puzzle_uid)
	puzzle_resource += ' path="%s" id="2_puzzle"]' % puzzle_resource_path

	return "\n".join([
		scene_header,
		"",
		board_resource,
		puzzle_resource,
		"",
		'[node name="%s" instance=ExtResource("1_board")]' % scene_path.get_basename().get_file(),
		'puzzle_data = ExtResource("2_puzzle")',
		'pause_world_while_open = false',
		'open_on_ready = true',
		"",
	])


func _path_for_puzzle_id(puzzle_id: String) -> String:
	var file_id := puzzle_id.strip_edges()
	if file_id == "":
		file_id = "new_light_puzzle"
	return SAVE_ROOT + file_id + ".tres"


func _get_selected_port(source: bool) -> LightPortData:
	if draft_puzzle == null:
		return null
	var ports: Array[LightPortData] = draft_puzzle.sources if source else draft_puzzle.exits
	if selection_index < 0 or selection_index >= ports.size():
		return null
	return ports[selection_index]


func _get_selected_placement() -> LightPiecePlacement:
	if draft_puzzle == null or selection_index < 0 or selection_index >= draft_puzzle.placements.size():
		return null
	return draft_puzzle.placements[selection_index]


func _clamp_board_size(value: Vector2i) -> Vector2i:
	return Vector2i(clampi(value.x, 1, 12), clampi(value.y, 1, 12))


func _clamp_cell(cell: Vector2i) -> Vector2i:
	if draft_puzzle == null:
		return cell
	return Vector2i(
		clampi(cell.x, 0, max(0, draft_puzzle.board_size.x - 1)),
		clampi(cell.y, 0, max(0, draft_puzzle.board_size.y - 1))
	)


func _clamp_piece_cell(placement: LightPiecePlacement, cell: Vector2i) -> Vector2i:
	if draft_puzzle == null or placement == null or placement.piece == null:
		return _clamp_cell(cell)
	return Vector2i(
		clampi(cell.x, 0, max(0, draft_puzzle.board_size.x - placement.piece.size.x)),
		clampi(cell.y, 0, max(0, draft_puzzle.board_size.y - placement.piece.size.y))
	)


func _clamp_piece_size(value: Vector2i) -> Vector2i:
	return Vector2i(clampi(value.x, 1, 4), clampi(value.y, 1, 4))


func _to_vector2i(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(roundi(value.x), roundi(value.y))
	return Vector2i.ZERO


func _is_cell_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < draft_puzzle.board_size.x and cell.y < draft_puzzle.board_size.y


func _piece_inside_board(placement: LightPiecePlacement) -> bool:
	if placement == null or placement.piece == null:
		return false
	return (
		placement.grid_position.x >= 0
		and placement.grid_position.y >= 0
		and placement.grid_position.x + placement.piece.size.x <= draft_puzzle.board_size.x
		and placement.grid_position.y + placement.piece.size.y <= draft_puzzle.board_size.y
	)


func _placement_overlaps_at(placement: LightPiecePlacement, target_cell: Vector2i, ignored_index: int = -1) -> bool:
	if draft_puzzle == null or placement == null or placement.piece == null:
		return false
	var placement_rect := Rect2i(target_cell, placement.piece.size)
	for index in range(draft_puzzle.placements.size()):
		if index == ignored_index:
			continue
		var other := draft_puzzle.placements[index]
		if other == null or other.piece == null:
			continue
		var other_rect := Rect2i(other.grid_position, other.piece.size)
		if placement_rect.intersects(other_rect):
			return true
	return false


func _exit_points_outside(port: LightPortData) -> bool:
	var next_cell := port.cell + LightPuzzleConstants.direction_vector(port.direction)
	return _is_cell_inside(port.cell) and not _is_cell_inside(next_cell)


func _source_points_inside(port: LightPortData) -> bool:
	var outside_cell := port.cell - LightPuzzleConstants.direction_vector(port.direction)
	return _is_cell_inside(port.cell) and not _is_cell_inside(outside_cell)


func _default_direction_for_port(cell: Vector2i, source: bool) -> int:
	if draft_puzzle == null:
		return LightPuzzleConstants.Direction.E
	if cell.x <= 0:
		return LightPuzzleConstants.Direction.E if source else LightPuzzleConstants.Direction.W
	if cell.x >= draft_puzzle.board_size.x - 1:
		return LightPuzzleConstants.Direction.W if source else LightPuzzleConstants.Direction.E
	if cell.y <= 0:
		return LightPuzzleConstants.Direction.S if source else LightPuzzleConstants.Direction.N
	if cell.y >= draft_puzzle.board_size.y - 1:
		return LightPuzzleConstants.Direction.N if source else LightPuzzleConstants.Direction.S
	return LightPuzzleConstants.Direction.E


func _default_port_id(port: LightPortData, source: bool) -> String:
	var prefix := "source" if source else "exit"
	var side := _port_side_name(port, source)
	match side:
		"left", "right":
			return "%s_%s_y%d" % [prefix, side, port.cell.y]
		"top", "bottom":
			return "%s_%s_x%d" % [prefix, side, port.cell.x]
		"corner_nw", "corner_ne", "corner_sw", "corner_se":
			return "%s_%s" % [prefix, side]
	return "%s_cell_x%d_y%d" % [prefix, port.cell.x, port.cell.y]


func _port_side_name(port: LightPortData, source: bool) -> String:
	if draft_puzzle == null:
		return "cell"
	var direction_vec := LightPuzzleConstants.direction_vector(port.direction)
	var outside_cell := port.cell - direction_vec
	if not source:
		outside_cell = port.cell + direction_vec
	var outside_left := outside_cell.x < 0
	var outside_right := outside_cell.x >= draft_puzzle.board_size.x
	var outside_top := outside_cell.y < 0
	var outside_bottom := outside_cell.y >= draft_puzzle.board_size.y
	if outside_left and outside_top:
		return "corner_nw"
	if outside_right and outside_top:
		return "corner_ne"
	if outside_left and outside_bottom:
		return "corner_sw"
	if outside_right and outside_bottom:
		return "corner_se"
	if outside_left:
		return "left"
	if outside_right:
		return "right"
	if outside_top:
		return "top"
	if outside_bottom:
		return "bottom"
	return "cell"


func _apply_piece_defaults(piece: LightPieceData) -> void:
	piece.size = _clamp_piece_size(piece.size)
	piece.display_name = _piece_display_name(piece.piece_type)
	piece.asset_key = _piece_base_id(piece.piece_type)
	match piece.piece_type:
		LightPuzzleConstants.PieceType.FILTER_RED:
			piece.filter_mask = LightPuzzleConstants.COLOR_RED
		LightPuzzleConstants.PieceType.FILTER_GREEN:
			piece.filter_mask = LightPuzzleConstants.COLOR_GREEN
		LightPuzzleConstants.PieceType.FILTER_BLUE:
			piece.filter_mask = LightPuzzleConstants.COLOR_BLUE
		LightPuzzleConstants.PieceType.FILTER_YELLOW:
			piece.filter_mask = LightPuzzleConstants.COLOR_YELLOW
		LightPuzzleConstants.PieceType.FILTER_CYAN:
			piece.filter_mask = LightPuzzleConstants.COLOR_CYAN
		LightPuzzleConstants.PieceType.FILTER_MAGENTA:
			piece.filter_mask = LightPuzzleConstants.COLOR_MAGENTA
		_:
			piece.filter_mask = LightPuzzleConstants.COLOR_WHITE
	if piece.piece_type == LightPuzzleConstants.PieceType.GLASS_BLOCK or piece.piece_type == LightPuzzleConstants.PieceType.OPAQUE_BLOCK:
		piece.move_axis = LightPuzzleConstants.MoveAxis.LOCKED
		piece.is_draggable = false
	else:
		piece.move_axis = LightPuzzleConstants.MoveAxis.BOTH
		piece.is_draggable = true


func _piece_base_id(piece_type: int) -> String:
	match piece_type:
		LightPuzzleConstants.PieceType.MIRROR_SLASH:
			return "mirror_slash"
		LightPuzzleConstants.PieceType.MIRROR_BACKSLASH:
			return "mirror_backslash"
		LightPuzzleConstants.PieceType.PLANE_MIRROR_HORIZONTAL:
			return "plane_mirror_horizontal"
		LightPuzzleConstants.PieceType.PLANE_MIRROR_VERTICAL:
			return "plane_mirror_vertical"
		LightPuzzleConstants.PieceType.PRISM_PLUS_45:
			return "prism_plus_45"
		LightPuzzleConstants.PieceType.PRISM_MINUS_45:
			return "prism_minus_45"
		LightPuzzleConstants.PieceType.FILTER_RED:
			return "filter_red"
		LightPuzzleConstants.PieceType.FILTER_GREEN:
			return "filter_green"
		LightPuzzleConstants.PieceType.FILTER_BLUE:
			return "filter_blue"
		LightPuzzleConstants.PieceType.FILTER_YELLOW:
			return "filter_yellow"
		LightPuzzleConstants.PieceType.FILTER_CYAN:
			return "filter_cyan"
		LightPuzzleConstants.PieceType.FILTER_MAGENTA:
			return "filter_magenta"
		LightPuzzleConstants.PieceType.GLASS_BLOCK:
			return "glass_block"
		LightPuzzleConstants.PieceType.OPAQUE_BLOCK:
			return "opaque_block"
	return "piece"


func _piece_display_name(piece_type: int) -> String:
	match piece_type:
		LightPuzzleConstants.PieceType.MIRROR_SLASH:
			return "斜杠镜"
		LightPuzzleConstants.PieceType.MIRROR_BACKSLASH:
			return "反斜杠镜"
		LightPuzzleConstants.PieceType.PLANE_MIRROR_HORIZONTAL:
			return "水平平面镜"
		LightPuzzleConstants.PieceType.PLANE_MIRROR_VERTICAL:
			return "垂直平面镜"
		LightPuzzleConstants.PieceType.PRISM_PLUS_45:
			return "+45 棱镜"
		LightPuzzleConstants.PieceType.PRISM_MINUS_45:
			return "-45 棱镜"
		LightPuzzleConstants.PieceType.FILTER_RED:
			return "红色滤镜"
		LightPuzzleConstants.PieceType.FILTER_GREEN:
			return "绿色滤镜"
		LightPuzzleConstants.PieceType.FILTER_BLUE:
			return "蓝色滤镜"
		LightPuzzleConstants.PieceType.FILTER_YELLOW:
			return "黄色滤镜"
		LightPuzzleConstants.PieceType.FILTER_CYAN:
			return "青色滤镜"
		LightPuzzleConstants.PieceType.FILTER_MAGENTA:
			return "品红滤镜"
		LightPuzzleConstants.PieceType.GLASS_BLOCK:
			return "玻璃障碍"
		LightPuzzleConstants.PieceType.OPAQUE_BLOCK:
			return "不透明障碍"
	return "棋子"


func _all_ids() -> Array[String]:
	var ids: Array[String] = []
	if draft_puzzle == null:
		return ids
	for port in draft_puzzle.sources:
		if port != null and port.port_id != "":
			ids.append(port.port_id)
	for port in draft_puzzle.exits:
		if port != null and port.port_id != "":
			ids.append(port.port_id)
	for placement in draft_puzzle.placements:
		if placement != null:
			if placement.placement_id != "":
				ids.append(placement.placement_id)
			if placement.piece != null and placement.piece.piece_id != "":
				ids.append(placement.piece.piece_id)
	return ids


func _unique_id(base: String, used: Array[String]) -> String:
	if not used.has(base):
		return base
	var counter := 1
	while true:
		var candidate := "%s_%03d" % [base, counter]
		if not used.has(candidate):
			return candidate
		counter += 1
	return base


func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


func _errors_from_validation(validation: Dictionary) -> String:
	var raw_errors: Array = validation.get("errors", [])
	var output := ""
	for index in range(raw_errors.size()):
		if index > 0:
			output += "; "
		output += str(raw_errors[index])
	return output


func _cells_from_validation(validation: Dictionary) -> Array[Vector2i]:
	var raw_cells: Array = validation.get("cells", [])
	var cells: Array[Vector2i] = []
	for cell in raw_cells:
		if cell is Vector2i:
			cells.append(cell)
	return cells
