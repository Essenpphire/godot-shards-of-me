class_name LightBoardSurface
extends Control

const ASSET_ROOT := "res://assets/images/puzzle/"

var board_size: Vector2i = Vector2i(5, 5)
var cell_size: float = 88.0
var beam_segments: Array = []
var sources: Array[LightPortData] = []
var exits: Array[LightPortData] = []
var exit_hits: Dictionary = {}

var _board_texture: Texture2D
var _source_texture: Texture2D
var _exit_textures: Dictionary = {}


static var _texture_cache: Dictionary = {}


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
	custom_minimum_size = Vector2(board_size) * cell_size
	size = custom_minimum_size
	_board_texture = _load_texture("board_panel.png")
	_source_texture = _load_texture("light_source_white.png")
	_exit_textures = {
		LightPuzzleConstants.COLOR_RED: _load_texture("exit_red.png"),
		LightPuzzleConstants.COLOR_GREEN: _load_texture("exit_green.png"),
		LightPuzzleConstants.COLOR_BLUE: _load_texture("exit_blue.png"),
	}
	queue_redraw()


func set_solution(solution: Dictionary) -> void:
	beam_segments = solution.get("segments", [])
	exit_hits = solution.get("exit_hits", {})
	queue_redraw()


func cell_to_local(cell: Vector2i) -> Vector2:
	return Vector2(cell) * cell_size


func cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size


func local_to_cell(local_position: Vector2) -> Vector2i:
	return Vector2i(
		floori(local_position.x / cell_size),
		floori(local_position.y / cell_size)
	)


func _draw() -> void:
	var board_rect := Rect2(Vector2.ZERO, Vector2(board_size) * cell_size)
	if _board_texture != null:
		draw_texture_rect(_board_texture, board_rect, false)
	else:
		draw_rect(board_rect, Color(0.04, 0.045, 0.06, 0.96), true)
	_draw_grid()
	_draw_beams()
	_draw_ports()


func _draw_grid() -> void:
	var board_pixels := Vector2(board_size) * cell_size
	for y in range(board_size.y):
		for x in range(board_size.x):
			var rect := Rect2(Vector2(x, y) * cell_size, Vector2.ONE * cell_size)
			draw_rect(rect.grow(-6.0), Color(0.05, 0.08, 0.11, 0.18), true)

	for x in range(board_size.x + 1):
		var px := x * cell_size
		draw_line(Vector2(px, 0.0), Vector2(px, board_pixels.y), Color(0.44, 0.52, 0.62, 0.38), 2.0, true)
	for y in range(board_size.y + 1):
		var py := y * cell_size
		draw_line(Vector2(0.0, py), Vector2(board_pixels.x, py), Color(0.44, 0.52, 0.62, 0.38), 2.0, true)

	draw_rect(Rect2(Vector2.ZERO, board_pixels), Color(0.7, 0.82, 0.95, 0.48), false, 3.0)


func _draw_beams() -> void:
	for segment in beam_segments:
		var color_mask: int = segment.get("color_mask", LightPuzzleConstants.COLOR_WHITE)
		var color := LightPuzzleConstants.color_to_draw(color_mask)
		color.a = 0.92
		var from_cell: Vector2i = segment.get("from", Vector2i.ZERO)
		var to_cell: Vector2i = segment.get("to", Vector2i.ZERO)
		var from_pos := cell_center(from_cell)
		var to_pos := cell_center(to_cell)
		draw_line(from_pos, to_pos, Color(color.r, color.g, color.b, 0.28), 12.0, true)
		draw_line(from_pos, to_pos, color, 4.0, true)


func _draw_ports() -> void:
	for source in sources:
		if source == null:
			continue
		var dir_vec := Vector2(LightPuzzleConstants.direction_vector(source.direction))
		var center := cell_center(source.cell) - dir_vec * cell_size * 0.48
		_draw_port_marker(center, source.color_mask, true, true)

	for exit_port in exits:
		if exit_port == null:
			continue
		var dir_vec := Vector2(LightPuzzleConstants.direction_vector(exit_port.direction))
		var center := cell_center(exit_port.cell) + dir_vec * cell_size * 0.48
		var key := exit_port.port_id if exit_port.port_id != "" else "%d,%d,%d" % [
			exit_port.cell.x,
			exit_port.cell.y,
			exit_port.direction,
		]
		_draw_port_marker(center, exit_port.color_mask, false, exit_hits.get(key, false))


func _draw_port_marker(center: Vector2, color_mask: int, is_source: bool, active: bool) -> void:
	var color := LightPuzzleConstants.color_to_draw(color_mask)
	if not active:
		color = color.darkened(0.55)
	var texture: Texture2D = _source_texture if is_source else _get_exit_texture(color_mask)
	if texture != null:
		var port_rect := Rect2(center - Vector2.ONE * 14.0, Vector2.ONE * 28.0)
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


func _load_texture(file_name: String) -> Texture2D:
	if _texture_cache.has(file_name):
		return _texture_cache[file_name]
	var texture := load(ASSET_ROOT + file_name) as Texture2D
	_texture_cache[file_name] = texture
	return texture
