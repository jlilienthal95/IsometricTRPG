class_name TerrainTurnProcessor
extends RefCounted

func process_terrain_turn(grid: BattleGrid, effect_executor: EffectExecutor, camera: BattleCamera, scene_tree: SceneTree, get_world_pos: Callable) -> void:
	var context = EffectContext.create(grid, effect_executor)
	for effect_id in grid.active_effect_cells:
		var cells = grid.get_cells_with_effect(effect_id)
		for cell in cells:
			await _process_cell(grid, cell, effect_id, effect_executor, camera, scene_tree, get_world_pos, context)

func _process_cell(grid: BattleGrid, cell: Vector3i, effect_id: EffectId.Id, effect_executor: EffectExecutor, camera: BattleCamera, scene_tree: SceneTree, get_world_pos: Callable, context: EffectContext) -> void:
	var tile = grid.get_tile(cell)
	if tile == null:
		return
	await camera.pan_to(get_world_pos.call(cell))
	for effect in tile.active_effects.duplicate():
		await scene_tree.create_timer(1).timeout
		if effect.effect_id == effect_id:
			await effect_executor.process_tick(tile, effect, context, true)
