extends Room

func _ready() -> void:
	super._ready()
	next_scene = "start"


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		Dialogic.start("test")
