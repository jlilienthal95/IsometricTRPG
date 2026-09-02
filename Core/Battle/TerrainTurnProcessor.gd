class_name TerrainTurnProcessor
extends RefCounted

# Processes the terrain turn: every active terrain effect and every active
# object effect ticks once. This class knows nothing about cinematics —
# camera presentation is purely reactive (BattleEvents -> CinematicDirector).
# wait_until_idle() between ticks only serializes whatever reactive beats a
# tick happens to produce; it never forces a beat to occur.
func process_terrain_turn(grid: BattleGrid, mover: UnitMover, effect_executor: EffectExecutor, director: CinematicDirector) -> void:
	var context = EffectContext.create(grid, mover, effect_executor)
	
	var cell_work: Array = []
	for effect_id in grid.active_effect_cells.keys():
		for cell in grid.get_cells_with_effect(effect_id):
			cell_work.append([effect_id, cell])
	var object_work: Array = []
	for effect_id in grid.active_effect_objects.keys():
		for object in grid.get_objects_with_effect(effect_id):
			object_work.append([effect_id, object])

	# Arm a lazy cinematic sequence: it opens only if a tick actually produces
	# a beat (an effect applied/removed, damage dealt). A terrain turn that just
	# re-ticks static frozen/slippery tiles adds and removes nothing, so no
	# sequence opens and the camera stays put.
	director.begin_batch()

	for entry in cell_work:
		await _process_cell(grid, entry[1], entry[0], effect_executor, context)
		await director.wait_until_idle()

	for entry in object_work:
		await _process_object(entry[1], entry[0], effect_executor, context)
		await director.wait_until_idle()

	await director.end_batch()

func _process_cell(grid: BattleGrid, cell: Vector3i, effect_id: EffectId.Id, effect_executor: EffectExecutor, context: EffectContext) -> void:
	var tile = grid.get_tile(cell)
	if tile == null:
		return
	var instance = tile.get_effect(effect_id)
	if instance == null:
		return
	await effect_executor.process_tick(tile, instance, context, true)

func _process_object(object: BattleObject, effect_id: EffectId.Id, effect_executor: EffectExecutor, context: EffectContext) -> void:
	if not is_instance_valid(object) or object.data.is_dead:
		return
	var instance = object.get_effect(effect_id)
	if instance == null:
		return
	await effect_executor.process_tick(object, instance, context, true)
