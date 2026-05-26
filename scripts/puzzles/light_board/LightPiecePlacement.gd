class_name LightPiecePlacement
extends Resource

@export var placement_id: String = ""
@export var piece: LightPieceData
@export var grid_position: Vector2i = Vector2i.ZERO
@export var locked: bool = false
@export var allowed_cells: Array[Vector2i] = []
@export var solution_position: Vector2i = Vector2i(-1, -1)


func get_size() -> Vector2i:
	if piece == null:
		return Vector2i.ONE
	return piece.size


func is_movable() -> bool:
	if piece == null:
		return false
	return piece.is_draggable and not locked and piece.move_axis != LightPuzzleConstants.MoveAxis.LOCKED


func duplicate_runtime() -> Dictionary:
	return {
		"placement_id": placement_id,
		"piece": piece,
		"grid_position": grid_position,
		"locked": locked,
		"allowed_cells": allowed_cells.duplicate(),
		"solution_position": solution_position,
	}
