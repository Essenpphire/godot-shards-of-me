class_name LightBeamSolver
extends RefCounted


static func solve(puzzle_data: LightPuzzleData, runtime_placements: Array = []) -> Dictionary:
	if puzzle_data == null:
		return {
			"solved": false,
			"segments": [],
			"exit_hits": {},
			"stops": [{"reason": "missing_puzzle_data"}],
		}

	var placements := runtime_placements
	if placements.is_empty():
		placements = puzzle_data.create_runtime_placements()

	var occupancy := _build_occupancy(placements)
	var segments: Array = []
	var stops: Array = []
	var exit_hits: Dictionary = {}
	for exit_port in puzzle_data.exits:
		if exit_port != null:
			exit_hits[_port_key(exit_port)] = false

	for source in puzzle_data.sources:
		if source == null or source.kind != LightPuzzleConstants.PortKind.SOURCE:
			continue
		var trace := _trace_source(puzzle_data, source, occupancy, exit_hits)
		segments.append_array(trace["segments"])
		stops.append_array(trace["stops"])

	var solved := puzzle_data.exits.size() > 0
	for exit_port in puzzle_data.exits:
		if exit_port == null:
			continue
		if not exit_hits.get(_port_key(exit_port), false):
			solved = false
			break

	return {
		"solved": solved,
		"segments": segments,
		"exit_hits": exit_hits,
		"stops": stops,
	}


static func _trace_source(
	puzzle_data: LightPuzzleData,
	source: LightPortData,
	occupancy: Dictionary,
	exit_hits: Dictionary
) -> Dictionary:
	var pos := source.cell
	var direction := source.direction
	var color_mask := source.color_mask
	var segments: Array = []
	var stops: Array = []
	var seen_states: Dictionary = {}

	for step in range(puzzle_data.max_beam_steps):
		if not _is_inside(pos, puzzle_data.board_size):
			stops.append({"reason": "source_outside_board", "source": source.port_id, "cell": pos})
			break

		var state_key := "%d,%d,%d,%d" % [pos.x, pos.y, direction, color_mask]
		if seen_states.has(state_key):
			stops.append({"reason": "loop_detected", "source": source.port_id, "cell": pos})
			break
		seen_states[state_key] = true

		var interaction := "empty"
		var occupancy_info = occupancy.get(_cell_key(pos), null)
		if occupancy_info != null:
			var piece := _get_runtime_piece(occupancy_info["placement"])
			if piece != null:
				interaction = piece.piece_id
				var applied := _apply_piece(piece, direction, color_mask)
				direction = applied["direction"]
				color_mask = applied["color_mask"]
				if applied["stopped"]:
					stops.append({
						"reason": applied["reason"],
						"source": source.port_id,
						"cell": pos,
						"piece": piece.piece_id,
					})
					break

		if color_mask == 0:
			stops.append({"reason": "light_absorbed", "source": source.port_id, "cell": pos})
			break

		var next_pos := pos + LightPuzzleConstants.direction_vector(direction)
		segments.append({
			"source": source.port_id,
			"from": pos,
			"to": next_pos,
			"direction": direction,
			"color_mask": color_mask,
			"interaction": interaction,
		})

		if not _is_inside(next_pos, puzzle_data.board_size):
			if not _mark_matching_exit(puzzle_data, pos, direction, color_mask, exit_hits):
				stops.append({
					"reason": "missed_exit",
					"source": source.port_id,
					"cell": pos,
					"direction": direction,
					"color_mask": color_mask,
				})
			break

		pos = next_pos

	return {"segments": segments, "stops": stops}


static func _apply_piece(piece: LightPieceData, direction: int, color_mask: int) -> Dictionary:
	var next_direction := direction
	var next_color := color_mask
	var stopped := false
	var reason := ""

	match piece.piece_type:
		LightPuzzleConstants.PieceType.MIRROR_SLASH:
			next_direction = LightPuzzleConstants.reflect_slash(direction)
		LightPuzzleConstants.PieceType.MIRROR_BACKSLASH:
			next_direction = LightPuzzleConstants.reflect_backslash(direction)
		LightPuzzleConstants.PieceType.PRISM_PLUS_45:
			next_direction = LightPuzzleConstants.rotate_direction(direction, 1)
		LightPuzzleConstants.PieceType.PRISM_MINUS_45:
			next_direction = LightPuzzleConstants.rotate_direction(direction, -1)
		LightPuzzleConstants.PieceType.OPAQUE_BLOCK:
			stopped = true
			reason = "blocked_by_opaque_piece"
		_:
			if piece.is_filter():
				next_color = color_mask & piece.get_filter_mask()

	return {
		"direction": next_direction,
		"color_mask": next_color,
		"stopped": stopped,
		"reason": reason,
	}


static func _mark_matching_exit(
	puzzle_data: LightPuzzleData,
	cell: Vector2i,
	direction: int,
	color_mask: int,
	exit_hits: Dictionary
) -> bool:
	var matched := false
	for exit_port in puzzle_data.exits:
		if exit_port == null or exit_port.kind != LightPuzzleConstants.PortKind.EXIT:
			continue
		if exit_port.cell == cell and exit_port.direction == direction and exit_port.accepts_color(color_mask):
			exit_hits[_port_key(exit_port)] = true
			matched = true
	return matched


static func _build_occupancy(runtime_placements: Array) -> Dictionary:
	var occupancy: Dictionary = {}
	for index in range(runtime_placements.size()):
		var placement = runtime_placements[index]
		var piece := _get_runtime_piece(placement)
		if piece == null:
			continue
		var position := _get_runtime_position(placement)
		for y in range(piece.size.y):
			for x in range(piece.size.x):
				var cell := position + Vector2i(x, y)
				occupancy[_cell_key(cell)] = {
					"placement_index": index,
					"placement": placement,
				}
	return occupancy


static func _get_runtime_piece(placement) -> LightPieceData:
	if placement is LightPiecePlacement:
		return placement.piece
	if placement is Dictionary:
		return placement.get("piece", null)
	return null


static func _get_runtime_position(placement) -> Vector2i:
	if placement is LightPiecePlacement:
		return placement.grid_position
	if placement is Dictionary:
		return placement.get("grid_position", Vector2i.ZERO)
	return Vector2i.ZERO


static func _is_inside(cell: Vector2i, board_size: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < board_size.x and cell.y < board_size.y


static func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


static func _port_key(port: LightPortData) -> String:
	if port.port_id != "":
		return port.port_id
	return "%d,%d,%d" % [port.cell.x, port.cell.y, port.direction]
