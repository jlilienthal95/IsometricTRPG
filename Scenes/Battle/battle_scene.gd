extends Node2D

# --- node references ---
@onready var _battle_grid: BattleGrid = $BattleGrid
@onready var _action_resolver: ActionResolver = $ActionResolver
@onready var _input_handler: InputHandler = $InputHandler
@onready var _battle_ui: BattleUI = $CanvasLayer/BattleUI
@onready var _battle_hud: BattleHUD = $CanvasLayer/BattleUI/BattleHUD
@onready var _character_info: CharacterInfo = $CanvasLayer/BattleUI/CharacterInfo
@onready var _pathfinder = $Pathfinder
@onready var _cursor: Node2D = $Cursor
@onready var _unit_mover = $UnitMover
@onready var _unit_ability_executor = $UnitAbilityExecutor
@onready var _tile_visual_manager = $TileVisualManager
@onready var _battle_camera = $BattleCamera
@onready var _terrain_layers = $TerrainLayers
@onready var _effect_executor = $EffectExecutor
@onready var _turn_queue = $TurnQueue

# --- state ---
# _turn_context is the single source of truth for "who's acting" plus all pathfinding
# data derived from them. It's built atomically in _on_active_unit_changed, the one signal
# BattleManager fires whenever the active unit changes — nothing else may assign to it,
# so there is no second cached unit reference that can desync from BattleManager.active_unit.
var _turn_context: TurnContext = null
var _previous_unit: Unit = null
var _previous_cell: Vector3i = Vector3i(999,999,999)

# =============================================================================
# SETUP
# =============================================================================

func _ready() -> void:
	print("getting ready...")
	randomize()
	_build_grid()
	_setup_systems()
	_spawn_units()
	print("setup complete")
	
	#var test = EffectSystemTest.new()
	#add_child(test)
	#await test.run_tests(_battle_grid, _battle_camera, _tile_visual_manager, _turn_context.unit)

# builds the logical grid from all elevation layers and sets their z indices
func _build_grid() -> void:
	for layer in _terrain_layers.get_children():
		var layer_name = str(layer.name)
		var num_str = ""
		for c in layer_name:
			if c.is_valid_int():
				num_str += c
			elif num_str != "":
				break
		if num_str == "":
			continue
		var elevation = num_str.to_int()
		var z_offset = layer.get_meta("z_offset", 0)
		layer.z_index = elevation * 4 + z_offset
		_battle_grid.build_from_tilemap(layer, elevation)
	_battle_grid.build_occlusion_map()

# wires up all system references and signal connections
func _setup_systems() -> void:
	# input
	_input_handler.setup(_terrain_layers.get_node("Elevation0"))
	_input_handler.cell_selected.connect(_on_cell_selected)
	_input_handler.cell_hovered.connect(_on_cell_hovered)
	_input_handler.cell_cancelled.connect(_on_cell_cancelled)

	# hud
	_battle_ui.setup(BattleManager)
	_character_info.setup(null)

	# pathfinder
	_pathfinder.setup(_battle_grid)
	
	#tile visuals and effects
	_tile_visual_manager.setup(_battle_grid, _terrain_layers)
	
	## cursor
	#_cursor.setup()
	
	# battle camara
	_battle_camera.setup(_cursor)

	# battle manager
	BattleManager.setup(_battle_grid, _battle_camera, _unit_mover, _unit_ability_executor, _battle_ui, _effect_executor, _turn_queue)
	BattleManager.state_changed.connect(_on_battle_state_changed)
	BattleManager.active_unit_changed.connect(_on_active_unit_changed)
	BattleManager.unit_moved.connect(_on_unit_moved)
	BattleManager.ability_selected.connect(_on_ability_selected)
	BattleManager.unit_executed_ability.connect(_on_unit_ability)

	# unit mover
	_unit_mover.setup(_battle_grid)
	_unit_mover.movement_complete.connect(_on_movement_complete)

	# unit ability executor
	_unit_ability_executor.setup(_battle_grid)
	
	#effect executor
	_effect_executor.setup(_battle_grid, _battle_camera, _tile_visual_manager)
	
	_battle_grid.tile_occupancy_changed.connect(_tile_visual_manager.refresh)

# TODO: replace with proper spawn system driven by battle/GameState configuration
func _spawn_units() -> void:
	var marta = _spawn_unit(Vector3i(-8, 0, 1), load("res://Data/Units/Marta.tres"))
	var theo = _spawn_unit(Vector3i(-8, -1, 1), load("res://Data/Units/Theo.tres"))
	var player_units: Array[Unit] = [marta]
	var enemy_units: Array[Unit] = [theo]
	
	print("setting up turn queue")
	_turn_queue.setup(player_units, enemy_units)
	# load only equipment relevant to this battle into EquipmentRegistry

	# NOTE: intentionally not peeking the turn queue here to pick a "current unit" —
	# get_next_unit() mutates the queue (pops front, pushes to back), which silently shifted
	# the turn order by one slot before the battle officially started. get_all_units() below
	# is non-mutating. Who's actually acting is established later, once, via
	# BattleManager.active_unit_changed -> _on_active_unit_changed.
	var all_units: Array[Unit] = _turn_queue.get_all_units()
	EquipmentRegistry.load_equipment_for_battle(all_units, PartyManager.inventory)

	# resolve equipment and ability references so equipped_equipment[] and abilties[] is populated on each unit
	for unit in all_units:
		unit.data.resolve_equipment()
		unit.data.resolve_abilities()
	
	BattleManager.call_deferred("start_battle", player_units, enemy_units)

# instantiates a Unit scene, places it on the grid, and sets up its data
func _spawn_unit(cell: Vector3i, unit_data: UnitData) -> Unit:
	var unit_scene = preload("res://Scenes/Battle/Unit.tscn")
	var unit: Unit = unit_scene.instantiate()
	unit.global_position = grid_to_world(cell)
	add_child(unit)
	unit.setup(unit_data, cell)
	_battle_grid.place_unit(unit, cell)
	_battle_camera.snap_to(unit.global_position)
	return unit

# =============================================================================
# GRID / WORLD
# =============================================================================

# converts a grid cell (Vector3i) to a world position using the correct elevation layer
func grid_to_world(cell: Vector3i) -> Vector2:
	var tile = _battle_grid.get_tile(cell)
	if tile == null:
		return Vector2.ZERO
	var layer = _terrain_layers.get_node("Elevation" + str(cell.z))
	var world_pos = layer.to_global(layer.map_to_local(Vector2i(cell.x, cell.y)))
	world_pos.y -= Constants.TILE_ORIGIN_OFFSET
	return world_pos

# finds the first valid reachable Vector3i cell matching the clicked Vector2i position
# returns null if no valid cell is found — always reads from _turn_context, so the check
# is always against whichever unit is actually active, never a stale reference
func _find_reachable_cell(cell: Vector2i):
	if _turn_context == null:
		return null
	var tile = _battle_grid.get_tile_at_highest_elevation(cell)
	if tile == null:
		return null
	var target = Vector3i(cell.x, cell.y, tile.elevation)
	var targeting = BattleManager.current_state == BattleManager.BattleState.TARGET_SELECT
	if _turn_context.is_reachable(target, targeting):
		return target
	return null

# =============================================================================
# INPUT HANDLERS
# =============================================================================

# moves the cursor to the hovered cell and updates the character info panel
func _on_cell_hovered(cell: Vector2i) -> void:
	if _battle_grid == null:
		return
	var tile = _battle_grid.get_tile_at_highest_elevation(cell)
	if tile == null:
		if _cursor.is_visible:
			_cursor.hide_cursor()
		return
	var destination = grid_to_world(Vector3i(cell.x, cell.y, tile.elevation))
	if not _cursor.is_visible:
		_cursor.show_cursor()
	_cursor.move_cursor(destination)
	
	var unit: Unit = _battle_grid.get_unit_at(Vector3i(cell.x, cell.y, tile.elevation))
	if unit != null:
		_character_info.setup(unit.data)
	else:
		_character_info.hide_window()

# routes cell selection to the appropriate BattleManager action based on current state
func _on_cell_selected(cell: Vector2i) -> void:
	#print("cell selected: ", "(", (cell.x - 1), ", ", (cell.y - 1), ")")
	match BattleManager.current_state:
		BattleManager.BattleState.MOVE_SELECT:
			_previous_cell = _turn_context.unit.grid_position
			var target = _find_reachable_cell(cell)
			if target != null:
				await BattleManager.confirm_move(target)
		BattleManager.BattleState.TARGET_SELECT:
			var target = _find_reachable_cell(cell)
			if target != null:
				await BattleManager.confirm_target(target)

# cancels the current sub-selection and returns to ACTION_SELECT
func _on_cell_cancelled() -> void:
	if (BattleManager.current_state == BattleManager.BattleState.ACTION_SELECT and
		_previous_cell != Vector3i(999,999,999)) and \
		not _turn_context.unit.data.has_acted:
		_battle_grid.move_unit(_turn_context.unit.grid_position, _previous_cell)
		_turn_context.unit.global_position = grid_to_world(_previous_cell)
		_battle_camera.pan_to(grid_to_world(_previous_cell))
		_turn_context.unit.reset_move()
		_battle_hud.refresh()
		_previous_cell = Vector3i(999, 999, 999)
	else:
		BattleManager.cancel_action()

# =============================================================================
# BATTLE STATE
# =============================================================================

# responds to battle state changes by updating highlights and clearing stale query data
func _on_battle_state_changed(new_state: BattleManager.BattleState) -> void:
	match new_state:
		BattleManager.BattleState.MOVE_SELECT:
			# move range was already computed atomically in _turn_context when the unit
			# became active — just display it, never recompute against a separate variable
			_pathfinder.debug_reachable(_turn_context.unit.grid_position, _turn_context.move_query, _turn_context.unit)
			_tile_visual_manager.show_move_range(_turn_context.reachable_move_cells, grid_to_world)
		BattleManager.BattleState.ACTION_SELECT:
			_tile_visual_manager.clear()
			if _turn_context != null:
				_turn_context.clear_ability()
		BattleManager.BattleState.ABILITIES_SELECT:
			pass
		BattleManager.BattleState.TARGET_SELECT:
			_tile_visual_manager.show_move_range(_turn_context.reachable_target_cells, grid_to_world)
		BattleManager.BattleState.RESOLVING:
			_tile_visual_manager.clear()
			if _turn_context.unit.data.has_moved && _turn_context.unit.data.has_acted:
				_previous_cell = Vector3i(999,999,999)
		BattleManager.BattleState.ENEMY_TURN:
			await get_tree().create_timer(2).timeout
			_turn_queue.start_next_turn()
		BattleManager.BattleState.TERRAIN_TURN:
			var processor = TerrainTurnProcessor.new()
			await processor.process_terrain_turn(_battle_grid, _effect_executor, _battle_camera, get_tree(), grid_to_world)
			await get_tree().create_timer(2).timeout
			_turn_queue.start_next_turn()
			

# connects the new active unit's signals to the HUD and updates camera and turn state.
# this is the single authoritative point where "who's acting" is established for the scene —
# _turn_context is built here, atomically, from the same unit reference BattleManager just set
# as active_unit. No other function may assign _turn_context, so there is nowhere for a stale
# unit reference to leak in and desync from BattleManager.active_unit.
func _on_active_unit_changed(unit: Unit) -> void:
	if _previous_unit != null:
		if _previous_unit.move_consumed.is_connected(_battle_ui.refresh_hud):
			_previous_unit.move_consumed.disconnect(_battle_ui.refresh_hud)
		if _previous_unit.ability_consumed.is_connected(_battle_ui.refresh_hud):
			_previous_unit.ability_consumed.disconnect(_battle_ui.refresh_hud)
		if _previous_unit.ability_impact.is_connected(_on_ability_impact):
			_previous_unit.ability_impact.disconnect(_on_ability_impact)
	unit.move_consumed.connect(_battle_ui.refresh_hud)
	unit.ability_consumed.connect(_battle_ui.refresh_hud)
	unit.ability_impact.connect(_on_ability_impact)

	_turn_context = TurnContext.for_unit(unit, _pathfinder)

	_battle_ui.on_turn_changed(unit)
	_battle_camera.pan_to(grid_to_world(unit.grid_position))
	_previous_unit = unit
	_previous_cell = Vector3i(999,999,999)

# =============================================================================
# ABILITY / MOVEMENT EXECUTION
# =============================================================================

# stores the selected ability for use when TARGET_SELECT state is entered.
# guards against desync: if this ever fires for a unit other than _turn_context's own,
# that's a bug upstream — fail loudly here rather than silently computing a target range
# for the wrong unit (which is exactly how the original self-targeting bug slipped through).
func _on_ability_selected(unit: Unit, ability: AbilityData) -> void:
	if _turn_context == null or unit != _turn_context.unit:
		push_error("Ability selected for a unit that doesn't match the active turn context")
		return
	_turn_context.select_ability(ability, _pathfinder)

# resolves ability damage via ActionResolver and refreshes the character info panel
func _on_ability_impact() -> void:
	_character_info.refresh()

# kicks off unit movement animation via UnitMover using the turn context's move query
func _on_unit_moved(unit: Unit, to_cell: Vector3i) -> void:
	var steps = _pathfinder.get_movement_path(unit.grid_position, to_cell, _turn_context.move_query, unit)
	_unit_mover.execute_movement(unit, steps, grid_to_world, _battle_camera)
	unit.consume_move()

# kicks off ability execution via UnitAbilityExecutor
func _on_unit_ability(caster: Unit, target_cell: Vector3i, ability: AbilityData, camera: BattleCamera) -> void:
	_unit_ability_executor.execute_ability(caster, target_cell, ability, camera, _action_resolver, _battle_ui, _effect_executor)
	caster.consume_ability()

func _on_movement_complete(unit: Unit) -> void:
	print("movement complete: ", unit.data.unit_name)

# =============================================================================
# DEBUG
# =============================================================================

# prints all grid cells with their elevation, terrain type, and walkability
func _debug_print_grid() -> void:
	for cell in _battle_grid.get_all_cells():
		var tile = _battle_grid.get_tile(cell)
		print(cell, " → elevation: ", tile.elevation, " terrain: ", tile.terrain_type, " is_walkable: ", str(tile.is_walkable))
