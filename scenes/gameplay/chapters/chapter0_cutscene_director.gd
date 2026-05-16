extends Node

@export_group("Cameras")
@export var pcam_start: PhantomCamera2D
@export var pcam_player: PhantomCamera2D

@onready var player: CharacterBody2D = $"../Player"

func _ready() -> void:
	start_intro_cutscene()
#总调度
func start_intro_cutscene() -> void:
	# 1. 锁定玩家控制 (你需要在 Player 脚本中加一个变量，比如 is_input_locked)
	player.set_physics_process(false) # 临时封锁移动，或者通过自定义状态机控制
	# 2. 初始机位激活，播放下课铃与人群声
	pcam_player.priority = 2
	#移动到npc
	await get_tree().create_timer(0.5).timeout  
	pcam_start.priority = 5
	#移动回来
	await get_tree().create_timer(2.0).timeout  
	_pan_camera_to_player()	
	#解除移动锁定
	await get_tree().create_timer(2.0).timeout
	player.set_physics_process(true)

func _pan_camera_to_player() -> void:
	#更改相机优先级来切换镜头
	pcam_player.priority = 10
