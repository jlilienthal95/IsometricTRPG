class_name HighlightManager
extends Node

const HIGHLIGHT_SCENE = preload("res://Scenes/Battle/HighlightTile.tscn")
var _active_highlights: Array[Node2D] = []

# instantiates a highlight tile for each cell in the range dictionary
# valid cells (true) use the default highlight color; invalid cells (false) are shown in red
func show_move_range(cells: Dictionary, get_world_pos: Callable) -> void:
	clear()
	for cell in cells:
		var highlight: Node2D = HIGHLIGHT_SCENE.instantiate()
		add_child(highlight)
		highlight.global_position = get_world_pos.call(cell)
		highlight.z_index = cell.z * 4 + 1
		if cells[cell] == false:
			highlight.modulate = Color(255, 0, 0, 0.75)
		_active_highlights.append(highlight)

# removes and frees all active highlight nodes
func clear() -> void:
	for highlight in _active_highlights:
		highlight.queue_free()
	_active_highlights.clear()
