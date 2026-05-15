extends PanelContainer

@onready var content_root: Control = $Messages
@onready var clue_image: TextureRect = $Messages/ClueImage
@onready var title_label: Label = $Messages/Title
@onready var desc_label: Label = $Messages/Description

func set_clue(clue:Dictionary)-> void:
	content_root.visible=true
	
	clue_image.texture=clue.get("image",null)
	title_label.text = clue.get("title", "")
	desc_label.text = clue.get("description", "")

func set_empty() -> void:
	content_root.visible = false

	clue_image.texture = null
	title_label.text = ""
	desc_label.text = ""
