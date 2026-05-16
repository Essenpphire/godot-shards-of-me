"""单例-游戏顶层系统"""
extends Node2D

"""预加载场景"""
#var scene_death = preload("res://Scenes/UI/死亡.tscn").instantiate()

"""一般场景"""
## 选出生点
var fst_spawn : bool = true
var scene_changing : bool = false
var scene_curr : String = "world"

const ChapterFilePath : String = "res://resources/chapters.json"
const PersistentDataPath : String = "user:/" # 少一个/，因为DataManager里会加上
const PersistentDataFileName : String = "persistent_data.json"

## 改变当前场景
func changeScene(scene : String) -> void:
	print("正在切换场景：" + scene)
	scene_changing = true
	
	var res = get_tree().change_scene_to_file(scene)
	
	if res == OK:
		scene_curr = scene
		scene_changing = false
		print("场景切换成功")
	else:
		print("场景切换失败！")

"""函数"""
# 再封装
func wait(seconds: float) -> Signal:
	return get_tree().create_timer(seconds).timeout

## 从池子里抽取场景并返回
## @todo 暂存GameManager以后迁移到工具单例里
func drawFromPool(pool : Array) -> Node2D:
	return pool[randi() % pool.size()].instantiate()

## 建议数值范围：0.0 ~ 10.0
func cameraShake(cnt : float) -> void:
	EventBus.game_camera_shake.emit(cnt)
	
func cameraLimit(xs : float, 
	ys : float, xe : float, ye : float) ->void:
	EventBus.game_camera_limit.emit(xs, ys, xe, ye)

func _init() -> void:
	# 初始化居中窗口
	var screen_size : Vector2 = DisplayServer.screen_get_size()
	var window_size : Vector2 = DisplayServer.window_get_size()
	
	DisplayServer.window_set_position(screen_size * 0.5 - window_size * 0.5)

func _ready() -> void:
	if Data.load_persistent_data(PersistentDataPath, PersistentDataFileName):
		print("持久化数据加载成功！")
	else:
		print("持久化数据加载失败！")

	if Chapter.load_chapter_data(ChapterFilePath):
		print("章节数据加载成功！")
	else:
		print("章节数据加载失败！")
