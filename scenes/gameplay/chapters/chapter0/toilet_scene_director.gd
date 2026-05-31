extends Node

const SURFACE_TOILET_SCENE := "res://scenes/gameplay/chapters/chapter0/toilet.tscn"
const TOILET1_PLAYED_KEY := "toilet1_played"

@export var dialog_chapter: String = "chapter0"
@export var dialog_label: String = "toilet1"


func _ready() -> void:
	await get_tree().process_frame

	var scene := get_tree().current_scene
	if scene == null:
		return

	# toilet_inside.tscn 继承 toilet.tscn，所以必须用真实当前场景路径排除里世界。
	if scene.scene_file_path != SURFACE_TOILET_SCENE:
		return

	if Chapter.get_data(TOILET1_PLAYED_KEY, false):
		return

	Chapter.set_data(TOILET1_PLAYED_KEY, true)
	await _play_toilet1()


func _play_toilet1() -> void:
	GameManager.lock_player_control(true)

	if not Dialogic.is_node_ready():
		await Dialogic.ready

	Dialogic.start(dialog_chapter, dialog_label)
	await Dialogic.timeline_ended

	GameManager.lock_player_control(false)
