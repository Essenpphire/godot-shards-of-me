extends SceneTree


func _init() -> void:
	var failures: Array[String] = []

	_expect_direction(
		"horizontal N -> S",
		LightPuzzleConstants.reflect_horizontal(LightPuzzleConstants.Direction.N),
		LightPuzzleConstants.Direction.S,
		failures
	)
	_expect_direction(
		"horizontal SE -> NE",
		LightPuzzleConstants.reflect_horizontal(LightPuzzleConstants.Direction.SE),
		LightPuzzleConstants.Direction.NE,
		failures
	)
	_expect_direction(
		"vertical E -> W",
		LightPuzzleConstants.reflect_vertical(LightPuzzleConstants.Direction.E),
		LightPuzzleConstants.Direction.W,
		failures
	)
	_expect_direction(
		"vertical NW -> NE",
		LightPuzzleConstants.reflect_vertical(LightPuzzleConstants.Direction.NW),
		LightPuzzleConstants.Direction.NE,
		failures
	)
	_expect_apply_piece(
		"horizontal mirror preserves color",
		LightPuzzleConstants.PieceType.PLANE_MIRROR_HORIZONTAL,
		LightPuzzleConstants.Direction.N,
		LightPuzzleConstants.COLOR_WHITE,
		LightPuzzleConstants.Direction.S,
		LightPuzzleConstants.COLOR_WHITE,
		failures
	)
	_expect_apply_piece(
		"vertical mirror preserves color",
		LightPuzzleConstants.PieceType.PLANE_MIRROR_VERTICAL,
		LightPuzzleConstants.Direction.E,
		LightPuzzleConstants.COLOR_RED,
		LightPuzzleConstants.Direction.W,
		LightPuzzleConstants.COLOR_RED,
		failures
	)

	if failures.is_empty():
		print("Light beam solver smoke test passed.")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)


func _expect_direction(label: String, actual: int, expected: int, failures: Array[String]) -> void:
	if actual == expected:
		return
	failures.append("%s expected %s but got %s" % [
		label,
		LightPuzzleConstants.direction_name(expected),
		LightPuzzleConstants.direction_name(actual),
	])


func _expect_apply_piece(
	label: String,
	piece_type: int,
	direction: int,
	color_mask: int,
	expected_direction: int,
	expected_color: int,
	failures: Array[String]
) -> void:
	var piece := LightPieceData.new()
	piece.piece_type = piece_type

	var result := LightBeamSolver._apply_piece(piece, direction, color_mask)
	if bool(result.get("stopped", true)):
		failures.append("%s unexpectedly stopped the beam" % label)
	if int(result.get("direction", -1)) != expected_direction:
		failures.append("%s expected direction %s but got %s" % [
			label,
			LightPuzzleConstants.direction_name(expected_direction),
			LightPuzzleConstants.direction_name(int(result.get("direction", -1))),
		])
	if int(result.get("color_mask", -1)) != expected_color:
		failures.append("%s expected color %s but got %s" % [
			label,
			LightPuzzleConstants.color_name(expected_color),
			LightPuzzleConstants.color_name(int(result.get("color_mask", -1))),
		])
