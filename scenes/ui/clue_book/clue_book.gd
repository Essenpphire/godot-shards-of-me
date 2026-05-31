extends Control

const CLUES_PER_PAGE: int = 4
var cur_page: int = 0

@onready var slots: Array = [
		$ClueBook/Clues/Clue1,
		$ClueBook/Clues/Clue2,
		$ClueBook/Clues/Clue3,
		$ClueBook/Clues/Clue4
	]

@onready var prev_button: Button = $ClueBook/PrevPageBtn
@onready var next_button: Button = $ClueBook/NextPageBtn
@onready var page_label: Label = $ClueBook/PageLabel

func save_data() -> Dictionary:
	return {
		"cur_page": cur_page,
	}

func load_data(data: Dictionary) -> void:
	cur_page = data.get("cur_page", 0)

func _ready() -> void:
	add_to_group("Persist")
	EventBus.clue_add_item.connect(on_clue_add_item)
	EventBus.clue_update_book.connect(on_clue_update_book)
	hide()
	prev_button.hide()
	next_button.hide()

func _unhandled_input(event):
	if event.is_action_pressed("打开线索"):
		if not visible:
			show()
			refresh_page()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		if visible:
			hide()
			get_viewport().set_input_as_handled()

func on_clue_add_item(_id : String) -> void:
	return

func on_clue_update_book() -> void:
	refresh_page()

func refresh_page() -> void:
	var ids : Array[String] = ClueManager.get_clues()
	var total_pages : int = get_total_pages(ids.size())
	cur_page = clampi(cur_page, 0, total_pages - 1)
	print("[ClueBook] 刷新 第%d/%d页 共%d条" % [cur_page + 1, total_pages, ids.size()])

	var start_index : int = cur_page * CLUES_PER_PAGE
	for i in range(CLUES_PER_PAGE):
		var idx : int = start_index + i
		if idx < ids.size():
			slots[i].set_clue_id(ids[idx])
		else:
			slots[i].set_empty()

	page_label.text = "%d / %d" % [cur_page + 1, total_pages]
	prev_button.visible = cur_page > 0
	next_button.visible = cur_page < total_pages - 1

func get_total_pages(clue_count: int) -> int:
	return max(1, ceili(clue_count / float(CLUES_PER_PAGE)))

func _on_prev_page_btn_pressed() -> void:
	cur_page -= 1
	refresh_page()

func _on_next_page_btn_pressed() -> void:
	cur_page += 1
	refresh_page()

func _on_exit_page_btn_pressed() -> void:
	hide()

## 测试按钮：用 items.json 里的 id 当作线索（如 "3" 是药）
func _on_button_pressed() -> void:
	ClueManager.add_clue("3")

func _on_debug_pressed() -> void:
	Chapter.set_data("collected_clues", [])
	ClueManager.clear_clues()
