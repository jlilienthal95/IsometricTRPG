class_name TerrainTurnProcessor
extends RefCounted

# Processes the terrain turn: every active terrain effect and every active
# object effect ticks once.
#
# Iteration-safety: handlers MUTATE the effect indices mid-turn (fire spreads
# to new cells, effects expire and unregister). Iterating the live dictionaries
# would skip/duplicate entries — so we snapshot the full work list up front.
# A snapshot also gives correct game semantics: cells ignited THIS terrain turn
# do not tick until the NEXT one.
func process_terrain_turn(grid: BattleGrid, effect_executor: EffectExecutor, camera: BattleCamera, scene_tree: SceneTree, get_world_pos: Callable, director: CinematicDirector = null) -> void:
	var context = EffectContext.create(grid, effect_executor)

	# snapshot: [ [effect_id, cell], ... ] and [ [effect_id, object], ... ]
	var cell_work: Array = []
	for effect_id in grid.active_effect_cells.keys():
		for cell in grid.get_cells_with_effect(effect_id):
			cell_work.append([effect_id, cell])
	var object_work: Array = []
	for effect_id in grid.active_effect_objects.keys():
		for object in grid.get_objects_with_effect(effect_id):
			object_work.append([effect_id, object])

	for entry in cell_work:
		await _process_cell(grid, entry[1], entry[0], effect_executor, camera, scene_tree, get_world_pos, context)
		if director != null:
			await director.wait_until_idle()

	for entry in object_work:
		await _process_object(entry[1], entry[0], effect_executor, camera, scene_tree, context)
		if director != null:
			await director.wait_until_idle()

func _process_cell(grid: BattleGrid, cell: Vector3i, effect_id: EffectId.Id, effect_executor: EffectExecutor, camera: BattleCamera, scene_tree: SceneTree, get_world_pos: Callable, context: EffectContext) -> void:
	var tile = grid.get_tile(cell)
	if tile == null:
		return
	# the effect may have been neutralized/expired earlier this same turn
	var instance = tile.get_effect(effect_id)
	if instance == null:
		return
	#await camera.pan_to(get_world_pos.call(cell))
	#await scene_tree.create_timer(1).timeout
	await effect_executor.process_tick(tile, instance, context, true)

func _process_object(object: BattleObject, effect_id: EffectId.Id, effect_executor: EffectExecutor, camera: BattleCamera, scene_tree: SceneTree, context: EffectContext) -> void:
	if not is_instance_valid(object) or object.data.is_dead:
		return
	var instance = object.get_effect(effect_id)
	if instance == null:
		return
	await camera.pan_to(object.global_position)
	await scene_tree.create_timer(1).timeout
	await effect_executor.process_tick(object, instance, context, true)
