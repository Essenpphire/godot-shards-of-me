extends Control
@onready var atk = %ATK

func calc():
	var s : int = 0
	for i in get_children():
		s += i.get_ATK()
		
	atk.text = "ATK: " + str(s)
