class_name HighlightManager
extends Node

var highlight_layer: TileMapLayer = null

func setup(layer: TileMapLayer) -> void:
	highlight_layer = layer

func show_move_range(cells: Array[Vector3i]) -> void:
	clear()
	for cell in cells:
		highlight_layer.set_cell(Vector2i(cell.x, cell.y), 0, Vector2i(0, 0))

func clear() -> void:
	highlight_layer.clear()
