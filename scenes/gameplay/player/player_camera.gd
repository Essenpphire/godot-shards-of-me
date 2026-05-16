extends Camera2D

@export var shake_str : float = 0.0 # 相机抖动强度
@export var shake_recover : float = 15.0 # 相机抖动回复强度
const ZOOM_DELTA = Vector2(0.01, 0.01)

func _ready() -> void:
	#zoom = Vector2.ONE
	pass
#func _physics_process(delta: float) -> void:
	#if Input.is_key_pressed(KEY_MINUS):
		#zoom -= ZOOM_DELTA
	#elif Input.is_key_pressed(KEY_EQUAL):
		#zoom += ZOOM_DELTA
	#zoom = zoom.clamp(1 * Vector2.ONE, 2 * Vector2.ONE)
	
