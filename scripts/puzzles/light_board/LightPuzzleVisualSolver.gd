class_name LightPuzzleVisualSolver
extends RefCounted

const DEFAULT_ROUTE_STATE_LIMIT: int = 50000
const DEFAULT_ROUTE_CANDIDATE_LIMIT: int = 48
const DEFAULT_LAYOUT_ATTEMPT_LIMIT: int = 256
const EMPTY_ROLE_KEY: String = "empty"


static func solve_visual(
	puzzle_data: LightPuzzleData,
	max_solutions: int = 12,
	max_seconds: float = 10.0
) -> Dictionary:
	var result := _default_result()
	if puzzle_data == null:
		result["message"] = "missing puzzle data"
		return result
	if puzzle_data.sources.is_empty() or puzzle_data.exits.is_empty():
		result["message"] = "missing source or exit"
		return result

	var started_msec := Time.get_ticks_msec()
	var max_msec := int(max_seconds * 1000.0)
	var context := _build_context(puzzle_data)
	var routes_by_source: Array = []

	for source_index in range(puzzle_data.sources.size()):
		var source := puzzle_data.sources[source_index] as LightPortData
		if source == null or source.kind != LightPuzzleConstants.PortKind.SOURCE:
			routes_by_source.append([])
			continue
		var routes := _straight_routes_for_source(puzzle_data, source_index, context)
		if not routes.is_empty():
			result["visited_routes"] = int(result.get("visited_routes", 0)) + routes.size()
		else:
			routes = _search_routes_for_source(
				puzzle_data,
				source_index,
				context,
				started_msec,
				max_msec,
				result
			)
		routes_by_source.append(routes)
		if bool(result.get("truncated", false)):
			break

	if not bool(result.get("truncated", false)):
		var accumulator := {
			"optical_keys": {},
			"layout_keys": {},
			"sample_limit": max(1, max_solutions),
			"layout_attempts": 0,
		}
		_combine_source_routes(
			puzzle_data,
			context,
			routes_by_source,
			0,
			[],
			started_msec,
			max_msec,
			result,
			accumulator
		)
		result["optical_solution_count"] = (accumulator["optical_keys"] as Dictionary).size()
		result["layout_solution_count"] = (accumulator["layout_keys"] as Dictionary).size()

	result["completed"] = not bool(result.get("truncated", false))
	result["message"] = _build_message(result)
	return result


static func _default_result() -> Dictionary:
	return {
		"completed": false,
		"truncated": false,
		"truncated_reason": "",
		"visited_routes": 0,
		"optical_solution_count": 0,
		"layout_solution_count": 0,
		"first_solution_positions": [],
		"first_solution_segments": [],
		"active_piece_indices": [],
		"unused_piece_indices": [],
		"sample_solutions": [],
		"reasoning_steps": [],
		"message": "",
	}


static func _build_context(puzzle_data: LightPuzzleData) -> Dictionary:
	var movable_indices: Array[int] = []
	var fixed_occupancy: Dictionary = {}

	for index in range(puzzle_data.placements.size()):
		var placement := puzzle_data.placements[index] as LightPiecePlacement
		if placement == null or placement.piece == null:
			continue
		if placement.is_movable():
			movable_indices.append(index)
		else:
			_add_piece_cells(fixed_occupancy, index, placement.grid_position, placement.piece.size)

	return {
		"movable_indices": movable_indices,
		"fixed_occupancy": fixed_occupancy,
	}


static func _search_routes_for_source(
	puzzle_data: LightPuzzleData,
	source_index: int,
	context: Dictionary,
	started_msec: int,
	max_msec: int,
	result: Dictionary
) -> Array:
	var source := puzzle_data.sources[source_index] as LightPortData
	if source == null:
		return []

	var start_state := {
		"source_index": source_index,
		"source_id": _port_key(source),
		"cell": source.cell,
		"direction": source.direction,
		"color_mask": source.color_mask,
		"requirements": {},
		"path_cells": [source.cell],
		"segments": [],
		"cost": 0,
		"turns": 0,
		"color_changes": 0,
		"active_count": 0,
		"color_history": [source.color_mask],
		"rank": _route_rank(puzzle_data, source.cell, source.direction, source.color_mask, 0, 0, 0, 0),
	}
	var queue: Array = [start_state]
	var seen: Dictionary = {}
	var routes: Array = []

	while not queue.is_empty():
		if _time_limit_reached(started_msec, max_msec):
			result["truncated"] = true
			result["truncated_reason"] = "time_limit"
			break
		if int(result.get("visited_routes", 0)) >= DEFAULT_ROUTE_STATE_LIMIT:
			result["truncated"] = true
			result["truncated_reason"] = "route_state_limit"
			break

		queue.sort_custom(func(a, b):
			return float(a.get("rank", 0.0)) < float(b.get("rank", 0.0))
		)
		var state: Dictionary = queue.pop_front()
		result["visited_routes"] = int(result.get("visited_routes", 0)) + 1

		var state_key := _route_state_key(state)
		if seen.has(state_key):
			continue
		seen[state_key] = true

		if (state.get("segments", []) as Array).size() >= puzzle_data.max_beam_steps:
			continue

		var actions := _actions_for_state_cell(puzzle_data, context, state)
		for action in actions:
			var expanded := _expand_route_state(puzzle_data, state, action)
			if expanded.is_empty():
				continue
			if bool(expanded.get("exited", false)):
				routes.append(expanded.get("route", {}))
				if routes.size() >= DEFAULT_ROUTE_CANDIDATE_LIMIT:
					queue.clear()
					break
				continue
			var next_state: Dictionary = expanded.get("state", {})
			if next_state.is_empty():
				continue
			queue.append(next_state)
		if bool(result.get("truncated", false)):
			break

	routes.sort_custom(func(a, b):
		return int(a.get("score", 0)) < int(b.get("score", 0))
	)
	return routes


static func _straight_routes_for_source(
	puzzle_data: LightPuzzleData,
	source_index: int,
	context: Dictionary
) -> Array:
	var source := puzzle_data.sources[source_index] as LightPortData
	if source == null:
		return []
	var routes: Array = []
	var straight_context := _context_without_source_glass(puzzle_data, context, source.cell)
	for exit_port in puzzle_data.exits:
		if exit_port == null or exit_port.kind != LightPuzzleConstants.PortKind.EXIT:
			continue
		if exit_port.direction != source.direction:
			continue
		if not _cell_is_on_ray(source.cell, exit_port.cell, source.direction):
			continue
		var base := _trace_straight_path(puzzle_data, straight_context, source, source_index, exit_port)
		if base.is_empty():
			continue
		var route_color := int(base.get("color_mask", source.color_mask))
		if exit_port.accepts_color(route_color):
			routes.append(base)
			continue
		var recolor_routes := _straight_recolor_routes(puzzle_data, straight_context, base, route_color, exit_port)
		routes.append_array(recolor_routes)
	routes.sort_custom(func(a, b):
		return int(a.get("score", 0)) < int(b.get("score", 0))
	)
	if routes.size() > DEFAULT_ROUTE_CANDIDATE_LIMIT:
		routes.resize(DEFAULT_ROUTE_CANDIDATE_LIMIT)
	return routes


static func _context_without_source_glass(
	puzzle_data: LightPuzzleData,
	context: Dictionary,
	source_cell: Vector2i
) -> Dictionary:
	var fixed_occupancy: Dictionary = (context.get("fixed_occupancy", {}) as Dictionary).duplicate()
	var source_key := _cell_key(source_cell)
	if fixed_occupancy.has(source_key):
		var fixed_index := int(fixed_occupancy[source_key])
		var placement := puzzle_data.placements[fixed_index] as LightPiecePlacement
		if placement != null and placement.piece != null and placement.piece.piece_type == LightPuzzleConstants.PieceType.GLASS_BLOCK:
			fixed_occupancy.erase(source_key)
	var straight_context := context.duplicate()
	straight_context["fixed_occupancy"] = fixed_occupancy
	return straight_context


static func _trace_straight_path(
	puzzle_data: LightPuzzleData,
	context: Dictionary,
	source: LightPortData,
	source_index: int,
	exit_port: LightPortData
) -> Dictionary:
	var fixed_occupancy: Dictionary = context.get("fixed_occupancy", {})
	var cell := source.cell
	var direction := source.direction
	var color_mask := source.color_mask
	var requirements: Dictionary = {}
	var path_cells: Array = []
	var segments: Array = []
	var color_history: Array = [color_mask]

	while _is_inside(cell, puzzle_data.board_size):
		path_cells.append(cell)
		var interaction := "empty"
		var cell_key := _cell_key(cell)
		if fixed_occupancy.has(cell_key):
			var fixed_index := int(fixed_occupancy[cell_key])
			var placement := puzzle_data.placements[fixed_index] as LightPiecePlacement
			if placement == null or placement.piece == null:
				return {}
			var action := _action_for_piece(placement.piece, direction, color_mask, cell, fixed_index, true)
			if action.is_empty():
				return {}
			var next_direction := int(action.get("direction", direction))
			if next_direction != direction:
				return {}
			var next_color := int(action.get("color_mask", color_mask))
			interaction = str(action.get("interaction", interaction))
			if action.has("requirement"):
				requirements[cell_key] = action["requirement"]
			if next_color != color_mask:
				color_mask = next_color
				color_history.append(color_mask)

		var next_cell := cell + LightPuzzleConstants.direction_vector(direction)
		segments.append({
			"source": _port_key(source),
			"from": cell,
			"to": next_cell,
			"direction": direction,
			"color_mask": color_mask,
			"interaction": interaction,
		})
		if cell == exit_port.cell:
			if not _is_inside(next_cell, puzzle_data.board_size):
				var route := {
					"source_index": source_index,
					"source_id": _port_key(source),
					"exit_keys": [_port_key(exit_port)],
					"requirements": requirements,
					"path_cells": path_cells,
					"segments": segments,
					"cost": path_cells.size(),
					"turns": 0,
					"color_changes": max(0, color_history.size() - 1),
					"active_count": requirements.size(),
					"color_history": color_history,
					"color_mask": color_mask,
				}
				route["score"] = _route_score(route)
				return route
			return {}
		cell = next_cell
	return {}


static func _straight_recolor_routes(
	puzzle_data: LightPuzzleData,
	context: Dictionary,
	base_route: Dictionary,
	incoming_color: int,
	exit_port: LightPortData
) -> Array:
	var routes: Array = []
	var path_cells: Array = base_route.get("path_cells", [])
	var first_path_cell: Vector2i = Vector2i(-9999, -9999)
	if not path_cells.is_empty():
		var raw_first_cell = path_cells[0]
		if raw_first_cell is Vector2i:
			first_path_cell = raw_first_cell
	var role_keys: Dictionary = {}
	for placement_index in context.get("movable_indices", []):
		var placement := puzzle_data.placements[int(placement_index)] as LightPiecePlacement
		if placement == null or placement.piece == null or not placement.piece.is_filter():
			continue
		var filter_mask := placement.piece.get_filter_mask()
		if not exit_port.accepts_color(filter_mask):
			continue
		var role_key := _piece_role_key(placement.piece)
		if role_keys.has(role_key):
			continue
		for cell in path_cells:
			if not (cell is Vector2i):
				continue
			var target_cell: Vector2i = cell
			if target_cell == first_path_cell:
				continue
			if not _position_is_valid(puzzle_data, placement, target_cell, context.get("fixed_occupancy", {})):
				continue
			if not _piece_can_move_directly_to(puzzle_data, placement, target_cell, context.get("fixed_occupancy", {}), int(placement_index)):
				continue
			var route := _route_with_inserted_filter(base_route, placement.piece, target_cell, incoming_color, filter_mask)
			routes.append(route)
			role_keys[role_key] = true
			break
	return routes


static func _route_with_inserted_filter(
	base_route: Dictionary,
	piece: LightPieceData,
	cell: Vector2i,
	incoming_color: int,
	filter_mask: int
) -> Dictionary:
	var route := base_route.duplicate(true)
	var requirements: Dictionary = (route.get("requirements", {}) as Dictionary).duplicate(true)
	var cell_key := _cell_key(cell)
	var segments_for_direction: Array = route.get("segments", [])
	var route_direction := 0
	if not segments_for_direction.is_empty():
		var first_segment = segments_for_direction[0]
		if first_segment is Dictionary:
			var first_segment_dict: Dictionary = first_segment
			route_direction = int(first_segment_dict.get("direction", 0))
	requirements[cell_key] = {
		"cell": cell,
		"piece_type": piece.piece_type,
		"filter_mask": filter_mask,
		"role_key": _piece_role_key(piece),
		"fixed_index": -1,
		"from_direction": route_direction,
		"to_direction": route_direction,
		"from_color": incoming_color,
		"to_color": filter_mask,
	}
	route["requirements"] = requirements
	route["active_count"] = requirements.size()
	route["color_changes"] = int(route.get("color_changes", 0)) + 1
	var color_history: Array = (route.get("color_history", []) as Array).duplicate()
	if color_history.is_empty() or int(color_history[color_history.size() - 1]) != filter_mask:
		color_history.append(filter_mask)
	route["color_history"] = color_history
	route["color_mask"] = filter_mask

	var segments: Array = (route.get("segments", []) as Array).duplicate(true)
	var recolored := false
	for index in range(segments.size()):
		var segment: Dictionary = segments[index]
		var from_cell: Vector2i = segment.get("from", Vector2i.ZERO)
		if from_cell == cell:
			recolored = true
			segment["interaction"] = piece.piece_id
		if recolored:
			segment["color_mask"] = filter_mask
		segments[index] = segment
	route["segments"] = segments
	route["score"] = _route_score(route)
	return route


static func _actions_for_state_cell(
	puzzle_data: LightPuzzleData,
	context: Dictionary,
	state: Dictionary
) -> Array:
	var cell: Vector2i = state.get("cell", Vector2i.ZERO)
	var cell_key := _cell_key(cell)
	var direction := int(state.get("direction", LightPuzzleConstants.Direction.E))
	var color_mask := int(state.get("color_mask", LightPuzzleConstants.COLOR_WHITE))
	var fixed_occupancy: Dictionary = context.get("fixed_occupancy", {})

	if fixed_occupancy.has(cell_key):
		var fixed_index := int(fixed_occupancy[cell_key])
		var fixed_placement := puzzle_data.placements[fixed_index] as LightPiecePlacement
		if fixed_placement == null or fixed_placement.piece == null:
			return []
		var fixed_action := _action_for_piece(
			fixed_placement.piece,
			direction,
			color_mask,
			cell,
			fixed_index,
			true
		)
		if fixed_action.is_empty():
			return []
		return [fixed_action]

	var requirements: Dictionary = state.get("requirements", {})
	if requirements.has(cell_key):
		var requirement: Dictionary = requirements[cell_key]
		var required_action := _action_for_role(
			int(requirement.get("piece_type", -1)),
			int(requirement.get("filter_mask", LightPuzzleConstants.COLOR_WHITE)),
			direction,
			color_mask,
			cell,
			int(requirement.get("fixed_index", -1))
		)
		if required_action.is_empty():
			return []
		return [required_action]

	var actions: Array = [_empty_action(direction, color_mask)]
	var role_keys: Dictionary = {}
	for placement_index in context.get("movable_indices", []):
		var placement := puzzle_data.placements[int(placement_index)] as LightPiecePlacement
		if placement == null or placement.piece == null:
			continue
		if not _position_is_valid(puzzle_data, placement, cell, fixed_occupancy):
			continue
		if not _piece_can_move_directly_to(puzzle_data, placement, cell, fixed_occupancy, int(placement_index)):
			continue
		if _piece_is_noop(placement.piece) or placement.piece.blocks_light():
			continue
		var role_key := _piece_role_key(placement.piece)
		if role_keys.has(role_key):
			continue
		role_keys[role_key] = true
		var action := _action_for_piece(placement.piece, direction, color_mask, cell, -1, false)
		if action.is_empty() or not bool(action.get("meaningful", false)):
			continue
		actions.append(action)

	actions.sort_custom(func(a, b):
		return int(a.get("action_cost", 0)) < int(b.get("action_cost", 0))
	)
	return actions


static func _expand_route_state(
	puzzle_data: LightPuzzleData,
	state: Dictionary,
	action: Dictionary
) -> Dictionary:
	var cell: Vector2i = state.get("cell", Vector2i.ZERO)
	var next_direction := int(action.get("direction", state.get("direction", LightPuzzleConstants.Direction.E)))
	var next_color := int(action.get("color_mask", state.get("color_mask", LightPuzzleConstants.COLOR_WHITE)))
	if next_color == 0:
		return {}

	var next_cell := cell + LightPuzzleConstants.direction_vector(next_direction)
	var segments: Array = (state.get("segments", []) as Array).duplicate(true)
	segments.append({
		"source": state.get("source_id", ""),
		"from": cell,
		"to": next_cell,
		"direction": next_direction,
		"color_mask": next_color,
		"interaction": action.get("interaction", "empty"),
	})

	var requirements: Dictionary = (state.get("requirements", {}) as Dictionary).duplicate(true)
	if action.has("requirement"):
		var requirement: Dictionary = action["requirement"]
		var requirement_key := _cell_key(requirement.get("cell", cell))
		if requirements.has(requirement_key):
			var existing: Dictionary = requirements[requirement_key]
			if str(existing.get("role_key", "")) != str(requirement.get("role_key", "")):
				return {}
		else:
			requirements[requirement_key] = requirement

	var color_history: Array = (state.get("color_history", []) as Array).duplicate()
	if color_history.is_empty() or int(color_history[color_history.size() - 1]) != next_color:
		color_history.append(next_color)

	if not _is_inside(next_cell, puzzle_data.board_size):
		var exit_keys := _matching_exit_keys(puzzle_data, cell, next_direction, next_color)
		if exit_keys.is_empty():
			return {}
		var route := {
			"source_index": state.get("source_index", 0),
			"source_id": state.get("source_id", ""),
			"exit_keys": exit_keys,
			"requirements": requirements,
			"path_cells": state.get("path_cells", []),
			"segments": segments,
			"cost": int(state.get("cost", 0)) + int(action.get("action_cost", 1)),
			"turns": int(state.get("turns", 0)) + int(action.get("turn_delta", 0)),
			"color_changes": int(state.get("color_changes", 0)) + int(action.get("color_delta", 0)),
			"active_count": requirements.size(),
			"color_history": color_history,
		}
		route["score"] = _route_score(route)
		return {"exited": true, "route": route}

	var path_cells: Array = (state.get("path_cells", []) as Array).duplicate()
	path_cells.append(next_cell)
	var cost := int(state.get("cost", 0)) + int(action.get("action_cost", 1))
	var turns := int(state.get("turns", 0)) + int(action.get("turn_delta", 0))
	var color_changes := int(state.get("color_changes", 0)) + int(action.get("color_delta", 0))
	var next_state := {
		"source_index": state.get("source_index", 0),
		"source_id": state.get("source_id", ""),
		"cell": next_cell,
		"direction": next_direction,
		"color_mask": next_color,
		"requirements": requirements,
		"path_cells": path_cells,
		"segments": segments,
		"cost": cost,
		"turns": turns,
		"color_changes": color_changes,
		"active_count": requirements.size(),
		"color_history": color_history,
		"rank": _route_rank(puzzle_data, next_cell, next_direction, next_color, cost, turns, color_changes, requirements.size()),
	}
	return {"exited": false, "state": next_state}


static func _combine_source_routes(
	puzzle_data: LightPuzzleData,
	context: Dictionary,
	routes_by_source: Array,
	source_index: int,
	current_routes: Array,
	started_msec: int,
	max_msec: int,
	result: Dictionary,
	accumulator: Dictionary
) -> void:
	if bool(result.get("truncated", false)):
		return
	if _time_limit_reached(started_msec, max_msec):
		result["truncated"] = true
		result["truncated_reason"] = "time_limit"
		return
	if source_index >= routes_by_source.size():
		_process_route_group(
			puzzle_data,
			context,
			current_routes,
			started_msec,
			max_msec,
			result,
			accumulator
		)
		return

	var source_routes: Array = routes_by_source[source_index]
	if source_routes.is_empty():
		return
	for route in source_routes:
		var next_routes := current_routes.duplicate()
		next_routes.append(route)
		if not _route_group_requirements_are_compatible(next_routes):
			continue
		if not _route_group_paths_are_compatible(next_routes):
			continue
		_combine_source_routes(
			puzzle_data,
			context,
			routes_by_source,
			source_index + 1,
			next_routes,
			started_msec,
			max_msec,
			result,
			accumulator
		)


static func _process_route_group(
	puzzle_data: LightPuzzleData,
	context: Dictionary,
	routes: Array,
	started_msec: int,
	max_msec: int,
	result: Dictionary,
	accumulator: Dictionary
) -> void:
	if routes.is_empty() or not _route_group_can_cover_exits(puzzle_data, routes):
		return
	var requirements := _merged_requirements(routes)
	var active_assignments := _match_active_requirements(
		puzzle_data,
		context,
		requirements,
		started_msec,
		max_msec,
		result
	)
	if bool(result.get("truncated", false)):
		return
	if active_assignments.is_empty():
		return
	var optical_key := _optical_solution_key(routes, requirements)
	(accumulator["optical_keys"] as Dictionary)[optical_key] = true
	for assignment in active_assignments:
		if _time_limit_reached(started_msec, max_msec):
			result["truncated"] = true
			result["truncated_reason"] = "time_limit"
			return
		_park_unused_pieces(
			puzzle_data,
			context,
			routes,
			assignment,
			started_msec,
			max_msec,
			result,
			accumulator
		)
		if bool(result.get("truncated", false)):
			return


static func _match_active_requirements(
	puzzle_data: LightPuzzleData,
	context: Dictionary,
	requirements: Dictionary,
	started_msec: int,
	max_msec: int,
	result: Dictionary
) -> Array:
	var fixed_occupancy: Dictionary = context.get("fixed_occupancy", {})
	var fixed_active: Dictionary = {}
	var movable_requirements: Array = []
	var occupied := fixed_occupancy.duplicate()

	for key in requirements.keys():
		var requirement: Dictionary = requirements[key]
		var fixed_index := int(requirement.get("fixed_index", -1))
		if fixed_index >= 0:
			fixed_active[fixed_index] = true
			continue
		movable_requirements.append(requirement)
	if not _movable_requirements_are_distinct(movable_requirements):
		return []

	movable_requirements.sort_custom(func(a, b):
		return str(a.get("role_key", "")) < str(b.get("role_key", ""))
	)

	var assignments: Array = []
	var initial := {
		"positions": _initial_positions(puzzle_data.placements),
		"active_indices": _dictionary_int_keys(fixed_active),
		"used_movable": {},
		"occupied": occupied,
	}
	_backtrack_active_requirements(
		puzzle_data,
		context,
		movable_requirements,
		0,
		initial,
		assignments,
		started_msec,
		max_msec,
		result
	)
	return assignments


static func _movable_requirements_are_distinct(requirements: Array) -> bool:
	var cells: Dictionary = {}
	for requirement in requirements:
		if not (requirement is Dictionary):
			continue
		var typed_requirement: Dictionary = requirement
		var cell: Vector2i = typed_requirement.get("cell", Vector2i.ZERO)
		var key := _cell_key(cell)
		if cells.has(key):
			return false
		cells[key] = true
	return true


static func _backtrack_active_requirements(
	puzzle_data: LightPuzzleData,
	context: Dictionary,
	requirements: Array,
	requirement_index: int,
	state: Dictionary,
	assignments: Array,
	started_msec: int,
	max_msec: int,
	result: Dictionary
) -> void:
	if bool(result.get("truncated", false)):
		return
	if _time_limit_reached(started_msec, max_msec):
		result["truncated"] = true
		result["truncated_reason"] = "time_limit"
		return
	if assignments.size() >= 64:
		return
	if requirement_index >= requirements.size():
		assignments.append({
			"positions": (state["positions"] as Array).duplicate(),
			"active_indices": (state["active_indices"] as Array).duplicate(),
			"used_movable": (state["used_movable"] as Dictionary).duplicate(),
			"occupied": (state["occupied"] as Dictionary).duplicate(),
		})
		return

	var requirement: Dictionary = requirements[requirement_index]
	var candidates := _active_piece_candidates_for_requirement(puzzle_data, context, requirement)
	candidates.sort_custom(func(a, b):
		return int(a.get("distance", 0)) < int(b.get("distance", 0))
	)
	for candidate in candidates:
		var placement_index := int(candidate.get("placement_index", -1))
		if (state["used_movable"] as Dictionary).has(placement_index):
			continue
		var target_cell: Vector2i = candidate.get("target_cell", Vector2i.ZERO)
		var placement := puzzle_data.placements[placement_index] as LightPiecePlacement
		if placement == null or placement.piece == null:
			continue
		if not _position_is_valid_with_occupancy(puzzle_data, placement, target_cell, state["occupied"]):
			continue
		if not _piece_can_move_directly_to(puzzle_data, placement, target_cell, state["occupied"], placement_index):
			continue

		var next_positions: Array = (state["positions"] as Array).duplicate()
		next_positions[placement_index] = target_cell
		var next_active: Array = (state["active_indices"] as Array).duplicate()
		next_active.append(placement_index)
		var next_used: Dictionary = (state["used_movable"] as Dictionary).duplicate()
		next_used[placement_index] = true
		var next_occupied: Dictionary = (state["occupied"] as Dictionary).duplicate()
		_add_piece_cells(next_occupied, placement_index, target_cell, placement.piece.size)

		_backtrack_active_requirements(
			puzzle_data,
			context,
			requirements,
			requirement_index + 1,
			{
				"positions": next_positions,
				"active_indices": next_active,
				"used_movable": next_used,
				"occupied": next_occupied,
			},
			assignments,
			started_msec,
			max_msec,
			result
		)


static func _active_piece_candidates_for_requirement(
	puzzle_data: LightPuzzleData,
	context: Dictionary,
	requirement: Dictionary
) -> Array:
	var candidates: Array = []
	var target_cell: Vector2i = requirement.get("cell", Vector2i.ZERO)
	var role_key := str(requirement.get("role_key", ""))
	var fixed_occupancy: Dictionary = context.get("fixed_occupancy", {})
	for placement_index in context.get("movable_indices", []):
		var placement := puzzle_data.placements[int(placement_index)] as LightPiecePlacement
		if placement == null or placement.piece == null:
			continue
		if _piece_role_key(placement.piece) != role_key:
			continue
		if not _position_is_valid(puzzle_data, placement, target_cell, fixed_occupancy):
			continue
		if not _piece_can_move_directly_to(puzzle_data, placement, target_cell, fixed_occupancy, int(placement_index)):
			continue
		candidates.append({
			"placement_index": int(placement_index),
			"target_cell": target_cell,
			"distance": _cell_distance(placement.grid_position, target_cell),
		})
	return candidates


static func _park_unused_pieces(
	puzzle_data: LightPuzzleData,
	context: Dictionary,
	routes: Array,
	assignment: Dictionary,
	started_msec: int,
	max_msec: int,
	result: Dictionary,
	accumulator: Dictionary
) -> void:
	var used_movable: Dictionary = assignment.get("used_movable", {})
	var unused_indices: Array = []
	for placement_index in context.get("movable_indices", []):
		if not used_movable.has(int(placement_index)):
			unused_indices.append(int(placement_index))

	var beam_cells := _beam_cells_for_routes(routes)
	var parking_options: Dictionary = {}
	for placement_index in unused_indices:
		var placement := puzzle_data.placements[int(placement_index)] as LightPiecePlacement
		if placement == null or placement.piece == null:
			return
		var options := _parking_candidates_for_piece(
			puzzle_data,
			placement,
			assignment.get("occupied", {}),
			beam_cells
		)
		if options.is_empty():
			return
		parking_options[placement_index] = options

	unused_indices.sort_custom(func(a, b):
		return (parking_options.get(a, []) as Array).size() < (parking_options.get(b, []) as Array).size()
	)

	_backtrack_parking(
		puzzle_data,
		routes,
		unused_indices,
		parking_options,
		0,
		assignment,
		started_msec,
		max_msec,
		result,
		accumulator
	)


static func _backtrack_parking(
	puzzle_data: LightPuzzleData,
	routes: Array,
	unused_indices: Array,
	parking_options: Dictionary,
	parking_index: int,
	state: Dictionary,
	started_msec: int,
	max_msec: int,
	result: Dictionary,
	accumulator: Dictionary
) -> void:
	if bool(result.get("truncated", false)):
		return
	if _time_limit_reached(started_msec, max_msec):
		result["truncated"] = true
		result["truncated_reason"] = "time_limit"
		return
	if int(accumulator.get("layout_attempts", 0)) >= DEFAULT_LAYOUT_ATTEMPT_LIMIT:
		return
	if parking_index >= unused_indices.size():
		accumulator["layout_attempts"] = int(accumulator.get("layout_attempts", 0)) + 1
		var positions: Array = (state["positions"] as Array).duplicate()
		var runtime := _runtime_for_positions(puzzle_data.placements, positions)
		var solved := LightBeamSolver.solve(puzzle_data, runtime)
		if not bool(solved.get("solved", false)):
			return
		var layout_key := _layout_solution_key(puzzle_data.placements, positions)
		var layout_keys: Dictionary = accumulator["layout_keys"]
		if layout_keys.has(layout_key):
			return
		layout_keys[layout_key] = true

		var active_indices: Array = (state["active_indices"] as Array).duplicate()
		active_indices.sort()
		var unused_copy := unused_indices.duplicate()
		unused_copy.sort()
		if (result.get("first_solution_positions", []) as Array).is_empty():
			result["first_solution_positions"] = positions
			result["first_solution_segments"] = solved.get("segments", [])
			result["active_piece_indices"] = active_indices
			result["unused_piece_indices"] = unused_copy
			result["reasoning_steps"] = _reasoning_steps_for_routes(routes)
		if (result.get("sample_solutions", []) as Array).size() < int(accumulator.get("sample_limit", 1)):
			(result["sample_solutions"] as Array).append({
				"positions": positions,
				"segments": solved.get("segments", []),
				"active_piece_indices": active_indices,
				"unused_piece_indices": unused_copy,
			})
		if (result.get("sample_solutions", []) as Array).size() >= int(accumulator.get("sample_limit", 1)):
			accumulator["layout_attempts"] = DEFAULT_LAYOUT_ATTEMPT_LIMIT
		return

	var placement_index := int(unused_indices[parking_index])
	var placement := puzzle_data.placements[placement_index] as LightPiecePlacement
	if placement == null or placement.piece == null:
		return
	for target_cell in parking_options.get(placement_index, []):
		if not _position_is_valid_with_occupancy(puzzle_data, placement, target_cell, state["occupied"]):
			continue
		if not _piece_can_move_directly_to(puzzle_data, placement, target_cell, state["occupied"], placement_index):
			continue
		var next_positions: Array = (state["positions"] as Array).duplicate()
		next_positions[placement_index] = target_cell
		var next_occupied: Dictionary = (state["occupied"] as Dictionary).duplicate()
		_add_piece_cells(next_occupied, placement_index, target_cell, placement.piece.size)
		_backtrack_parking(
			puzzle_data,
			routes,
			unused_indices,
			parking_options,
			parking_index + 1,
			{
				"positions": next_positions,
				"active_indices": state["active_indices"],
				"used_movable": state["used_movable"],
				"occupied": next_occupied,
			},
			started_msec,
			max_msec,
			result,
			accumulator
		)


static func _parking_candidates_for_piece(
	puzzle_data: LightPuzzleData,
	placement: LightPiecePlacement,
	occupied: Dictionary,
	beam_cells: Dictionary
) -> Array:
	var outside_beam: Array = []
	var beam_noop: Array = []
	for y in range(puzzle_data.board_size.y - placement.piece.size.y + 1):
		for x in range(puzzle_data.board_size.x - placement.piece.size.x + 1):
			var cell := Vector2i(x, y)
			if not _position_is_allowed_for_piece(placement, cell):
				continue
			if not _position_is_valid_with_occupancy(puzzle_data, placement, cell, occupied):
				continue
			if not _piece_can_move_directly_to(puzzle_data, placement, cell, occupied):
				continue
			var overlaps_beam := _piece_overlaps_any_cell(cell, placement.piece.size, beam_cells)
			if not overlaps_beam:
				outside_beam.append(cell)
			elif _piece_is_noop(placement.piece):
				beam_noop.append(cell)

	outside_beam.sort_custom(func(a, b):
		return _cell_distance(placement.grid_position, a) < _cell_distance(placement.grid_position, b)
	)
	beam_noop.sort_custom(func(a, b):
		return _cell_distance(placement.grid_position, a) < _cell_distance(placement.grid_position, b)
	)
	var candidates := outside_beam
	candidates.append_array(beam_noop)
	if candidates.size() > 8:
		candidates.resize(8)
	return candidates


static func _action_for_piece(
	piece: LightPieceData,
	direction: int,
	color_mask: int,
	cell: Vector2i,
	fixed_index: int,
	is_fixed: bool
) -> Dictionary:
	return _action_for_role(
		piece.piece_type,
		_filter_mask_for_piece(piece),
		direction,
		color_mask,
		cell,
		fixed_index,
		piece.piece_id,
		is_fixed
	)


static func _action_for_role(
	piece_type: int,
	filter_mask: int,
	direction: int,
	color_mask: int,
	cell: Vector2i,
	fixed_index: int = -1,
	interaction: String = "",
	is_fixed: bool = false
) -> Dictionary:
	var applied := _apply_piece_type(piece_type, filter_mask, direction, color_mask)
	if bool(applied.get("stopped", false)):
		return {}

	var next_direction := int(applied.get("direction", direction))
	var next_color := int(applied.get("color_mask", color_mask))
	var direction_changed := next_direction != direction
	var color_changed := next_color != color_mask
	var meaningful := direction_changed or color_changed
	var role_key := _role_key(piece_type, filter_mask)
	var action_cost := 4
	if _is_filter_type(piece_type):
		action_cost = 3
	if direction_changed:
		action_cost += 2
	if color_changed:
		action_cost += 1

	var action := {
		"direction": next_direction,
		"color_mask": next_color,
		"interaction": interaction if interaction != "" else _role_label(piece_type, filter_mask),
		"meaningful": meaningful,
		"action_cost": action_cost,
		"turn_delta": 1 if direction_changed else 0,
		"color_delta": 1 if color_changed else 0,
	}
	if meaningful or (is_fixed and not _piece_type_is_noop(piece_type)):
		action["requirement"] = {
			"cell": cell,
			"piece_type": piece_type,
			"filter_mask": filter_mask,
			"role_key": role_key,
			"fixed_index": fixed_index,
			"from_direction": direction,
			"to_direction": next_direction,
			"from_color": color_mask,
			"to_color": next_color,
		}
	return action


static func _empty_action(direction: int, color_mask: int) -> Dictionary:
	return {
		"direction": direction,
		"color_mask": color_mask,
		"interaction": "empty",
		"meaningful": false,
		"action_cost": 1,
		"turn_delta": 0,
		"color_delta": 0,
	}


static func _apply_piece_type(piece_type: int, filter_mask: int, direction: int, color_mask: int) -> Dictionary:
	var next_direction := direction
	var next_color := color_mask
	var stopped := false
	match piece_type:
		LightPuzzleConstants.PieceType.MIRROR_SLASH:
			next_direction = LightPuzzleConstants.reflect_slash(direction)
		LightPuzzleConstants.PieceType.MIRROR_BACKSLASH:
			next_direction = LightPuzzleConstants.reflect_backslash(direction)
		LightPuzzleConstants.PieceType.PLANE_MIRROR_HORIZONTAL:
			next_direction = LightPuzzleConstants.reflect_horizontal(direction)
		LightPuzzleConstants.PieceType.PLANE_MIRROR_VERTICAL:
			next_direction = LightPuzzleConstants.reflect_vertical(direction)
		LightPuzzleConstants.PieceType.PRISM_PLUS_45:
			next_direction = LightPuzzleConstants.rotate_direction(direction, 1)
		LightPuzzleConstants.PieceType.PRISM_MINUS_45:
			next_direction = LightPuzzleConstants.rotate_direction(direction, -1)
		LightPuzzleConstants.PieceType.OPAQUE_BLOCK:
			stopped = true
		_:
			if _is_filter_type(piece_type):
				next_color = filter_mask
	return {
		"direction": next_direction,
		"color_mask": next_color,
		"stopped": stopped,
	}


static func _route_rank(
	puzzle_data: LightPuzzleData,
	cell: Vector2i,
	direction: int,
	color_mask: int,
	cost: int,
	turns: int,
	color_changes: int,
	active_count: int
) -> float:
	var distance := _nearest_exit_distance(puzzle_data, cell)
	var color_penalty := 0
	if not _any_exit_accepts_color(puzzle_data, color_mask):
		color_penalty = 2
	return float(cost + distance * 2 + turns * 3 + color_changes * 2 + active_count * 5 + color_penalty)


static func _route_score(route: Dictionary) -> int:
	return (
		int(route.get("cost", 0))
		+ int(route.get("turns", 0)) * 3
		+ int(route.get("color_changes", 0)) * 2
		+ int(route.get("active_count", 0)) * 5
	)


static func _nearest_exit_distance(puzzle_data: LightPuzzleData, cell: Vector2i) -> int:
	var best := 999999
	for exit_port in puzzle_data.exits:
		if exit_port is LightPortData:
			best = mini(best, _cell_distance(cell, exit_port.cell))
	return best


static func _any_exit_accepts_color(puzzle_data: LightPuzzleData, color_mask: int) -> bool:
	for exit_port in puzzle_data.exits:
		if exit_port is LightPortData and exit_port.accepts_color(color_mask):
			return true
	return false


static func _matching_exit_keys(
	puzzle_data: LightPuzzleData,
	cell: Vector2i,
	direction: int,
	color_mask: int
) -> Array:
	var matches: Array = []
	for exit_port in puzzle_data.exits:
		if exit_port == null or exit_port.kind != LightPuzzleConstants.PortKind.EXIT:
			continue
		if exit_port.cell == cell and exit_port.direction == direction and exit_port.accepts_color(color_mask):
			matches.append(_port_key(exit_port))
	return matches


static func _route_group_can_cover_exits(puzzle_data: LightPuzzleData, routes: Array) -> bool:
	var hit_exits: Dictionary = {}
	for route in routes:
		for exit_key in (route.get("exit_keys", []) as Array):
			hit_exits[str(exit_key)] = true
	for exit_port in puzzle_data.exits:
		if exit_port == null or exit_port.kind != LightPuzzleConstants.PortKind.EXIT:
			continue
		if not hit_exits.has(_port_key(exit_port)):
			return false
	return true


static func _route_group_requirements_are_compatible(routes: Array) -> bool:
	var merged: Dictionary = {}
	for route in routes:
		var requirements: Dictionary = route.get("requirements", {})
		for key in requirements.keys():
			var requirement: Dictionary = requirements[key]
			if merged.has(key):
				var existing: Dictionary = merged[key]
				if str(existing.get("role_key", "")) != str(requirement.get("role_key", "")):
					return false
			else:
				merged[key] = requirement
	return true


static func _route_group_paths_are_compatible(routes: Array) -> bool:
	var cell_actions: Dictionary = {}
	for route in routes:
		var requirements: Dictionary = route.get("requirements", {})
		for key in requirements.keys():
			var requirement: Dictionary = requirements[key]
			cell_actions[str(key)] = str(requirement.get("role_key", EMPTY_ROLE_KEY))
	for route in routes:
		for segment in (route.get("segments", []) as Array):
			var cell: Vector2i = segment.get("from", Vector2i.ZERO)
			var key := _cell_key(cell)
			if not cell_actions.has(key):
				continue
			if str(segment.get("interaction", "empty")) == "empty":
				return false
	return true


static func _merged_requirements(routes: Array) -> Dictionary:
	var merged: Dictionary = {}
	for route in routes:
		var requirements: Dictionary = route.get("requirements", {})
		for key in requirements.keys():
			merged[key] = requirements[key]
	return merged


static func _optical_solution_key(routes: Array, requirements: Dictionary) -> String:
	var route_entries: Array[String] = []
	for route in routes:
		var segment_entries: Array[String] = []
		for segment in (route.get("segments", []) as Array):
			var from_cell: Vector2i = segment.get("from", Vector2i.ZERO)
			var to_cell: Vector2i = segment.get("to", Vector2i.ZERO)
			segment_entries.append("%d,%d>%d,%d:%d" % [
				from_cell.x,
				from_cell.y,
				to_cell.x,
				to_cell.y,
				int(segment.get("direction", 0)),
			])
		route_entries.append("%s->%s" % [
			str(route.get("source_id", "")),
			_join_strings(segment_entries, ";"),
		])
	route_entries.sort()

	var requirement_entries: Array[String] = []
	for key in requirements.keys():
		var requirement: Dictionary = requirements[key]
		if _is_filter_type(int(requirement.get("piece_type", -1))):
			continue
		var cell: Vector2i = requirement.get("cell", Vector2i.ZERO)
		requirement_entries.append("%d,%d=%s" % [cell.x, cell.y, str(requirement.get("role_key", ""))])
	requirement_entries.sort()
	return "%s|%s" % [_join_strings(route_entries, "|"), _join_strings(requirement_entries, "|")]


static func _layout_solution_key(placements: Array, positions: Array) -> String:
	var entries: Array[String] = []
	for index in range(placements.size()):
		var placement := placements[index] as LightPiecePlacement
		if placement == null or placement.piece == null:
			continue
		var cell: Vector2i = positions[index]
		entries.append("%s@%d,%d" % [_placement_visual_signature(placement), cell.x, cell.y])
	entries.sort()
	return _join_strings(entries, "|")


static func _placement_visual_signature(placement: LightPiecePlacement) -> String:
	var allowed: Array[String] = []
	for cell in placement.allowed_cells:
		if cell is Vector2i:
			allowed.append("%d,%d" % [cell.x, cell.y])
	allowed.sort()
	return "%s:%d:%s" % [
		_piece_role_key(placement.piece),
		1 if placement.locked else 0,
		_join_strings(allowed, ";"),
	]


static func _reasoning_steps_for_routes(routes: Array) -> Array[String]:
	var steps: Array[String] = []
	for route in routes:
		var color_history: Array = route.get("color_history", [LightPuzzleConstants.COLOR_WHITE])
		var start_color := LightPuzzleConstants.COLOR_WHITE
		if not color_history.is_empty():
			start_color = int(color_history[0])
		steps.append("Source %s starts as %s." % [
			str(route.get("source_id", "")),
			LightPuzzleConstants.color_name(start_color),
		])
		var requirements: Dictionary = route.get("requirements", {})
		var ordered_requirements: Array = []
		for key in requirements.keys():
			ordered_requirements.append(requirements[key])
		ordered_requirements.sort_custom(func(a, b):
			var cell_a: Vector2i = a.get("cell", Vector2i.ZERO)
			var cell_b: Vector2i = b.get("cell", Vector2i.ZERO)
			if cell_a.y == cell_b.y:
				return cell_a.x < cell_b.x
			return cell_a.y < cell_b.y
		)
		for requirement in ordered_requirements:
			var cell: Vector2i = requirement.get("cell", Vector2i.ZERO)
			var from_color := int(requirement.get("from_color", 0))
			var to_color := int(requirement.get("to_color", 0))
			var from_direction := int(requirement.get("from_direction", 0))
			var to_direction := int(requirement.get("to_direction", 0))
			if from_color != to_color:
				steps.append("At %d,%d %s changes color %s -> %s." % [
					cell.x,
					cell.y,
					_role_label(int(requirement.get("piece_type", -1)), int(requirement.get("filter_mask", 0))),
					LightPuzzleConstants.color_name(from_color),
					LightPuzzleConstants.color_name(to_color),
				])
			if from_direction != to_direction:
				steps.append("At %d,%d %s turns %s -> %s." % [
					cell.x,
					cell.y,
					_role_label(int(requirement.get("piece_type", -1)), int(requirement.get("filter_mask", 0))),
					LightPuzzleConstants.direction_name(from_direction),
					LightPuzzleConstants.direction_name(to_direction),
				])
		var history_names: Array[String] = []
		for color in (route.get("color_history", []) as Array):
			history_names.append(LightPuzzleConstants.color_name(int(color)))
		if not history_names.is_empty():
			steps.append("Color path: %s -> exit." % _join_strings(history_names, " -> "))
	return steps


static func _runtime_for_positions(placements: Array, positions: Array) -> Array:
	var runtime: Array = []
	for index in range(placements.size()):
		var placement := placements[index] as LightPiecePlacement
		if placement == null:
			runtime.append(null)
			continue
		var runtime_entry := placement.duplicate_runtime()
		runtime_entry["grid_position"] = positions[index]
		runtime.append(runtime_entry)
	return runtime


static func _initial_positions(placements: Array) -> Array:
	var positions: Array = []
	for placement in placements:
		var typed_placement := placement as LightPiecePlacement
		if typed_placement == null:
			positions.append(Vector2i(-1, -1))
		else:
			positions.append(typed_placement.grid_position)
	return positions


static func _position_is_valid(
	puzzle_data: LightPuzzleData,
	placement: LightPiecePlacement,
	target_cell: Vector2i,
	fixed_occupancy: Dictionary
) -> bool:
	return (
		_position_is_allowed_for_piece(placement, target_cell)
		and _position_is_valid_with_occupancy(puzzle_data, placement, target_cell, fixed_occupancy)
	)


static func _position_is_valid_with_occupancy(
	puzzle_data: LightPuzzleData,
	placement: LightPiecePlacement,
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
	for y in range(placement.piece.size.y):
		for x in range(placement.piece.size.x):
			if occupancy.has(_cell_key(target_cell + Vector2i(x, y))):
				return false
	return true


static func _position_is_allowed_for_piece(placement: LightPiecePlacement, target_cell: Vector2i) -> bool:
	return placement.allowed_cells.is_empty() or placement.allowed_cells.has(target_cell)


static func _piece_can_move_directly_to(
	puzzle_data: LightPuzzleData,
	placement: LightPiecePlacement,
	target_cell: Vector2i,
	occupancy: Dictionary,
	placement_index: int = -1
) -> bool:
	if placement == null or placement.piece == null:
		return false
	var start_cell := placement.grid_position
	if target_cell == start_cell:
		return true
	var delta := target_cell - start_cell
	if delta.x != 0 and delta.y != 0:
		return false
	var step := Vector2i(_axis_sign(delta.x), _axis_sign(delta.y))
	if not _move_steps_for_axis(placement.piece.move_axis).has(step):
		return false

	var current := start_cell + step
	while true:
		if not _position_is_valid_for_moving_piece(puzzle_data, placement, target_cell if current == target_cell else current, occupancy, placement_index):
			return false
		if current == target_cell:
			return true
		current += step
	return false


static func _position_is_valid_for_moving_piece(
	puzzle_data: LightPuzzleData,
	placement: LightPiecePlacement,
	target_cell: Vector2i,
	occupancy: Dictionary,
	placement_index: int
) -> bool:
	if placement == null or placement.piece == null:
		return false
	if not _position_is_allowed_for_piece(placement, target_cell):
		return false
	if target_cell.x < 0 or target_cell.y < 0:
		return false
	if target_cell.x + placement.piece.size.x > puzzle_data.board_size.x:
		return false
	if target_cell.y + placement.piece.size.y > puzzle_data.board_size.y:
		return false
	for y in range(placement.piece.size.y):
		for x in range(placement.piece.size.x):
			var key := _cell_key(target_cell + Vector2i(x, y))
			if occupancy.has(key) and int(occupancy[key]) != placement_index:
				return false
	return true


static func _move_steps_for_axis(move_axis: int) -> Array[Vector2i]:
	match move_axis:
		LightPuzzleConstants.MoveAxis.HORIZONTAL:
			return [Vector2i(1, 0), Vector2i(-1, 0)]
		LightPuzzleConstants.MoveAxis.VERTICAL:
			return [Vector2i(0, 1), Vector2i(0, -1)]
		LightPuzzleConstants.MoveAxis.LOCKED:
			return []
	return [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


static func _axis_sign(value: int) -> int:
	if value > 0:
		return 1
	if value < 0:
		return -1
	return 0


static func _piece_overlaps_any_cell(position: Vector2i, size: Vector2i, cells: Dictionary) -> bool:
	for y in range(size.y):
		for x in range(size.x):
			if cells.has(_cell_key(position + Vector2i(x, y))):
				return true
	return false


static func _beam_cells_for_routes(routes: Array) -> Dictionary:
	var cells: Dictionary = {}
	for route in routes:
		for cell in (route.get("path_cells", []) as Array):
			if cell is Vector2i:
				cells[_cell_key(cell)] = true
	return cells


static func _piece_is_noop(piece: LightPieceData) -> bool:
	return piece.piece_type == LightPuzzleConstants.PieceType.GLASS_BLOCK


static func _piece_type_is_noop(piece_type: int) -> bool:
	return piece_type == LightPuzzleConstants.PieceType.GLASS_BLOCK


static func _is_filter_type(piece_type: int) -> bool:
	return piece_type in [
		LightPuzzleConstants.PieceType.FILTER_RED,
		LightPuzzleConstants.PieceType.FILTER_GREEN,
		LightPuzzleConstants.PieceType.FILTER_BLUE,
		LightPuzzleConstants.PieceType.FILTER_YELLOW,
		LightPuzzleConstants.PieceType.FILTER_CYAN,
		LightPuzzleConstants.PieceType.FILTER_MAGENTA,
	]


static func _filter_mask_for_piece(piece: LightPieceData) -> int:
	if piece == null:
		return LightPuzzleConstants.COLOR_WHITE
	if piece.is_filter():
		return piece.get_filter_mask()
	return piece.filter_mask


static func _piece_role_key(piece: LightPieceData) -> String:
	if piece == null:
		return EMPTY_ROLE_KEY
	return _role_key(piece.piece_type, _filter_mask_for_piece(piece))


static func _role_key(piece_type: int, filter_mask: int) -> String:
	return "%d:%d" % [piece_type, filter_mask if _is_filter_type(piece_type) else 0]


static func _role_label(piece_type: int, filter_mask: int) -> String:
	match piece_type:
		LightPuzzleConstants.PieceType.MIRROR_SLASH:
			return "mirror /"
		LightPuzzleConstants.PieceType.MIRROR_BACKSLASH:
			return "mirror \\"
		LightPuzzleConstants.PieceType.PLANE_MIRROR_HORIZONTAL:
			return "horizontal mirror"
		LightPuzzleConstants.PieceType.PLANE_MIRROR_VERTICAL:
			return "vertical mirror"
		LightPuzzleConstants.PieceType.PRISM_PLUS_45:
			return "+45 prism"
		LightPuzzleConstants.PieceType.PRISM_MINUS_45:
			return "-45 prism"
		LightPuzzleConstants.PieceType.OPAQUE_BLOCK:
			return "opaque block"
		_:
			if _is_filter_type(piece_type):
				return "%s filter" % LightPuzzleConstants.color_name(filter_mask).to_lower()
	return "piece"


static func _route_state_key(state: Dictionary) -> String:
	var cell: Vector2i = state.get("cell", Vector2i.ZERO)
	return "%d,%d,%d,%d|%s" % [
		cell.x,
		cell.y,
		int(state.get("direction", 0)),
		int(state.get("color_mask", 0)),
		_requirement_signature(state.get("requirements", {})),
	]


static func _requirement_signature(requirements: Dictionary) -> String:
	var entries: Array[String] = []
	for key in requirements.keys():
		var requirement: Dictionary = requirements[key]
		entries.append("%s=%s" % [str(key), str(requirement.get("role_key", ""))])
	entries.sort()
	return _join_strings(entries, "|")


static func _dictionary_int_keys(values: Dictionary) -> Array:
	var output: Array = []
	for key in values.keys():
		output.append(int(key))
	output.sort()
	return output


static func _add_piece_cells(occupancy: Dictionary, placement_index: int, position: Vector2i, size: Vector2i) -> void:
	for y in range(size.y):
		for x in range(size.x):
			occupancy[_cell_key(position + Vector2i(x, y))] = placement_index


static func _is_inside(cell: Vector2i, board_size: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < board_size.x and cell.y < board_size.y


static func _cell_is_on_ray(origin: Vector2i, target: Vector2i, direction: int) -> bool:
	var step := LightPuzzleConstants.direction_vector(direction)
	if step == Vector2i.ZERO:
		return false
	var cell := origin
	for _index in range(256):
		if cell == target:
			return true
		cell += step
	return false


static func _cell_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(abs(a.x - b.x), abs(a.y - b.y))


static func _time_limit_reached(started_msec: int, max_msec: int) -> bool:
	return max_msec > 0 and Time.get_ticks_msec() - started_msec >= max_msec


static func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


static func _port_key(port: LightPortData) -> String:
	if port.port_id != "":
		return port.port_id
	return "%d,%d,%d" % [port.cell.x, port.cell.y, port.direction]


static func _join_strings(values: Array, separator: String) -> String:
	var output := ""
	for index in range(values.size()):
		if index > 0:
			output += separator
		output += str(values[index])
	return output


static func _build_message(result: Dictionary) -> String:
	var visited := int(result.get("visited_routes", 0))
	var optical := int(result.get("optical_solution_count", 0))
	var layouts := int(result.get("layout_solution_count", 0))
	if bool(result.get("truncated", false)):
		return "Visual solver truncated by %s after visiting %d route states; found %d optical / %d layout solutions." % [
			str(result.get("truncated_reason", "")),
			visited,
			optical,
			layouts,
		]
	if optical == 0:
		return "No visual route found after visiting %d route states." % visited
	if layouts == 0:
		return "%d optical route(s) found, but no full layout can park the unused pieces safely." % optical
	if optical == 1:
		return "Unique optical solution found with %d full layout(s) after visiting %d route states." % [
			layouts,
			visited,
		]
	return "%d optical solutions and %d full layout(s) found after visiting %d route states." % [
		optical,
		layouts,
		visited,
	]
