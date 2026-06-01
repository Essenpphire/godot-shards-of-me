"""单例-游戏顶层系统"""
extends Node2D

const ItemFilePath : String = "res://resources/items.json"
const ItemTexurePath : String = "res://assets/images/items/"
## 章节场景根目录。完整路径 = ChapterScenePath + Chapter.cur_scene + ".tscn"
const ChapterScenePath : String = "res://scenes/gameplay/chapters/"

var player_control_locked: bool = false


func wait(seconds: float) -> Signal:
	return get_tree().create_timer(seconds).timeout

func back_to_menu() -> void:
	GGT.change_scene("res://scenes/menu/menu.tscn", {"show_progress_bar": false})

## 取当前玩家位置
func get_player_pos() -> Vector2:
	var players := get_tree().get_nodes_in_group("Player")
	if players.is_empty():
		return Vector2.ZERO
	var p := players[0] as Node2D
	return p.global_position if p else Vector2.ZERO

## 通知玩家移动到指定位置
func change_player_pos(pos : Vector2) -> void:
	EventBus.player_change_pos.emit(pos)

func lock_player_control(stat : bool = true) -> void:
	player_control_locked = stat
	EventBus.player_control_lock.emit(stat)

func is_player_control_locked() -> bool:
	return player_control_locked

# 全屏
func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_F11:
		toggle_fullscreen()

func toggle_fullscreen():
	var window = get_window()
	if window.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
		window.mode = Window.MODE_WINDOWED
	else:
		window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
