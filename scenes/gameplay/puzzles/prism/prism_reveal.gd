class_name PrismReveal
extends Node2D

enum InteractionMode {
	DRAG,
	CLICK_STEP,
}

@export_group("Chapter")
@export var san_loss_per_turn: int = 5

@export_group("Rotation")
@export_range(0.0, 360.0, 0.1) var target_rotation_deg: float = 0.0:
	set(value):
		target_rotation_deg = wrapf(value, 0.0, 360.0)
		_update_reveal_alpha()
@export var enable_keyboard_rotation: bool = true
@export_range(1.0, 720.0, 1.0, "suffix:deg/s") var turn_speed_deg_per_sec: float = 240.0
@export_range(1.0, 360.0, 1.0, "suffix:deg/s") var keyboard_rotation_speed_deg_per_sec: float = 90.0
@export_range(0.01, 2.0, 0.01, "suffix:deg/px") var drag_rotation_sensitivity_deg_per_px: float = 0.12
@export_enum("Drag", "Click Step") var interaction_mode: int = InteractionMode.DRAG
@export_range(1.0, 180.0, 1.0) var click_step_deg: float = 30.0

@export_group("Reveal")
@export var revealed_texture: Texture2D
@export var revealed_clue_id: String = ""
@export var collect_revealed_clue_with_interact: bool = true
@export var auto_collect_revealed_clue: bool = false
@export_range(0.0, 1.0, 0.01) var clue_collect_alpha_threshold: float = 0.85
@export_range(0.0, 360.0, 0.1) var best_reveal_angle_deg: float = 32.0:
	set(value):
		best_reveal_angle_deg = wrapf(value, 0.0, 360.0)
		_update_reveal_alpha()
@export_range(0.1, 180.0, 0.1) var reveal_tolerance_deg: float = 12.0:
	set(value):
		reveal_tolerance_deg = maxf(value, 0.1)
		_update_reveal_alpha()
@export_range(0.0, 1.0, 0.01) var min_reveal_alpha: float = 0.0:
	set(value):
		min_reveal_alpha = clampf(value, 0.0, 1.0)
		_update_reveal_alpha()
@export_range(0.0, 1.0, 0.01) var max_reveal_alpha: float = 1.0:
	set(value):
		max_reveal_alpha = clampf(value, 0.0, 1.0)
		_update_reveal_alpha()

@export_group("Presentation")
@export var render_viewport_size: Vector2i = Vector2i(320, 320)
@export var prism_mesh_size: Vector3 = Vector3(1.2, 2.2, 0.9)
@export var prism_body_color: Color = Color(0.66, 0.92, 1.0, 0.62)
@export var prism_outline_color: Color = Color(0.92, 0.98, 1.0, 0.14)
@export_range(1.0, 16.0, 0.1) var render_camera_distance: float = 18.0
@export_range(0.01, 0.6, 0.01) var render_topdown_ratio: float = 0.24

@onready var revealed_sprite: Sprite2D = $Composition/RevealedSprite
@onready var prism_sprite: Sprite2D = $Composition/PrismSprite
@onready var prism_hit_area: Area2D = $Composition/PrismHitArea
@onready var prism_hit_collision: CollisionShape2D = $Composition/PrismHitArea/CollisionShape2D
@onready var collect_hint: Panel = get_node_or_null("Hint")
@onready var viewport: SubViewport = $SubViewport
@onready var camera: Camera3D = $SubViewport/PrismRoot/Camera3D
@onready var presentation_pivot: Node3D = $SubViewport/PrismRoot/PresentationPivot
@onready var spin_pivot: Node3D = $SubViewport/PrismRoot/PresentationPivot/SpinPivot
@onready var prism_mesh: MeshInstance3D = $SubViewport/PrismRoot/PresentationPivot/SpinPivot/PrismMesh
@onready var shell_mesh: MeshInstance3D = $SubViewport/PrismRoot/PresentationPivot/SpinPivot/PrismShell
@onready var key_light: DirectionalLight3D = $SubViewport/PrismRoot/KeyLight
@onready var fill_light: DirectionalLight3D = $SubViewport/PrismRoot/FillLight

var _dragging: bool = false
var _display_rotation_deg: float = 0.0
var _revealed_clue_collected: bool = false
var _player_in_collect_range: bool = false
var _last_reveal_alpha: float = 0.0
var _collect_hint_active: bool = false


func _ready() -> void:
	_configure_viewport()
	_configure_prism_render()
	prism_sprite.texture = viewport.get_texture()
	prism_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if revealed_texture != null:
		revealed_sprite.texture = revealed_texture
	if collect_hint != null:
		collect_hint.hide()
	_display_rotation_deg = target_rotation_deg
	_apply_prism_rotation(_display_rotation_deg)
	_update_reveal_alpha()


func _process(delta: float) -> void:
	_update_visual_rotation(delta)

	if not enable_keyboard_rotation:
		return

	var rotate_axis := Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	if is_zero_approx(rotate_axis):
		return

	target_rotation_deg += rotate_axis * keyboard_rotation_speed_deg_per_sec * delta


func set_prism_rotation(value_deg: float, snap: bool = false) -> void:
	target_rotation_deg = value_deg
	if snap:
		_display_rotation_deg = target_rotation_deg
		_apply_prism_rotation(_display_rotation_deg)
		_update_reveal_alpha()


func rotate_prism(delta_deg: float) -> void:
	target_rotation_deg += delta_deg


func set_revealed_texture(texture: Texture2D) -> void:
	revealed_texture = texture
	revealed_sprite.texture = texture


func _configure_viewport() -> void:
	viewport.size = render_viewport_size
	viewport.transparent_bg = true
	viewport.handle_input_locally = false
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func _configure_prism_render() -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.0
	var focus_point := Vector3(0.0, prism_mesh_size.y * 0.16, 0.0)
	# Match the game's 2.5D read direction as closely as a standard orthographic camera allows:
	# +X reads toward lower-left, +Z reads right, +Y reads up.
	var horizontal_direction := Vector3(-0.99694, 0.0, -0.06760).normalized()
	var view_direction := Vector3(
		horizontal_direction.x,
		-render_topdown_ratio,
		horizontal_direction.z
	).normalized()
	camera.position = focus_point - (view_direction * render_camera_distance)
	camera.look_at(focus_point, Vector3.UP)

	presentation_pivot.rotation_degrees = Vector3.ZERO

	key_light.rotation_degrees = Vector3(-42.0, -30.0, 0.0)
	key_light.light_energy = 1.5
	fill_light.rotation_degrees = Vector3(25.0, 145.0, 0.0)
	fill_light.light_energy = 0.85

	var core_mesh := BoxMesh.new()
	core_mesh.size = prism_mesh_size
	prism_mesh.mesh = core_mesh

	var shell := BoxMesh.new()
	shell.size = prism_mesh_size + Vector3.ONE * 0.08
	shell_mesh.mesh = shell

	var core_material := StandardMaterial3D.new()
	core_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_material.albedo_color = prism_body_color
	core_material.roughness = 0.08
	core_material.metallic = 0.1
	core_material.emission_enabled = true
	core_material.emission = prism_body_color * 0.2
	core_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	prism_mesh.material_override = core_material

	var shell_material := StandardMaterial3D.new()
	shell_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shell_material.albedo_color = prism_outline_color
	shell_material.roughness = 0.0
	shell_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shell_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	shell_mesh.material_override = shell_material


func _update_visual_rotation(delta: float) -> void:
	var distance := _signed_angular_delta_deg(_display_rotation_deg, target_rotation_deg)
	if is_zero_approx(distance):
		return

	var max_step := turn_speed_deg_per_sec * delta
	if absf(distance) <= max_step:
		_display_rotation_deg = target_rotation_deg
	else:
		_display_rotation_deg = wrapf(_display_rotation_deg + signf(distance) * max_step, 0.0, 360.0)

	_apply_prism_rotation(_display_rotation_deg)
	_update_reveal_alpha()


func _apply_prism_rotation(rotation_deg: float) -> void:
	if not is_instance_valid(spin_pivot):
		return
	spin_pivot.rotation_degrees.y = rotation_deg


func _update_reveal_alpha() -> void:
	if not is_instance_valid(revealed_sprite):
		return

	var distance := _angular_distance_deg(_display_rotation_deg, best_reveal_angle_deg)
	var normalized := clampf(1.0 - (distance / reveal_tolerance_deg), 0.0, 1.0)
	var eased := smoothstep(0.0, 1.0, normalized)
	var alpha := lerpf(min_reveal_alpha, max_reveal_alpha, eased)

	var color := revealed_sprite.modulate
	color.a = alpha
	revealed_sprite.modulate = color
	revealed_sprite.visible = alpha > 0.01
	_last_reveal_alpha = alpha
	_update_collect_hint()
	if auto_collect_revealed_clue:
		_try_collect_revealed_clue()


func _angular_distance_deg(a: float, b: float) -> float:
	return absf(wrapf(a - b + 180.0, 0.0, 360.0) - 180.0)


func _signed_angular_delta_deg(from_deg: float, to_deg: float) -> float:
	return wrapf(to_deg - from_deg + 180.0, 0.0, 360.0) - 180.0


func _try_collect_revealed_clue() -> void:
	if _revealed_clue_collected or not _can_collect_revealed_clue():
		return

	var clue_manager := get_node_or_null("/root/ClueManager")
	if clue_manager == null:
		return
	if clue_manager.get_clues().has(revealed_clue_id):
		_revealed_clue_collected = true
		_update_collect_hint()
		return

	clue_manager.add_clue(revealed_clue_id)
	_revealed_clue_collected = true
	_update_collect_hint()


func _can_collect_revealed_clue() -> bool:
	return not revealed_clue_id.is_empty() and _last_reveal_alpha >= clue_collect_alpha_threshold


func _update_collect_hint() -> void:
	if collect_hint == null:
		return
	var should_show := (
		collect_revealed_clue_with_interact
		and _player_in_collect_range
		and not _revealed_clue_collected
		and _can_collect_revealed_clue()
	)
	if should_show and not _collect_hint_active:
		collect_hint.show()
		collect_hint.fade_in()
		_collect_hint_active = true
	elif not should_show and _collect_hint_active:
		collect_hint.fade_out()
		_collect_hint_active = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("互动"):
		if collect_revealed_clue_with_interact and _player_in_collect_range and _can_collect_revealed_clue():
			_try_collect_revealed_clue()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not _is_pointer_over_prism():
				return
			match interaction_mode:
				InteractionMode.DRAG:
					_begin_drag()
				InteractionMode.CLICK_STEP:
					_apply_click_step()
			get_viewport().set_input_as_handled()
			return

		_dragging = false
		return

	if event is InputEventMouseMotion and _dragging and interaction_mode == InteractionMode.DRAG:
		target_rotation_deg += event.relative.x * drag_rotation_sensitivity_deg_per_px
		get_viewport().set_input_as_handled()


func _begin_drag() -> void:
	_dragging = true
	_reduce_san_for_turn()


func _apply_click_step() -> void:
	target_rotation_deg += click_step_deg
	_reduce_san_for_turn()


func _reduce_san_for_turn() -> void:
	if Engine.is_editor_hint():
		return
	var chapter := get_node_or_null("/root/Chapter")
	if chapter == null:
		return
	chapter.san -= san_loss_per_turn


func _is_pointer_over_prism() -> bool:
	if not is_instance_valid(prism_hit_area) or not is_instance_valid(prism_hit_collision):
		return false

	var shape := prism_hit_collision.shape
	if shape is RectangleShape2D:
		var local_point := prism_hit_area.to_local(get_global_mouse_position())
		var rect_shape := shape as RectangleShape2D
		var half_size := rect_shape.size * 0.5
		return Rect2(-half_size, rect_shape.size).has_point(local_point)

	return false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_dragging = false


func _on_collect_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		_player_in_collect_range = true
		_update_collect_hint()


func _on_collect_detection_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		_player_in_collect_range = false
		_update_collect_hint()
