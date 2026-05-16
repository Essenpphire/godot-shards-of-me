class_name Room
extends Node

@onready var Player : CharacterBody2D = $Player
@onready var main_camera: Camera2D = $Player/Camera2D 
var can_change_scene : bool = false
var next_scene : String = ""

## 切换场景
## scene_name相对于res://scenes/gameplay定位
func change_scene() -> void:
	if can_change_scene == true and Input.is_action_pressed("互动"):
			GGT.change_scene("res://scenes/gameplay/" + next_scene + ".tscn")
			# 防止玩家一直按E
			can_change_scene = false


func _ready() -> void:
	#锁定相机
	_stabilize_camera()
	
	var scene_data = GGT.get_current_scene_data()
	print("GGT/Gameplay: scene params are ", scene_data.params)

	#Player.position = get_viewport().get_visible_rect().size / 2
	#var viewport : Rect2 = get_viewport().get_visible_rect()	
	if GGT.is_changing_scene(): # this will be false if starting the scene with "Run current scene" or F6 shortcut
		await GGT.scene_transition_finished

	print("GGT/Gameplay: scene transition animation finished")


func _physics_process(delta: float) -> void:
	change_scene()


func _on_door_body_entered(body: Node2D) -> void:
	can_change_scene = true


func _on_door_body_exited(body: Node2D) -> void:
	can_change_scene = false

## 逻辑：查找当前场景中优先级最高的 PhantomCamera2D，并在渲染前强制同步位置和 Zoom。
func _stabilize_camera() -> void:
	if not is_instance_valid(main_camera):
		return
	var active_pcam: PhantomCamera2D = null
	var max_priority: int = -1

	# 获取场景中所有属于 "PCam" 组的相机
	var all_pcams = get_tree().get_nodes_in_group("PCam")

	# 自动筛选出优先级最高的那个相机（即玩家一睁眼应该看到的画面）
	for pcam in all_pcams:
		if pcam is PhantomCamera2D and pcam.priority > max_priority:
			max_priority = pcam.priority
			active_pcam = pcam
	# 强制将原生相机的数据覆盖，彻底消灭第 0 帧的默认值
	if active_pcam and active_pcam.tween_resource:
		var original_duration: float = active_pcam.tween_resource.duration
		active_pcam.tween_resource.duration = 0.0
		
		# 硬件相机基础位置初步拉近，缩小物理视差跨度
		main_camera.global_position = active_pcam.global_position
		await get_tree().process_frame
		
		# 无缝校准完毕，将原版精心配置的运镜时间归还，确保后续游戏内演出的电影级运镜质感
		active_pcam.tween_resource.duration = original_duration
		print("全局镜头管理: 跨场景相机位置与 Zoom 缩放已在黑屏背后完美对齐至: ", active_pcam.name)
