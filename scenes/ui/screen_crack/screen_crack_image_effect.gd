extends TextureRect
# 资源加载
const CRACK_STAGE_2 := preload("res://assets/images/ui/mirror_shattered/crack_stage_2.png")
const CRACK_STAGE_3 := preload("res://assets/images/ui/mirror_shattered/crack_stage_3.png")
const CRACK_STAGE_4 := preload("res://assets/images/ui/mirror_shattered/crack_stage_4.png")
const CRACK_ZERO := preload("res://assets/images/ui/mirror_shattered/crack_zero.png")

# 音效导入
@export var mirror_shattered_sfx:AudioStream


# 黑暗遮罩变量导入
@export var darkness_overlay_path: NodePath
@export var darkness_color := Color(0.0, 0.0, 0.0, 1.0)
@export_range(0.0, 1.0, 0.01) var max_darkness_alpha := 0.55:
	set(value):
		max_darkness_alpha = clampf(value, 0.0, 1.0)
		_apply_crack_state()



# 裂纹状态变量
@export_range(0, 4, 1) var crack_state := 1:
	set(value):
		crack_state = clampi(value, 0, 4)
		_apply_crack_state()


@export_range(0.0, 1.0, 0.01) var overlay_alpha := 0.85:
	set(value):
		overlay_alpha = clampf(value, 0.0, 1.0)
		_apply_crack_state()

var pre_stage:int

func _ready() -> void:
	EventBus.san_update.connect(_on_san_update)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	stretch_mode = TextureRect.STRETCH_SCALE
	
	pre_stage=_get_san_stage(Chapter.san)
	_set_crack_state(pre_stage)
	if material == null:
		var additive_material := CanvasItemMaterial.new()
		additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = additive_material

#设置碎裂阶段方法
func _set_crack_state(value: int) -> void:
	crack_state = value
	_apply_crack_state()


func _apply_crack_state() -> void:
	if not is_inside_tree():
		return

	var darkness_factor := 0.0

	match crack_state:
		0:
			texture = CRACK_ZERO
			visible = true
			darkness_factor = 1.0
		1:
			texture = null
			visible = false
			darkness_factor = 0.0
		2:
			texture = CRACK_STAGE_2
			visible = true
			darkness_factor = 0.35
		3:
			texture = CRACK_STAGE_3
			visible = true
			darkness_factor = 0.65
		4:
			texture = CRACK_STAGE_4
			visible = true
			darkness_factor = 0.88

	modulate = Color(1.0, 1.0, 1.0, overlay_alpha)
	_apply_darkness_overlay(darkness_factor)

func _apply_darkness_overlay(darkness_factor: float) -> void:
	if darkness_overlay_path.is_empty():
		return

	var overlay := get_node_or_null(darkness_overlay_path) as ColorRect
	if overlay == null:
		return

	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(
		darkness_color.r,
		darkness_color.g,
		darkness_color.b,
		max_darkness_alpha * clampf(darkness_factor, 0.0, 1.0)
	)
	overlay.visible = overlay.color.a > 0.0

func _san_state_changed(pre_san:int,cur_san:int)->bool:
	return false;
#判断san值阶段
func _get_san_stage(val: int) -> int:
	
	if val <= 0:
		GameManager.lock_player_control()
		Dialogic.start("endings", "san_turn_0")
		return 0
	elif val <= 25:
		return 4
	elif val <= 50:
		return 3
	elif val <= 75:
		return 2
	else:
		return 1

func _on_san_stage_lower()->void:
	print("san阶段降低")
	Audio.play_sfx(mirror_shattered_sfx)
	return
	
func _on_san_stage_zero()->void:
	print("san值归零")
	return
	
func _on_san_stage_upper()->void:
	print("san值恢复")
	return

func _on_san_update(val:int)->void:
	var cur_stage=_get_san_stage(val)
	_set_crack_state(cur_stage)
	if(cur_stage==0):
		_on_san_stage_zero()
	elif(cur_stage>pre_stage):
		_on_san_stage_lower()
	elif(cur_stage<pre_stage):
		_on_san_stage_upper()
	pre_stage=cur_stage


func _on_san_decrease_btn_pressed() -> void:
	Chapter.san -= 25

func _on_san_increase_btn_pressed() -> void:
	Chapter.san += 25
