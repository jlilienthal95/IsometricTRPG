extends Node2D

const TILE_HEIGHT = 64
		# corrects horizontal centering of sprite

var _reachable_cells: Dictionary = {}
var _current_move_query: RangeQuery = null
var _current_ability: AbilityData = null

func _ready() -> void:
	print('getting ready...')
	for i in range(15):
		var layer = $TerrainLayers.get_node("Elevation" + str(i))
		if layer:
			$BattleGrid.build_from_tilemap(layer, i)
			layer.z_index = i * 4
			
			
	$BattleGrid.build_occlusion_map()

	#set up input handling
	$InputHandler.setup($TerrainLayers/Elevation0)
	$InputHandler.cell_selected.connect(_on_cell_selected)
	$InputHandler.cell_hovered.connect(_on_cell_hovered)
	$InputHandler.cell_cancelled.connect(_on_cell_cancelled)
	
	#set up battleHUD
	$CanvasLayer/BattleHUD.setup(BattleManager)
	
	#set up pathfinder
	$Pathfinder.setup($BattleGrid)
	
	#set up highlight layer
	#$HighlightManager.setup($HighlightLayer)
	
	#set up cursor
	$Cursor.setup($Cursor/CursorSprite)
	
	#set up battle manager
	BattleManager.setup($BattleGrid, $BattleCamera, $UnitMover, $UnitAbilityExecutor)
	BattleManager.state_changed.connect(_on_battle_state_changed)
	BattleManager.active_unit_changed.connect(_on_active_unit_changed)
	#battle manager actions
	BattleManager.unit_moved.connect(_on_unit_moved)
	BattleManager.move_consumed.connect($CanvasLayer/BattleHUD.move_consumed)
	BattleManager.ability_selected.connect(_on_ability_selected)
	BattleManager.unit_executed_ability.connect(_on_unit_ability)
	BattleManager.attack_consumed.connect($CanvasLayer/BattleHUD.attack_consumed)
	
	#set up unit mover
	$UnitMover.setup($BattleGrid)
	$UnitMover.movement_complete.connect(_on_movement_complete)
	
	#temp hardcoded logic to generate units
	var marta = _spawn_test_unit(Vector3i(-6,0,1), load("res://Data/Units/Marta.tres"))
	var theo = _spawn_test_unit(Vector3i(-6,-3,1), load("res://Data/Units/Theo.tres"))
	var player_units: Array[Unit] = [marta]
	var enemy_units: Array[Unit] = [theo]
	var inventory: Array[int] = []
	
	# load items needed for this battle into ItemRegistry
	var all_units: Array[Unit] = []
	all_units.append_array(player_units)
	all_units.append_array(enemy_units)
	ItemRegistry.load_items_for_battle(all_units, PartyManager.inventory)

	# resolve equipment on all units so equipped_items is populated
	for unit in all_units:
		unit.data.resolve_equipment()
		#TODO resolve abilities
	
	BattleManager.start_battle(player_units, enemy_units);
	print("setup complete")
	
func grid_to_world(cell: Vector3i) -> Vector2:
	var tile = $BattleGrid.get_tile(cell)
	if tile == null:
		return Vector2.ZERO
	var layer = $TerrainLayers.get_node("Elevation" + str(cell.z))
	var world_pos = layer.to_global(layer.map_to_local(Vector2i(cell.x, cell.y)))
	return world_pos
	
func _on_cell_hovered(cell: Vector2i) -> void:
	var tile = $BattleGrid.get_tile_at_highest_elevation(cell)
	if tile == null:
		if $Cursor.is_visible:
			$Cursor.hide_cursor()
		return
	var destination = grid_to_world(Vector3i(cell.x, cell.y, tile.elevation))
	if not $Cursor.is_visible:
		$Cursor.show_cursor()
	$Cursor.move_cursor(destination)
	
func _find_reachable_cell(cell: Vector2i):
	for reachable_cell in _reachable_cells:
		if reachable_cell.x == cell.x and reachable_cell.y == cell.y:
			if _reachable_cells[reachable_cell] == true:
				return reachable_cell
	return null

func _on_cell_selected(cell: Vector2i) -> void:
	print("cell selected: ", cell)
	match BattleManager.current_state:
		BattleManager.BattleState.MOVE_SELECT:
			var target = _find_reachable_cell(cell)
			if target != null:
				BattleManager.confirm_move(target)
		BattleManager.BattleState.TARGET_SELECT:
			var target = _find_reachable_cell(cell)
			if target != null:
				BattleManager.confirm_target(target)

func _on_cell_cancelled() -> void:
	BattleManager.cancel_action()

func _debug_print_grid():
	for cell in $BattleGrid.get_all_cells():
		var tile = $BattleGrid.get_tile(cell)
		print(cell, " → elevation: ", tile.elevation, " terrain: ", tile.terrain_type, " is_walkable: ", str(tile.is_walkable));

func _spawn_test_unit(test_cell: Vector3i, unit_data: UnitData) -> Unit:
	var unit_scene = preload("res://Scenes/Battle/Unit.tscn")
	var unit: Unit = unit_scene.instantiate()
	unit.global_position = grid_to_world(test_cell)
	#print(unit_data.unit_name)
	add_child(unit)
	unit.setup(unit_data, test_cell)
	$BattleGrid.place_unit(unit, test_cell)
	$BattleCamera.snap_to(unit.global_position)
	return unit
	
func _on_ability_selected(unit: Unit, ability: AbilityData) -> void:
	_current_ability = ability
	
func _on_battle_state_changed(new_state: BattleManager.BattleState) -> void:
	match new_state:
		BattleManager.BattleState.MOVE_SELECT:
			var unit = BattleManager.active_unit
			_current_move_query = $Pathfinder.build_move_query(unit.data, true)
			_reachable_cells = $Pathfinder.get_cells_in_range(unit.grid_position, _current_move_query, unit)
			#_reachable_cells = _reachable_cells.filter(func(cell): 
				#return cell != unit.grid_position
			#)
			_reachable_cells.erase(unit.grid_position)
			$HighlightManager.show_move_range(_reachable_cells, grid_to_world)
		BattleManager.BattleState.ACTION_SELECT:
			$HighlightManager.clear()
			_current_move_query = null
			_current_ability = null
		BattleManager.BattleState.ATTACK_SELECT:
			pass
		BattleManager.BattleState.TARGET_SELECT:
			var unit = BattleManager.active_unit
			var query: RangeQuery = $Pathfinder.build_ability_query(_current_ability)
			_reachable_cells = $Pathfinder.get_cells_in_range(unit.grid_position, query, unit)
			$HighlightManager.show_move_range(_reachable_cells, grid_to_world)
		BattleManager.BattleState.RESOLVING:
			pass

func _on_unit_moved(unit: Unit, to_cell: Vector3i) -> void:
	var steps = $Pathfinder.get_movement_path(unit.grid_position, to_cell, _current_move_query, unit)
	$UnitMover.execute_movement(unit, steps, grid_to_world, $BattleCamera)

func _on_unit_ability(caster: Unit, target_cell: Vector3i, ability: AbilityData, camera: BattleCamera) -> void:
	print("executing ability...")
	$UnitAbilityExecutor.execute_ability(caster, target_cell, ability, camera)

var _previous_unit: Unit = null

func _on_active_unit_changed(unit: Unit) -> void:
	# disconnect previous unit
	if _previous_unit != null:
		if _previous_unit.move_consumed.is_connected($CanvasLayer/BattleHUD.move_consumed):
			_previous_unit.move_consumed.disconnect($CanvasLayer/BattleHUD.move_consumed)
		if _previous_unit.action_consumed.is_connected($CanvasLayer/BattleHUD.attack_consumed):
			_previous_unit.action_consumed.disconnect($CanvasLayer/BattleHUD.attack_consumed)
	# connect new unit
	unit.move_consumed.connect($CanvasLayer/BattleHUD.move_consumed)
	unit.action_consumed.connect($CanvasLayer/BattleHUD.attack_consumed)
	$CanvasLayer/BattleHUD.on_turn_changed(unit.data.equipped_items)
	$BattleCamera.pan_to(grid_to_world(unit.grid_position))
	_previous_unit = unit
	
func _on_movement_complete(unit: Unit) -> void:
	print("movement complete: ", unit.data.unit_name)
	
