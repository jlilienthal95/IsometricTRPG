class_name UnitMover
extends Node

signal movement_complete(unit: Unit)

var _grid: BattleGrid = null
var _is_moving: bool = false

func setup(grid: BattleGrid) -> void:
	_grid = grid

func execute_movement(unit: Unit, steps: Array[MovementStep], get_world_pos: Callable, camera: BattleCamera) -> void:
	if _is_moving:
		push_error("UnitMover: movement already in progress")
		return
	_is_moving = true
	_execute_steps(unit, steps, get_world_pos, camera)

func _execute_steps(unit: Unit, steps: Array[MovementStep], get_world_pos: Callable, camera: BattleCamera) -> void:
	for step in steps:
		# update grid position
		var from = unit.grid_position
		_grid.move_unit(from, step.cell)
		unit.update_z_index()
		
		# flip unit horizontally depending on movement direction
		if (from.x > step.cell.x || from.y < step.cell.y) && from.z == step.cell.z:
			unit.set_facing(true)
		else:
			unit.set_facing(false)
			
		# choose animation based on step type
		if step.is_jump:
			unit.play_jump()
		else:
			unit.play_walk()
		
		# tween to next world position
		var target_pos = get_world_pos.call(step.cell)
		var tween = unit.create_tween()
		tween.tween_property(unit, "global_position", target_pos, 0.15)
		await tween.finished
		camera.pan_to(target_pos)
	
	unit.play_idle()
	_is_moving = false
	emit_signal("movement_complete", unit)
