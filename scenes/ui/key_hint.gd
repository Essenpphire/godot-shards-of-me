extends Panel

func fade_in(time : float = 0.3):
	var tween = get_tree().create_tween()
	tween.tween_property(self, "modulate:a", 1.0, time)
	
func fade_out(time : float = 0.3):
	var tween = get_tree().create_tween()
	tween.tween_property(self, "modulate:a", 0.0, time)

func _ready() -> void:
	modulate.a = 0.0

func _process(delta: float) -> void:
	pass
