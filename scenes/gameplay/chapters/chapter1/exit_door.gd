extends "res://scenes/props/prop_door.gd"

const KEY_ID: String = "9"
const NEXT_SCENE: String = "chapter2/classroom"


## 玄关出口：复用普通门的房间提示，但开门前先检查钥匙是否在手上。
func handle_interact() -> void:
	if not ClueManager.has_in_inventory(KEY_ID):
		Dialogic.start("chapter1", "door_without_key")
		_interacted = false
		return

	Dialogic.start("chapter1", "door_with_key")
	await Dialogic.timeline_ended
	Chapter.change_scene(NEXT_SCENE)
