class_name UnitMover
extends Node

signal movement_complete(unit: Unit)

var _grid: BattleGrid = null
var _is_moving: bool = false

# initializes the mover with a reference to the battle grid
func setup(grid: BattleGrid) -> void:
	_grid = grid

# begins step-by-step movement — guards against concurrent movement
func execute_movement(unit: Unit, steps: Array[MovementStep], get_world_pos: Callable, camera: BattleCamera) -> void:
	if _is_moving:
		push_error("UnitMover: movement already in progress")
		return
	_is_moving = true
	_execute_steps(unit, steps, get_world_pos, camera)

# moves the unit through each step, updating grid position, z_index, facing, and animation
func _execute_steps(unit: Unit, steps: Array[MovementStep], get_world_pos: Callable, camera: BattleCamera) -> void:
	for step in steps:
		var from = unit.grid_position
		_grid.move_unit(from, step.cell)
		unit.update_z_index()
		unit.set_facing_toward(from, step.cell)

		if step.is_jump:
			unit.play_jump()
		else:
			unit.play_walk()

		var target_pos = get_world_pos.call(step.cell)
		var tween = unit.create_tween()
		tween.tween_property(unit, "global_position", target_pos, 0.15)
		await tween.finished
		camera.pan_to(target_pos)

		# check if unit is standing under a water tile
		var above = Vector3i(step.cell.x - 1, step.cell.y - 1, step.cell.z + 1)
		print("above: ", above)
		var above_tile = _grid.get_tile(above)
		if above_tile:
			print("type: ", above_tile.terrain_type)
		if above_tile != null and above_tile.terrain_type == BattleTileData.TerrainType.WATER:
			print("water above!")
			unit.on_terrain_changed(BattleTileData.TerrainType.WATER)
		else:
			unit.on_terrain_changed(BattleTileData.TerrainType.NORMAL)
	unit.play_idle()
	_is_moving = false
	emit_signal("movement_complete", unit)
