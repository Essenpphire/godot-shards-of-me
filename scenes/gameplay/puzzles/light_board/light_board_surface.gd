class_name LightBoardSurface
extends Control

var board_size: Vector2i = Vector2i(5, 5)
var cell_size: float = 88.0
var beam_segments: Array = []
var sources: Array[LightPortData] = []
var exits: Array[LightPortData] = []
var exit_hits: Dictionary = {}


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
	draw_rect(board_rect, Color(0.04, 0.045, 0.06, 0.96), true)
	_draw_grid()
	_draw_beams()
	_draw_ports()


func _draw_grid() -> void:
	var board_pixels := Vector2(board_size) * cell_size
	for y in range(board_size.y):
		for x in range(board_size.x):
			var rect := Rect2(Vector2(x, y) * cell_size, Vector2.ONE * cell_size)
			var tint := Color(0.11, 0.125, 0.15, 0.88)
			if (x + y) % 2 == 0:
				tint = Color(0.13, 0.15, 0.18, 0.88)
			draw_rect(rect.grow(-2.0), tint, true)

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
		_draw_port_marker(center, source.color_mask, "S", true)

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
		_draw_port_marker(center, exit_port.color_mask, "E", exit_hits.get(key, false))


func _draw_port_marker(center: Vector2, color_mask: int, label: String, active: bool) -> void:
	var color := LightPuzzleConstants.color_to_draw(color_mask)
	if not active:
		color = color.darkened(0.55)
	draw_circle(center, 12.0, Color(color.r, color.g, color.b, 0.34))
	draw_circle(center, 7.0, color)

	var font := get_theme_default_font()
	var font_size := 14
	var label_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	draw_string(
		font,
		center - label_size * 0.5 + Vector2(0.0, label_size.y * 0.75),
		label,
		HORIZONTAL_ALIGNMENT_CENTER,
		-1.0,
		font_size,
		Color(0.98, 0.98, 0.98)
	)
