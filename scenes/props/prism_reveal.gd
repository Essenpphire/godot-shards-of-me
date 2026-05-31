class_name PrismReveal
extends Node2D

@export_group("Chapter")
@export var san_loss_per_rotation: int = 5

@export_group("Rotation")
@export_range(0.0, 360.0, 0.1, "radians_as_degrees") var prism_rotation_deg: float = 0.0:
	set(value):
		prism_rotation_deg = wrapf(value, 0.0, 360.0)
		_apply_prism_rotation()
		_update_reveal_alpha()
@export var allow_debug_input: bool = true
@export_range(1.0, 360.0, 1.0, "suffix:deg/s") var keyboard_rotate_speed: float = 90.0
@export_range(0.01, 2.0, 0.01, "suffix:deg/px") var drag_rotate_sensitivity: float = 0.12

@export_group("Reveal")
@export var revealed_texture: Texture2D
@export_range(0.0, 360.0, 0.1, "radians_as_degrees") var reveal_angle_deg: float = 32.0:
	set(value):
		reveal_angle_deg = wrapf(value, 0.0, 360.0)
		_update_reveal_alpha()
@export_range(0.1, 180.0, 0.1, "radians_as_degrees") var reveal_window_deg: float = 12.0:
	set(value):
		reveal_window_deg = maxf(value, 0.1)
		_update_reveal_alpha()
@export_range(0.0, 1.0, 0.01) var hidden_alpha: float = 0.0:
	set(value):
		hidden_alpha = clampf(value, 0.0, 1.0)
		_update_reveal_alpha()
@export_range(0.0, 1.0, 0.01) var shown_alpha: float = 1.0:
	set(value):
		shown_alpha = clampf(value, 0.0, 1.0)
		_update_reveal_alpha()

@export_group("Presentation")
@export var viewport_size: Vector2i = Vector2i(320, 320)
@export var prism_size: Vector3 = Vector3(1.2, 2.2, 0.9)
@export var prism_color: Color = Color(0.66, 0.92, 1.0, 0.62)
@export var prism_outline_color: Color = Color(0.92, 0.98, 1.0, 0.14)
@export_range(1.0, 16.0, 0.1) var camera_distance: float = 18.0
@export_range(0.01, 0.6, 0.01) var camera_topdown_ratio: float = 0.24

@onready var revealed_sprite: Sprite2D = $Composition/RevealedSprite
@onready var prism_sprite: Sprite2D = $Composition/PrismSprite
@onready var viewport: SubViewport = $SubViewport
@onready var camera: Camera3D = $SubViewport/PrismRoot/Camera3D
@onready var presentation_pivot: Node3D = $SubViewport/PrismRoot/PresentationPivot
@onready var spin_pivot: Node3D = $SubViewport/PrismRoot/PresentationPivot/SpinPivot
@onready var prism_mesh: MeshInstance3D = $SubViewport/PrismRoot/PresentationPivot/SpinPivot/PrismMesh
@onready var shell_mesh: MeshInstance3D = $SubViewport/PrismRoot/PresentationPivot/SpinPivot/PrismShell
@onready var key_light: DirectionalLight3D = $SubViewport/PrismRoot/KeyLight
@onready var fill_light: DirectionalLight3D = $SubViewport/PrismRoot/FillLight

var _dragging: bool = false


func _ready() -> void:
	_configure_viewport()
	_configure_prism_render()
	prism_sprite.texture = viewport.get_texture()
	prism_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if revealed_texture != null:
		revealed_sprite.texture = revealed_texture
	_apply_prism_rotation()
	_update_reveal_alpha()


func _process(delta: float) -> void:
	if not allow_debug_input:
		return

	var rotate_axis := Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	if is_zero_approx(rotate_axis):
		return

	prism_rotation_deg += rotate_axis * keyboard_rotate_speed * delta


func set_prism_rotation(value_deg: float) -> void:
	prism_rotation_deg = value_deg


func rotate_prism(delta_deg: float) -> void:
	prism_rotation_deg += delta_deg


func set_revealed_texture(texture: Texture2D) -> void:
	revealed_texture = texture
	revealed_sprite.texture = texture


func _configure_viewport() -> void:
	viewport.size = viewport_size
	viewport.transparent_bg = true
	viewport.handle_input_locally = false
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func _configure_prism_render() -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.0
	var focus_point := Vector3(0.0, prism_size.y * 0.16, 0.0)
	# Match the game's 2.5D read direction as closely as a standard orthographic camera allows:
	# +X reads toward lower-left, +Z reads right, +Y reads up.
	var horizontal_direction := Vector3(-0.99694, 0.0, -0.06760).normalized()
	var view_direction := Vector3(
		horizontal_direction.x,
		-camera_topdown_ratio,
		horizontal_direction.z
	).normalized()
	camera.position = focus_point - (view_direction * camera_distance)
	camera.look_at(focus_point, Vector3.UP)

	presentation_pivot.rotation_degrees = Vector3.ZERO

	key_light.rotation_degrees = Vector3(-42.0, -30.0, 0.0)
	key_light.light_energy = 1.5
	fill_light.rotation_degrees = Vector3(25.0, 145.0, 0.0)
	fill_light.light_energy = 0.85

	var core_mesh := BoxMesh.new()
	core_mesh.size = prism_size
	prism_mesh.mesh = core_mesh

	var shell := BoxMesh.new()
	shell.size = prism_size + Vector3.ONE * 0.08
	shell_mesh.mesh = shell

	var core_material := StandardMaterial3D.new()
	core_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_material.albedo_color = prism_color
	core_material.roughness = 0.08
	core_material.metallic = 0.1
	core_material.emission_enabled = true
	core_material.emission = prism_color * 0.2
	core_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	prism_mesh.material_override = core_material

	var shell_material := StandardMaterial3D.new()
	shell_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shell_material.albedo_color = prism_outline_color
	shell_material.roughness = 0.0
	shell_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shell_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	shell_mesh.material_override = shell_material


func _apply_prism_rotation() -> void:
	if not is_instance_valid(spin_pivot):
		return
	spin_pivot.rotation_degrees.y = prism_rotation_deg


func _update_reveal_alpha() -> void:
	if not is_instance_valid(revealed_sprite):
		return

	var distance := _angular_distance_deg(prism_rotation_deg, reveal_angle_deg)
	var normalized := clampf(1.0 - (distance / reveal_window_deg), 0.0, 1.0)
	var eased := smoothstep(0.0, 1.0, normalized)
	var alpha := lerpf(hidden_alpha, shown_alpha, eased)

	var color := revealed_sprite.modulate
	color.a = alpha
	revealed_sprite.modulate = color
	revealed_sprite.visible = alpha > 0.01


func _angular_distance_deg(a: float, b: float) -> float:
	return absf(wrapf(a - b + 180.0, 0.0, 360.0) - 180.0)


func _on_prism_hit_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if _dragging:
			Chapter.san -= san_loss_per_rotation # 旋转棱镜降低SAN
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and _dragging:
		prism_rotation_deg += event.relative.x * drag_rotate_sensitivity
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_dragging = false
