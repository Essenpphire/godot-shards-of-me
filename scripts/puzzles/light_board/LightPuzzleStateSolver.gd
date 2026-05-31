class_name LightPuzzleStateSolver
extends RefCounted

const DEFAULT_MAX_STATES: int = 100000000
const DEFAULT_MAX_SECONDS: float = 60.0
const DEFAULT_SAMPLE_LIMIT: int = 12


static func solve_reachable(
	puzzle_data: LightPuzzleData,
	max_solutions: int = 0,
	max_states: int = DEFAULT_MAX_STATES,
	max_seconds: float = DEFAULT_MAX_SECONDS
) -> Dictionary:
	var result := {
		"completed": false,
		"truncated": false,
		"truncated_reason": "",
		"visited_states": 0,
		"expanded_states": 0,
		"labelled_solution_count": 0,
		"visual_solution_count": 0,
		"first_solution_positions": [],
		"first_solution_moves": [],
		"first_solution_segments": [],
		"sample_solutions": [],
		"message": "",
	}
	if puzzle_data == null:
		result["message"] = "missing puzzle data"
		return result

	var placements: Array = puzzle_data.placements
	var movable_indices := _movable_indices(placements)
	var initial_state := _initial_state(placements, movable_indices)
	var initial_key := _state_key(initial_state)
	var fixed_occupancy := _fixed_occupancy(placements, movable_indices)
	var started_msec := Time.get_ticks_msec()
	var max_msec := int(max_seconds * 1000.0)

	var queue: Array = [initial_state]
	var cursor := 0
	var seen: Dictionary = {}
	seen[initial_key] = true
	var parents: Dictionary = {}
	parents[initial_key] = {
		"parent": "",
		"move": {},
	}
	var visual_solutions := {}

	while cursor < queue.size():
		if max_msec > 0 and Time.get_ticks_msec() - started_msec >= max_msec:
			result["truncated"] = true
			result["truncated_reason"] = "time_limit"
			break

		var state: Array = queue[cursor]
		cursor += 1
		result["expanded_states"] = int(result["expanded_states"]) + 1

		var runtime := _runtime_for_state(placements, movable_indices, state)
		var solution := LightBeamSolver.solve(puzzle_data, runtime)
		if bool(solution.get("solved", false)):
			result["labelled_solution_count"] = int(result["labelled_solution_count"]) + 1
			var full_positions := _full_positions_for_state(placements, movable_indices, state)
			var visual_key := _visual_solution_key(placements, full_positions)
			visual_solutions[visual_key] = true
			if (result["first_solution_positions"] as Array).is_empty():
				result["first_solution_positions"] = full_positions
				result["first_solution_moves"] = _reconstruct_moves(_state_key(state), parents)
				result["first_solution_segments"] = solution.get("segments", [])
			if (result["sample_solutions"] as Array).size() < DEFAULT_SAMPLE_LIMIT:
				(result["sample_solutions"] as Array).append(full_positions)
			if max_solutions > 0 and int(result["labelled_solution_count"]) >= max_solutions:
				result["truncated"] = true
				result["truncated_reason"] = "solution_limit"
				break

		var occupancy := _occupancy_for_state(placements, movable_indices, state, fixed_occupancy)
		for move in _legal_moves(puzzle_data, placements, movable_indices, state, occupancy):
			var next_state: Array = move["state"]
			var next_key := _state_key(next_state)
			if seen.has(next_key):
				continue
			if max_states > 0 and seen.size() >= max_states:
				result["truncated"] = true
				result["truncated_reason"] = "state_limit"
				break
			seen[next_key] = true
			parents[next_key] = {
				"parent": _state_key(state),
				"move": move["move"],
			}
			queue.append(next_state)
		if bool(result["truncated"]):
			break

	result["visited_states"] = seen.size()
	result["visual_solution_count"] = visual_solutions.size()
	result["completed"] = not bool(result["truncated"])
	result["message"] = _build_message(result)
	return result


static func _movable_indices(placements: Array) -> Array[int]:
	var indices: Array[int] = []
	for index in range(placements.size()):
		var placement := placements[index] as LightPiecePlacement
		if placement != null and placement.is_movable():
			indices.append(index)
	return indices


static func _initial_state(placements: Array, movable_indices: Array[int]) -> Array:
	var state: Array = []
	for placement_index in movable_indices:
		var placement := placements[placement_index] as LightPiecePlacement
		state.append(placement.grid_position)
	return state


static func _fixed_occupancy(placements: Array, movable_indices: Array[int]) -> Dictionary:
	var movable_lookup := {}
	for placement_index in movable_indices:
		movable_lookup[placement_index] = true

	var occupancy := {}
	for index in range(placements.size()):
		if movable_lookup.has(index):
			continue
		var placement := placements[index] as LightPiecePlacement
		if placement == null or placement.piece == null:
			continue
		_add_piece_cells(occupancy, index, placement.grid_position, placement.piece.size)
	return occupancy


static func _runtime_for_state(placements: Array, movable_indices: Array[int], state: Array) -> Array:
	var runtime: Array = []
	for index in range(placements.size()):
		var placement := placements[index] as LightPiecePlacement
		if placement == null:
			runtime.append(null)
			continue
		runtime.append({
			"placement_id": placement.placement_id,
			"piece": placement.piece,
			"grid_position": placement.grid_position,
			"locked": placement.locked,
			"allowed_cells": placement.allowed_cells,
			"solution_position": placement.solution_position,
		})
	for state_index in range(movable_indices.size()):
		var placement_index: int = movable_indices[state_index]
		var runtime_entry: Dictionary = runtime[placement_index]
		runtime_entry["grid_position"] = state[state_index]
		runtime[placement_index] = runtime_entry
	return runtime


static func _full_positions_for_state(placements: Array, movable_indices: Array[int], state: Array) -> Array:
	var positions: Array = []
	for placement in placements:
		var typed_placement := placement as LightPiecePlacement
		if typed_placement != null:
			positions.append(typed_placement.grid_position)
		else:
			positions.append(Vector2i(-1, -1))
	for state_index in range(movable_indices.size()):
		positions[movable_indices[state_index]] = state[state_index]
	return positions


static func _occupancy_for_state(
	placements: Array,
	movable_indices: Array[int],
	state: Array,
	fixed_occupancy: Dictionary
) -> Dictionary:
	var occupancy := fixed_occupancy.duplicate()
	for state_index in range(movable_indices.size()):
		var placement_index: int = movable_indices[state_index]
		var placement := placements[placement_index] as LightPiecePlacement
		if placement == null or placement.piece == null:
			continue
		var cell: Vector2i = state[state_index]
		_add_piece_cells(occupancy, placement_index, cell, placement.piece.size)
	return occupancy


static func _legal_moves(
	puzzle_data: LightPuzzleData,
	placements: Array,
	movable_indices: Array[int],
	state: Array,
	occupancy: Dictionary
) -> Array:
	var moves: Array = []
	for state_index in range(movable_indices.size()):
		var placement_index: int = movable_indices[state_index]
		var placement := placements[placement_index] as LightPiecePlacement
		if placement == null or placement.piece == null:
			continue
		var start_cell: Vector2i = state[state_index]
		for step in _move_steps(placement.piece.move_axis):
			var target_cell := start_cell + step
			while _position_is_valid(puzzle_data, placement, placement_index, target_cell, occupancy):
				var next_state := state.duplicate()
				next_state[state_index] = target_cell
				moves.append({
					"state": next_state,
					"move": {
						"placement_index": placement_index,
						"placement_id": placement.placement_id,
						"from": start_cell,
						"to": target_cell,
					},
				})
				target_cell += step
	return moves


static func _move_steps(move_axis: int) -> Array[Vector2i]:
	match move_axis:
		LightPuzzleConstants.MoveAxis.HORIZONTAL:
			return [Vector2i(1, 0), Vector2i(-1, 0)]
		LightPuzzleConstants.MoveAxis.VERTICAL:
			return [Vector2i(0, 1), Vector2i(0, -1)]
		LightPuzzleConstants.MoveAxis.LOCKED:
			return []
	return [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


static func _position_is_valid(
	puzzle_data: LightPuzzleData,
	placement: LightPiecePlacement,
	placement_index: int,
	target_cell: Vector2i,
	occupancy: Dictionary
) -> bool:
	if placement == null or placement.piece == null:
		return false
	if target_cell.x < 0 or target_cell.y < 0:
		return false
	if target_cell.x + placement.piece.size.x > puzzle_data.board_size.x:
		return false
	if target_cell.y + placement.piece.size.y > puzzle_data.board_size.y:
		return false
	if not placement.allowed_cells.is_empty() and not placement.allowed_cells.has(target_cell):
		return false
	for y in range(placement.piece.size.y):
		for x in range(placement.piece.size.x):
			var cell := target_cell + Vector2i(x, y)
			var key := _cell_key(cell)
			if occupancy.has(key) and int(occupancy[key]) != placement_index:
				return false
	return true


static func _add_piece_cells(occupancy: Dictionary, placement_index: int, position: Vector2i, size: Vector2i) -> void:
	for y in range(size.y):
		for x in range(size.x):
			occupancy[_cell_key(position + Vector2i(x, y))] = placement_index


static func _state_key(state: Array) -> String:
	var output := ""
	for index in range(state.size()):
		var cell: Vector2i = state[index]
		if index > 0:
			output += "|"
		output += "%d,%d" % [cell.x, cell.y]
	return output


static func _visual_solution_key(placements: Array, full_positions: Array) -> String:
	var entries: Array[String] = []
	for index in range(placements.size()):
		var placement := placements[index] as LightPiecePlacement
		if placement == null or placement.piece == null:
			continue
		var cell: Vector2i = full_positions[index]
		entries.append("%s@%d,%d" % [_visual_piece_signature(placement), cell.x, cell.y])
	entries.sort()
	var output := ""
	for index in range(entries.size()):
		if index > 0:
			output += "|"
		output += entries[index]
	return output


static func _visual_piece_signature(placement: LightPiecePlacement) -> String:
	var piece := placement.piece
	var allowed: Array[String] = []
	for cell in placement.allowed_cells:
		if cell is Vector2i:
			allowed.append("%d,%d" % [cell.x, cell.y])
	allowed.sort()
	var allowed_text := ""
	for index in range(allowed.size()):
		if index > 0:
			allowed_text += ";"
		allowed_text += allowed[index]
	return "%d:%d,%d:%d:%d:%s:%s" % [
		piece.piece_type,
		piece.size.x,
		piece.size.y,
		piece.filter_mask,
		piece.move_axis,
		str(piece.is_draggable and not placement.locked),
		allowed_text,
	]


static func _reconstruct_moves(state_key: String, parents: Dictionary) -> Array:
	var moves: Array = []
	var current_key := state_key
	while parents.has(current_key):
		var entry: Dictionary = parents[current_key]
		var parent_key: String = entry.get("parent", "")
		if parent_key == "":
			break
		moves.append(entry.get("move", {}))
		current_key = parent_key
	moves.reverse()
	return moves


static func _build_message(result: Dictionary) -> String:
	if bool(result.get("truncated", false)):
		return "Solver truncated by %s after visiting %d states." % [
			str(result.get("truncated_reason", "")),
			int(result.get("visited_states", 0)),
		]
	var visual_count := int(result.get("visual_solution_count", 0))
	var labelled_count := int(result.get("labelled_solution_count", 0))
	if visual_count == 0:
		return "No solution found after visiting %d states." % int(result.get("visited_states", 0))
	if visual_count == 1:
		return "Unique visual solution found (%d labelled solution) after visiting %d states." % [
			labelled_count,
			int(result.get("visited_states", 0)),
		]
	return "%d visual solutions found (%d labelled solutions) after visiting %d states." % [
		visual_count,
		labelled_count,
		int(result.get("visited_states", 0)),
	]


static func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]
