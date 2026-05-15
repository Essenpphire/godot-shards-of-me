extends TextureRect

@export_enum("NONE:0","HEAD:1","BODY:2","LEG:3", "ACTIVE:4") var slot_type : int = 0
@export var ATK = 0:
	set(val):
		ATK = val
		%debug.text = str(ATK)
		
		if get_parent() is PassiveSlot:
			get_parent().get_parent().calc()

@onready var prop : Dictionary = {"TEXTURE": texture, "ATK" : ATK, "SLOT_TYPE": slot_type}:
	set(val):
		prop = val
		texture = prop["TEXTURE"]
		ATK = prop["ATK"]
		slot_type = prop["SLOT_TYPE"]
