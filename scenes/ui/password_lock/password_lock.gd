extends Control

const PASSWORD := "795"
const CODE_LENGTH := 3

@onready var digit_labels: Array[Label] = [
	$LockBackground/Digits/Digit0/Value,
	$LockBackground/Digits/Digit1/Value,
	$LockBackground/Digits/Digit2/Value,
]

var digits := [0, 0, 0]

func _ready() -> void:
	_update_display()


func _update_display() -> void:
	for i in CODE_LENGTH:
		digit_labels[i].text = str(digits[i])


func _check_code() -> void:
	var current_code := ""
	for i in CODE_LENGTH:
		current_code += str(digits[i])
	if current_code == PASSWORD:
		Dialogic.start("chapter0", "code_succ")
		# hide self
		queue_free()
	else:
		# status_label.text = "密码错误"
		Dialogic.start("chapter0", "code_error")
		hide()
		pass


func _on_ok_pressed() -> void:
	_check_code()


func _on_arrow_pressed(index: int, delta: int) -> void:
	digits[index] = wrapi(digits[index] + delta, 0, 10)
	_update_display()
