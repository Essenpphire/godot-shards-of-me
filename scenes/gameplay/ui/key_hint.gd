extends Panel

func toggle_fade(time : float = 0.3):
	var tween = get_tree().create_tween()
	if modulate.a != 1.0:
		tween.tween_property(self, "modulate:a", 1.0, time)
	else:
		tween.tween_property(self, "modulate:a", 0.0, time)

func _ready() -> void:
	modulate.a = 0.0

func _process(delta: float) -> void:
	pass
