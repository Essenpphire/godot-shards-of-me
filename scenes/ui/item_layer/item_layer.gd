# item_layer.gd
extends CanvasLayer

@onready var image: TextureRect = $Content/Image
@onready var image_full : TextureRect = $ContentFull/Image
@onready var info : VBoxContainer = $Content/Info
@onready var title_label: Label = $Content/Info/Title
@onready var desc_label: Label = $Content/Info/Description

# 也许后面有用
var curr_id: String = ""

func _ready() -> void:
	hide()
	EventBus.clue_inspect_item.connect(_on_inspect_item)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()

func _on_inspect_item(id: String) -> void:
	show_item(id)

## 根据物品 id 填充并显示详情面板
func show_item(id: String) -> void:
	var item_info : Dictionary = ItemData.get_item_info(id)
	if item_info.is_empty():
		push_warning("ItemLayer: 物品 ID '%s' 不存在" % id)
		return
	curr_id = id
	title_label.text = item_info.get("name", "")
	var desc : String = item_info.get("description", "")
	if desc.is_empty():
		info.hide()
	else:
		desc_label.text = desc
		info.show()
	var texture_path: String = item_info.get("texture_path", "")
	if texture_path != "" and ResourceLoader.exists(texture_path):
		image.texture = load(texture_path)
		image_full.texture = load(texture_path)
	else:
		image.texture = null
		image_full.texture = null
	show()

func _close() -> void:
	UiLayer.get_node("ClueBook").show()
	curr_id = ""
	hide()

func _on_exit_btn_pressed() -> void:
	_close()
