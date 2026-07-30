class_name TerrainTurnProcessor
extends RefCounted

# Processes the terrain turn: every active terrain effect and every active
# object effect ticks once. This class knows nothing about cinematics —
# camera presentation is purely reactive (BattleEvents -> CinematicDirector).
# wait_until_idle() between ticks only serializes whatever reactive beats a
# tick happens to produce; it never forces a beat to occur.
func process_terrain_turn(grid: BattleGrid, effect_executor: EffectExecutor, director: CinematicDirector) -> void:
	var context = EffectContext.create(grid, effect_executor)
	var cell_work: Array = []
	for effect_id in grid.active_effect_cells.keys():
		for cell in grid.get_cells_with_effect(effect_id):
			cell_work.append([effect_id, cell])
	var object_work: Array = []
	for effect_id in grid.active_effect_objects.keys():
		for object in grid.get_objects_with_effect(effect_id):
			object_work.append([effect_id, object])

	print("[TTP] terrain turn — cell_work: ", cell_work.size(), " object_work: ", object_work.size())
	for entry in cell_work:
		print("[TTP] processing cell: ", entry[1], " effect: ", EffectId.Id.keys()[entry[0]])
		await _process_cell(grid, entry[1], entry[0], effect_executor, context)
		print("[TTP] cell processed — waiting for director idle")
		await director.wait_until_idle()
		print("[TTP] director idle after cell")

	for entry in object_work:
		print("[TTP] processing object effect: ", EffectId.Id.keys()[entry[0]])
		await _process_object(entry[1], entry[0], effect_executor, context)
		print("[TTP] object processed — waiting for director idle")
		await director.wait_until_idle()
		print("[TTP] director idle after object")
	print("[TTP] terrain turn complete")

func _process_cell(grid: BattleGrid, cell: Vector3i, effect_id: EffectId.Id, effect_executor: EffectExecutor, context: EffectContext) -> void:
	var tile = grid.get_tile(cell)
	if tile == null:
		print("[TTP:_process_cell] tile null at: ", cell)
		return
	var instance = tile.get_effect(effect_id)
	if instance == null:
		print("[TTP:_process_cell] no instance for effect: ", EffectId.Id.keys()[effect_id], " at: ", cell)
		return
	print("[TTP:_process_cell] ticking — cell: ", cell, " effect: ", EffectId.Id.keys()[effect_id], " ticks_active: ", instance.ticks_active, " rounds_remaining: ", instance.rounds_remaining)
	await effect_executor.process_tick(tile, instance, context, true)
	print("[TTP:_process_cell] tick complete — cell: ", cell)

func _process_object(object: BattleObject, effect_id: EffectId.Id, effect_executor: EffectExecutor, context: EffectContext) -> void:
	if not is_instance_valid(object) or object.data.is_dead:
		return
	var instance = object.get_effect(effect_id)
	if instance == null:
		return
	await effect_executor.process_tick(object, instance, context, true)
