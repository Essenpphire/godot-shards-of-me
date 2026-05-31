extends Prop

## 玩家要传送到的下一个场景
@export var next_scene : String
## 传送SAN值消耗
@export var san_cost : int = 0
## 玩家在下个场景中的坐标
@export var next_pos : Vector2 = Vector2(627, 497)
## 通往的房间名（玩家靠近时显示，留空则不显示）
@export var room_name : String = ""

@onready var room_hint : Panel = $RoomHint
@onready var room_label : Label = $RoomHint/Label

func _ready() -> void:
	super._ready()
	room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	room_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	room_label.text = room_name

## override 开门操作
func handle_interact():
	var params = {
		"player_pos": next_pos
	}
	print("开门：", next_scene)
	Chapter.change_scene(next_scene, san_cost, params)

func _on_detection_body_entered(body: Node2D) -> void:
	super._on_detection_body_entered(body)
	if body.is_in_group("Player") and room_name != "":
		room_hint.fade_in()

func _on_detection_body_exited(body: Node2D) -> void:
	super._on_detection_body_exited(body)
	if body.is_in_group("Player"):
		room_hint.fade_out()
