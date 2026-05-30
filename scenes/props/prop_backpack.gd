extends Prop

func _ready() -> void:
	if Chapter.get_data("collected_clues", []).has("1"):
		can_interact = false
	super._ready()

## override 背包里有盒子
func handle_interact() -> void:
	ClueManager.add_clue("1")
	Dialogic.start("chapter0", "find_box")
	$Hint.hide()
