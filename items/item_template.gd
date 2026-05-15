# item_template.gd
# Item.gd - 物品基类
class_name Item
extends Resource

@export var id: String = "item_001"
@export var name : String = "物品"
@export var description: String = "物品描述"
@export var type : ItemType = ItemType.CLUE

enum ItemType {
	CONSUMABLE,  # 消耗品
	CLUE   # 线索
}

func handle_use(user: Node) -> bool:
	return false

func get_display_name() -> String:
	return name

"""
extends Sprite2D
 
@export var ID = "0"
 
func _ready():
	texture = load("res://assets/curated/" + ItemData.get_texture(ID))
 
 
func _on_body_entered(body):
	get_parent().find_child("Inventory").add_item(ID)
	queue_free()
 """
