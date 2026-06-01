extends CanvasLayer

const KITCHEN_PUZZLE_SCENE: PackedScene = preload("res://scenes/gameplay/puzzles/easy_01.tscn")
const KITCHEN_PUZZLE_ID: String = "easy_01"

var _active_puzzle: LightPuzzleBoard

## 打开厨房机关盒对应的 easy_01 解谜场景。
func open_kitchen_puzzle() -> void:
	if is_instance_valid(_active_puzzle):
		if _active_puzzle.visible:
			return
		close_active_puzzle()
	_active_puzzle = KITCHEN_PUZZLE_SCENE.instantiate() as LightPuzzleBoard
	_active_puzzle.stable_puzzle_id = KITCHEN_PUZZLE_ID
	_active_puzzle.puzzle_solved.connect(_on_kitchen_puzzle_solved)
	_active_puzzle.puzzle_closed.connect(_on_active_puzzle_closed)
	add_child(_active_puzzle)

## 关闭当前由 PuzzleLayer 打开的解谜场景。
func close_active_puzzle() -> void:
	if not is_instance_valid(_active_puzzle):
		return
	var puzzle := _active_puzzle
	_active_puzzle = null
	if puzzle.puzzle_closed.is_connected(_on_active_puzzle_closed):
		puzzle.puzzle_closed.disconnect(_on_active_puzzle_closed)
	if puzzle.visible:
		puzzle.close_puzzle()
	else:
		puzzle.save_current_state()
	puzzle.queue_free()


func flush_active_puzzle_state() -> void:
	if not is_instance_valid(_active_puzzle):
		return
	_active_puzzle.save_current_state()

func _on_kitchen_puzzle_solved(puzzle_id: String) -> void:
	EventBus.puzzle_light_solved.emit(puzzle_id)


func _on_active_puzzle_closed(_puzzle_id: String) -> void:
	close_active_puzzle()
