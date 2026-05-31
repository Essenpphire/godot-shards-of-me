extends Control

const ASSET_ROOT := "res://assets/images/puzzle/"

# board_panel.png 原始尺寸及内部参数，可在编辑器中调整
@export var board_panel_cell_px: float = 300   # 底图中单个格子的像素大小
@export var board_panel_border_px: float = 162.0  # 底图中边框的像素宽度

var board_size: Vector2i = Vector2i(5, 5)
var cell_size: float = 88.0
var beam_segments: Array = []
var sources: Array[LightPortData] = []
var exits: Array[LightPortData] = []
var exit_hits: Dictionary = {}
var board_margin := Rect2(Vector2(0, 0), Vector2(0, 0))
@export var port_icon_size: float = 48.0

var _board_texture: Texture2D
var _source_texture: Texture2D
var _exit_textures: Dictionary = {}


static var _texture_cache: Dictionary = {}


func _get_scaled_border() -> float:
	return board_panel_border_px / board_panel_cell_px * cell_size


func configure(
	new_board_size: Vector2i,
	new_cell_size: float,
	new_sources: Array[LightPortData],
	new_exits: Array[LightPortData]
) -> void:
	board_size = new_board_size
	cell_size = new_cell_size
	sources = new_sources
	exits = new_exits
	_board_texture = _load_texture("board_panel.png")
	_source_texture = _load_texture("light_source_white.png")
	_exit_textures = {
		LightPuzzleConstants.COLOR_RED: _load_texture("exit_red.png"),
		LightPuzzleConstants.COLOR_GREEN: _load_texture("exit_green.png"),
		LightPuzzleConstants.COLOR_BLUE: _load_texture("exit_blue.png"),
	}
	_calculate_board_margin()
	# 控件大小 = 网格区域 + 两侧边框
	var border := _get_scaled_border()
	custom_minimum_size = Vector2(board_size) * cell_size + Vector2(border, border) * 2.0
	size = custom_minimum_size
	queue_redraw()


func set_solution(solution: Dictionary) -> void:
	beam_segments = solution.get("segments", [])
	exit_hits = solution.get("exit_hits", {})
	queue_redraw()


func cell_to_local(cell: Vector2i) -> Vector2:
	return board_margin.position + Vector2(cell) * _cell_step()


func cell_center(cell: Vector2i) -> Vector2:
	return board_margin.position + (Vector2(cell) + Vector2(0.5, 0.5)) * _cell_step()


func local_to_cell(local_position: Vector2) -> Vector2i:
	var local := local_position - board_margin.position
	var step := _cell_step()
	return Vector2i(
		floori(local.x / step),
		floori(local.y / step)
	)


func local_to_cell_centered(local_position: Vector2, piece_size: Vector2i = Vector2i.ONE) -> Vector2i:
	var local := local_position - board_margin.position
	var step := _cell_step()
	var half_size := Vector2(piece_size) * 0.5
	return Vector2i(
		roundi(local.x / step - half_size.x),
		roundi(local.y / step - half_size.y)
	)


func _draw() -> void:
	var step := _cell_step()
	var grid_size := Vector2(board_size) * step
	var board_rect := Rect2(board_margin.position, grid_size)
	if _board_texture != null:
		# 底图从(0,0)缩放到控件完整尺寸（含两侧边框）
		var border := _get_scaled_border()
		var panel_size := Vector2(board_size) * cell_size + Vector2(border, border) * 2.0
		draw_texture_rect(_board_texture, Rect2(Vector2.ZERO, panel_size), false)
	else:
		draw_rect(board_rect, Color(0.04, 0.045, 0.06, 0.96), true)
	_draw_grid()
	_draw_beams()
	_draw_ports()


func _draw_grid() -> void:
	var step := _cell_step()
	var board_pixels := Vector2(board_size) * step
	for y in range(board_size.y):
		for x in range(board_size.x):
			var rect := Rect2(board_margin.position + Vector2(x, y) * step, Vector2.ONE * step)
			draw_rect(rect.grow(-6.0), Color(0.05, 0.08, 0.11, 0.18), true)

	for x in range(board_size.x + 1):
		var px := board_margin.position.x + x * step
		draw_line(Vector2(px, board_margin.position.y), Vector2(px, board_margin.position.y + board_pixels.y), Color(0.44, 0.52, 0.62, 0.38), 2.0, true)
	for y in range(board_size.y + 1):
		var py := board_margin.position.y + y * step
		draw_line(Vector2(board_margin.position.x, py), Vector2(board_margin.position.x + board_pixels.x, py), Color(0.44, 0.52, 0.62, 0.38), 2.0, true)

	draw_rect(Rect2(board_margin.position, board_pixels), Color(0.7, 0.82, 0.95, 0.48), false, 3.0)


func _draw_beams() -> void:
	for segment in beam_segments:
		var color_mask: int = segment.get("color_mask", LightPuzzleConstants.COLOR_WHITE)
		var color := LightPuzzleConstants.color_to_draw(color_mask)
		color.a = 0.92
		var from_cell: Vector2i = segment.get("from", Vector2i.ZERO)
		var to_cell: Vector2i = segment.get("to", Vector2i.ZERO)
		var direction: int = segment.get("direction", LightPuzzleConstants.Direction.E)
		var from_pos := _beam_start_position(segment, from_cell)
		var to_pos := _beam_end_position(from_cell, to_cell, direction)
		draw_line(from_pos, to_pos, Color(color.r, color.g, color.b, 0.28), 12.0, true)
		draw_line(from_pos, to_pos, color, 4.0, true)


func _draw_ports() -> void:
	for source in sources:
		if source == null:
			continue
		var center := _port_marker_center(source, true)
		_draw_port_marker(center, source.color_mask, true, true)

	for exit_port in exits:
		if exit_port == null:
			continue
		var center := _port_marker_center(exit_port, false)
		var key := _port_key(exit_port)
		_draw_port_marker(center, exit_port.color_mask, false, exit_hits.get(key, false))


func _draw_port_marker(center: Vector2, color_mask: int, is_source: bool, active: bool) -> void:
	var color := LightPuzzleConstants.color_to_draw(color_mask)
	if not active:
		color = color.darkened(0.55)
	var texture: Texture2D = _source_texture if is_source else _get_exit_texture(color_mask)
	if texture != null:
		var port_rect := Rect2(center - Vector2.ONE * (port_icon_size * 0.5), Vector2.ONE * port_icon_size)
		draw_texture_rect(texture, port_rect, false, Color(1.0, 1.0, 1.0, 1.0 if active else 0.45))
	else:
		draw_circle(center, 12.0, Color(color.r, color.g, color.b, 0.34))
		draw_circle(center, 7.0, color)


func _get_exit_texture(color_mask: int) -> Texture2D:
	if _exit_textures.has(color_mask):
		return _exit_textures[color_mask]
	if color_mask == LightPuzzleConstants.COLOR_YELLOW:
		return _exit_textures.get(LightPuzzleConstants.COLOR_RED, null)
	if color_mask == LightPuzzleConstants.COLOR_CYAN:
		return _exit_textures.get(LightPuzzleConstants.COLOR_BLUE, null)
	if color_mask == LightPuzzleConstants.COLOR_MAGENTA:
		return _exit_textures.get(LightPuzzleConstants.COLOR_RED, null)
	return null


func _beam_start_position(segment: Dictionary, from_cell: Vector2i) -> Vector2:
	var source_key := str(segment.get("source", ""))
	for source in sources:
		if source != null and _port_key(source) == source_key and source.cell == from_cell:
			return _port_marker_center(source, true)
	return cell_center(from_cell)


func _beam_end_position(from_cell: Vector2i, to_cell: Vector2i, direction: int) -> Vector2:
	if _is_cell_inside(to_cell):
		return cell_center(to_cell)
	var dir_vec := Vector2(LightPuzzleConstants.direction_vector(direction))
	for exit_port in exits:
		if exit_port != null and exit_port.cell == from_cell and exit_port.direction == direction:
			return _port_marker_center(exit_port, false)
	return cell_center(from_cell) + dir_vec * (_cell_step() * 0.58)


func _port_marker_center(port: LightPortData, is_source: bool) -> Vector2:
	var dir_vec := Vector2(LightPuzzleConstants.direction_vector(port.direction))
	var sign := -1.0 if is_source else 1.0
	return cell_center(port.cell) + dir_vec * (_cell_step() * 0.58 * sign)


func _port_key(port: LightPortData) -> String:
	if port.port_id != "":
		return port.port_id
	return "%d,%d,%d" % [port.cell.x, port.cell.y, port.direction]


func _is_cell_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < board_size.x and cell.y < board_size.y


func _load_texture(file_name: String) -> Texture2D:
	if _texture_cache.has(file_name):
		return _texture_cache[file_name]
	var texture := load(ASSET_ROOT + file_name) as Texture2D
	_texture_cache[file_name] = texture
	return texture


func _cell_step() -> float:
	return cell_size


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_calculate_board_margin()
		queue_redraw()


func _calculate_board_margin() -> void:
	var step := _cell_step()
	var board_pixels := Vector2(board_size) * step
	# 网格从缩放后的边框位置开始
	var border := _get_scaled_border()
	board_margin = Rect2(Vector2(border, border), board_pixels)
