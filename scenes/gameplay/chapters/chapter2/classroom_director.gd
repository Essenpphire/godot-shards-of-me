extends Node

const INTRO_PLAYED_KEY: String = "chapter2_classroom_intro_played"
const HALLWAY_SCENE: String = "chapter2/hallway"
const HALLWAY_PLAYER_POS: Vector2 = Vector2(185, 471)
const INTRO_PRIORITY: int = 30
const PAN_DURATION: float = 3.6
const FADE_DURATION: float = 0.7
const FADE_HOLD: float = 0.3
const EXIT_WALK_DURATION: float = 3.0

@onready var intro_camera: PhantomCamera2D = $"../Cameras/IntroPanPcam"
@onready var player_follow_camera: PhantomCamera2D = $"../Cameras/PlayerFollowPcam"
@onready var native_camera: Camera2D = $"../Camera2D"
@onready var class_head_right: Node2D = $"../CameraTargets/ClassHeadRight"
@onready var class_tail_left: Node2D = $"../CameraTargets/ClassTailLeft"
@onready var exit_point: Node2D = $"../CameraTargets/ExitPoint"
@onready var player: PlayerCharacter = $"../Sortables/Player"
@onready var player_sprite: AnimatedSprite2D = $"../Sortables/Player/AnimatedSprite2D"
@onready var npc_group: CanvasItem = $"../Sortables/npc_group"
@onready var black: ColorRect = $"../CutsceneFadeLayer/Black"

var _block_input: bool = false
var _changing_to_hallway: bool = false


func _ready() -> void:
	await _wait_for_scene_ready()

	if Chapter.get_data(INTRO_PLAYED_KEY, false):
		_prepare_revisited_classroom()
		return

	Chapter.set_data(INTRO_PLAYED_KEY, true)
	await _play_classroom_sequence()


func _play_classroom_sequence() -> void:
	GameManager.lock_player_control(true)
	player.set_physics_process(false)
	_block_input = true
	black.show()
	black.color.a = 0.0
	_activate_intro_camera()

	if GGT.is_changing_scene():
		await GGT.scene_transition_finished

	await _play_class_pan()
	await _fade_between_classes()
	await _play_exit_walk()
	await _fade_out_to_hallway()


func _play_class_pan() -> void:
	var target_offset: Vector2 = class_tail_left.global_position - class_head_right.global_position
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(intro_camera, "follow_offset", target_offset, PAN_DURATION)
	await tween.finished


func _fade_between_classes() -> void:
	await _tween_black_alpha(1.0, FADE_DURATION)
	await get_tree().create_timer(FADE_HOLD).timeout
	_activate_player_follow_camera()
	await _tween_black_alpha(0.0, FADE_DURATION)


func _play_exit_walk() -> void:
	player_sprite.flip_h = false
	player_sprite.play("move")
	npc_group.visible = true
	npc_group.modulate.a = 1.0

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(player, "global_position", exit_point.global_position, EXIT_WALK_DURATION)
	tween.tween_property(npc_group, "modulate:a", 0.0, EXIT_WALK_DURATION)
	await tween.finished

	player_sprite.play("idle")
	npc_group.hide()


func _fade_out_to_hallway() -> void:
	await _tween_black_alpha(1.0, FADE_DURATION)
	await _go_to_hallway()


func _go_to_hallway() -> void:
	if _changing_to_hallway:
		return
	_changing_to_hallway = true
	if GGT.is_changing_scene():
		await GGT.scene_transition_finished
	_block_input = false
	if is_instance_valid(player):
		player.set_physics_process(true)
	GameManager.lock_player_control(false)
	var params := {
		"player_pos": HALLWAY_PLAYER_POS,
		"show_progress_bar": false,
	}
	Chapter.change_scene(HALLWAY_SCENE, 0, params)


func _prepare_revisited_classroom() -> void:
	_block_input = false
	black.hide()
	black.color.a = 0.0
	intro_camera.priority = 0
	player_follow_camera.priority = INTRO_PRIORITY
	if is_instance_valid(player):
		player.set_physics_process(true)
	GameManager.lock_player_control(false)
	_sync_native_camera(player_follow_camera)


func _activate_intro_camera() -> void:
	player_follow_camera.priority = 0
	intro_camera.priority = INTRO_PRIORITY
	intro_camera.follow_target = class_head_right
	intro_camera.follow_offset = Vector2.ZERO
	_sync_native_camera(intro_camera)


func _activate_player_follow_camera() -> void:
	intro_camera.priority = 0
	player_follow_camera.priority = INTRO_PRIORITY
	player_follow_camera.follow_target = player
	player_follow_camera.follow_offset = Vector2.ZERO
	_sync_native_camera(player_follow_camera)


func _sync_native_camera(pcam: PhantomCamera2D) -> void:
	pcam.teleport_position()
	native_camera.global_transform = pcam.get_transform_output()
	native_camera.zoom = pcam.zoom
	native_camera.limit_left = pcam.limit_left
	native_camera.limit_top = pcam.limit_top
	native_camera.limit_right = pcam.limit_right
	native_camera.limit_bottom = pcam.limit_bottom
	native_camera.reset_physics_interpolation()


func _tween_black_alpha(alpha: float, duration: float) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(black, "color:a", alpha, duration)
	await tween.finished


func _wait_for_scene_ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _input(_event: InputEvent) -> void:
	if _block_input:
		get_viewport().set_input_as_handled()


func _unhandled_input(_event: InputEvent) -> void:
	if _block_input:
		get_viewport().set_input_as_handled()
