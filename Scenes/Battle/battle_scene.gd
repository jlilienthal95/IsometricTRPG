extends Node2D

const TILE_HEIGHT = 64
const UNIT_Y_OFFSET = 60	# shifts unit up to sit on tile surface
const UNIT_X_OFFSET = 5		# corrects horizontal centering of sprite

var _reachable_cells: Array[Vector3i] = []

func _ready() -> void:
	print('getting ready...')
	for i in range(15):
		var layer = $TerrainLayers.get_node("Elevation" + str(i))
		if layer:
			$BattleGrid.build_from_tilemap(layer, i)
			layer.z_index = i

	#set up input handling
	$InputHandler.setup($TerrainLayers/Elevation0)
	$InputHandler.cell_selected.connect(_on_cell_selected)
	$InputHandler.cell_hovered.connect(_on_cell_hovered)
	$InputHandler.cell_cancelled.connect(_on_cell_cancelled)
	
	#set up battleHUD
	$CanvasLayer/BattleHUD.setup($BattleManager)
	
	#set up pathfinder
	$Pathfinder.setup($BattleGrid)
	
	#set up highlight layer
	$HighlightManager.setup($HighlightLayer)
	
	#set up battle manager
	$BattleManager.setup($BattleGrid, $UnitMover)
	$BattleManager.state_changed.connect(_on_battle_state_changed)
	$BattleManager.unit_moved.connect(_on_unit_moved)
	$BattleManager.active_unit_changed.connect(_on_active_unit_changed)
	$BattleManager.move_consumed.connect($CanvasLayer/BattleHUD.move_consumed)
	$BattleManager.attack_consumed.connect($CanvasLayer/BattleHUD.attack_consumed)
	
	#set up unit mover
	$UnitMover.setup($BattleGrid)
	$UnitMover.movement_complete.connect(_on_movement_complete)
	
	#temp hardcoded logic to generate units
	var marta = _spawn_test_unit(Vector3i(-1,2,1), load("res://Data/Units/Marta.tres"))
	var theo = _spawn_test_unit(Vector3i(-2,2,1), load("res://Data/Units/Theo.tres"))
	var player_units: Array[Unit] = [marta,theo]
	var enemy_units: Array[Unit] = []
	var inventory: Array[int] = []
	
	# load items needed for this battle into ItemRegistry
	var all_units: Array[Unit] = []
	all_units.append_array(player_units)
	all_units.append_array(enemy_units)
	ItemRegistry.load_items_for_battle(all_units, PartyManager.inventory)

	# resolve equipment on all units so equipped_items is populated
	for unit in all_units:
		unit.data.resolve_equipment()
	
	
	$BattleManager.start_battle(player_units, enemy_units);
	print("setup complete")
	
func grid_to_world(cell: Vector3i) -> Vector2:
	var tile = $BattleGrid.get_tile(cell)
	if tile == null:
		return Vector2.ZERO
	var layer = $TerrainLayers.get_node("Elevation" + str(cell.z))
	var world_pos = layer.to_global(layer.map_to_local(Vector2i(cell.x, cell.y)))
	world_pos.y -= UNIT_Y_OFFSET
	world_pos.x += UNIT_X_OFFSET;
	return world_pos
	
func _on_cell_hovered(cell: Vector2i) -> void:
	pass
	
func _on_cell_selected(cell: Vector2i) -> void:
	print("cell selected: ", cell)
	match $BattleManager.current_state:
		BattleManager.BattleState.MOVE_SELECT:
			# find matching Vector3i in reachable cells
			for reachable_cell in _reachable_cells:
				if reachable_cell.x == cell.x and reachable_cell.y == cell.y:
					$BattleManager.confirm_move(reachable_cell)
					break
		BattleManager.BattleState.TARGET_SELECT:
			$BattleManager.confirm_target(Vector3i(cell.x, cell.y, 0))

func _on_cell_cancelled() -> void:
	$BattleManager.cancel_action()

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
func _on_battle_state_changed(new_state: BattleManager.BattleState) -> void:
	match new_state:
		BattleManager.BattleState.MOVE_SELECT:
			var unit = $BattleManager.active_unit
			var query = $Pathfinder.build_move_query(unit.data, true)
			_reachable_cells = $Pathfinder.get_cells_in_range(unit.grid_position, query, unit)
			_reachable_cells = _reachable_cells.filter(func(cell): 
				return cell != unit.grid_position
			)
			$HighlightManager.show_move_range(_reachable_cells)
			
		BattleManager.BattleState.ACTION_SELECT:
			$HighlightManager.clear()
		BattleManager.BattleState.TARGET_SELECT:
			$HighlightManager.clear()
		

func _on_unit_moved(unit: Unit, to_cell: Vector3i) -> void:
	var query = $Pathfinder.build_move_query(unit.data, true)
	var steps = $Pathfinder.get_movement_path(unit.grid_position, to_cell, query, unit)
	$UnitMover.execute_movement(unit, steps, grid_to_world, $BattleCamera)

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
	
