# clue.gd
# 线索书里单个线索槽位 — 纯渲染层：拿到 id → 用 ItemData 查信息显示。
extends Panel

@onready var clue_image: TextureRect = $ClueImage
@onready var info: Control = $Info
@onready var title_label: Label = $Info/Title
@onready var desc_label: Label = $Info/Description
@onready var action_menu: VBoxContainer = $ActionMenu
@onready var inspect_btn: Button = $ActionMenu/InspectBtn
@onready var slot_btn: Button = $ActionMenu/SlotBtn

## 当前槽位绑定的物品 id（"" 表示空槽）
var item_id : String = ""

func _ready() -> void:
	action_menu.hide()

## 用 id 填充：从 ItemData 查信息
func set_clue_id(id : String) -> void:
	item_id = id
	action_menu.hide()
	if id == "":
		set_empty()
		return
	var info_dict : Dictionary = ItemData.get_item_info(id)
	if info_dict.is_empty():
		set_empty()
		return
	info.show()
	var tex_path : String = info_dict.get("texture_path", "")
	clue_image.texture = load(tex_path) if tex_path != "" else null
	title_label.text = info_dict.get("name", "")
	desc_label.text = info_dict.get("description", "")

func set_empty() -> void:
	item_id = ""
	title_label.text = ""
	desc_label.text = ""
	clue_image.texture = null

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if item_id == "":
			return
		if action_menu.visible:
			action_menu.hide()
			info.show()
		else:
			action_menu.show()
			info.hide()

func _on_inspect_btn_pressed() -> void:
	print("仔细查看: ", item_id)
	UiLayer.get_node("ClueBook").hide()
	UiLayer.get_node("ItemLayer").show()
	match item_id:
		"0":
			UiLayer.get_node("ItemLayer/Content").hide()
			UiLayer.get_node("ItemLayer/ContentFull").show()
			EventBus.clue_inspect_item.emit(item_id)
		"1":
			UiLayer.get_node("ItemLayer").hide()
			PuzzleLayer.get_node("PasswordLock").show()
		_:	
			UiLayer.get_node("ItemLayer/ContentFull").hide()
			UiLayer.get_node("ItemLayer/Content").show()
			action_menu.hide()
			info.show()
			EventBus.clue_inspect_item.emit(item_id)

## "拿到手上"：把线索转移到物品栏
func _on_slot_btn_pressed() -> void:
	if item_id == "":
		push_warning("Clue: 空槽位，无法转移")
		return
	action_menu.hide()
	ClueManager.move_clues_to_inventory(item_id)
	# 视图会通过 clue_update_book 信号自动刷新
