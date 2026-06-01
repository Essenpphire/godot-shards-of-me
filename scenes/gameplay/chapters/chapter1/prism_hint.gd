extends Area2D

func _ready() -> void:
	if Dialogic.VAR.get_variable("chapter1.read_prism"):
		queue_free()
	connect("body_entered", _on_body_entered)
	Dialogic.signal_event.connect(func(argument):
		if argument == "show_prism":
			Dialogic.start("chapter1", "find_prism")
	)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		Dialogic.start("chapter1", "find_prism")
		queue_free()
