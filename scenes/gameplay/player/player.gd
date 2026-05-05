extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -800.0

@onready var Sprite : AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("Player")

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		pass

	var dir := Input.get_vector("向左移动", "向右移动", "向内移动", "向外移动")
	if dir:
		Sprite.flip_h = true if dir.x < 0 else false
		Sprite.play("move")
		velocity = dir * SPEED
	else:
		Sprite.play("idle")
		velocity = velocity.move_toward(Vector2.ZERO, SPEED)

	move_and_slide()
