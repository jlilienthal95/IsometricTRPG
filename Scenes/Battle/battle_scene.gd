extends Node2D

const TILE_HEIGHT = 64
const UNIT_Y_OFFSET = 60	# shifts unit up to sit on tile surface
const UNIT_X_OFFSET = 5		# corrects horizontal centering of sprite

func _ready() -> void:
	for i in range(15):
		var layer = $TerrainLayers.get_node("Elevation" + str(i))
		if layer:
			$BattleGrid.build_from_tilemap(layer, i)

	#setup input handling
	$InputHandler.setup($TerrainLayers/Elevation0)
	$InputHandler.cell_selected.connect(_on_cell_selected)
	$InputHandler.cell_hovered.connect(_on_cell_hovered)
	$InputHandler.cell_cancelled.connect(_on_cell_cancelled)
	
	#setup battleHUD
	$BattleHUD.setup($BattleManager)
	
	#temp hardcoded logic to generate units
	var unit = _spawn_test_unit()
	var player_units: Array[Unit] = [unit];
	var enemy_units: Array[Unit] = [];
	
	$BattleManager.start_battle(player_units, enemy_units);
	
func _on_cell_hovered(cell: Vector2i) -> void:
	pass
	
func _on_cell_selected(cell: Vector2i) -> void:
	print("cell selected:")
	var tile = $BattleGrid.get_tile(cell)
	if tile == null:
		return
	match $BattleManager.current_state:
		BattleManager.BattleState.MOVE_SELECT:
			$BattleManager.confirm_move(cell)
		BattleManager.BattleState.TARGET_SELECT:
			$BattleManager.confirm_target(cell)

func _on_cell_cancelled() -> void:
	$BattleManager.cancel_action()

func _debug_print_grid():
	for cell in $BattleGrid.get_all_cells():
		var tile = $BattleGrid.get_tile(cell)
		print(cell, " → elevation: ", tile.elevation, " terrain: ", tile.terrain_type, " is_walkable: ", str(tile.is_walkable));

func _spawn_test_unit() -> Unit:
	var unit_scene = preload("res://Scenes/Battle/Unit.tscn")
	var unit = unit_scene.instantiate()
	add_child(unit)
	var test_cell = Vector2i(-1, 2)
	unit.global_position = grid_to_world(test_cell)
	var test_data = UnitData.new()
	test_data.unit_name = "Test Unit"
	unit.setup(test_data, test_cell)
	$BattleGrid.place_unit(unit, test_cell)
	$BattleCamera.snap_to(unit.global_position)
	print(unit);
	return unit

func grid_to_world(cell: Vector2i) -> Vector2:
	var tile = $BattleGrid.get_tile(cell)
	if tile == null:
		return Vector2.ZERO
	var layer = $TerrainLayers.get_node("Elevation" + str(tile.elevation))
	var world_pos = layer.to_global(layer.map_to_local(cell))
	world_pos.y -= UNIT_Y_OFFSET
	world_pos.x += UNIT_X_OFFSET;
	return world_pos
	
