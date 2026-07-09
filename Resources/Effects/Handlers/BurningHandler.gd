class_name BurningHandler
extends EffectHandler

const EFFECT = EffectId.Id.BURNING
const TICK_DAMAGE_MULTIPLIER: float = 0.5

func _resolve_tile(tile: BattleTileData, instance: EffectInstance, context: EffectContext) -> void:
	if tile.has_effect(EffectId.Id.SOAKED):
		await context.executor.remove_effect(tile, EFFECT, EffectExecutor.RemovalReason.NEUTRALIZED)
		return

	# check threshold consequences before spreading
	if instance.ticks_active >= EffectRules.DURATION_THRESHOLD_TICKS.get(EFFECT, 999):
		var flat_neighbors = PropagationEngine.get_flat_neighbors(tile.cell, context.grid)
		for cell in flat_neighbors:
			var neighbor_tile = context.grid.get_tile(cell)
			if neighbor_tile != null and neighbor_tile.terrain_type == BattleTileData.TerrainType.STONE:
				await context.executor.apply_effect(neighbor_tile, EffectId.Id.REDHOT)
		if tile.terrain_type == BattleTileData.TerrainType.WOOD or tile.terrain_type == BattleTileData.TerrainType.GRASS or tile.terrain_type == BattleTileData.TerrainType.DRY_GRASS:
			context.executor.convert_terrain(tile, BattleTileData.TerrainType.ASH)
		# fire expires — do not spread
		await context.executor.remove_effect(tile, EFFECT, EffectExecutor.RemovalReason.EXPIRED)
		return

	# only spread if still alive
	var susceptible = EffectRules.SUSCEPTIBLE_TERRAIN.get(EFFECT, [])
	var new_cells = PropagationEngine.propagate_gradual(
		[tile.cell], context.grid, susceptible,
		func(from, to): return to.z >= from.z
	)

	for cell in new_cells:
		var neighbor_tile = context.grid.get_tile(cell)
		if neighbor_tile != null and not neighbor_tile.has_effect(EFFECT):
			await context.executor.apply_effect(neighbor_tile, EFFECT)

	var metal_neighbors = context.grid.get_effect_neighbors(tile.cell, true)
	if instance.ticks_active >= 2:
		for cell in metal_neighbors:
			var neighbor_tile = context.grid.get_tile(cell)
			if neighbor_tile != null and neighbor_tile.terrain_type == BattleTileData.TerrainType.METAL:
				await context.executor.apply_effect(neighbor_tile, EffectId.Id.REDHOT, 1)

	# ignite whatever is standing on this tile — unit or object alike
	var occupant = context.grid.get_actor_at(tile.cell)
	if occupant != null:
		var susceptible_terrain = EffectRules.SUSCEPTIBLE_TERRAIN.get(EFFECT, [])
		if susceptible_terrain.has(tile.terrain_type):
			await context.executor.apply_effect(occupant, EFFECT)

func _resolve_unit(unit: Unit, instance: EffectInstance, context: EffectContext) -> void:
	if unit.data.immunities.has(EFFECT):
		return
	var base_amount = int(Constants.BASE_DAMAGE_UNIT * TICK_DAMAGE_MULTIPLIER)
	if unit.data.weaknesses.has(EFFECT):
		base_amount *= 2
	var damage = EffectDamageResolver.resolve(unit, EFFECT, base_amount)
	await unit.apply_damage(damage)

# objects burn for the same tick damage units do
func _resolve_object(object: BattleObject, instance: EffectInstance, context: EffectContext) -> void:
	var base_amount = int(Constants.BASE_DAMAGE_UNIT * TICK_DAMAGE_MULTIPLIER)
	var damage = EffectDamageResolver.resolve(object, EFFECT, base_amount)
	await object.apply_damage(damage)

func on_unit_turn_end(actor, instance: EffectInstance, context: EffectContext) -> void:
	var tile = context.grid.get_tile(actor.grid_position)
	if tile == null:
		return
	var susceptible = EffectRules.SUSCEPTIBLE_TERRAIN.get(EFFECT, [])
	if susceptible.has(tile.terrain_type):
		await context.executor.apply_effect(tile, EFFECT, instance.rounds_remaining)
		
	if actor is Unit:
		_resolve_unit(actor, instance, context)
	if actor is BattleObject:
		_resolve_object(actor, instance, context)
	if actor is BattleTileData:
		push_error("Unit turn end called from tile. Tile: ", actor)
	#if

	#unit.apply_damage(damage)
