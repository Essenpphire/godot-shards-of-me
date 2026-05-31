extends Prop

const KEY_ID: String = "9"
const NEXT_SCENE: String = "chapter2/classroom"


## 玄关出口：钥匙必须先从线索书拿到手上，也就是进入物品栏。
func handle_interact() -> void:
	if not ClueManager.has_in_inventory(KEY_ID):
		Dialogic.start("chapter1", "door_without_key")
		_interacted = false
		return

	Dialogic.start("chapter1", "door_with_key")
	await Dialogic.timeline_ended
	Chapter.change_scene(NEXT_SCENE)
