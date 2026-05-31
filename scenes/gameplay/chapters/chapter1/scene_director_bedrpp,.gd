extends Node

const INTRO_PRIORITY: int = 30
const INTRO_DURATION: float = 2.6
const PLAYER_PCAM_PRIORITY: int = 10
const GET_UP_CHAPTER: String = "chapter1"
const GET_UP_LABEL: String = "get_up"
const INTRO_PLAYED_KEY: String = "chapter1_bedroom_intro_played"
const DIALOGIC_INTRO_PLAYED_KEY: String = "chapter1.intro_played"

@onready var intro_camera: PhantomCamera2D = $"../Cameras/IntroPanPcam"
@onready var player_camera: PhantomCamera2D = $"../Sortables/Player/PlayerPhantomCamera2D"
@onready var native_camera: Camera2D = $"../Camera2D"
@onready var intro_start: Node2D = $"../CameraTargets/IntroStart"
@onready var intro_end: Node2D = $"../CameraTargets/IntroEnd"
@onready var black: ColorRect = $"../IntroFadeLayer/Black"

var _block_intro_input: bool = false


func _ready() -> void:
	if not Dialogic.is_node_ready():
		await Dialogic.ready

	# 第二次回到卧室时不再接管镜头或启动起床对白。
	if _is_room_reentry() or _has_intro_played():
		Chapter.set_data(INTRO_PLAYED_KEY, true)
		return

	await _play_intro_camera()
	Chapter.set_data(INTRO_PLAYED_KEY, true)
	_play_get_up_dialogue()


func _has_intro_played() -> bool:
	return (
		Chapter.get_data(INTRO_PLAYED_KEY, false)
		or Dialogic.VAR.get_variable(DIALOGIC_INTRO_PLAYED_KEY, false, true)
	)


func _is_room_reentry() -> bool:
	var params = GGT.get_current_scene_data().params
	return params is Dictionary and params.get("player_pos", Vector2.ZERO) != Vector2.ZERO


func _play_intro_camera() -> void:
	GameManager.lock_player_control(true)
	_block_intro_input = true
	black.show()
	black.color.a = 1.0

	# 等待房间模板和 PhantomCameraHost 完成初始同步，避免第一帧闪到玩家镜头。
	await _wait_for_camera_ready()

	intro_camera.priority = INTRO_PRIORITY
	player_camera.priority = 0
	intro_camera.follow_target = intro_start
	intro_camera.follow_offset = Vector2.ZERO
	intro_camera.teleport_position()
	await get_tree().process_frame

	var target_offset: Vector2 = intro_end.global_position - intro_start.global_position
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(intro_camera, "follow_offset", target_offset, INTRO_DURATION)
	tween.tween_property(black, "color:a", 0.0, INTRO_DURATION)
	await tween.finished

	_block_intro_input = false
	_activate_player_camera()
	black.hide()


func _input(_event: InputEvent) -> void:
	if _block_intro_input:
		get_viewport().set_input_as_handled()


func _unhandled_input(_event: InputEvent) -> void:
	if _block_intro_input:
		get_viewport().set_input_as_handled()


func _wait_for_camera_ready() -> void:
	# Room 模板会在进场时同步初始镜头，等两帧后再接管最稳定。
	await get_tree().process_frame
	await get_tree().process_frame


func _activate_player_camera() -> void:
	# 直接同步真实 Camera2D，避免切回玩家镜头时出现一帧跳闪。
	intro_camera.priority = 0
	player_camera.priority = PLAYER_PCAM_PRIORITY
	player_camera.teleport_position()
	native_camera.global_transform = player_camera.get_transform_output()
	native_camera.zoom = player_camera.zoom
	native_camera.limit_left = player_camera.limit_left
	native_camera.limit_top = player_camera.limit_top
	native_camera.limit_right = player_camera.limit_right
	native_camera.limit_bottom = player_camera.limit_bottom
	native_camera.reset_physics_interpolation()


func _play_get_up_dialogue() -> void:
	# 起床对白必须在镜头完全亮起后启动。
	Dialogic.start(GET_UP_CHAPTER, GET_UP_LABEL)
