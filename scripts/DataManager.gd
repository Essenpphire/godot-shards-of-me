# DataManager.gd
extends Node
## 数据管理器，负责加载和保存游戏数据 (Persist标签分组)，例如章节数据、玩家状态等
class_name DataManager
# 暂存路径和文件名，供保存时使用
var data_path : String = ""
var data_file_name : String = ""

## 加载持久化数据，例如章节数据、玩家状态等
func load_persistent_data(path : String, file_name : String) -> bool:
	if not DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_absolute(path)
	var full_path = path + "/" + file_name
	if not FileAccess.file_exists(full_path):
		var new_file = FileAccess.open(full_path, FileAccess.WRITE)
		if new_file:
			new_file.store_string("{}") # 写入空JSON对象
			new_file.close()
			data_path = path
			data_file_name = file_name
			print("持久化数据文件创建成功: ", full_path)
			return true
		else:
			push_error("无法创建持久化数据文件: ", full_path)
			return false

	data_path = path
	data_file_name = file_name
	var file = FileAccess.open(full_path, FileAccess.READ)
	if file:
		var json_str = file.get_as_text()
		var json = JSON.new()
		var parse_err = json.parse(json_str)
		if parse_err == OK:
			var data_dict = json.data
			# 将数据分发给所有Persist分组的节点
			var persist_nodes = get_tree().get_nodes_in_group("Persist")
			for node in persist_nodes:
				if node.name not in data_dict:
					continue
				
				if node.has_method("load_data"):
					node.call("load_data", data_dict[node.name])
				else:
					push_error("节点缺少load_data方法: ", node.name)
			return true
		else:
			push_error("JSON解析失败: ", json.get_error_message())
			return false
	else:
		push_error("无法打开持久化数据文件: ", full_path)
	return false

## 保存持久化数据，例如章节数据、玩家状态等 [br]
## [b][return][/b]: 是否保存成功
func save_persistent_data() -> bool:
	var full_path = data_path + "/" + data_file_name
	var file = FileAccess.open(full_path, FileAccess.WRITE)
	var output_dict = {}
	if file:
		var save_nodes = get_tree().get_nodes_in_group("Persist")
		for node in save_nodes:
			if (node.has_method("save_data")):
				var node_data = node.call("save_data")
				output_dict[node.name] = node_data
			else:
				push_error("节点缺少save_data方法: ", node.name)
		file.store_string(JSON.stringify(output_dict))
		print("持久化数据保存成功: ", full_path)
		return true
	else:
		push_error("无法保存持久化数据文件: ", full_path)
		return false
