extends Node

const HARD_02_PUZZLE_ID: String = "easy_01"
const SOLVED_HOLD_SECONDS: float = 2.0
const COMPLETE_CLUE_ID: String = "10"
const LOCKED_BOX_ITEM_ID: String = "8"

@onready var home_key: Node = $"../Sortables/HomeKey"
@onready var locked_box: Prop = $"../Sortables/LockedBox"

var _finishing_puzzle: bool = false


func _ready() -> void:
	EventBus.puzzle_light_solved.connect(_on_puzzle_light_solved)
	EventBus.clue_add_item.connect(_on_clue_state_changed)
	EventBus.clue_update_book.connect(_on_clue_state_changed)
	_refresh_key_visibility()
	_refresh_locked_box_visibility()


## 厨房钥匙只有在机关盒谜题解开后才出现。
func _refresh_key_visibility() -> void:
	var solved: bool = Chapter.get_data("chapter1_kitchen_box_solved", false)
	if is_instance_valid(home_key):
		home_key.visible = solved
		home_key.can_interact = solved


func _refresh_locked_box_visibility(_unused = null) -> void:
	if not is_instance_valid(locked_box):
		return

	if _has_collected_locked_box():
		locked_box.hide()
		locked_box.can_interact = false
		locked_box.detection.monitoring = false
		locked_box.detection.monitorable = false
		locked_box.hint.hide()
		return

	if not _has_complete_clue():
		locked_box.hide()
		locked_box.can_interact = false
		locked_box.detection.monitoring = false
		locked_box.detection.monitorable = false
		locked_box.hint.hide()
		locked_box._in_range = false
		return

	locked_box.show()
	locked_box.can_interact = true
	locked_box.sprite.hide()
	locked_box.detection.monitoring = true
	locked_box.detection.monitorable = true


func _has_complete_clue() -> bool:
	return ClueManager.get_clues().has(COMPLETE_CLUE_ID)


func _has_collected_locked_box() -> bool:
	return (
		ClueManager.get_clues().has(LOCKED_BOX_ITEM_ID)
		or ClueManager.has_in_inventory(LOCKED_BOX_ITEM_ID)
	)


func _on_clue_state_changed(_unused = null) -> void:
	_refresh_locked_box_visibility()


func _on_puzzle_light_solved(puzzle_id: String) -> void:
	if puzzle_id != HARD_02_PUZZLE_ID or _finishing_puzzle:
		return
	if Chapter.get_data("chapter1_kitchen_box_solved", false):
		return
	_finishing_puzzle = true
	Chapter.set_data("chapter1_kitchen_box_solved", true)
	# 解谜成功后先停留在当前界面，让玩家看清完成状态。
	await get_tree().create_timer(SOLVED_HOLD_SECONDS).timeout
	PuzzleLayer.close_active_puzzle()
	_refresh_key_visibility()
	Dialogic.start("chapter1", "kitchen_box_solve")
	_finishing_puzzle = false
