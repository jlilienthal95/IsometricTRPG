extends Node2D

var show_grid: bool = false

# toggles the debug grid overlay on/off with the Home key
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_home"):
		show_grid = not show_grid
		queue_redraw()

# draws isometric diamond outlines over every cell in the battle grid
# uses Elevation1 as the reference layer for consistent screen positioning
func _draw() -> void:
	if not show_grid:
		return
	var battle_grid = get_parent().get_node("BattleGrid")
	var reference_layer = get_parent().get_node("TerrainLayers/Elevation1")
	for cell in battle_grid.get_all_cells():
		var local_pos = reference_layer.map_to_local(Vector2i(cell.x, cell.y))
		var world_pos = reference_layer.to_global(local_pos)
		var top = world_pos + Vector2(0, -32)
		var right = world_pos + Vector2(56, 0)
		var bottom = world_pos + Vector2(0, 32)
		var left = world_pos + Vector2(-56, 0)
		draw_polyline(PackedVector2Array([top, right, bottom, left, top]), Color.WHITE, 1.0)
