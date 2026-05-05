class_name Room
extends Node

@onready var Player : CharacterBody2D = $Player
var can_change_scene : bool = false
var next_scene : String = ""

## 切换场景
## scene_name相对于res://scenes/gameplay定位
func change_scene() -> void:
	if can_change_scene == true and Input.is_action_pressed("互动"):
			GGT.change_scene("res://scenes/gameplay/" + next_scene + ".tscn")


func _ready() -> void:
	var scene_data = GGT.get_current_scene_data()
	print("GGT/Gameplay: scene params are ", scene_data.params)

	#Player.position = get_viewport().get_visible_rect().size / 2
	var viewport : Rect2 = get_viewport().get_visible_rect()
	GameManager.cameraLimit(0, 0, viewport.size.x, viewport.size.y)
	
	if GGT.is_changing_scene(): # this will be false if starting the scene with "Run current scene" or F6 shortcut
		await GGT.scene_transition_finished

	print("GGT/Gameplay: scene transition animation finished")


func _physics_process(delta: float) -> void:
	change_scene()


func _on_door_body_entered(body: Node2D) -> void:
	can_change_scene = true


func _on_door_body_exited(body: Node2D) -> void:
	can_change_scene = false
