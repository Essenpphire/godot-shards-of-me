extends CanvasLayer

const HARD_02_SCENE: PackedScene = preload("res://scenes/gameplay/puzzles/hard_02.tscn")

var _active_puzzle: LightPuzzleBoard

## 打开厨房机关盒对应的 hard_02 解谜场景。
func open_hard_02() -> void:
	if is_instance_valid(_active_puzzle):
		return
	_active_puzzle = HARD_02_SCENE.instantiate() as LightPuzzleBoard
	# hard_02 的资源 puzzle_id 暂为 new_light_puzzle，这里转成稳定的场景级 ID。
	_active_puzzle.puzzle_solved.connect(_on_hard_02_solved)
	add_child(_active_puzzle)

## 关闭当前由 PuzzleLayer 打开的解谜场景。
func close_active_puzzle() -> void:
	if not is_instance_valid(_active_puzzle):
		return
	_active_puzzle.queue_free()
	_active_puzzle = null

func _on_hard_02_solved(_puzzle_id: String) -> void:
	EventBus.puzzle_light_solved.emit("hard_02")
