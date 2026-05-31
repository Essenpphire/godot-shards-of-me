## 可互动物体基类
class_name Prop
extends StaticBody2D

## 是否能互动
@export var can_interact : bool = false
## 互动前必须已经收集的线索 ID。为空时不限制互动。
@export var required_clue_id : String = ""
## 需要按顺序检查的线索 ID。用于同一个物体有多个前置步骤的情况。
@export var required_clue_ids : PackedStringArray = PackedStringArray()
## 未满足前置线索时播放的 Dialogic 时间线。
@export var required_clue_dialog_chapter : String = ""
## 未满足前置线索时播放的 Dialogic 标签。
@export var required_clue_dialog_label : String = ""
## 多前置步骤分别对应的 Dialogic 标签。数量不足时使用最后一个标签。
@export var required_clue_dialog_labels : PackedStringArray = PackedStringArray()
@onready var sprite : Sprite2D = $Sprite2D
@onready var collision : CollisionShape2D = $CollisionShape2D
@onready var detection : Area2D = $Detection
@onready var hint : Panel = $Hint
	
## 是否在互动范围内
var _in_range : bool = false
## 是否被互动过
var _interacted : bool = false
var _missing_required_dialog_label : String = ""
	
## 虚函数 [br]
## 定义物品互动行为
func handle_interact():
	pass

func _ready() -> void:
	if can_interact:
		hint.show()
	else:
		hint.hide()

func _physics_process(delta: float) -> void:
	if GameManager.is_player_control_locked():
		return

	if Input.is_action_just_pressed("互动") and can_interact:
		if not _in_range:
			return
		if _interacted:
			return
		if not _has_required_clue():
			_play_required_clue_dialog()
			return
		_interacted = true
		handle_interact()

func _has_required_clue() -> bool:
	_missing_required_dialog_label = ""
	var required_ids : PackedStringArray = required_clue_ids
	if required_ids.is_empty() and not required_clue_id.is_empty():
		required_ids = PackedStringArray([required_clue_id])
	if required_ids.is_empty():
		return true
	var collected_clues : Array = Chapter.get_data("collected_clues", [])
	for index : int in range(required_ids.size()):
		if not collected_clues.has(required_ids[index]):
			_missing_required_dialog_label = _get_required_clue_dialog_label(index)
			return false
	return true

func _play_required_clue_dialog() -> void:
	if required_clue_dialog_chapter.is_empty() or _missing_required_dialog_label.is_empty():
		return
	Dialogic.start(required_clue_dialog_chapter, _missing_required_dialog_label)

func _get_required_clue_dialog_label(index : int) -> String:
	if required_clue_dialog_labels.is_empty():
		return required_clue_dialog_label
	return required_clue_dialog_labels[min(index, required_clue_dialog_labels.size() - 1)]

func _on_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		hint.fade_in()
		_in_range = true

func _on_detection_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		hint.fade_out()
		_in_range = false
