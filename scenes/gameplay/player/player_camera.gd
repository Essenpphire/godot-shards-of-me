extends Camera2D

@export var shake_str : float = 0.0 # 相机抖动强度
@export var shake_recover : float = 15.0 # 相机抖动回复强度
@export var startup_zoom: Vector2 = Vector2(1.2, 1.2)
@export var make_current_on_enter: bool = true
const ZOOM_DELTA = Vector2(0.01, 0.01)

func _enter_tree() -> void:
	_apply_startup_state()


func _ready() -> void:
	_apply_startup_state()
	reset_physics_interpolation()


func _apply_startup_state() -> void:
	zoom = startup_zoom
	offset = Vector2.ZERO
	if make_current_on_enter:
		make_current()


#func _physics_process(delta: float) -> void:
	#if Input.is_key_pressed(KEY_MINUS):
		#zoom -= ZOOM_DELTA
	#elif Input.is_key_pressed(KEY_EQUAL):
		#zoom += ZOOM_DELTA
	#zoom = zoom.clamp(1 * Vector2.ONE, 2 * Vector2.ONE)
	
