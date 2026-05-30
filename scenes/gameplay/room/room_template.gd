class_name Room
extends Node

@export var bgm : AudioStream

@onready var player: CharacterBody2D = $Sortables/Player
@onready var player_camera: PhantomCamera2D = $Sortables/Player/PlayerPhantomCamera2D
@onready var main_camera: Camera2D = $Camera2D


func _ready() -> void:
	## 传送玩家
	var params = GGT.get_current_scene_data().params
	var _pos : Vector2 = params.get("player_pos", Vector2.ZERO)
	if _pos != Vector2.ZERO:
		_apply_player_start_position(_pos)

	_prime_main_camera()
	
	## @todo 以后存fullpath得了，别用太直观的思路写场景控制。。。
	var cur_scene : String = scene_file_path
	cur_scene = cur_scene.trim_prefix("res://scenes/gameplay/chapters/").trim_suffix(".tscn")
	Chapter.cur_scene = cur_scene

	if GGT.is_changing_scene():
		await GGT.scene_transition_finished

	if bgm:
		Audio.set_volume(0, 0.1)
		Audio.play_music(bgm)


func _apply_player_start_position(pos: Vector2) -> void:
	player.global_position = pos
	GameManager.change_player_pos(pos)


func _prime_main_camera() -> void:
	main_camera.make_current()
	main_camera.offset = Vector2.ZERO

	player_camera.teleport_position()
	main_camera.global_transform = player_camera.get_transform_output()
	main_camera.zoom = player_camera.zoom
	main_camera.limit_left = player_camera.limit_left
	main_camera.limit_top = player_camera.limit_top
	main_camera.limit_right = player_camera.limit_right
	main_camera.limit_bottom = player_camera.limit_bottom
	main_camera.reset_physics_interpolation()
