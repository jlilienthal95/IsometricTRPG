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
	for cell in battle_grid.get_all_cells():
		var world_pos = get_parent().grid_to_world(cell)
		world_pos.x -= get_parent().UNIT_X_OFFSET
		# four corners of the isometric diamond
		var top = world_pos + Vector2(0, -32)
		var right = world_pos + Vector2(56, 0)
		var bottom = world_pos + Vector2(0, 32)
		var left = world_pos + Vector2(-56, 0)
		var points = PackedVector2Array([top, right, bottom, left])
		draw_polyline(PackedVector2Array([top, right, bottom, left, top]), Color.WHITE, 1.0)
