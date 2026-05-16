# ChapterManager.gd
extends Node

## 章节管理器，负责控制游戏的章节流程、判定条件和结局
class_name ChapterManager

# 运行时状态
## 一个Dictionary，key为章节ID，value为该章节的数据字典，包含 "name", "next" 和 "data" 字段
var chapter_definition: Dictionary = {}
## 当前章节的数据字典，包含 "name", "next" 和 "data" 字段 [br]
## 此处的data是初始化时从章节数据加载的，可以在章节流程中修改并保存到持久化数据中
var current_chapter_definition: Dictionary = {}

# 持久化数据
## 当前章节ID
var current_chapter_id: String = "prologue"
## 当前章节的运行时数据（基于current_chapter_definition的data内容初始化），可以在章节流程中修改并保存到持久化数据中
var active_chapter_data: Dictionary = {}
var san: int = 100

func _ready():
	add_to_group("Persist") # 加入持久化分组，GameManager会调用DataManager加载运行时数据

func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("chapter_debug_next_chapter"):
		advance_to_next_chapter()

## 三元运算符的表达式函数版本，供章节流程表达式调用
static func next(flag: bool, true_chapter: String, false_chapter: String) -> String:
	return true_chapter if flag else false_chapter

## 开始新游戏，重置章节状态 [br]
func new_game() -> void:
	current_chapter_id = "prologue"
	if chapter_definition.has(current_chapter_id):
		current_chapter_definition = chapter_definition[current_chapter_id]
		active_chapter_data = current_chapter_definition["data"].duplicate(true) # 深拷贝
		
		EventBus.enter_chapter.emit(current_chapter_id, 
		 current_chapter_definition["name"], active_chapter_data, false)
	else:
		push_error("章节数据缺失: ", current_chapter_id)

## 进入下一章节，基于当前章节定义中的 "next" 字段进行判定 [br]
func advance_to_next_chapter() -> void:
	if not current_chapter_definition.is_empty():
		if "next" not in current_chapter_definition:
			push_error("章节缺少下一章节信息，是否已达到结局？当前章节: ", current_chapter_id)
			return
		var next_info = current_chapter_definition["next"]
		var expression_str = next_info.get("expression", "")
		var arg_names = next_info.get("args", [])
		var args = []
		for arg_name in arg_names:
			if arg_name in active_chapter_data:
				args.append(active_chapter_data[arg_name])
			else:
				push_error("参数缺失: ", arg_name)
		
		if expression_str != "":
			var expression = Expression.new()
			var error = expression.parse(expression_str, PackedStringArray(arg_names))
			if error != OK:
				push_error("表达式解析失败: ", expression.get_error_message())
				return
			
			var next_chapter_id = expression.execute(args, self)
			if (expression.has_execute_failed()):
				push_error("表达式执行失败: ", expression.get_execute_error_message())
				return
			
			if next_chapter_id in chapter_definition:
				current_chapter_id = next_chapter_id
				current_chapter_definition = chapter_definition[current_chapter_id]
				if "data" in current_chapter_definition:
					active_chapter_data = current_chapter_definition["data"].duplicate(true) # 深拷贝
				
				EventBus.enter_chapter.emit(current_chapter_id, 
				 current_chapter_definition["name"], 
				 active_chapter_data,
				 not current_chapter_definition.has("next"))
				print("进入章节: ", current_chapter_definition)
			else:
				push_error("下一章节ID无效: ", next_chapter_id)
		else:
			push_error("下一章节表达式缺失: ", current_chapter_id)
	else:
		push_error("章节数据缺失: ", current_chapter_id)

## 加载章节数据 [br]
## [b][param path][/b]: JSON文件路径，例如 "res://resources/chapters.json" [br]
## [b][return][/b]: 是否加载成功
func load_chapter_data(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	
	var chapter_file = FileAccess.open(path, FileAccess.READ)
	var json_str = chapter_file.get_as_text()
	var json = JSON.new()
	var parse_err = json.parse(json_str)
	if parse_err != OK:
		push_error("JSON解析失败: ", json.get_error_message())
		return false
	
	chapter_definition = json.data
	# 设计上此方法应在DataManager.load_persistent_data()之后调用
	# 因此可以直接使用current_chapter_id来初始化current_chapter_definition
	if chapter_definition.has(current_chapter_id):
		current_chapter_definition = chapter_definition[current_chapter_id]
	else:
		push_error("当前章节数据缺失: ", current_chapter_id)
		return false
	return true

# DataManager 数据管理
func save_data() -> Dictionary:
	return {
		"current_chapter": current_chapter_id,
		"active_chapter_data": active_chapter_data,
		"san": san
	}

func load_data(data: Dictionary) -> void:
	current_chapter_id = data.get("current_chapter", "prologue")
	active_chapter_data = data.get("active_chapter_data", {})
	san = data.get("san", 100)
