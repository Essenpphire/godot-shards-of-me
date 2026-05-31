class_name AuthorPalette
extends VBoxContainer

signal tool_selected(mode: int, payload: Dictionary)
signal select_puzzle_requested

const MODE_SELECT: int = 0
const MODE_PLACE_SOURCE: int = 1
const MODE_PLACE_EXIT: int = 2
const MODE_PLACE_PIECE: int = 3
const MODE_PLACE_BLOCK: int = 4
const MODE_EDIT_ALLOWED_CELLS: int = 5

var _tool_buttons: Array[Button] = []
var _active_key: String = ""


func _ready() -> void:
	_build_palette()


func set_active_tool(mode: int, payload: Dictionary = {}) -> void:
	_active_key = _tool_key(mode, payload)
	for button in _tool_buttons:
		button.button_pressed = button.get_meta("tool_key", "") == _active_key


func _build_palette() -> void:
	_clear_children()
	_tool_buttons.clear()

	_add_section("选择")
	_add_action_button("谜题设置", func() -> void: select_puzzle_requested.emit())
	_add_tool_button("选择 / 移动", MODE_SELECT)
	_add_tool_button("编辑可移动格", MODE_EDIT_ALLOWED_CELLS)

	_add_section("端口")
	_add_tool_button("白色光源", MODE_PLACE_SOURCE, {"color_mask": LightPuzzleConstants.COLOR_WHITE})
	_add_tool_button("红色出口", MODE_PLACE_EXIT, {"color_mask": LightPuzzleConstants.COLOR_RED})
	_add_tool_button("绿色出口", MODE_PLACE_EXIT, {"color_mask": LightPuzzleConstants.COLOR_GREEN})
	_add_tool_button("蓝色出口", MODE_PLACE_EXIT, {"color_mask": LightPuzzleConstants.COLOR_BLUE})

	_add_section("光学元件")
	_add_tool_button("斜杠镜 /", MODE_PLACE_PIECE, {"piece_type": LightPuzzleConstants.PieceType.MIRROR_SLASH})
	_add_tool_button("反斜杠镜 \\", MODE_PLACE_PIECE, {"piece_type": LightPuzzleConstants.PieceType.MIRROR_BACKSLASH})
	_add_tool_button("水平平面镜", MODE_PLACE_PIECE, {"piece_type": LightPuzzleConstants.PieceType.PLANE_MIRROR_HORIZONTAL})
	_add_tool_button("垂直平面镜", MODE_PLACE_PIECE, {"piece_type": LightPuzzleConstants.PieceType.PLANE_MIRROR_VERTICAL})
	_add_tool_button("+45 棱镜", MODE_PLACE_PIECE, {"piece_type": LightPuzzleConstants.PieceType.PRISM_PLUS_45})
	_add_tool_button("-45 棱镜", MODE_PLACE_PIECE, {"piece_type": LightPuzzleConstants.PieceType.PRISM_MINUS_45})

	_add_section("滤镜")
	_add_tool_button("红色滤镜", MODE_PLACE_PIECE, {"piece_type": LightPuzzleConstants.PieceType.FILTER_RED})
	_add_tool_button("绿色滤镜", MODE_PLACE_PIECE, {"piece_type": LightPuzzleConstants.PieceType.FILTER_GREEN})
	_add_tool_button("蓝色滤镜", MODE_PLACE_PIECE, {"piece_type": LightPuzzleConstants.PieceType.FILTER_BLUE})
	_add_tool_button("黄色滤镜", MODE_PLACE_PIECE, {"piece_type": LightPuzzleConstants.PieceType.FILTER_YELLOW})
	_add_tool_button("青色滤镜", MODE_PLACE_PIECE, {"piece_type": LightPuzzleConstants.PieceType.FILTER_CYAN})
	_add_tool_button("品红滤镜", MODE_PLACE_PIECE, {"piece_type": LightPuzzleConstants.PieceType.FILTER_MAGENTA})

	_add_section("障碍")
	_add_tool_button("玻璃障碍", MODE_PLACE_BLOCK, {"piece_type": LightPuzzleConstants.PieceType.GLASS_BLOCK})
	_add_tool_button("不透明障碍", MODE_PLACE_BLOCK, {"piece_type": LightPuzzleConstants.PieceType.OPAQUE_BLOCK})

	set_active_tool(MODE_SELECT)


func _add_section(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.8, 0.86, 0.94))
	add_child(label)


func _add_action_button(text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(callback)
	add_child(button)


func _add_tool_button(text: String, mode: int, payload: Dictionary = {}) -> void:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_ALL
	button.set_meta("tool_key", _tool_key(mode, payload))
	button.pressed.connect(func() -> void:
		tool_selected.emit(mode, payload.duplicate())
	)
	_tool_buttons.append(button)
	add_child(button)


func _tool_key(mode: int, payload: Dictionary = {}) -> String:
	var key := str(mode)
	var keys := payload.keys()
	keys.sort()
	for payload_key in keys:
		key += "|%s=%s" % [str(payload_key), str(payload[payload_key])]
	return key


func _clear_children() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
