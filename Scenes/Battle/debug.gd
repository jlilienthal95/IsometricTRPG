extends Node2D

var show_grid: bool = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_home"):
		show_grid = not show_grid
		queue_redraw()

func _draw() -> void:
	if not show_grid:
		return
	var battle_grid = get_parent().get_node("BattleGrid")
	var reference_layer = get_parent().get_node("TerrainLayers/Elevation1")
	for cell in battle_grid.get_all_cells():
		var local_pos = reference_layer.map_to_local(Vector2i(cell.x, cell.y))
		var world_pos = reference_layer.to_global(local_pos)
		world_pos.y -= Constants.TILE_ORIGIN_OFFSET
		var top = world_pos + Vector2(0, -8)
		var right = world_pos + Vector2(16, 0)
		var bottom = world_pos + Vector2(0, 8)
		var left = world_pos + Vector2(-16, 0)
		draw_polyline(PackedVector2Array([top, right, bottom, left, top]), Color.WHITE, 1.0)
