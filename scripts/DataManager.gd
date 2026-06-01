# DataManager.gd
extends Node
## 数据管理器，负责加载和保存游戏数据（Persist 标签分组），例如章节数据、玩家状态、对话进程等。 [br]
## 所有数据统一保存到 Dialogic 的存档系统中，固定使用名为 "process" 的 slot。 [br]
## 实际落盘位置：[code]user://dialogic/saves/process/[/code]
## - [code]state.txt[/code]：Dialogic 自身的对话进程（由 [member Dialogic.Save] 写入）
## - [code]game_data.txt[/code]：项目自定义的 Persist 节点数据
class_name DataManager

## 固定使用的 Dialogic 存档 slot 名称
const SLOT_NAME : String = "process"
## 项目自定义数据在 slot 内的文件名
const DATA_FILE_NAME : String = "game_data.txt"


## 等待 Dialogic 自动加载就绪。 [br]
## 由于 autoload 的注册顺序，[code]Dialogic[/code] 排在 [code]Data[/code]/[code]GameManager[/code] 之后，
## 因此首次访问 Dialogic 子系统前必须先确保其 [code]_ready()[/code] 已执行。
func _wait_dialogic_ready() -> void:
	if not Dialogic.is_node_ready():
		await Dialogic.ready


## 加载持久化数据，例如章节数据、玩家状态、对话进程等。 [br]
## 数据从 Dialogic 的 "process" slot 读取并分发给所有 [code]Persist[/code] 分组的节点。 [br]
## [b][return][/b]: 是否成功（slot 不存在视为首次启动，返回 [code]false[/code]）
func load_persistent_data() -> bool:
	await _wait_dialogic_ready()

	# slot 还不存在，视为首次启动，节点保留默认值
	if not Dialogic.Save.has_slot(SLOT_NAME):
		print("[DataManager] 未发现存档 slot \"", SLOT_NAME)
		return false

	# 加载 Dialogic 自身的对话进程（state.txt）
	# 若 slot 内没有 state.txt（比如只手动写过 game_data.txt），load 会返回 FAILED，
	# 此时不当作错误处理，仅打印提示
	var dialogic_err := Dialogic.Save.load(SLOT_NAME)
	if dialogic_err != OK:
		print("[DataManager] Dialogic 对话状态未加载（slot 可能为空）：", dialogic_err)

	# 加载项目自定义数据（game_data.txt）
	var data_dict = Dialogic.Save.load_file(SLOT_NAME, DATA_FILE_NAME, {})
	print(data_dict)
	if typeof(data_dict) != TYPE_DICTIONARY:
		push_error("[DataManager] 持久化数据格式无效，期望 Dictionary")
		return false

	# 分发给所有 Persist 分组的节点
	var persist_nodes := get_tree().get_nodes_in_group("Persist")
	for node in persist_nodes:
		if not (node.name in data_dict):
			continue
		if node.has_method("load_data"):
			print(node.name)
			node.call("load_data", data_dict[node.name])
		else:
			push_error("[DataManager] 节点缺少 load_data 方法: ", node.name)

	if is_instance_valid(ClueManager):
		ClueManager.sync_chapter_state()

	print("[DataManager] 对话数据加载成功，slot: ", SLOT_NAME)
	return true


## 保存持久化数据，例如章节数据、玩家状态、对话进程等。 [br]
## 数据统一写入 Dialogic 的 "process" slot。 [br]
## [b][return][/b]: 是否保存成功
func save_persistent_data() -> bool:
	await _wait_dialogic_ready()
	if is_instance_valid(PuzzleLayer):
		PuzzleLayer.flush_active_puzzle_state()

	# 收集所有 Persist 分组节点的数据
	var output_dict := {}
	var persist_nodes := get_tree().get_nodes_in_group("Persist")
	for node in persist_nodes:
		if node.has_method("save_data"):
			output_dict[node.name] = node.call("save_data")
		else:
			push_error("[DataManager] 节点缺少 save_data 方法: ", node.name)

	# 写入项目自定义数据（game_data.txt）
	var data_err := Dialogic.Save.save_file(SLOT_NAME, DATA_FILE_NAME, output_dict)
	if data_err != OK:
		push_error("[DataManager] 自定义数据保存失败: ", data_err)
		return false

	# 写入 Dialogic 自身的对话进程（state.txt）
	# Dialogic.Save.save 还会顺带写 info.txt 与缩略图，统一落在同一个 slot 目录
	var dialogic_err := Dialogic.Save.save(SLOT_NAME)
	if dialogic_err != OK:
		push_error("[DataManager] Dialogic 状态保存失败: ", dialogic_err)
		return false

	print("[DataManager] 持久化数据保存成功，slot: ", SLOT_NAME)
	return true


## 是否存在已保存的进度。 [br]
## 用于主菜单"继续游戏"等需要判断存档存在性的场景。
func has_save() -> bool:
	if not Dialogic.is_node_ready():
		await Dialogic.ready
	return Dialogic.Save.has_slot(SLOT_NAME)


## 删除持久化进度，恢复到首次启动状态。
func delete_save() -> Error:
	if not Dialogic.is_node_ready():
		await Dialogic.ready
	Dialogic.VAR.reset()
	if is_instance_valid(Chapter):
		Chapter.reset_runtime_state()
	if is_instance_valid(ClueManager):
		ClueManager.reset_runtime_data()
	return Dialogic.Save.delete_slot(SLOT_NAME)
