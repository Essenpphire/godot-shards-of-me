extends Node

const PANG_TALKED_VARIABLE: String = "chapter2.pang_talked"
const INTERACT_ACTION: StringName = &"\u4e92\u52a8"

@onready var hint: Panel = $"../Hint"

var _in_range: bool = false
var _dialogue_playing: bool = false


func _ready() -> void:
	hint.show()
	hint.modulate.a = 0.0


func _physics_process(_delta: float) -> void:
	if _dialogue_playing:
		return
	if Dialogic.VAR.get_variable(PANG_TALKED_VARIABLE, false, true):
		return
	if GameManager.is_player_control_locked():
		return
	if not _in_range:
		return
	if not Input.is_action_just_pressed(INTERACT_ACTION):
		return

	_play_start_dialogue()


func _play_start_dialogue() -> void:
	_dialogue_playing = true
	hint.fade_out()
	GameManager.lock_player_control(true)

	if not Dialogic.is_node_ready():
		await Dialogic.ready

	Dialogic.start("chapter2", "start")
	await Dialogic.timeline_ended
	GameManager.lock_player_control(false)


func _on_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		_in_range = true
		if not _dialogue_playing and not Dialogic.VAR.get_variable(PANG_TALKED_VARIABLE, false, true):
			hint.fade_in()


func _on_detection_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		_in_range = false
		hint.fade_out()
