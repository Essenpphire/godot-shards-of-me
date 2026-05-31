extends SceneTree


func _init() -> void:
	var puzzle := load("res://resources/puzzles/light_board/hard_01.tres") as LightPuzzleData
	if puzzle == null:
		push_error("Failed to load hard_01.tres")
		quit(1)
		return

	var result := LightPuzzleStateSolver.solve_reachable(puzzle, 0, 1000000, 20.0)
	var failures: Array[String] = []
	if not bool(result.get("completed", false)):
		failures.append("solver did not complete: %s" % str(result.get("truncated_reason", "")))
	if int(result.get("labelled_solution_count", -1)) != 8:
		failures.append("expected 8 labelled solutions, got %d" % int(result.get("labelled_solution_count", -1)))
	if int(result.get("visual_solution_count", -1)) != 4:
		failures.append("expected 4 visual solutions, got %d" % int(result.get("visual_solution_count", -1)))
	if (result.get("first_solution_positions", []) as Array).is_empty():
		failures.append("expected a first solution preview")

	if failures.is_empty():
		print("Light puzzle state solver smoke test passed.")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)
