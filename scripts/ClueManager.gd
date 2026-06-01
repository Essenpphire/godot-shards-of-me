extends Node

## 线索书收集到的线索 里面存id就行
var clues : Array[String] = []
## 物品栏（同样只存 id）
var inventory : Array[String] = []

func _ready() -> void:
	add_to_group("Persist")
	## 超级拼装
	Dialogic.signal_event.connect(func(arg):
		if arg == "combine_clues":
			remove_clue("6")
			remove_clue("7")
			add_clue("10")
	)

func save_data() -> Dictionary:
	return {
		"clues": clues,
		"inventory": inventory,
	}

func load_data(data: Dictionary) -> void:
	# 兼容历史存档 key "collected_clues"
	clues = _to_str_array(data.get("clues", data.get("collected_clues", [])))
	inventory = _to_str_array(data.get("inventory", []))
	EventBus.clue_update_book.emit()
	EventBus.inventory_update.emit()

static func _to_str_array(src) -> Array[String]:
	var out : Array[String] = []
	if src is Array:
		for v in src:
			out.append(str(v))
	return out

# ============== 线索书 ==============
func clear_clues() -> void:
	print("已清除！")
	clues.clear()
	EventBus.clue_update_book.emit()

func add_clue(new_clue : String) -> void:
	print("尝试添加线索: ", new_clue)
	if new_clue == "" or clues.has(new_clue):
		return
	clues.append(new_clue)
	Chapter.set_data("collected_clues", new_clue, true)
	EventBus.clue_add_item.emit(new_clue)
	EventBus.clue_update_book.emit()

func remove_clue(clue : String) -> void:
	print("尝试移除线索: ", clue)
	clues.erase(clue)
	EventBus.clue_update_book.emit()

func get_clues() -> Array[String]:
	return clues

# ============== 物品栏 ==============
func clear_inventory() -> void:
	inventory.clear()
	EventBus.inventory_update.emit()

func add_to_inventory(item_id : String) -> void:
	print("尝试添加物品到物品栏: ", item_id)
	if item_id == "" or inventory.has(item_id):
		return
	inventory.append(item_id)
	EventBus.inventory_update.emit()

func remove_from_inventory(item_id : String) -> void:
	print("尝试从物品栏移除: ", item_id)
	inventory.erase(item_id)
	EventBus.inventory_update.emit()

func get_inventory() -> Array[String]:
	return inventory

func has_in_inventory(item_id : String) -> bool:
	return inventory.has(item_id)

# ============== 转移 ==============
## 物品栏 → 线索书（slot 上点"放回书中"）
func move_inventory_to_clues(item_id : String) -> bool:
	if item_id == "" or not inventory.has(item_id):
		return false
	inventory.erase(item_id)
	if not clues.has(item_id):
		clues.append(item_id)
		EventBus.clue_add_item.emit(item_id)
	EventBus.inventory_update.emit()
	EventBus.clue_update_book.emit()
	return true

## 线索书 → 物品栏（clue 上点"拿到手上"）
func move_clues_to_inventory(item_id : String) -> bool:
	if item_id == "" or not clues.has(item_id):
		return false
	clues.erase(item_id)
	if not inventory.has(item_id):
		inventory.append(item_id)
	EventBus.clue_update_book.emit()
	EventBus.inventory_update.emit()
	return true
