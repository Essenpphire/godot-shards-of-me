extends NinePatchRect

const CLUES_PER_PAGE: int = 4
var cur_page=0;

@onready var slots: Array[PanelContainer] = [
	$Clues/Clue1,
	$Clues/Clue2,
	$Clues/Clue3,
	$Clues/Clue4
]

@onready var prev_button: Button = $pre
@onready var next_button: Button = $next
@onready var page_label: Label = $pagelabel

func _ready() -> void:
	EventBus.clue_item_add.connect(_on_Eventbus_clue_item_add)
	EventBus.clue_book_update.connect(_on_Eventbus_clue_book_update)

func _on_Eventbus_clue_item_add(Clue)->void:
	return

func _on_Eventbus_clue_book_update()->void:
	refresh_page()
	return

func refresh_page()->void:
	var clues: Array[Dictionary] = ClueManager.get_collected_clues()
	var total_pages: int = get_total_pages(clues.size())
	print("刷新线索书页面")
	print("当前线索数量：", clues.size())
	cur_page = clampi(cur_page, 0, total_pages - 1)
	print("======== 当前页线索 ========")
	print("当前页：", cur_page + 1)

	
	var start_index: int = cur_page * CLUES_PER_PAGE
	for i: int in range(CLUES_PER_PAGE):
		var clue_index: int = start_index + i

		if clue_index < clues.size():
			var clue: Dictionary = clues[clue_index]
			print(
				"槽位 ", i + 1,
				" | 索引 ", clue_index,
				" | 标题：", clue.get("title", "无标题"),
				" | ID：", clue.get("id", "无ID")
			)
		else:
			print("槽位 ", i + 1, " | 空")

	for i: int in range(CLUES_PER_PAGE):
		var clue_index: int = start_index + i

		if clue_index < clues.size():
			slots[i].set_clue(clues[clue_index])
		else:
			slots[i].set_empty()

	page_label.text = "%d / %d" % [cur_page + 1, total_pages]

	prev_button.visible = cur_page > 0
	next_button.visible = cur_page < total_pages - 1
	return

func get_total_pages(clue_count: int) -> int:
	return max(1, ceili(clue_count / float(CLUES_PER_PAGE)))

func _on_next_pressed() -> void:
	cur_page+=1
	refresh_page()

func _on_pre_pressed() -> void:
	cur_page-=1
	refresh_page()



func _on_button_pressed() -> void:
	#添加clue时模板如下
	ClueManager.add_clue({
			"id": "test_clue_" + str(Time.get_ticks_msec()),#内部id
			"title": "测试线索",#小标题
			"description": "这是一条测试用线索，用来检查线索书是否能正常新增和翻页。",#下方描述
			"image": null#图片地址
		})
