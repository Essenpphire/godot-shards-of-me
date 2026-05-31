class_name MirrorWordLock
extends Node2D

signal mirror_locked

@export_group("Player Tracking")
@export var tracked_player_path: NodePath
@export_range(-4096.0, 4096.0, 1.0) var lock_player_world_x: float = 0.0
@export_range(1.0, 512.0, 1.0) var lock_window_width: float = 36.0
@export_range(0.0, 2048.0, 1.0, "suffix:px") var reflection_move_range_px: float = 180.0
@export var find_player_in_group: bool = true

@export_group("Mirror Layout")
@export var mirror_view_size: Vector2 = Vector2(260.0, 180.0)
@export var outside_view_size: Vector2 = Vector2(116.0, 180.0)
@export_range(0.0, 128.0, 1.0) var mirror_outside_gap: float = 0.0
@export_range(4.0, 40.0, 1.0) var mirror_frame_thickness: float = 12.0

@export_group("Content")
@export var mirror_texture: Texture2D
@export var outside_texture: Texture2D
@export var fallback_texture_size: Vector2i = Vector2i(1024, 256)
@export_range(0.0, 1024.0, 1.0) var source_region_y: float = 24.0
@export_range(0.0, 1024.0, 1.0) var aligned_mirror_source_x: float = 392.0
@export_range(0.0, 1024.0, 1.0) var outside_source_origin_x: float = 260.0
@export var auto_align_same_origin_images: bool = true
@export var fallback_text: String = "SPEAK\nTHE NAME"

@export_group("State")
@export var starts_already_locked: bool = false

@onready var reflection_sprite: Sprite2D = $Composition/ReflectionSprite
@onready var outside_slice_sprite: Sprite2D = $Composition/OutsideSliceSprite
@onready var mirror_back: Polygon2D = $Composition/MirrorBack
@onready var mirror_shadow: Polygon2D = $Composition/MirrorShadow
@onready var outer_shadow: Polygon2D = $Composition/OutsideShadow
@onready var frame_top: Polygon2D = $Composition/FrameTop
@onready var frame_bottom: Polygon2D = $Composition/FrameBottom
@onready var frame_left: Polygon2D = $Composition/FrameLeft
@onready var frame_right: Polygon2D = $Composition/FrameRight
@onready var seam_line: Line2D = $Composition/SeamLine
@onready var outside_frame: Polygon2D = $Composition/OutsideFrame
@onready var source_viewport: SubViewport = $SourceViewport
@onready var source_back: ColorRect = $SourceViewport/WallCanvas/Back
@onready var source_label: Label = $SourceViewport/WallCanvas/WordLabel
@onready var source_band_top: ColorRect = $SourceViewport/WallCanvas/BandTop
@onready var source_band_bottom: ColorRect = $SourceViewport/WallCanvas/BandBottom

var _player: Node2D
var _locked: bool = false
var _resolved_reflection_texture: Texture2D
var _resolved_outside_texture: Texture2D


func _ready() -> void:
	_locked = starts_already_locked
	_player = _resolve_player()
	_configure_source_texture()
	_configure_geometry()
	_update_mirror_from_player(true)


func _physics_process(_delta: float) -> void:
	if _locked:
		return
	if not is_instance_valid(_player):
		_player = _resolve_player()
	if not is_instance_valid(_player):
		return
	_update_mirror_from_player(false)


func reset_lock() -> void:
	_locked = false
	_update_mirror_from_player(true)


func force_lock() -> void:
	if _locked:
		return
	_locked = true
	_apply_reflection_x(_get_aligned_reflection_x())
	mirror_locked.emit()


func is_locked() -> bool:
	return _locked


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

	_resolved_reflection_texture = mirror_texture
	if _resolved_reflection_texture == null:
		_resolved_reflection_texture = reflection_sprite.texture
	if _resolved_reflection_texture == null:
		_resolved_reflection_texture = source_viewport.get_texture()

	_resolved_outside_texture = outside_texture
	if _resolved_outside_texture == null:
		_resolved_outside_texture = outside_slice_sprite.texture
	if _resolved_outside_texture == null:
		_resolved_outside_texture = _resolved_reflection_texture
	reflection_sprite.texture = _resolved_reflection_texture
	outside_slice_sprite.texture = _resolved_outside_texture

	reflection_sprite.region_enabled = true
	reflection_sprite.centered = false
	outside_slice_sprite.region_enabled = true
	outside_slice_sprite.centered = false


func _configure_geometry() -> void:
	var mirror_rect := Rect2(Vector2.ZERO, mirror_view_size)
	var outside_rect := Rect2(Vector2(mirror_view_size.x + mirror_outside_gap, 0.0), outside_view_size)

	reflection_sprite.position = mirror_rect.position
	outside_slice_sprite.position = outside_rect.position

	mirror_back.polygon = PackedVector2Array([
		mirror_rect.position,
		Vector2(mirror_rect.end.x, mirror_rect.position.y),
		mirror_rect.end,
		Vector2(mirror_rect.position.x, mirror_rect.end.y)
	])

	mirror_shadow.polygon = PackedVector2Array([
		Vector2(14.0, mirror_rect.end.y + 10.0),
		Vector2(mirror_rect.end.x + 22.0, mirror_rect.end.y + 6.0),
		Vector2(mirror_rect.end.x + 40.0, mirror_rect.end.y + 26.0),
		Vector2(28.0, mirror_rect.end.y + 36.0)
	])

	outer_shadow.polygon = PackedVector2Array([
		Vector2(outside_rect.position.x + 8.0, outside_rect.end.y + 8.0),
		Vector2(outside_rect.end.x + 16.0, outside_rect.end.y + 4.0),
		Vector2(outside_rect.end.x + 28.0, outside_rect.end.y + 18.0),
		Vector2(outside_rect.position.x + 18.0, outside_rect.end.y + 24.0)
	])

	frame_top.polygon = _rect_polygon(Rect2(-mirror_frame_thickness, -mirror_frame_thickness, mirror_view_size.x + mirror_frame_thickness * 2.0, mirror_frame_thickness))
	frame_bottom.polygon = _rect_polygon(Rect2(-mirror_frame_thickness, mirror_view_size.y, mirror_view_size.x + mirror_frame_thickness * 2.0, mirror_frame_thickness))
	frame_left.polygon = _rect_polygon(Rect2(-mirror_frame_thickness, 0.0, mirror_frame_thickness, mirror_view_size.y))
	frame_right.polygon = _rect_polygon(Rect2(mirror_view_size.x, 0.0, mirror_frame_thickness, mirror_view_size.y))
	outside_frame.polygon = _rect_polygon(Rect2(outside_rect.position.x, outside_rect.position.y, outside_rect.size.x, outside_rect.size.y))
	seam_line.points = PackedVector2Array([
		Vector2(mirror_view_size.x + mirror_outside_gap * 0.5, 0.0),
		Vector2(mirror_view_size.x + mirror_outside_gap * 0.5, maxf(mirror_view_size.y, outside_view_size.y))
	])


func _rect_polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y)
	])


func _update_mirror_from_player(force_refresh: bool) -> void:
	if _locked and not force_refresh:
		_apply_reflection_x(_get_aligned_reflection_x())
		return

	var reflection_x := _get_aligned_reflection_x()
	if is_instance_valid(_player):
		var tracking_bounds := _get_tracking_bounds_x()
		var tracked_player_x := clampf(_player.global_position.x, tracking_bounds.x, tracking_bounds.y)
		var aligned_player_x := clampf(lock_player_world_x, tracking_bounds.x, tracking_bounds.y)
		var tracked_ratio := inverse_lerp(tracking_bounds.x, tracking_bounds.y, tracked_player_x)
		var aligned_ratio := inverse_lerp(tracking_bounds.x, tracking_bounds.y, aligned_player_x)
		var offset_units := tracked_player_x - aligned_player_x
		reflection_x = _get_aligned_reflection_x() + (tracked_ratio - aligned_ratio) * _get_effective_reflection_travel()

		if absf(offset_units) <= lock_window_width * 0.5:
			reflection_x = _get_aligned_reflection_x()
			if not _locked:
				_locked = true
				mirror_locked.emit()

	if force_refresh or not _locked:
		_apply_reflection_x(reflection_x)
	else:
		_apply_reflection_x(_get_aligned_reflection_x())


func _apply_reflection_x(reflection_x: float) -> void:
	var reflection_region_x := _get_source_x_for_local_x(
		reflection_x,
		0.0,
		mirror_view_size.x,
		_get_texture_width(reflection_sprite.texture)
	)
	var outside_region_x := _get_source_x_for_local_x(
		_get_aligned_reflection_x(),
		_get_effective_outside_source_offset_x(),
		outside_view_size.x,
		_get_texture_width(outside_slice_sprite.texture)
	)

	reflection_sprite.region_rect = Rect2(reflection_region_x, source_region_y, mirror_view_size.x, mirror_view_size.y)
	outside_slice_sprite.region_rect = Rect2(outside_region_x, source_region_y, outside_view_size.x, outside_view_size.y)


func _get_aligned_reflection_x() -> float:
	if auto_align_same_origin_images and _textures_share_same_width():
		var texture_width := _get_texture_width(reflection_sprite.texture)
		var seam_source_x := texture_width - (_get_effective_outside_source_offset_x() + outside_view_size.x)
		var max_reflection_x := maxf(0.0, texture_width - mirror_view_size.x)
		return clampf(seam_source_x, 0.0, max_reflection_x)
	return aligned_mirror_source_x


func _get_tracking_bounds_x() -> Vector2:
	var left_world_x := to_global(Vector2.ZERO).x
	var right_world_x := to_global(Vector2(mirror_view_size.x, 0.0)).x
	return Vector2(minf(left_world_x, right_world_x), maxf(left_world_x, right_world_x))


func _get_source_x_for_local_x(source_origin_x: float, local_x: float, region_width: float, texture_width: float) -> float:
	var max_region_x := maxf(0.0, texture_width - region_width)
	return clampf(source_origin_x + local_x, 0.0, max_region_x)


func _get_texture_width(texture: Texture2D) -> float:
	if texture == null:
		return fallback_texture_size.x
	return texture.get_size().x


func _get_effective_reflection_travel() -> float:
	if auto_align_same_origin_images and _textures_share_same_width():
		return _get_aligned_reflection_x()
	return reflection_move_range_px


func _get_effective_outside_source_offset_x() -> float:
	if auto_align_same_origin_images and _textures_share_same_width():
		return _get_outside_layout_offset_x()
	return outside_source_origin_x


func _textures_share_same_width() -> bool:
	if reflection_sprite.texture == null or outside_slice_sprite.texture == null:
		return false
	return is_equal_approx(
		_get_texture_width(reflection_sprite.texture),
		_get_texture_width(outside_slice_sprite.texture)
	)


func _get_outside_layout_offset_x() -> float:
	return outside_slice_sprite.position.x - reflection_sprite.position.x
