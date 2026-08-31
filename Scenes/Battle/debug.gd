extends Node2D

# =============================================================================
# Debug tools: grid overlay, hover inspector, and a tile-effect/terrain panel
# that operates on a click-and-drag multi-tile selection.
#
# The debug panel bypasses BattleManager's state machine entirely (it calls
# EffectExecutor/BattleGrid directly), which is why _on_effect_applied and
# _on_effect_removed explicitly restore the HUD via _battle_ui.fade_in()
# after acting — in real gameplay that's BattleUI._on_state_changed()'s job,
# triggered by a state transition, but no state transition happens here.
# =============================================================================

var show_grid: bool = false
var debug_mode: bool = false

# every cell currently selected for a debug operation — populated by
# click-and-drag in _unhandled_input. Empty means nothing selected.
var _selected_cells: Array[Vector3i] = []
var _dragging: bool = false

var _debug_panel: DebugPanel = null
var _battle_grid: BattleGrid = null
var _effect_executor: EffectExecutor = null
var _unit_mover: UnitMover = null
var _tile_visual_manager: TileVisualManager = null
var _battle_ui: BattleUI = null
var _cinematic_director: CinematicDirector = null
var _reference_layer: TileMapLayer = null
var _input_handler: Node = null
var _hover_label: Label = null

func _ready() -> void:
	_battle_grid = get_parent().get_node("BattleGrid")
	_effect_executor = get_parent().get_node("EffectExecutor")
	_unit_mover = get_parent().get_node("UnitMover")
	_tile_visual_manager = get_parent().get_node("TileVisualManager")
	_battle_ui = get_parent().get_node("CanvasLayer/BattleUI")
	_reference_layer = get_parent().get_node("TerrainLayers/Elevation1")
	_input_handler = get_parent().get_node("InputHandler")
	_debug_panel = get_parent().get_node("CanvasLayer/DebugPanel")
	_debug_panel.terrain_selected.connect(_on_terrain_selected)
	_debug_panel.effect_applied.connect(_on_effect_applied)
	_debug_panel.effect_removed.connect(_on_effect_removed)
	_debug_panel.walkable_toggled.connect(_on_walkable_toggled)
	_debug_panel.tick_requested.connect(_tick_selected_tiles)
	_debug_panel.visible = false
	
	var canvas = CanvasLayer.new()
	canvas.layer = 100  # above everything
	add_child(canvas)
	
	var shadow = Label.new()
	shadow.position = Vector2(11, 11)
	shadow.add_theme_font_size_override("font_size", 10)
	shadow.add_theme_color_override("font_color", Color.BLACK)
	canvas.add_child(shadow)
	
	_hover_label = Label.new()
	_hover_label.position = Vector2(10, 10)
	_hover_label.add_theme_font_size_override("font_size", 10)
	_hover_label.add_theme_color_override("font_color", Color.YELLOW)
	canvas.add_child(_hover_label)
	_input_handler.cell_hovered.connect(func(cell):
		var text = _get_hover_text(cell)
		_hover_label.text = text
		shadow.text = text
	)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_home"):
		show_grid = not show_grid
		_hover_label.visible = show_grid
		queue_redraw()
	if event.is_action_pressed("debug_toggle"):
		debug_mode = not debug_mode
		_debug_panel.visible = debug_mode
		_input_handler.set_process_unhandled_input(not debug_mode)
		if not debug_mode:
			_clear_selection()

# =============================================================================
# INPUT — click-and-drag builds up _selected_cells; releasing the mouse ends
# the drag but leaves the selection in place until the next click starts a
# new one. Right-click clears the current selection.
# =============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if not debug_mode:
		return

	if event is InputEventMouseButton:
		if _debug_panel.visible and _debug_panel.get_global_rect().has_point(get_viewport().get_mouse_position()):
			return  # clicks over the panel itself never touch the grid

		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = true
				_clear_selection()
				_try_add_cell_at_screen_pos(event.global_position)
			else:
				_dragging = false

		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_clear_selection()

	elif event is InputEventMouseMotion and _dragging:
		_try_add_cell_at_screen_pos(event.global_position)

	if event.is_action_pressed("ui_accept"):
		await _tick_selected_tiles()

# resolves the tile under screen_pos and adds it to the selection if it
# isn't already there (drag can pass back over the same tile repeatedly).
func _try_add_cell_at_screen_pos(screen_pos: Vector2) -> void:
	var tile := _resolve_tile_at_screen_pos(screen_pos)
	if tile == null:
		return
	if _selected_cells.has(tile.cell):
		return
	_selected_cells.append(tile.cell)
	_debug_panel.refresh_selection_info(_selected_cells, _battle_grid)
	_refresh_selection_highlight()

# shared click/drag tile resolution — was duplicated inline in the old
# single-click handler; now used by both click and drag-motion.
func _resolve_tile_at_screen_pos(screen_pos: Vector2) -> BattleTileData:
	var mouse_pos = _reference_layer.get_global_mouse_position()
	var local_pos = _reference_layer.to_local(mouse_pos)
	local_pos.y += Constants.TILE_ORIGIN_OFFSET
	var map_pos = _reference_layer.local_to_map(local_pos)
	return _battle_grid.get_tile_at_highest_elevation(map_pos)

func _clear_selection() -> void:
	_selected_cells.clear()
	_tile_visual_manager.clear_highlights()
	_debug_panel.refresh_selection_info(_selected_cells, _battle_grid)
	queue_redraw()

# reuses TileVisualManager's existing move-range highlight rather than a
# separate debug-only highlight system — every selected cell renders as a
# normal (non-red) highlight since "invalid" has no meaning here.
# get_parent() is battle_scene, which already exposes grid_to_world exactly
# as every other Callable-based caller in the project expects it.
func _refresh_selection_highlight() -> void:
	var cells: Dictionary = {}
	for cell in _selected_cells:
		cells[cell] = true
	_tile_visual_manager.show_move_range(cells, get_parent().grid_to_world)
	queue_redraw()

# =============================================================================
# ACTIONS — all operate over the full selection, not a single tile
# =============================================================================

func _tick_selected_tiles() -> void:
	if _selected_cells.is_empty():
		return
	var context = EffectContext.create(_battle_grid, _unit_mover, _effect_executor)
	for cell in _selected_cells:
		var tile = _battle_grid.get_tile(cell)
		if tile == null or tile.active_effects.is_empty():
			continue
		for instance in tile.active_effects.duplicate():
			await _effect_executor.process_tick(tile, instance, context, true)
	_debug_panel.refresh_selection_info(_selected_cells, _battle_grid)
	BattleManager.current_state = BattleManager.BattleState.ACTION_SELECT
	
func _on_terrain_selected(terrain_type: int) -> void:
	for cell in _selected_cells:
		var tile = _battle_grid.get_tile(cell)
		if tile == null:
			continue
		tile.terrain_type = terrain_type
		_tile_visual_manager.refresh(tile)
	_debug_panel.refresh_selection_info(_selected_cells, _battle_grid)

func _on_effect_applied(effect_id: EffectId.Id) -> void:
	for cell in _selected_cells:
		var tile = _battle_grid.get_tile(cell)
		if tile == null:
			continue
		await _effect_executor.apply_effect(tile, effect_id)
	_debug_panel.refresh_selection_info(_selected_cells, _battle_grid)
	# apply_effect()'s await only covers the handler's immediate resolve, NOT
	# the cinematic beat it enqueues on CinematicDirector — with multiple
	# selected tiles, later beats can still be mid-flight (each re-hiding the
	# HUD via begin_sequence -> fade_out) after this loop has finished.
	# wait_until_idle() ensures fade_in() happens after every enqueued beat
	# is actually done, not just after this loop returns.
	var director := _get_cinematic_director()
	if director != null:
		await director.wait_until_idle()
	await _battle_ui.fade_in()

func _on_effect_removed(effect_id: EffectId.Id) -> void:
	for cell in _selected_cells:
		var tile = _battle_grid.get_tile(cell)
		if tile == null:
			continue
		await _effect_executor.remove_effect(tile, effect_id)
	_debug_panel.refresh_selection_info(_selected_cells, _battle_grid)
	var director := _get_cinematic_director()
	if director != null:
		await director.wait_until_idle()
	await _battle_ui.fade_in()

func _on_walkable_toggled(value: bool) -> void:
	for cell in _selected_cells:
		var tile = _battle_grid.get_tile(cell)
		if tile == null:
			continue
		tile.is_walkable = value
	_debug_panel.refresh_selection_info(_selected_cells, _battle_grid)

# =============================================================================
# DRAWING
# =============================================================================

func _draw() -> void:
	if not show_grid:
		return
	# selection highlighting is handled by TileVisualManager now (see
	# _refresh_selection_highlight) — this just draws the plain grid outline
	for cell in _battle_grid.get_all_cells():
		var local_pos = _reference_layer.map_to_local(Vector2i(cell.x, cell.y))
		var world_pos = _reference_layer.to_global(local_pos)
		world_pos.y -= Constants.TILE_ORIGIN_OFFSET
		var top = world_pos + Vector2(0, -8)
		var right = world_pos + Vector2(16, 0)
		var bottom = world_pos + Vector2(0, 8)
		var left = world_pos + Vector2(-16, 0)
		draw_polyline(PackedVector2Array([top, right, bottom, left, top]), Color.WHITE, 1.0)

func _get_hover_text(cell: Vector2i) -> String:
	if not show_grid:
		return ""
	var tile = _battle_grid.get_tile_at_highest_elevation(cell)
	if tile == null:
		return "(%d, %d) —" % [cell.x, cell.y]
	return "(%d, %d, %d) %s" % [
		tile.cell.x, tile.cell.y, tile.cell.z,
		BattleTileData.TerrainType.keys()[tile.terrain_type]
	]

func _get_cinematic_director() -> CinematicDirector:
	if _cinematic_director == null:
		_cinematic_director = get_parent().get_node_or_null("CinematicDirector")
	return _cinematic_director
