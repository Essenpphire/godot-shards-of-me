extends Control

@onready var btn_play = $MarginContainer/Control/VBoxContainer/PlayButton
@onready var btn_continue = $MarginContainer/Control/VBoxContainer/ContinueButton
@onready var btn_exit = $MarginContainer/Control/VBoxContainer/ExitButton
@onready var texture_rect = $TextureRect
@onready var color_rect = $ColorRect
@onready var title_vbox = $MarginContainer/Control/CenterContainer/TitleVBox
@onready var button_container = $MarginContainer/Control/VBoxContainer
@onready var version_container = $MarginContainer/Control/Version
@onready var credits_container = $MarginContainer/Control/Credits

# BGM
@export var menu_bgm : AudioStream

# 是否存档
var have_saved : bool = false

func _ready():
	# 等动画播完再启用按键
	btn_play.disabled = true
	btn_exit.disabled = true
	btn_continue.disabled = true
	# 初始透明，准备渐入
	_set_alpha(texture_rect, 0.0)
	_set_alpha(color_rect, 0.0)
	_set_alpha(title_vbox, 0.0)
	_set_alpha(button_container, 0.0)
	_set_alpha(version_container, 0.0)
	_set_alpha(credits_container, 0.0)
	
	# 隐藏Layer
	UiLayer.hide()
	PuzzleLayer.hide()

	var tween = create_tween()
	tween.set_parallel(false)


	# 背景层淡入
	tween.tween_callback(func(): _fade_in(texture_rect, 0.8))
	tween.tween_callback(func(): _fade_in(color_rect, 0.8))
	tween.tween_interval(0.5)

	# 标题淡入
	tween.tween_callback(func(): _fade_in(title_vbox, 0.6))
	tween.tween_interval(0.4)

	# 按钮淡入
	tween.tween_callback(func(): _fade_in(button_container, 0.5))
	tween.tween_interval(0.3)

	# 角落信息淡入
	tween.tween_callback(func(): _fade_in(version_container, 0.4))
	tween.tween_callback(func(): _fade_in(credits_container, 0.4))
	tween.tween_interval(0.2)

	# 渐入完成后启动呼吸动画和聚焦
	tween.tween_callback(func():
		have_saved = await Data.load_persistent_data()
		#_start_breathing_animation()
		btn_play.disabled = false
		btn_exit.disabled = false
		if have_saved:
			btn_continue.disabled = false
		btn_play.grab_focus()
		# 最后始放bgm
		Audio.set_volume(0, 0.1)
		Audio.play_music(menu_bgm)
	)

	if OS.has_feature('web'):
		btn_exit.queue_free()


func _set_alpha(node: CanvasItem, alpha: float) -> void:
	var color = node.modulate
	color.a = alpha
	node.modulate = color


func _fade_in(node: CanvasItem, duration: float) -> void:
	var tween = create_tween()
	tween.tween_property(node, "modulate:a", 1.0, duration)


func _on_PlayButton_pressed() -> void:
	UiLayer.show()
	PuzzleLayer.show()
	Audio.stop_music()
	Chapter.new_game()
	# Data 内部会等待 Dialogic 就绪，所有持久化数据统一存放在 Dialogic 的 "process" slot

func _on_continue_button_pressed() -> void:
	UiLayer.show()
	PuzzleLayer.show()
	Audio.stop_music()
	Chapter.continue_game()

func _on_ExitButton_pressed() -> void:
	var transitions = get_node_or_null("/root/GGT_Transitions")
	if transitions:
		transitions.fade_in({
			'show_progress_bar': false
		})
		await transitions.anim.animation_finished
		await get_tree().create_timer(0.3).timeout
	get_tree().quit()


func _on_clear_save_btn_pressed() -> void:
	Data.delete_save()
	btn_continue.disabled = true
