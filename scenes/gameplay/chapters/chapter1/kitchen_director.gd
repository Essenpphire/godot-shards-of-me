extends Node

const HARD_02_PUZZLE_ID: String = "hard_02"
const SOLVED_HOLD_SECONDS: float = 2.0

@onready var home_key: Node = $"../Sortables/HomeKey"

var _finishing_puzzle: bool = false


func _ready() -> void:
	EventBus.puzzle_light_solved.connect(_on_puzzle_light_solved)
	_refresh_key_visibility()


## 厨房钥匙只有在机关盒谜题解开后才出现。
func _refresh_key_visibility() -> void:
	var solved: bool = Chapter.get_data("chapter1_kitchen_box_solved", false)
	if is_instance_valid(home_key):
		home_key.visible = solved
		home_key.can_interact = solved


func _on_puzzle_light_solved(puzzle_id: String) -> void:
	if puzzle_id != HARD_02_PUZZLE_ID or _finishing_puzzle:
		return
	_finishing_puzzle = true
	Chapter.set_data("chapter1_kitchen_box_solved", true)
	# 解谜成功后先停留在当前界面，让玩家看清完成状态。
	await get_tree().create_timer(SOLVED_HOLD_SECONDS).timeout
	PuzzleLayer.close_active_puzzle()
	_refresh_key_visibility()
	Dialogic.start("chapter1", "kitchen_box_solve")
	_finishing_puzzle = false
