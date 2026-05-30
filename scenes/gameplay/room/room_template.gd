class_name Room
extends Node

@onready var Player : CharacterBody2D = _find_player()
@onready var main_camera: Camera2D = _find_main_camera()

@export var bgm : AudioStream

func _ready() -> void:
	## 传送玩家
	var params = GGT.get_current_scene_data().params
	var _pos : Vector2 = params.get("player_pos", Vector2.ZERO)
	if _pos != Vector2.ZERO:
		GameManager.change_player_pos(_pos)
		$Camera2D.position = _pos
	
	## @todo 以后存fullpath得了，别用太直观的思路写场景控制。。。
	var cur_scene : String = scene_file_path
	cur_scene = cur_scene.trim_prefix("res://scenes/gameplay/chapters/").trim_suffix(".tscn")
	Chapter.cur_scene = cur_scene

	if GGT.is_changing_scene():
		await GGT.scene_transition_finished

	if bgm:
		Audio.set_volume(0, 0.1)
		Audio.play_music(bgm)


func _find_player() -> CharacterBody2D:
	var direct_player := get_node_or_null("Player")
	if direct_player is CharacterBody2D:
		return direct_player as CharacterBody2D

	var sortable_player := get_node_or_null("Sortables/Player")
	if sortable_player is CharacterBody2D:
		return sortable_player as CharacterBody2D

	for node in get_tree().get_nodes_in_group("Player"):
		if node is CharacterBody2D and is_ancestor_of(node):
			return node as CharacterBody2D

	return null


## 真实渲染相机由 PhantomCameraHost 驱动，挂在 room 根节点 "Camera2D"。
## 跟早期版本不同，它已经不挂在玩家身上，玩家移动不会带着相机跑。
func _find_main_camera() -> Camera2D:
	var camera := get_node_or_null("Camera2D")
	return camera as Camera2D if camera is Camera2D else null
