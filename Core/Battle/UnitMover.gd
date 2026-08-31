class_name UnitMover
extends Node

# Executes step-by-step grid movement for ANY battle actor — units walking,
# but also objects being pushed, rolled, or sliding on ice. Actors implement
# the shared movement interface (play_walk/play_jump/play_idle,
# set_facing_toward, update_z_index, set_effect_alpha, on_terrain_changed);
# BattleObject stubs the visual calls it doesn't need.

signal movement_complete(actor)

var _grid: BattleGrid = null
var _is_moving: bool = false
var is_interrupted: bool = false
var direction: Vector3i = Vector3i(999,999,999)

func setup(grid: BattleGrid) -> void:
	_grid = grid

func execute_movement(actor, steps: Array[MovementStep], get_world_pos: Callable, camera: BattleCamera) -> void:
	if _is_moving:
		push_error("UnitMover: movement already in progress")
		return
	_is_moving = true
	is_interrupted = false
	_execute_steps(actor, steps, get_world_pos, camera)

func _execute_steps(actor, steps: Array[MovementStep], get_world_pos: Callable, camera: BattleCamera) -> void:
	for step in steps:
		# restore alpha to neutral — refresh_tile_occupancy will re-dim if needed
		actor.set_effect_alpha(1.0)
		var from = actor.grid_position
		if is_interrupted:
			var delta = step.cell - from
			direction = Vector3i(sign(delta.x), sign(delta.y), 0)
			continue
		direction = Vector3i(999,999,999)
		_grid.move_actor(actor, from, step.cell)
		actor.update_z_index()
		actor.set_facing_toward(from, step.cell)
		if step.is_jump:
			actor.play_jump()
		else:
			actor.play_walk()
		var target_pos = get_world_pos.call(step.cell)
		var tween = actor.create_tween()
		tween.tween_property(actor, "global_position", target_pos, 0.15)
		await tween.finished
		camera.pan_to(target_pos)

		# check water tile above
		var above = Vector3i(step.cell.x - 1, step.cell.y - 1, step.cell.z + 1)
		var above_tile = _grid.get_tile(above)
		if above_tile != null and above_tile.terrain_type == BattleTileData.TerrainType.WATER:
			actor.on_terrain_changed(BattleTileData.TerrainType.WATER)
		else:
			actor.on_terrain_changed(BattleTileData.TerrainType.NORMAL)

	actor.play_idle()
	_is_moving = false
	emit_signal("movement_complete", actor)
