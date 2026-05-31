extends CanvasLayer

@onready var pause := self
@onready var pause_button := $MarginContainer/Control/PauseButton
@onready var resume_option := $MarginContainer/Control/VBoxOptions/Resume
@onready var label = $MarginContainer/Control/Label
@onready var pause_options = $MarginContainer/Control/VBoxOptions
@onready var color_rect = $ColorRect

@onready var nodes_grp1 = [pause_button, label] # should be visible during gamemplay and hidden during pause
@onready var nodes_grp2 = [pause_options, color_rect] # should be visible only in pause menu


func _ready():
	pause_hide()


func pause_show():
	for n in nodes_grp1:
		n.hide()
	for n in nodes_grp2:
		n.show()
		n.modulate.a = 0.0

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(color_rect, "modulate:a", 1.0, 0.25)
	tween.tween_property(pause_options, "modulate:a", 1.0, 0.25).set_delay(0.05)


func pause_hide():
	for n in nodes_grp1:
		if n:
			n.show()

	for n in nodes_grp2:
		if n:
			n.hide()


func _unhandled_input(event):
	if event.is_action_pressed("pause"):
		# 让位：UI 弹层（物品详情 / 线索书 / 线索操作菜单）可见时，
		# 把 ESC 优先交给它们关闭，自己不响应。
		if _is_ui_overlay_active():
			return
		if get_tree().paused:
			resume()
		else:
			pause_game()
		get_viewport().set_input_as_handled()


func _is_ui_overlay_active() -> bool:
	var ui := get_node_or_null("/root/UiLayer")
	if ui == null:
		return false
	var item_layer := ui.get_node_or_null("ItemLayer")
	if item_layer != null and item_layer.visible:
		return true
	var clue_book := ui.get_node_or_null("ClueBook")
	if clue_book != null and clue_book.visible:
		return true
	return false


func resume():
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(color_rect, "modulate:a", 0.0, 0.2)
	tween.tween_property(pause_options, "modulate:a", 0.0, 0.15)
	await tween.finished
	get_tree().paused = false
	pause_hide()


func pause_game():
	resume_option.grab_focus()
	get_tree().paused = true
	pause_show()


func _on_Resume_pressed():
	resume()


func _on_PauseButton_pressed():
	pause_game()


func _on_main_menu_pressed():
	Dialogic.end_timeline(true)
	# Data.save_persistent_data() 内部会写入 Dialogic 的 "process" slot，
	# 同时落盘自定义数据与 Dialogic 自身对话状态，无需再单独调用 Dialogic.Save.save()
	await Data.save_persistent_data()
	GGT.change_scene("res://scenes/menu/menu.tscn", {"show_progress_bar": false})
