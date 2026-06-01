extends Node

# 开场电影镜头的优先级。
# 这里脚本只调度一个 PhantomCamera2D：先平移到 windows，再在同一台镜头上 zoom。
const CUTSCENE_PRIORITY := 20

# Intro -> windows 的平移时长。
const PAN_DURATION := 2.0

# 平移到 windows 后停顿一下，再开始缩放。
const HOLD_BEFORE_ZOOM := 0.35

# windows 镜头最终放大的倍率；数值越大，画面越近。
const WINDOWS_ZOOM := Vector2(2.2, 2.2)

# 开场镜头结束后要播放的 Dialogic 时间线和标签。
# 对应 res://dialogs/chapter0.dtl 里的 "label cut_in"。
const CUT_IN_TIMELINE := "res://dialogs/chapter0.dtl"
const CUT_IN_LABEL := "cut_in"
const RETURN_DIALOG_PLAYED_KEY := "chapter0_return_dialog_played"

# NPC 群组淡出后的透明度。
# 0.0 是完全透明，1.0 是完全不透明。
const NPC_GROUP_FADE_ALPHA := 0.0

# 电影镜头期间临时打开的超大相机边界。
# 关键目的：避免原本的 limit 把斜向平移钳制成“先横移，再斜移”。
const CINEMATIC_LIMIT := 10000000


# 使用当前场景里的 Cameras/Intro 作为整段开场镜头。
# Cameras/Windows 可以保留在场景里，但这段脚本不再依赖它。
@onready var cutscene_camera: PhantomCamera2D = $"../Cameras/Intro"

# 真实渲染画面的 Camera2D，由 PhantomCameraHost 每帧驱动。
# 这里只用它来临时放开/恢复 limit，不再手动同步位置和 zoom。
@onready var native_camera: Camera2D = $"../Camera2D"

@onready var player: PlayerCharacter = $"../Sortables/Player"
@onready var intro_target: Node2D = $"../CameraTargets/Intro"
@onready var windows_target: Node2D = $"../CameraTargets/windows"

# NPC 群组是 Node2D，继承自 CanvasItem，因此可以直接 tween modulate.a。
# 父节点的透明度会乘到所有子 Sprite2D 上，不需要逐个处理子节点。
@onready var npc_group: CanvasItem = $"../Sortables/npc_group"

# 以 camera 节点作为 key，保存原始 limit。
# Rect2 的 position 表示 left/top，size 表示 right-left / bottom-top。
var _saved_limits: Dictionary = {}

# 只在“镜头动画阶段”拦截普通输入。
# 进入 Dialogic 后必须关闭这个开关，否则 Dialogic 的 [wait_input] 也会被拦掉。
var _is_camera_animation_input_blocked := false

var _played

func _ready() -> void:
	_played = Chapter.get_data("is_intro_played", false)
	if _played:
		cutscene_camera.priority = 0
	else:
		cutscene_camera.priority = CUTSCENE_PRIORITY

	# 等待 PhantomCameraHost 和 PhantomCamera2D 完成初始化。
	# 这样后续 priority、teleport_position、limit 修改会更稳定。
	await get_tree().process_frame
	await get_tree().process_frame

	if _played:
		npc_group.hide()
		## 第二次回来欧阳夜出来对话
		if not Chapter.get_data(RETURN_DIALOG_PLAYED_KEY, false):
			Chapter.set_data(RETURN_DIALOG_PLAYED_KEY, true)
			Dialogic.start("chapter0", "diag1")
	else:
		play_intro_to_windows()
		Chapter.set_data("is_intro_played", true)


func play_intro_to_windows() -> void:
	GameManager.wait(2.0)
	# 这里先锁住玩家移动，并在镜头动画阶段拦截键盘/鼠标事件。
	# 玩家不能移动，也不能通过暂停、背包、交互等事件式输入打断演出。
	_lock_player_control(true)
	_set_camera_animation_input_blocked(true)
	
	_prepare_npc_group_for_fade()

	# 平移开始前先放开 PhantomCamera 和真实 Camera2D 的限制。
	# 如果不这样做，Intro 当前 zoom 和 limit_bottom 等限制可能会改写镜头轨迹。
	_open_limits([cutscene_camera, native_camera])

	# 让开场镜头成为当前 active PhantomCamera。
	cutscene_camera.priority = CUTSCENE_PRIORITY
	cutscene_camera.follow_target = intro_target
	cutscene_camera.follow_offset = Vector2.ZERO

	# 强制 PhantomCamera 输出对齐到 intro_target。
	# teleport_position 会通知 PhantomCameraHost 同步真实 Camera2D 的位置。
	cutscene_camera.teleport_position()
	await get_tree().process_frame

	await _pan_to_windows()
	await get_tree().create_timer(HOLD_BEFORE_ZOOM).timeout
	await _zoom_on_windows()

	# 如果后面还要继续电影镜头，可以把恢复 limit 和解锁玩家延后。
	_restore_limits()

	# Dialogic 自己需要接收确认键/鼠标点击来推进 [wait_input]。
	# 所以在启动 Dialogic 之前，关闭本脚本的全局输入拦截；
	# 但玩家移动仍保持锁定，后续由 chapter0.dtl 末尾的 do 事件负责切场景和解锁。
	_set_camera_animation_input_blocked(false)
	_play_cut_in_dialogic()


func _input(_event: InputEvent) -> void:
	if _is_camera_animation_input_blocked:
		get_viewport().set_input_as_handled()


func _unhandled_input(_event: InputEvent) -> void:
	if _is_camera_animation_input_blocked:
		get_viewport().set_input_as_handled()


func _pan_to_windows() -> void:
	# Follow 模式下，镜头中心 = follow_target.global_position + follow_offset。
	# 因此要让画面中心从 Intro 到 windows，只需要 tween 这个 offset。
	var windows_offset := windows_target.global_position - intro_target.global_position

	var tween := create_tween()
	# set_parallel(true) 表示后续加入的 tween_property 会同时开始。
	# 这里让相机平移和 npc_group 淡出严格同步，不需要额外 AnimationPlayer。
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(cutscene_camera, "follow_offset", windows_offset, PAN_DURATION)
	tween.tween_property(npc_group, "modulate:a", NPC_GROUP_FADE_ALPHA, PAN_DURATION)
	await tween.finished

	# 透明度到 0 后再关掉 visible。
	# 这样既保留了渐隐过程，又避免完全透明的 NPC 继续参与绘制。
	npc_group.visible = false


func _zoom_on_windows() -> void:
	# 平移结束后不切镜头，直接在同一个 PhantomCamera 上 zoom。
	# 这样避免两台镜头切换带来的二次插值、priority 竞争和额外 teleport。
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(cutscene_camera, "zoom", WINDOWS_ZOOM, 1.2)
	await tween.finished


func _play_cut_in_dialogic() -> void:
	# Dialogic 是 Autoload，但它可能还没 ready。
	# 等待 ready 可以避免首次进场时启动时间线失败。
	if not Dialogic.is_node_ready():
		await Dialogic.ready

	if not Dialogic.timeline_exists(CUT_IN_TIMELINE):
		push_error("Classroom SceneDirector: Dialogic timeline not found: " + CUT_IN_TIMELINE)
		return

	# 第二个参数是 label 名称，会跳到 chapter0.dtl 中的 "label cut_in"。
	Dialogic.start(CUT_IN_TIMELINE, CUT_IN_LABEL)


func _lock_player_control(locked: bool) -> void:
	# 这一层会同时更新 GameManager 的全局锁状态，并通过 EventBus 通知玩家脚本。
	# 这样轮询式输入（门、道具互动等）和玩家移动都会尊重同一把锁。
	GameManager.lock_player_control(locked)


func _set_camera_animation_input_blocked(blocked: bool) -> void:
	# 这一层是镜头动画阶段的事件拦截。
	# 注意不要在 Dialogic 阶段保持 true，否则 Dialogic 无法响应推进输入。
	_is_camera_animation_input_blocked = blocked


func _prepare_npc_group_for_fade() -> void:
	# 如果将来重播这段演出，或从调试状态重复进入场景，
	# 这里可以保证 NPC 群组总是先恢复可见，再开始淡出。
	npc_group.visible = true
	npc_group.modulate.a = 1.0


func _open_limits(cameras: Array) -> void:
	_saved_limits.clear()

	for camera in cameras:
		_saved_limits[camera] = Rect2(
			camera.limit_left,
			camera.limit_top,
			camera.limit_right - camera.limit_left,
			camera.limit_bottom - camera.limit_top
		)

		camera.limit_left = -CINEMATIC_LIMIT
		camera.limit_top = -CINEMATIC_LIMIT
		camera.limit_right = CINEMATIC_LIMIT
		camera.limit_bottom = CINEMATIC_LIMIT


func _restore_limits() -> void:
	for camera in _saved_limits:
		var limits: Rect2 = _saved_limits[camera]
		camera.limit_left = int(limits.position.x)
		camera.limit_top = int(limits.position.y)
		camera.limit_right = int(limits.position.x + limits.size.x)
		camera.limit_bottom = int(limits.position.y + limits.size.y)

	_saved_limits.clear()
