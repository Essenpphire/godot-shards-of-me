class_name WindowBirdFx
extends Node2D

signal flyby_started
signal flyby_finished

@export var effect_name := "window_bird_flyby"
@export var listen_to_event_bus := true
@export var play_on_ready := false

@export_group("Flight Path")
@export var start_position := Vector2(-640, -190)
@export var pass_position := Vector2(0, -210)
@export var end_position := Vector2(640, -180)
@export_range(0.1, 10.0, 0.05) var fly_duration := 2.4
@export_range(0.0, 32.0, 1.0) var bob_amplitude := 8.0
@export_range(0.0, 8.0, 0.25) var bob_cycles := 2.0

@export_group("Bird")
@export var bird_tilt_degrees := -5.0
@export_range(0.0, 1.0, 0.01) var visible_alpha := 0.72
@export_range(0.0, 1.0, 0.01) var fade_duration := 0.12

@onready var bird: AnimatedSprite2D = $bird
@onready var flight_path: Node2D = $FlightPath
@onready var start_marker: Marker2D = $FlightPath/Start
@onready var pass_marker: Marker2D = $FlightPath/Pass
@onready var end_marker: Marker2D = $FlightPath/End

var _fly_tween: Tween


func _ready() -> void:
	_set_bird_idle()

	if listen_to_event_bus:
		EventBus.game_vfx_play.connect(_on_game_vfx_play)

	if play_on_ready:
		call_deferred("play_bird_flyby")


func _exit_tree() -> void:
	if listen_to_event_bus and EventBus.game_vfx_play.is_connected(_on_game_vfx_play):
		EventBus.game_vfx_play.disconnect(_on_game_vfx_play)


func play_bird_flyby() -> void:
	if is_instance_valid(_fly_tween):
		_fly_tween.kill()

	_prepare_bird_for_flight()
	flyby_started.emit()

	_fly_tween = create_tween().set_parallel(true)
	_fly_tween.tween_method(_set_flight_progress, 0.0, 1.0, fly_duration)
	_fly_tween.tween_property(bird, "modulate:a", visible_alpha, fade_duration)
	_fly_tween.tween_property(bird, "modulate:a", 0.0, fade_duration).set_delay(max(0.0, fly_duration - fade_duration))
	_fly_tween.tween_callback(_finish_bird_flyby).set_delay(fly_duration)


func _on_game_vfx_play(requested_effect_name: String) -> void:
	if requested_effect_name == effect_name:
		play_bird_flyby()


func _prepare_bird_for_flight() -> void:
	bird.visible = true
	bird.position = _get_start_position()
	bird.rotation_degrees = bird_tilt_degrees
	bird.flip_h = _get_end_position().x < _get_start_position().x
	bird.modulate.a = 0.0
	bird.play()


func _finish_bird_flyby() -> void:
	_set_bird_idle()
	flyby_finished.emit()
	EventBus.game_vfx_over.emit(effect_name)


func _set_bird_idle() -> void:
	bird.stop()
	bird.visible = false
	bird.position = _get_start_position()
	bird.rotation_degrees = 0.0
	bird.modulate.a = 0.0


func _set_flight_progress(progress: float) -> void:
	var base_position := Vector2.ZERO
	var start := _get_start_position()
	var mid := _get_pass_position()
	var finish := _get_end_position()

	if progress < 0.5:
		var segment_progress := smoothstep(0.0, 1.0, progress / 0.5)
		base_position = start.lerp(mid, segment_progress)
	else:
		var segment_progress := smoothstep(0.0, 1.0, (progress - 0.5) / 0.5)
		base_position = mid.lerp(finish, segment_progress)

	var bob_offset := sin(progress * TAU * bob_cycles) * bob_amplitude
	bird.position = base_position + Vector2(0.0, bob_offset)


func _get_start_position() -> Vector2:
	if is_instance_valid(start_marker):
		return start_marker.position
	return start_position


func _get_pass_position() -> Vector2:
	if is_instance_valid(pass_marker):
		return pass_marker.position
	return pass_position


func _get_end_position() -> Vector2:
	if is_instance_valid(end_marker):
		return end_marker.position
	return end_position
