## 可互动物体基类
class_name Prop
extends StaticBody2D

@onready var sprite : Sprite2D = $Sprite2D
@onready var collision : CollisionShape2D = $CollisionShape2D
@onready var detection : Area2D = $Detection
@onready var hint : Panel = $Hint
## 在范围内是否能互动
var can_interact : bool = false
## 是否一次性互动
var oneshot : bool = true
	
## 虚函数 [br]
## 定义物品互动行为
func handle_interact():
	pass

func _ready() -> void:
	pass

func _physics_process(delta: float) -> void:
	if Input.is_action_pressed("互动") and can_interact:
		handle_interact()
		if oneshot:
			hint.fade_out()
			#detection.body_entered.disconnect(_on_detection_body_entered)
			#detection.body_entered.disconnect(_on_detection_body_exited)

func _on_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		hint.fade_in()
		can_interact = true

func _on_detection_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		hint.fade_out()
		can_interact = false
