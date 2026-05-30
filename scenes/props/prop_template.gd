## 可互动物体基类
class_name Prop
extends StaticBody2D

## 是否能互动
@export var can_interact : bool = false
@onready var sprite : Sprite2D = $Sprite2D
@onready var collision : CollisionShape2D = $CollisionShape2D
@onready var detection : Area2D = $Detection
@onready var hint : Panel = $Hint
	
## 是否在互动范围内
var _in_range : bool = false
## 是否被互动过
var _interacted : bool = false
	
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
		_interacted = true
		handle_interact()

func _on_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		hint.fade_in()
		_in_range = true

func _on_detection_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		hint.fade_out()
		_in_range = false
