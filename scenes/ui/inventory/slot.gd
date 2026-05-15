extends PanelContainer
class_name Slot
 
@onready var texture_rect = $TextureRect
@export_enum("NONE:0","HEAD:1","BODY:2","LEG:3", "ACTIVE:4") var slot_type : int
## 格子是否被填满（有物品）
var filled : bool = false

## 开始拖拽 物品
func _get_drag_data(at_position):
	set_drag_preview(get_preview())
	return texture_rect
 
## 能否放物品
func _can_drop_data(_pos, data):
	return data is TextureRect
 
## 放下物品
func _drop_data(_pos, data):
	var tmp = texture_rect.prop
	texture_rect.prop = data.prop
	data.prop = tmp
 
func get_preview():
	var preview_texture = TextureRect.new()
 
	preview_texture.texture = texture_rect.texture
	preview_texture.expand_mode = 1
	preview_texture.size = Vector2(64, 64)
 
	var preview = Control.new()
	preview.add_child(preview_texture)
 
	return preview
 
func get_ATK():
	return texture_rect.ATK
 
func set_property(data):
	texture_rect.prop = data
 
	if data["TEXTURE"] == null:
		filled = false
	else:
		filled = true
 
