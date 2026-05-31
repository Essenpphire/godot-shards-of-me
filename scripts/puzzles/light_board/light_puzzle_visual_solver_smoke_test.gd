extends SceneTree


func _init() -> void:
	var failures: Array[String] = []
	_expect_hard_02_solves(failures)
	_expect_diagonal_active_move_is_rejected(failures)
	_expect_intermediate_color_filter_is_allowed(failures)
	_expect_decoy_pieces_do_not_inflate_optical_count(failures)
	_expect_duplicate_roles_do_not_inflate_optical_count(failures)
	_expect_no_safe_parking_rejects_layout(failures)

	if failures.is_empty():
		print("Light puzzle visual solver smoke test passed.")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)


func _expect_hard_02_solves(failures: Array[String]) -> void:
	var puzzle := load("res://resources/puzzles/light_board/hard_02.tres") as LightPuzzleData
	if puzzle == null:
		failures.append("hard_02.tres did not load")
		return
	var result := LightPuzzleVisualSolver.solve_visual(puzzle, 8, 5.0)
	_expect_solution("hard_02", result, failures)


func _expect_diagonal_active_move_is_rejected(failures: Array[String]) -> void:
	var puzzle := _new_line_puzzle(
		[
			_placement("source_glass", LightPuzzleConstants.PieceType.GLASS_BLOCK, Vector2i(0, 0), false),
			_placement("green", LightPuzzleConstants.PieceType.FILTER_GREEN, Vector2i(0, 1), true),
		],
		Vector2i(2, 2)
	)
	var result := LightPuzzleVisualSolver.solve_visual(puzzle, 8, 5.0)
	if int(result.get("layout_solution_count", 0)) != 0:
		failures.append("diagonal active move expected 0 layout solutions, got %d" % int(result.get("layout_solution_count", 0)))


func _expect_intermediate_color_filter_is_allowed(failures: Array[String]) -> void:
	var puzzle := _new_line_puzzle(
		[
			_placement("red", LightPuzzleConstants.PieceType.FILTER_RED, Vector2i(1, 0), false),
			_placement("green", LightPuzzleConstants.PieceType.FILTER_GREEN, Vector2i(2, 1), true),
		],
		Vector2i(4, 2)
	)
	var result := LightPuzzleVisualSolver.solve_visual(puzzle, 8, 5.0)
	_expect_solution("intermediate red then green", result, failures)
	if int(result.get("optical_solution_count", 0)) != 1:
		failures.append("intermediate color expected 1 optical solution, got %d" % int(result.get("optical_solution_count", 0)))


func _expect_decoy_pieces_do_not_inflate_optical_count(failures: Array[String]) -> void:
	var puzzle := _new_line_puzzle(
		[
			_placement("green", LightPuzzleConstants.PieceType.FILTER_GREEN, Vector2i(2, 0), true),
			_placement("decoy_red", LightPuzzleConstants.PieceType.FILTER_RED, Vector2i(0, 1), true),
			_placement("decoy_mirror", LightPuzzleConstants.PieceType.MIRROR_SLASH, Vector2i(2, 1), true),
		],
		Vector2i(3, 2)
	)
	var result := LightPuzzleVisualSolver.solve_visual(puzzle, 8, 5.0)
	_expect_solution("decoy pieces", result, failures)
	if int(result.get("optical_solution_count", 0)) != 1:
		failures.append("decoys expected 1 optical solution, got %d" % int(result.get("optical_solution_count", 0)))


func _expect_duplicate_roles_do_not_inflate_optical_count(failures: Array[String]) -> void:
	var puzzle := _new_line_puzzle(
		[
			_placement("green_a", LightPuzzleConstants.PieceType.FILTER_GREEN, Vector2i(0, 1), true),
			_placement("green_b", LightPuzzleConstants.PieceType.FILTER_GREEN, Vector2i(2, 1), true),
		],
		Vector2i(3, 2)
	)
	var result := LightPuzzleVisualSolver.solve_visual(puzzle, 8, 5.0)
	_expect_solution("duplicate green roles", result, failures)
	if int(result.get("optical_solution_count", 0)) != 1:
		failures.append("duplicate roles expected 1 optical solution, got %d" % int(result.get("optical_solution_count", 0)))
	if int(result.get("layout_solution_count", 0)) < 1:
		failures.append("duplicate roles expected at least 1 layout solution")


func _expect_no_safe_parking_rejects_layout(failures: Array[String]) -> void:
	var puzzle := _new_line_puzzle(
		[
			_placement("green", LightPuzzleConstants.PieceType.FILTER_GREEN, Vector2i(1, 0), true),
			_placement("opaque_decoy", LightPuzzleConstants.PieceType.OPAQUE_BLOCK, Vector2i(0, 0), true),
			_placement("glass_lock_0", LightPuzzleConstants.PieceType.GLASS_BLOCK, Vector2i(0, 1), false),
			_placement("glass_lock", LightPuzzleConstants.PieceType.GLASS_BLOCK, Vector2i(1, 1), false),
			_placement("glass_lock_2", LightPuzzleConstants.PieceType.GLASS_BLOCK, Vector2i(2, 1), false),
		],
		Vector2i(3, 2)
	)
	var result := LightPuzzleVisualSolver.solve_visual(puzzle, 8, 5.0)
	if int(result.get("layout_solution_count", 0)) != 0:
		failures.append("no safe parking expected 0 layout solutions, got %d" % int(result.get("layout_solution_count", 0)))


func _expect_solution(label: String, result: Dictionary, failures: Array[String]) -> void:
	if bool(result.get("truncated", false)):
		failures.append("%s truncated: %s" % [label, str(result.get("truncated_reason", ""))])
	if int(result.get("optical_solution_count", 0)) <= 0:
		failures.append("%s expected an optical solution" % label)
	if int(result.get("layout_solution_count", 0)) <= 0:
		failures.append("%s expected a layout solution" % label)
	if (result.get("first_solution_positions", []) as Array).is_empty():
		failures.append("%s expected first solution positions" % label)


func _new_line_puzzle(placements: Array[LightPiecePlacement], board_size: Vector2i) -> LightPuzzleData:
	var puzzle := LightPuzzleData.new()
	puzzle.puzzle_id = "visual_solver_test"
	puzzle.title = "Visual Solver Test"
	puzzle.board_size = board_size
	puzzle.max_beam_steps = 32
	puzzle.sources = [_port("source_left_y0", LightPuzzleConstants.PortKind.SOURCE, Vector2i(0, 0), LightPuzzleConstants.Direction.E, LightPuzzleConstants.COLOR_WHITE)]
	puzzle.exits = [_port("exit_right_y0", LightPuzzleConstants.PortKind.EXIT, Vector2i(board_size.x - 1, 0), LightPuzzleConstants.Direction.E, LightPuzzleConstants.COLOR_GREEN)]
	puzzle.placements = placements
	return puzzle


func _port(port_id: String, kind: int, cell: Vector2i, direction: int, color_mask: int) -> LightPortData:
	var port := LightPortData.new()
	port.port_id = port_id
	port.kind = kind
	port.cell = cell
	port.direction = direction
	port.color_mask = color_mask
	port.requires_exact_color = true
	return port


func _placement(placement_id: String, piece_type: int, cell: Vector2i, movable: bool) -> LightPiecePlacement:
	var piece := LightPieceData.new()
	piece.piece_id = placement_id
	piece.display_name = placement_id
	piece.piece_type = piece_type
	piece.size = Vector2i.ONE
	piece.move_axis = LightPuzzleConstants.MoveAxis.BOTH if movable else LightPuzzleConstants.MoveAxis.LOCKED
	piece.is_draggable = movable
	piece.filter_mask = LightPuzzleConstants.COLOR_WHITE
	piece.asset_key = placement_id
	match piece_type:
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

	var placement := LightPiecePlacement.new()
	placement.placement_id = placement_id
	placement.piece = piece
	placement.grid_position = cell
	placement.locked = not movable
	return placement
