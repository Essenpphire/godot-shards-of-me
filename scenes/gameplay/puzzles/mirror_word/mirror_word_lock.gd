class_name MirrorWordLock
extends Node2D

@export_group("Player Tracking")
@export var tracked_player_path: NodePath
@export var find_player_in_group: bool = true
@export var reveal_world_point: Vector2 = Vector2.ZERO
@export_range(0.0, 512.0, 1.0, "suffix:px") var full_alpha_distance: float = 24.0
@export_range(1.0, 2048.0, 1.0, "suffix:px") var fade_distance: float = 260.0

@export_group("Mirror Layout")
@export var mirror_view_size: Vector2 = Vector2(260.0, 180.0)

@export_group("Content")
@export var mirror_texture: Texture2D
@export var fallback_texture_size: Vector2i = Vector2i(1024, 256)
@export var source_region_position: Vector2 = Vector2.ZERO
@export var fallback_text: String = "SPEAK\nTHE NAME"

@export_group("Reveal")
@export_range(0.0, 1.0, 0.01) var hidden_alpha: float = 0.0
@export_range(0.0, 1.0, 0.01) var shown_alpha: float = 1.0
@export_range(0.0, 1.0, 0.01) var clue_collect_alpha_threshold: float = 0.9
@export var revealed_clue_id: String = ""

@export_group("State")
@export var starts_already_collected: bool = false

@onready var reflection_sprite: Sprite2D = $Composition/ReflectionSprite
@onready var mirror_back: Polygon2D = $Composition/MirrorBack
@onready var mirror_shadow: Polygon2D = $Composition/MirrorShadow
@onready var source_viewport: SubViewport = $SourceViewport
@onready var source_back: ColorRect = $SourceViewport/WallCanvas/Back
@onready var source_label: Label = $SourceViewport/WallCanvas/WordLabel
@onready var source_band_top: ColorRect = $SourceViewport/WallCanvas/BandTop
@onready var source_band_bottom: ColorRect = $SourceViewport/WallCanvas/BandBottom
@onready var collect_hint: Panel = get_node_or_null("Hint")

var _player: Node2D
var _collected: bool = false
var _hint_active: bool = false
var _current_alpha: float = 0.0


func _ready() -> void:
	_collected = starts_already_collected
	_player = _resolve_player()
	_configure_source_texture()
	_configure_geometry()
	_update_reveal_alpha()
	if collect_hint != null:
		collect_hint.hide()


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_player):
		_player = _resolve_player()
	_update_reveal_alpha()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("互动") and _can_collect_clue():
		_collect_clue()
		get_viewport().set_input_as_handled()


func reset_lock() -> void:
	_collected = false
	_update_reveal_alpha()


func force_lock() -> void:
	_collect_clue()


func is_locked() -> bool:
	return _collected


func _resolve_player() -> Node2D:
	if tracked_player_path != NodePath():
		var node := get_node_or_null(tracked_player_path)
		if node is Node2D:
			return node as Node2D

	if find_player_in_group:
		for node in get_tree().get_nodes_in_group("Player"):
			if node is Node2D:
				return node as Node2D

	return null


func _configure_source_texture() -> void:
	source_viewport.size = fallback_texture_size
	source_back.size = Vector2(fallback_texture_size)
	source_band_top.position = Vector2(0.0, 18.0)
	source_band_top.size = Vector2(fallback_texture_size.x, 20.0)
	source_band_bottom.position = Vector2(0.0, fallback_texture_size.y - 42.0)
	source_band_bottom.size = Vector2(fallback_texture_size.x, 18.0)
	source_label.text = fallback_text
	source_label.size = Vector2(fallback_texture_size)

	var resolved_texture := mirror_texture
	if resolved_texture == null:
		resolved_texture = reflection_sprite.texture
	if resolved_texture == null:
		resolved_texture = source_viewport.get_texture()

	reflection_sprite.texture = resolved_texture
	reflection_sprite.region_enabled = true
	reflection_sprite.centered = false

	var region_pos := source_region_position
	if region_pos == Vector2.ZERO and resolved_texture != null:
		var tex_size := resolved_texture.get_size()
		if tex_size.x > mirror_view_size.x or tex_size.y > mirror_view_size.y:
			region_pos = (tex_size - mirror_view_size) / 2.0

	reflection_sprite.region_rect = Rect2(region_pos, mirror_view_size)


func _configure_geometry() -> void:
	var mirror_rect := Rect2(Vector2.ZERO, mirror_view_size)
	reflection_sprite.position = mirror_rect.position

	mirror_back.polygon = _rect_polygon(mirror_rect)
	mirror_shadow.polygon = PackedVector2Array([
		Vector2(14.0, mirror_rect.end.y + 10.0),
		Vector2(mirror_rect.end.x + 22.0, mirror_rect.end.y + 6.0),
		Vector2(mirror_rect.end.x + 40.0, mirror_rect.end.y + 26.0),
		Vector2(28.0, mirror_rect.end.y + 36.0)
	])


func _rect_polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y)
	])


func _update_reveal_alpha() -> void:
	if not is_instance_valid(reflection_sprite):
		return

	_current_alpha = _calculate_alpha()
	var color := reflection_sprite.modulate
	color.a = _current_alpha
	reflection_sprite.modulate = color
	reflection_sprite.visible = _current_alpha > 0.01
	_update_collect_hint()


func _calculate_alpha() -> float:
	if not is_instance_valid(_player):
		return hidden_alpha

	var safe_fade_distance := maxf(fade_distance, full_alpha_distance + 1.0)
	var distance := _player.global_position.distance_to(reveal_world_point)
	var normalized := clampf(
		1.0 - inverse_lerp(full_alpha_distance, safe_fade_distance, distance),
		0.0,
		1.0
	)
	return lerpf(hidden_alpha, shown_alpha, smoothstep(0.0, 1.0, normalized))


func _can_collect_clue() -> bool:
	return (
		not _collected
		and not revealed_clue_id.is_empty()
		and _current_alpha >= clue_collect_alpha_threshold
	)


func _collect_clue() -> void:
	if _collected or revealed_clue_id.is_empty():
		return

	var clue_manager := get_node_or_null("/root/ClueManager")
	if clue_manager != null and not clue_manager.get_clues().has(revealed_clue_id):
		clue_manager.add_clue(revealed_clue_id)

	_collected = true
	_update_collect_hint()


func _update_collect_hint() -> void:
	if collect_hint == null:
		return

	var should_show := _can_collect_clue()
	if should_show and not _hint_active:
		collect_hint.show()
		collect_hint.fade_in()
		_hint_active = true
	elif not should_show and _hint_active:
		collect_hint.fade_out()
		_hint_active = false
