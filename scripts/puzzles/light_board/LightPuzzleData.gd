class_name LightPuzzleData
extends Resource

@export var puzzle_id: String = ""
@export var title: String = ""
@export var board_size: Vector2i = Vector2i(5, 5)
@export var sources: Array[LightPortData] = []
@export var exits: Array[LightPortData] = []
@export var placements: Array[LightPiecePlacement] = []
@export var max_beam_steps: int = 64
@export var solved_event_name: String = ""
@export_multiline var designer_notes: String = ""


func create_runtime_placements() -> Array:
	var runtime: Array = []
	for placement in placements:
		if placement != null:
			runtime.append(placement.duplicate_runtime())
	return runtime
