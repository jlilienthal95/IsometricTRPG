extends Node2D

var show_grid: bool = false
var debug_mode: bool = false
var _selected_cell: Vector3i = Vector3i(999, 999, 999)
var _debug_panel: DebugPanel = null
var _battle_grid: BattleGrid = null
var _effect_executor: EffectExecutor = null
var _tile_visual_manager: TileVisualManager = null
var _reference_layer: TileMapLayer = null
var _input_handler: Node = null

func _ready() -> void:
	_battle_grid = get_parent().get_node("BattleGrid")
	_effect_executor = get_parent().get_node("EffectExecutor")
	_tile_visual_manager = get_parent().get_node("TileVisualManager")
	_reference_layer = get_parent().get_node("TerrainLayers/Elevation1")
	_input_handler = get_parent().get_node("InputHandler")
	_debug_panel = get_parent().get_node("CanvasLayer/DebugPanel")
	_debug_panel.terrain_selected.connect(_on_terrain_selected)
	_debug_panel.effect_applied.connect(_on_effect_applied)
	_debug_panel.effect_removed.connect(_on_effect_removed)
	_debug_panel.walkable_toggled.connect(_on_walkable_toggled)
	_debug_panel.tick_requested.connect(_tick_selected_tile)
	_debug_panel.visible = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_home"):
		show_grid = not show_grid
		queue_redraw()
	if event.is_action_pressed("debug_toggle"):
		debug_mode = not debug_mode
		_debug_panel.visible = debug_mode
		_input_handler.set_process_unhandled_input(not debug_mode)
		if not debug_mode:
			_selected_cell = Vector3i(999, 999, 999)
			queue_redraw()
			
func _unhandled_input(event: InputEvent) -> void:
	if debug_mode and event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _debug_panel.visible and _debug_panel.get_global_rect().has_point(get_viewport().get_mouse_position()):
				print("blocked by panel")
				return
			_handle_debug_click(event.global_position)

	if event.is_action_pressed("ui_accept") and debug_mode:
		await _tick_selected_tile()
		
func _tick_selected_tile() -> void:
	if _selected_cell == Vector3i(999, 999, 999):
		return
	var tile = _battle_grid.get_tile(_selected_cell)
	if tile == null or tile.active_effects.is_empty():
		print("no effects to tick")
		return
	var context = EffectContext.create(_battle_grid, _effect_executor)
	for instance in tile.active_effects.duplicate():
		await _effect_executor.process_tick(tile, instance, context, true)
	_debug_panel.refresh_tile_info(tile)
	print("tick complete")

func _handle_debug_click(screen_pos: Vector2) -> void:
	var mouse_pos = _reference_layer.get_global_mouse_position()
	var local_pos = _reference_layer.to_local(mouse_pos)
	local_pos.y += Constants.TILE_ORIGIN_OFFSET
	var map_pos = _reference_layer.local_to_map(local_pos)
	var tile = _battle_grid.get_tile_at_highest_elevation(map_pos)
	print("handle_debug_click — map_pos: ", map_pos, " tile: ", tile.cell if tile else "null")
	if tile == null:
		return
	_selected_cell = tile.cell
	print("selected cell updated to: ", _selected_cell)
	_debug_panel.refresh_tile_info(tile)
	queue_redraw()

func _on_terrain_selected(terrain_type: int) -> void:
	if _selected_cell == Vector3i(999, 999, 999):
		return
	var tile = _battle_grid.get_tile(_selected_cell)
	if tile == null:
		return
	tile.terrain_type = terrain_type
	_tile_visual_manager.refresh(tile)
	_debug_panel.refresh_tile_info(tile)

func _on_effect_applied(effect_id: EffectId.Id) -> void:
	if _selected_cell == Vector3i(999, 999, 999):
		return
	var tile = _battle_grid.get_tile(_selected_cell)
	if tile == null:
		return
	await _effect_executor.apply_effect(tile, effect_id)
	_debug_panel.refresh_tile_info(tile)

func _on_effect_removed(effect_id: EffectId.Id) -> void:
	if _selected_cell == Vector3i(999, 999, 999):
		return
	var tile = _battle_grid.get_tile(_selected_cell)
	if tile == null:
		return
	await _effect_executor.remove_effect(tile, effect_id)
	_debug_panel.refresh_tile_info(tile)

func _on_walkable_toggled(value: bool) -> void:
	if _selected_cell == Vector3i(999, 999, 999):
		return
	var tile = _battle_grid.get_tile(_selected_cell)
	if tile == null:
		return
	tile.is_walkable = value
	_debug_panel.refresh_tile_info(tile)

func _draw() -> void:
	if not show_grid:
		return
	for cell in _battle_grid.get_all_cells():
		var local_pos = _reference_layer.map_to_local(Vector2i(cell.x, cell.y))
		var world_pos = _reference_layer.to_global(local_pos)
		world_pos.y -= Constants.TILE_ORIGIN_OFFSET
		var color = Color.YELLOW if cell == _selected_cell else Color.WHITE
		var top = world_pos + Vector2(0, -8)
		var right = world_pos + Vector2(16, 0)
		var bottom = world_pos + Vector2(0, 8)
		var left = world_pos + Vector2(-16, 0)
		draw_polyline(PackedVector2Array([top, right, bottom, left, top]), color, 1.0)
