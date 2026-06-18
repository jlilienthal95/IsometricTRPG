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
		# TODO: Z index flickers during tween as unit passes through cells with different
		# occlusion rules. Fix by interpolating Z index based on actual world position.

		# flip unit to face the direction of movement
		if (from.x > step.cell.x or from.y < step.cell.y) and from.z == step.cell.z:
			unit.set_facing(true)
		else:
			unit.set_facing(false)

		# play appropriate animation for step type
		if step.is_jump:
			unit.play_jump()
		else:
			unit.play_walk()

		# tween unit to next world position
		var target_pos = get_world_pos.call(step.cell)
		var tween = unit.create_tween()
		tween.tween_property(unit, "global_position", target_pos, 0.15)
		await tween.finished
		camera.pan_to(target_pos)

	unit.play_idle()
	_is_moving = false
	emit_signal("movement_complete", unit)
