extends "res://scenes/props/prop_door.gd"

const WASHED_FACE_KEY := "toilet_washed_face"

@export var blocked_dialog_chapter: String = "chapter0"
@export var blocked_dialog_label: String = "exit_toilet"


func handle_interact() -> void:
	if Chapter.get_data(WASHED_FACE_KEY, false):
		super.handle_interact()
		return

	GameManager.lock_player_control(true)
	if not Dialogic.is_node_ready():
		await Dialogic.ready

	Dialogic.start(blocked_dialog_chapter, blocked_dialog_label)
	await Dialogic.timeline_ended

	GameManager.lock_player_control(false)
	_interacted = false
