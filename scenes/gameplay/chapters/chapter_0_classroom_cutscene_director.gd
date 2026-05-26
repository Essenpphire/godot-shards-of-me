extends Node

const INTRO_START_ZOOM := Vector2(1.5, 1.5)
const INTRO_FRAME_ZOOM := Vector2(1.4, 1.4)
const PLAYER_ACTION_ZOOM := Vector2(1.6, 1.6)

@export_group("Cameras")
@export var pcam_player: PhantomCamera2D
@export var pcam_intro_pan: PhantomCamera2D
@export var native_camera: Camera2D

@export_group("Targets")
@export var player: PlayerCharacter
@export var intro_start_frame_target: Node2D
@export var intro_frame_center_target: Node2D

@export_group("VFX")
@export var window_bird_fx: WindowBirdFx

@export_group("Timing")
@export_range(0.1, 5.0, 0.05) var intro_pan_duration := 2.0
@export_range(0.1, 5.0, 0.05) var player_return_duration := 1.2


func _ready() -> void:
	_resolve_nodes()
	start_intro_cutscene()


func start_intro_cutscene() -> void:
	if not _has_required_nodes():
		return

	player.lock_control()
	await get_tree().create_timer(0.6).timeout

	await _play_intro_camera_move()
	await _play_window_bird_flyby()
	await _switch_to_player_camera()

	player.unlock_control()


func _clamp_camera_center(target_position: Vector2, zoom: Vector2) -> Vector2:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var half_view := Vector2(
		viewport_size.x * 0.5 / zoom.x,
		viewport_size.y * 0.5 / zoom.y
	)
	return Vector2(
		clampf(target_position.x, float(native_camera.limit_left) + half_view.x, float(native_camera.limit_right) - half_view.x),
		clampf(target_position.y, float(native_camera.limit_top) + half_view.y, float(native_camera.limit_bottom) - half_view.y)
	)


func _has_required_nodes() -> bool:
	return (
		is_instance_valid(pcam_player)
		and is_instance_valid(pcam_intro_pan)
		and is_instance_valid(native_camera)
		and is_instance_valid(player)
		and is_instance_valid(intro_start_frame_target)
		and is_instance_valid(intro_frame_center_target)
		and is_instance_valid(window_bird_fx)
	)


func _resolve_nodes() -> void:
	if not is_instance_valid(pcam_player):
		pcam_player = get_node_or_null("../Cameras/PCam_Player") as PhantomCamera2D
	if not is_instance_valid(pcam_intro_pan):
		pcam_intro_pan = get_node_or_null("../Cameras/PCam_IntroPan") as PhantomCamera2D
	if not is_instance_valid(native_camera):
		native_camera = get_node_or_null("../Sortables/Player/Camera2D") as Camera2D
	if not is_instance_valid(player):
		player = get_node_or_null("../Sortables/Player") as PlayerCharacter
	if not is_instance_valid(intro_start_frame_target):
		intro_start_frame_target = get_node_or_null("../CameraTargets/IntroStartFrame") as Node2D
	if not is_instance_valid(intro_frame_center_target):
		intro_frame_center_target = get_node_or_null("../CameraTargets/IntroFrameCenter") as Node2D
	if not is_instance_valid(window_bird_fx):
		window_bird_fx = get_node_or_null("../Background/windows") as WindowBirdFx


func _play_window_bird_flyby() -> void:
	if not is_instance_valid(window_bird_fx):
		return

	EventBus.game_vfx_play.emit(window_bird_fx.effect_name)
	await window_bird_fx.flyby_finished


func _play_intro_camera_move() -> void:
	var framed_center := _get_intro_frame_center()
	var framed_offset := framed_center - intro_start_frame_target.global_position

	pcam_intro_pan.follow_target = intro_start_frame_target
	pcam_intro_pan.zoom = INTRO_START_ZOOM
	pcam_intro_pan.follow_offset = Vector2.ZERO
	pcam_intro_pan.priority = 35
	pcam_player.priority = 0
	await get_tree().process_frame

	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(pcam_intro_pan, "follow_offset", framed_offset, intro_pan_duration)
	tween.tween_property(pcam_intro_pan, "zoom", INTRO_FRAME_ZOOM, intro_pan_duration)
	await tween.finished
	pcam_intro_pan.priority = 35


func _get_intro_frame_center() -> Vector2:
	# This marker is the art-directed center for the shared window + player frame.
	return _clamp_camera_center(intro_frame_center_target.global_position, INTRO_FRAME_ZOOM)


func _switch_to_player_camera() -> void:
	pcam_player.zoom = PLAYER_ACTION_ZOOM
	pcam_player.priority = 50
	await get_tree().create_timer(player_return_duration).timeout

	pcam_intro_pan.priority = 0
