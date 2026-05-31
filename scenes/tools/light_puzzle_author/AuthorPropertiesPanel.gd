class_name AuthorPropertiesPanel
extends VBoxContainer

signal property_changed(field: String, value: Variant)
signal action_requested(action: String)

const SELECTION_NONE: int = 0
const SELECTION_PUZZLE: int = 1
const SELECTION_SOURCE: int = 2
const SELECTION_EXIT: int = 3
const SELECTION_PLACEMENT: int = 4

var _is_populating: bool = false


func show_context(selection_kind: int, selection_index: int, puzzle: LightPuzzleData, save_path: String) -> void:
	_is_populating = true
	_clear_children()

	match selection_kind:
		SELECTION_PUZZLE:
			_build_puzzle_fields(puzzle, save_path)
		SELECTION_SOURCE:
			_build_port_fields(_get_port(puzzle, true, selection_index), "光源")
		SELECTION_EXIT:
			_build_port_fields(_get_port(puzzle, false, selection_index), "出口")
		SELECTION_PLACEMENT:
			_build_placement_fields(_get_placement(puzzle, selection_index))
		_:
			_add_header("未选择内容")
			_add_help("使用“选择 / 移动”，或从左侧面板选择一个工具。")

	_is_populating = false


func _build_puzzle_fields(puzzle: LightPuzzleData, save_path: String) -> void:
	_add_header("谜题")
	if puzzle == null:
		_add_help("当前没有载入谜题草稿。")
		return
	_add_string("puzzle_id", "谜题编号", puzzle.puzzle_id)
	_add_string("title", "标题", puzzle.title)
	_add_vector2i("board_size", "棋盘尺寸", puzzle.board_size, Vector2i(1, 1), Vector2i(12, 12))
	_add_int("max_beam_steps", "最大光线步数", puzzle.max_beam_steps, 1, 512)
	_add_multiline("designer_notes", "设计备注", puzzle.designer_notes)
	_add_string("save_path", "保存路径", save_path)


func _build_port_fields(port: LightPortData, title: String) -> void:
	_add_header(title)
	if port == null:
		_add_help("端口数据缺失。")
		return
	_add_string("port_id", "端口编号", port.port_id)
	_add_vector2i("cell", "连接格", port.cell, Vector2i(0, 0), Vector2i(32, 32))
	_add_option("direction", "光线方向", ["东", "东南", "南", "西南", "西", "西北", "北", "东北"], port.direction)
	_add_color_mask("color_mask", "颜色", port.color_mask)
	_add_bool("requires_exact_color", "需要精确颜色", port.requires_exact_color)
	_add_action("delete_selected", "删除端口")


func _build_placement_fields(placement: LightPiecePlacement) -> void:
	_add_header("棋子")
	if placement == null:
		_add_help("棋子放置数据缺失。")
		return

	var piece := placement.piece
	_add_string("placement_id", "放置编号", placement.placement_id)
	_add_vector2i("grid_position", "棋盘位置", placement.grid_position, Vector2i(0, 0), Vector2i(32, 32))
	_add_bool("locked", "锁定放置", placement.locked)
	_add_vector2i("solution_position", "答案位置", placement.solution_position, Vector2i(-1, -1), Vector2i(32, 32))
	_add_allowed_cells_summary(placement.allowed_cells)

	if piece == null:
		_add_help("这个放置项没有棋子资源。")
	else:
		_add_option(
			"piece_type",
			"棋子类型",
			[
				"斜杠镜 /",
				"反斜杠镜 \\",
				"+45 棱镜",
				"-45 棱镜",
				"红色滤镜",
				"绿色滤镜",
				"蓝色滤镜",
				"黄色滤镜",
				"青色滤镜",
				"品红滤镜",
				"玻璃障碍",
				"不透明障碍",
				"水平平面镜",
				"垂直平面镜",
			],
			piece.piece_type
		)
		_add_vector2i("size", "占格尺寸", piece.size, Vector2i(1, 1), Vector2i(4, 4))
		_add_option("move_axis", "移动轴", ["自由移动", "仅横向", "仅纵向", "锁定"], piece.move_axis)
		_add_bool("is_draggable", "可拖动", piece.is_draggable)
		_add_color_mask("filter_mask", "滤镜颜色", piece.filter_mask)

	_add_action("delete_selected", "删除棋子")


func _add_header(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.88, 0.93, 1.0))
	add_child(label)


func _add_help(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)


func _add_row(label_text: String, control: Control) -> void:
	var label := Label.new()
	label.text = label_text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)
	add_child(control)


func _add_string(field: String, label_text: String, value: String) -> void:
	var edit := LineEdit.new()
	edit.text = value
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_submitted.connect(func(new_text: String) -> void:
		_emit_property(field, new_text)
	)
	edit.focus_exited.connect(func() -> void:
		_emit_property(field, edit.text)
	)
	_add_row(label_text, edit)


func _add_multiline(field: String, label_text: String, value: String) -> void:
	var edit := TextEdit.new()
	edit.text = value
	edit.custom_minimum_size = Vector2(0.0, 88.0)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.focus_exited.connect(func() -> void:
		_emit_property(field, edit.text)
	)
	_add_row(label_text, edit)


func _add_int(field: String, label_text: String, value: int, min_value: int, max_value: int) -> void:
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = 1.0
	spin.value = value
	spin.value_changed.connect(func(new_value: float) -> void:
		_emit_property(field, int(new_value))
	)
	_add_row(label_text, spin)


func _add_bool(field: String, label_text: String, value: bool) -> void:
	var check := CheckBox.new()
	check.text = label_text
	check.button_pressed = value
	check.toggled.connect(func(new_value: bool) -> void:
		_emit_property(field, new_value)
	)
	add_child(check)


func _add_vector2i(field: String, label_text: String, value: Vector2i, min_value: Vector2i, max_value: Vector2i) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var x_spin := _create_axis_spin(value.x, min_value.x, max_value.x)
	var y_spin := _create_axis_spin(value.y, min_value.y, max_value.y)
	row.add_child(_axis_label("横"))
	row.add_child(x_spin)
	row.add_child(_axis_label("纵"))
	row.add_child(y_spin)
	x_spin.value_changed.connect(func(_new_value: float) -> void:
		_emit_property(field, Vector2i(int(x_spin.value), int(y_spin.value)))
	)
	y_spin.value_changed.connect(func(_new_value: float) -> void:
		_emit_property(field, Vector2i(int(x_spin.value), int(y_spin.value)))
	)
	_add_row(label_text, row)


func _add_option(field: String, label_text: String, options: Array[String], value: int) -> void:
	var option := OptionButton.new()
	for item in options:
		option.add_item(item)
	option.select(clampi(value, 0, maxi(0, options.size() - 1)))
	option.item_selected.connect(func(index: int) -> void:
		_emit_property(field, index)
	)
	_add_row(label_text, option)


func _add_color_mask(field: String, label_text: String, value: int) -> void:
	var option := OptionButton.new()
	var masks: Array[Dictionary] = [
		{"name": "红色", "mask": LightPuzzleConstants.COLOR_RED},
		{"name": "绿色", "mask": LightPuzzleConstants.COLOR_GREEN},
		{"name": "蓝色", "mask": LightPuzzleConstants.COLOR_BLUE},
		{"name": "黄色", "mask": LightPuzzleConstants.COLOR_YELLOW},
		{"name": "青色", "mask": LightPuzzleConstants.COLOR_CYAN},
		{"name": "品红", "mask": LightPuzzleConstants.COLOR_MAGENTA},
		{"name": "白色", "mask": LightPuzzleConstants.COLOR_WHITE},
	]
	var selected_index := 0
	for index in range(masks.size()):
		var entry := masks[index]
		option.add_item(entry["name"])
		option.set_item_metadata(index, entry["mask"])
		if int(entry["mask"]) == value:
			selected_index = index
	option.select(selected_index)
	option.item_selected.connect(func(index: int) -> void:
		_emit_property(field, int(option.get_item_metadata(index)))
	)
	_add_row(label_text, option)


func _add_allowed_cells_summary(cells: Array[Vector2i]) -> void:
	var label := Label.new()
	label.text = "可移动格：已选择 %d 格" % cells.size()
	add_child(label)
	_add_help("使用“编辑可移动格”工具，然后点击棋盘格来切换可移动范围。")
	_add_action("clear_allowed_cells", "清空可移动格")


func _add_action(action: String, text: String) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(func() -> void:
		if not _is_populating:
			action_requested.emit(action)
	)
	add_child(button)


func _create_axis_spin(value: int, min_value: int, max_value: int) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = 1.0
	spin.value = value
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spin


func _axis_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _emit_property(field: String, value: Variant) -> void:
	if _is_populating:
		return
	property_changed.emit(field, value)


func _get_port(puzzle: LightPuzzleData, source: bool, index: int) -> LightPortData:
	if puzzle == null:
		return null
	var ports: Array[LightPortData] = puzzle.sources if source else puzzle.exits
	if index < 0 or index >= ports.size():
		return null
	return ports[index]


func _get_placement(puzzle: LightPuzzleData, index: int) -> LightPiecePlacement:
	if puzzle == null or index < 0 or index >= puzzle.placements.size():
		return null
	return puzzle.placements[index]


func _clear_children() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
