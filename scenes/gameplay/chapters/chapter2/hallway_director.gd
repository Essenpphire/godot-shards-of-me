extends Node

const REACHED_HALLWAY_KEY: String = "chapter2_reached_inside_hallway"
const PLAYER_AVATAR_KEY: String = "player_avatar"
const OUYANG_YE_AVATAR: String = "ouyang_ye"

@export var bgm: AudioStream

@onready var surface_background: Node = $"../Background"
@onready var inside_background: Node = $"../Background2"
@onready var player_sprite: AnimatedSprite2D = $"../Sortables/Player/AnimatedSprite2D"


func _ready() -> void:
	Chapter.set_data(REACHED_HALLWAY_KEY, true)
	Chapter.set_data(PLAYER_AVATAR_KEY, OUYANG_YE_AVATAR)
	_show_inside_world()
	_apply_ouyang_ye_avatar()
	await _play_bgm_if_needed()
	GameManager.lock_player_control(false)


func _show_inside_world() -> void:
	surface_background.visible = false
	inside_background.visible = true


func _play_bgm_if_needed() -> void:
	if bgm == null:
		return
	if GGT.is_changing_scene():
		await GGT.scene_transition_finished
	Audio.set_volume(0, 0.1)
	Audio.play_music(bgm)


func _apply_ouyang_ye_avatar() -> void:
	if player_sprite.sprite_frames == null:
		return
	if not player_sprite.sprite_frames.has_animation("Ye_idle"):
		return
	if not player_sprite.sprite_frames.has_animation("Ye_walk"):
		return

	var frames: SpriteFrames = player_sprite.sprite_frames.duplicate(true) as SpriteFrames
	if frames == null:
		return
	_copy_animation(frames, "Ye_idle", "idle")
	_copy_animation(frames, "Ye_walk", "move")
	player_sprite.sprite_frames = frames
	player_sprite.play("idle")


func _copy_animation(frames: SpriteFrames, from_name: StringName, to_name: StringName) -> void:
	frames.clear(to_name)
	frames.set_animation_speed(to_name, frames.get_animation_speed(from_name))
	frames.set_animation_loop(to_name, frames.get_animation_loop(from_name))

	for index: int in range(frames.get_frame_count(from_name)):
		var texture := frames.get_frame_texture(from_name, index)
		var duration := frames.get_frame_duration(from_name, index)
		frames.add_frame(to_name, texture, duration)
