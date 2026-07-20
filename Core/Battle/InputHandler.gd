class_name InputHandler
extends Node

signal cell_selected(cell: Vector2i)
signal cell_hovered(cell: Vector2i)
signal cell_cancelled

var _reference_layer: TileMapLayer = null
var _last_hovered_cell: Vector2i = Vector2i(-999, 999)

func setup(reference_layer: TileMapLayer) -> void:
	_reference_layer = reference_layer

func _unhandled_input(event: InputEvent) -> void:
	if _reference_layer == null:
		return
	if not BattleManager.active_unit == null:
		if event is InputEventMouseMotion and BattleManager.active_unit.data.is_player_controlled:
			var cell = _get_cell_under_mouse()
			if cell != _last_hovered_cell:
				_last_hovered_cell = cell
				emit_signal("cell_hovered", cell)
		if event.is_action_pressed("menu_select"):
			var cell = _get_cell_under_mouse()
			emit_signal("cell_selected", cell)
		if event.is_action_pressed("menu_cancel"):
			emit_signal("cell_cancelled")

func _get_cell_under_mouse() -> Vector2i:
	var mouse_pos = _reference_layer.get_global_mouse_position()
	var local_pos = _reference_layer.to_local(mouse_pos)
	local_pos.y += Constants.TILE_ORIGIN_OFFSET  # offset upward to account for bottom origin
	return _reference_layer.local_to_map(local_pos)
