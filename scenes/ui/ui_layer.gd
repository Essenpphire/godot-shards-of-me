extends CanvasLayer

@onready var item_layer : CanvasLayer = $ItemLayer
@onready var san_label : Label = $San

func _ready() -> void:
	item_layer.hide()
	show()
	san_label.text = "SAN:" + str(Chapter.san)
	EventBus.san_update.connect(func(san): 
		san_label.text = "SAN:" + str(san)	
	)
	
