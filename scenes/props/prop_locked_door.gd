extends "res://scenes/props/prop_door.gd"

## 解锁需要的物品 ID（需在 ClueManager 的 inventory 中）
@export var required_key_id : String = ""

func handle_interact():
	if required_key_id == "":
		super.handle_interact()
		return

	if ClueManager.has_in_inventory(required_key_id):
		super.handle_interact()
	else:
		Dialogic.start("system", "door_locked")
		_interacted = false
