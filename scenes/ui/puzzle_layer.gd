extends CanvasLayer

const HARD_02_SCENE: PackedScene = preload("res://scenes/gameplay/puzzles/hard_02.tscn")
const HARD_02_PUZZLE_ID: String = "hard_02"

var _active_puzzle: LightPuzzleBoard

## 打开厨房机关盒对应的 hard_02 解谜场景。
func open_hard_02() -> void:
	if is_instance_valid(_active_puzzle):
		if _active_puzzle.visible:
			return
		close_active_puzzle()
	_active_puzzle = HARD_02_SCENE.instantiate() as LightPuzzleBoard
	# hard_02 的资源 puzzle_id 暂为 new_light_puzzle，这里转成稳定的场景级 ID。
	_active_puzzle.stable_puzzle_id = HARD_02_PUZZLE_ID
	_active_puzzle.puzzle_solved.connect(_on_hard_02_solved)
	_active_puzzle.puzzle_closed.connect(_on_active_puzzle_closed)
	add_child(_active_puzzle)

## 关闭当前由 PuzzleLayer 打开的解谜场景。
func close_active_puzzle() -> void:
	if not is_instance_valid(_active_puzzle):
		return
	_active_puzzle.save_current_state()
	_active_puzzle.queue_free()
	_active_puzzle = null


func flush_active_puzzle_state() -> void:
	if not is_instance_valid(_active_puzzle):
		return
	_active_puzzle.save_current_state()

func _on_hard_02_solved(_puzzle_id: String) -> void:
	EventBus.puzzle_light_solved.emit("hard_02")


func _on_active_puzzle_closed(_puzzle_id: String) -> void:
	close_active_puzzle()
