extends Prop

@export_group("Camera")
@export var camera_path: NodePath = ^"../../Camera2D"
@export var mark_path: NodePath
@export var target_zoom: Vector2 = Vector2(1.45, 1.45)
@export var reveal_offset: Vector2 = Vector2(0, 180)
@export_range(0.05, 5.0, 0.05) var reveal_start_duration: float = 0.6
@export_range(0.05, 8.0, 0.05) var focus_duration: float = 2.0
@export_range(0.0, 3.0, 0.05) var hold_on_focus_duration: float = 0.35
@export_range(0.05, 5.0, 0.05) var restore_duration: float = 0.8

@export_group("Dialog")
@export var dialog_chapter: String = "chapter0"
@export var wash_dialog_label: String = "wash_face"

@export_group("Wash")
@export var san_restore: int = 30

const WASHED_FACE_KEY := "toilet_washed_face"

var _camera_host: Node = null
var _old_host_process_mode: int = Node.PROCESS_MODE_INHERIT
var _is_camera_input_blocked: bool = false


func _ready() -> void:
	super._ready()


func handle_interact() -> void:
	await _wash_face()


func _input(_event: InputEvent) -> void:
	if _is_camera_input_blocked:
		get_viewport().set_input_as_handled()


func _unhandled_input(_event: InputEvent) -> void:
	if _is_camera_input_blocked:
		get_viewport().set_input_as_handled()


func _wash_face() -> void:
	can_interact = false

	Chapter.san = Chapter.san + san_restore
	Chapter.set_data(WASHED_FACE_KEY, true)
	await _play_camera_dialog(wash_dialog_label)

	_enable_interaction_again()


func _play_camera_dialog(dialog_label: String) -> void:
	hint.fade_out()
	GameManager.lock_player_control(true)
	GameManager.player_control_locked = true

	var camera := get_node_or_null(camera_path) as Camera2D
	var mark := get_node_or_null(mark_path) as Node2D
	var old_camera_pos := Vector2.ZERO
	var old_zoom := Vector2.ONE
	var has_camera_target := camera != null and mark != null

	if has_camera_target:
		old_camera_pos = camera.global_position
		old_zoom = camera.zoom
		_take_over_camera(camera)
		await _play_camera_focus(camera, mark)
	else:
		push_warning("[prop_mirror] camera_path or mark_path is not set")

	await _play_dialog(dialog_label)

	if has_camera_target and is_instance_valid(camera):
		await _restore_camera(camera, old_camera_pos, old_zoom)
	_release_camera()

	GameManager.player_control_locked = false
	GameManager.lock_player_control(false)


func _take_over_camera(camera: Camera2D) -> void:
	_camera_host = camera.get_node_or_null("PhantomCameraHost")
	if _camera_host:
		_old_host_process_mode = _camera_host.process_mode
		_camera_host.process_mode = Node.PROCESS_MODE_DISABLED

	camera.make_current()
	camera.reset_physics_interpolation()


func _release_camera() -> void:
	if _camera_host:
		_camera_host.process_mode = _old_host_process_mode
	_camera_host = null


func _play_camera_focus(camera: Camera2D, mark: Node2D) -> void:
	_is_camera_input_blocked = true

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(camera, "global_position", mark.global_position + reveal_offset, reveal_start_duration)
	tween.tween_property(camera, "global_position", mark.global_position, focus_duration)
	tween.parallel().tween_property(camera, "zoom", target_zoom, focus_duration)
	await tween.finished
	
	if hold_on_focus_duration > 0.0:
		await get_tree().create_timer(hold_on_focus_duration).timeout

	_is_camera_input_blocked = false


func _restore_camera(camera: Camera2D, old_camera_pos: Vector2, old_zoom: Vector2) -> void:
	var restore := create_tween().set_parallel(true)
	restore.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	restore.tween_property(camera, "global_position", old_camera_pos, restore_duration)
	restore.tween_property(camera, "zoom", old_zoom, restore_duration)
	await restore.finished
	camera.reset_physics_interpolation()


func _play_dialog(dialog_label: String) -> void:
	if dialog_label.is_empty():
		return

	if not Dialogic.is_node_ready():
		await Dialogic.ready

	Dialogic.start(dialog_chapter, dialog_label)
	await Dialogic.timeline_ended


func _enable_interaction_again() -> void:
	can_interact = true
	_interacted = false
