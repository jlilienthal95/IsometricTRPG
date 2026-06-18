extends Node2D

# --- node references ---
@onready var _battle_grid: BattleGrid = $BattleGrid
@onready var _action_resolver: ActionResolver = $ActionResolver
@onready var _input_handler: InputHandler = $InputHandler
@onready var _battle_hud: BattleHUD = $CanvasLayer/BattleHUD
@onready var _character_info = $CanvasLayer/CharacterInfo
@onready var _pathfinder = $Pathfinder
@onready var _cursor = $Cursor
@onready var _unit_mover = $UnitMover
@onready var _unit_ability_executor = $UnitAbilityExecutor
@onready var _highlight_manager = $HighlightManager
@onready var _battle_camera = $BattleCamera
@onready var _terrain_layers = $TerrainLayers

# --- state ---
var _reachable_cells: Dictionary = {}
var _current_move_query: RangeQuery = null
var _current_ability: AbilityData = null
var _current_unit: Unit = null
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

# builds the logical grid from all elevation layers and sets their z indices
func _build_grid() -> void:
	for i in range(15):
		var layer = _terrain_layers.get_node("Elevation" + str(i))
		if layer:
			_battle_grid.build_from_tilemap(layer, i)
			layer.z_index = i * 4
	_battle_grid.build_occlusion_map()

# wires up all system references and signal connections
func _setup_systems() -> void:
	# input
	_input_handler.setup(_terrain_layers.get_node("Elevation0"))
	_input_handler.cell_selected.connect(_on_cell_selected)
	_input_handler.cell_hovered.connect(_on_cell_hovered)
	_input_handler.cell_cancelled.connect(_on_cell_cancelled)

	# hud
	_battle_hud.setup(BattleManager)
	_character_info.setup(null)

	# pathfinder
	_pathfinder.setup(_battle_grid)

	# cursor
	_cursor.setup(_cursor.get_node("CursorSprite"))

	# battle manager
	BattleManager.setup(_battle_grid, _battle_camera, _unit_mover, _unit_ability_executor)
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

# TODO: replace with proper spawn system driven by battle/GameState configuration
func _spawn_units() -> void:
	var marta = _spawn_unit(Vector3i(-6, 0, 1), load("res://Data/Units/Marta.tres"))
	var theo = _spawn_unit(Vector3i(-6, -3, 1), load("res://Data/Units/Theo.tres"))
	var player_units: Array[Unit] = [marta]
	var enemy_units: Array[Unit] = [theo]

	# load only items relevant to this battle into ItemRegistry
	var all_units: Array[Unit] = []
	all_units.append_array(player_units)
	all_units.append_array(enemy_units)

	_current_unit = player_units[0]
	_current_unit.ability_impact.connect(_on_ability_impact)

	ItemRegistry.load_items_for_battle(all_units, PartyManager.inventory)

	# resolve equipment and ability references so equipped_items[] and abilties[] is populated on each unit
	for unit in all_units:
		unit.data.resolve_equipment()
		print("resolving abilities...")
		unit.data.resolve_abilities()

	BattleManager.start_battle(player_units, enemy_units)

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
	return layer.to_global(layer.map_to_local(Vector2i(cell.x, cell.y)))

# finds the first valid reachable Vector3i cell matching the clicked Vector2i position
# returns null if no valid cell is found
func _find_reachable_cell(cell: Vector2i):
	for reachable_cell in _reachable_cells:
		if reachable_cell.x == cell.x and reachable_cell.y == cell.y:
			if _reachable_cells[reachable_cell] == true:
				return reachable_cell
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
	print("cell selected: ", cell)
	match BattleManager.current_state:
		BattleManager.BattleState.MOVE_SELECT:
			_previous_cell = _current_unit.grid_position
			var target = _find_reachable_cell(cell)
			if target != null:
				BattleManager.confirm_move(target)
		BattleManager.BattleState.TARGET_SELECT:
			var target = _find_reachable_cell(cell)
			if target != null:
				BattleManager.confirm_target(target)

# cancels the current sub-selection and returns to ACTION_SELECT
func _on_cell_cancelled() -> void:
	if (BattleManager.current_state == BattleManager.BattleState.ACTION_SELECT and
		_previous_cell != Vector3i(999,999,999)) and \
		not _current_unit.data.has_acted:
		_battle_grid.move_unit(_current_unit.grid_position, _previous_cell)
		_current_unit.global_position = grid_to_world(_previous_cell)
		_battle_camera.pan_to(grid_to_world(_previous_cell))
		_current_unit.reset_move()
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
			_current_unit = BattleManager.active_unit
			_current_move_query = _pathfinder.build_move_query(_current_unit.data, true)
			_reachable_cells = _pathfinder.get_cells_in_range(_current_unit.grid_position, _current_move_query, _current_unit)
			_reachable_cells.erase(_current_unit.grid_position)
			_highlight_manager.show_move_range(_reachable_cells, grid_to_world)
		BattleManager.BattleState.ACTION_SELECT:
			_highlight_manager.clear()
			_current_move_query = null
			_current_ability = null
		BattleManager.BattleState.ABILITIES_SELECT:
			pass
		BattleManager.BattleState.TARGET_SELECT:
			var query: RangeQuery = _pathfinder.build_ability_query(_current_ability)
			_reachable_cells = _pathfinder.get_cells_in_range(_current_unit.grid_position, query, _current_unit)
			_highlight_manager.show_move_range(_reachable_cells, grid_to_world)
		BattleManager.BattleState.RESOLVING:
			_highlight_manager.clear()
			if _current_unit.data.has_moved && _current_unit.data.has_acted:
				_previous_cell = Vector3i(999,999,999)

# connects the new active unit's signals to the HUD and updates camera and turn state
func _on_active_unit_changed(unit: Unit) -> void:
	# disconnect previous unit's signals from HUD
	if _previous_unit != null:
		if _previous_unit.move_consumed.is_connected(_battle_hud.move_consumed):
			_previous_unit.move_consumed.disconnect(_battle_hud.move_consumed)
		if _previous_unit.action_consumed.is_connected(_battle_hud.ability_consumed):
			_previous_unit.action_consumed.disconnect(_battle_hud.ability_consumed)
	# connect new unit's signals
	unit.move_consumed.connect(_battle_hud.move_consumed)
	unit.action_consumed.connect(_battle_hud.ability_consumed)
	_battle_hud.on_turn_changed(unit)
	_battle_camera.pan_to(grid_to_world(unit.grid_position))
	_previous_unit = unit

# =============================================================================
# ABILITY / MOVEMENT EXECUTION
# =============================================================================

# stores the selected ability for use when TARGET_SELECT state is entered
func _on_ability_selected(unit: Unit, ability: AbilityData) -> void:
	print("on ability selected")
	print("unit: ", unit.data.unit_name, "ability: ", ability.ability_name)
	_current_ability = ability

# resolves ability damage via ActionResolver and refreshes the character info panel
func _on_ability_impact() -> void:
	_unit_ability_executor.resolve_ability(_action_resolver)
	_character_info.refresh()

# kicks off unit movement animation via UnitMover using the cached move query
func _on_unit_moved(unit: Unit, to_cell: Vector3i) -> void:
	var steps = _pathfinder.get_movement_path(unit.grid_position, to_cell, _current_move_query, unit)
	_unit_mover.execute_movement(unit, steps, grid_to_world, _battle_camera)
	unit.consume_move()

# kicks off ability execution via UnitAbilityExecutor
func _on_unit_ability(caster: Unit, target_cell: Vector3i, ability: AbilityData, camera: BattleCamera) -> void:
	_unit_ability_executor.execute_ability(caster, target_cell, ability, camera)
	caster.consume_action()

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
