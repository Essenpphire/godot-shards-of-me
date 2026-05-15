extends Prop

## override 开门动画
func handle_interact():
	var tween = create_tween()
	tween.set_parallel(true)  # 同时执行
	tween.tween_property(sprite, "position:x", -17, 0.5)
	tween.tween_property(sprite, "rotation_degrees", -90, 0.5)
	tween.tween_property(sprite, "skew", deg_to_rad(89.9), 0.5)
	tween.set_parallel(false)
	tween.tween_callback(func(): 
		sprite.hide()
		collision.disabled = true
	)

func _ready() -> void:
	can_interact = false
	oneshot = true
	sprite.position = Vector2.ZERO
	sprite.rotation_degrees = -30
	sprite.skew = deg_to_rad(30.0)
