extends Prop

@export var puzzle_data: LightPuzzleData
@export var board_scene: PackedScene = preload("res://scenes/gameplay/puzzles/light_board/light_puzzle_board.tscn")
@export var disable_after_solved: bool = true

var _board: LightPuzzleBoard
var _solved: bool = false


func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("互动") and can_interact:
		handle_interact()


func handle_interact() -> void:
	if _solved and disable_after_solved:
		return
	if puzzle_data == null:
		push_error("Light puzzle prop has no puzzle_data assigned.")
		return
	_ensure_board()
	if _board.visible:
		return
	_board.open_puzzle(puzzle_data)


func _ensure_board() -> void:
	if is_instance_valid(_board):
		return
	_board = board_scene.instantiate() as LightPuzzleBoard
	get_tree().current_scene.add_child(_board)
	_board.puzzle_solved.connect(_on_puzzle_solved)


func _on_puzzle_solved(puzzle_id: String) -> void:
	if puzzle_data == null or puzzle_id != puzzle_data.puzzle_id:
		return
	_solved = true
	if disable_after_solved:
		can_interact = false
		if hint != null:
			hint.hide()
