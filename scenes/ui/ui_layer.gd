extends CanvasLayer

@onready var mirror_shattered_layer: Control = $mirror_shattered
@onready var item_layer : CanvasLayer = $ItemLayer
@onready var inventory: Control = $Inventory
@onready var clue_book: Control = $ClueBook
@onready var san_label : Label = $San

func _ready() -> void:
	hide_gameplay_ui()
	show()
	san_label.text = "SAN:" + str(Chapter.san)
	EventBus.san_update.connect(func(san): 
		san_label.text = "SAN:" + str(san)	
	)


func hide_gameplay_ui() -> void:
	mirror_shattered_layer.hide()
	inventory.hide()
	clue_book.hide()
	item_layer.hide()



func show_gameplay_ui() -> void:
	mirror_shattered_layer.show()
	inventory.show()
	#san_label.show()
