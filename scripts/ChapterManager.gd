# ChapterManager.gd
extends Node

## 章节管理器：持久化"章节运行时变量 + 当前场景 + 玩家位置 + SAN"，
## 并对外提供章节场景切换入口 [method change_scene]。
## 章节内的判定/分支由各章节脚本自己写，本管理器不再维护流程图。
class_name ChapterManager

## 默认章节数据
const DEFAULT_CHAPTER_DATA : Dictionary = {
	"chapter0": {}
}

## 嵌套字典，存各章节内的运行时变量。
## e.g. chapter_data["chapter0"]["door_opened"] = true
var chapter_data: Dictionary = {}

## 当前玩家所在的章节场景（相对 [member GameManager.ChapterScenePath]，不带 .tscn 后缀）
## e.g. "chapter0/chapter0_classroom"
## 完整路径 = GameManager.ChapterScenePath + cur_scene + ".tscn"
var cur_scene: String = ""

## 玩家在 cur_scene 中的位置（保存时由 GameManager 实时收集，读档时回填给玩家）
var player_pos: Vector2 = Vector2.ZERO

## 角色精神值。与章节流程解耦，但仍由本管理器持久化
## （ui_layer / screen_crack / change_scene 都在使用 Chapter.san）
var san: int = 100:
	set(value):
		san = clampi(value, 0, 100)
		EventBus.san_update.emit(san)

func _ready() -> void:
	add_to_group("Persist") # 加入持久化分组，由 DataManager 统一调度 save/load

## 重置为新游戏初始状态。仅清字段 + 设默认起点，不做场景跳转。
## 跳转由调用方（如 menu.gd）使用 [method change_scene] 完成。
func new_game() -> void:
	if Dialogic.is_node_ready():
		Dialogic.VAR.reset()
	ClueManager.reset_runtime_data()
	chapter_data.clear()
	cur_scene = "chapter0/classroom"
	player_pos = Vector2(246, 476)
	san = 100
	var params = {
		"show_progress_bar": true,
		"player_pos": player_pos
	}
	change_scene(cur_scene, 0, params)


func reset_runtime_state() -> void:
	chapter_data.clear()
	cur_scene = ""
	player_pos = Vector2.ZERO
	san = 100

## 继续游戏
## 注意要显示调用Data.load_persistent_data
func continue_game() -> void:
	var params = {
		"show_progress_bar": true,
		"player_pos": player_pos
	}
	change_scene(cur_scene, 0, params)


# ============================================================
# 章节数据
# ============================================================
## 全局游戏数据管理
## 使用示例：
## - set_data("is_key_get", true)              # 设置标志
## - set_data("wash_face_cnt", 3)              # 设置数字
## - set_data("collected_clues", "钥匙")       # 追加到数组
## - set_data("collected_clues", ["钥匙", "笔记"]) # 替换数组
## - set_data("collected_clues", "药水", true) # 追加模式

## 设置游戏数据
func set_data(arg_name: String, value, append_mode: bool = false) -> bool:
	# 参数校验
	if arg_name.is_empty():
		push_error("set_data: arg_name 不能为空")
		return false
	
	# 获取当前值
	var current = chapter_data.get(arg_name)
	
	# 根据类型和模式处理
	match typeof(current):
		TYPE_NIL:
			# 不存在，直接赋值。append_mode 下视为「追加进新数组」
			if append_mode:
				if typeof(value) == TYPE_ARRAY:
					chapter_data[arg_name] = value.duplicate()
				else:
					chapter_data[arg_name] = [value]
			else:
				chapter_data[arg_name] = value
		
		TYPE_ARRAY:
			# 当前是数组
			if append_mode:
				if typeof(value) == TYPE_ARRAY:
					chapter_data[arg_name].append_array(value)
				else:
					chapter_data[arg_name].append(value)
			else:
				# 替换模式
				if typeof(value) == TYPE_ARRAY:
					chapter_data[arg_name] = value.duplicate()
				else:
					chapter_data[arg_name] = [value]
		
		TYPE_BOOL:
			# 布尔值
			if typeof(value) == TYPE_BOOL:
				chapter_data[arg_name] = value
			elif typeof(value) in [TYPE_INT, TYPE_FLOAT]:
				chapter_data[arg_name] = value != 0
			else:
				chapter_data[arg_name] = bool(value)
		
		TYPE_INT, TYPE_FLOAT:
			# 数字类型
			if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
				if append_mode:
					chapter_data[arg_name] = current + value
				else:
					chapter_data[arg_name] = value
			else:
				chapter_data[arg_name] = int(value) if typeof(value) == TYPE_STRING else value
		
		TYPE_STRING:
			if append_mode:
				chapter_data[arg_name] = current + str(value)
			else:
				chapter_data[arg_name] = str(value)
		
		_:
			chapter_data[arg_name] = value
	return true
	
## 读取游戏数据
## @param arg_name: 数据键名
## @param default: 默认值（当键不存在时返回）
## @return: 对应的数据值，不存在时返回 default
func get_data(arg_name: String, default = null):
	if arg_name.is_empty():
		push_error("get_data: arg_name 不能为空")
		return default
	
	if chapter_data.has(arg_name):
		return chapter_data[arg_name]
	
	return default
		

# ============================================================
# 场景切换
# ============================================================
## 切到下一个章节场景。 [br]
## [param scene_name]: 相对 [member GameManager.ChapterScenePath] 的路径，
## 不带 .tscn 后缀。e.g. "chapter0/chapter0_hallway" [br]
## [param san_cost]: 切场景的精神消耗（默认 0） [br]
## [param params]: 透传给 [method GGT.change_scene] 的参数字典
func change_scene(scene_name: String, san_cost: int = 0, params: Dictionary = {}) -> void:
	if scene_name == "":
		push_error("[Chapter.change_scene] 场景名为空")
		return
	var full_path : String = GameManager.ChapterScenePath + scene_name + ".tscn"
	if not ResourceLoader.exists(full_path):
		push_error("[Chapter.change_scene] 场景不存在: ", full_path)
		return

	if san_cost != 0:
		san -= san_cost

	cur_scene = scene_name
	GGT.change_scene(full_path, params)


func change_scene_to_pos(scene_name: String, x: float, y: float, san_cost: int = 0) -> void:
	change_scene(scene_name, san_cost, {"player_pos": Vector2(x, y)})

# ============================================================
# 持久化协议（DataManager）
# ============================================================
func save_data() -> Dictionary:
	return {
		"chapter_data": chapter_data,
		"cur_scene": cur_scene,
		"player_pos": GameManager.get_player_pos(),
		"san": san,
	}

func load_data(data: Dictionary) -> void:
	chapter_data = data.get("chapter_data", {})
	cur_scene = data.get("cur_scene", "")
	player_pos = data.get("player_pos", Vector2.ZERO)
	san = data.get("san", 100)
	# 玩家节点若已加载会立即瞬移；若未加载则信号 emit 落空，
	# 玩家自己的 _ready 末尾应再从 Chapter.player_pos 拉一次以兜底
	GameManager.change_player_pos(player_pos)
