class_name BurningHandler
extends EffectHandler

const EFFECT = EffectId.Id.BURNING
const TICK_DAMAGE_MULTIPLIER: float = 0.5

func _resolve_tile(tile: BattleTileData, instance: EffectInstance, context: EffectContext) -> void:
	# ash, stone, metal and other non-flammable terrain should never sustain fire —
	# if fire somehow ended up on an incompatible tile, extinguish it immediately
	var susceptible = EffectRules.SUSCEPTIBLE_TERRAIN.get(EFFECT, [])
	if not susceptible.has(tile.terrain_type):
		print("[BH:resolve_tile] non-susceptible terrain: ", BattleTileData.TerrainType.keys()[tile.terrain_type], " — extinguishing")
		await context.executor.remove_effect(tile, EFFECT, EffectExecutor.RemovalReason.EXPIRED)
		return

	if tile.has_effect(EffectId.Id.SOAKED):
		await context.executor.remove_effect(tile, EFFECT, EffectExecutor.RemovalReason.NEUTRALIZED)
		return
		
	if instance.ticks_active >= EffectRules.DURATION_THRESHOLD_TICKS.get(EFFECT, 999):
		var flat_neighbors = PropagationEngine.get_flat_neighbors(tile.cell, context.grid)
		for cell in flat_neighbors:
			var neighbor_tile = context.grid.get_tile(cell)
			if neighbor_tile != null and neighbor_tile.terrain_type == BattleTileData.TerrainType.STONE:
				await _spread_effect(neighbor_tile, EffectId.Id.REDHOT, context)
		if tile.terrain_type == BattleTileData.TerrainType.WOOD or \
		tile.terrain_type == BattleTileData.TerrainType.GRASS or \
		tile.terrain_type == BattleTileData.TerrainType.DRY_GRASS:
			context.executor.convert_terrain(tile, BattleTileData.TerrainType.ASH)
		await context.executor.remove_effect(tile, EFFECT, EffectExecutor.RemovalReason.EXPIRED)
		return

	var new_cells = PropagationEngine.propagate_gradual(
		[tile.cell], context.grid, susceptible,
		func(from, to): return to.z >= from.z
	)
	for cell in new_cells:
		var neighbor_tile = context.grid.get_tile(cell)
		if neighbor_tile != null:
			await _spread_effect(neighbor_tile, EFFECT, context)

	var metal_neighbors = context.grid.get_effect_neighbors(tile.cell, true)
	if instance.ticks_active >= 2:
		for cell in metal_neighbors:
			var neighbor_tile = context.grid.get_tile(cell)
			if neighbor_tile != null and neighbor_tile.terrain_type == BattleTileData.TerrainType.METAL:
				await _spread_effect(neighbor_tile, EffectId.Id.REDHOT, context, 1)

	var occupant = context.grid.get_actor_at(tile.cell)
	if occupant != null:
		var susceptible_terrain = EffectRules.SUSCEPTIBLE_TERRAIN.get(EFFECT, [])
		if susceptible_terrain.has(tile.terrain_type):
			await _spread_effect(occupant, EFFECT, context)

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
	print("[BH:turn_end] tile: ", tile.cell, " terrain: ", BattleTileData.TerrainType.keys()[tile.terrain_type], " susceptible: ", susceptible.has(tile.terrain_type))
	if susceptible.has(tile.terrain_type):
		# use _spread_effect — it won't refresh duration on an existing instance,
		# and won't re-apply if already burning
		await _spread_effect(tile, EFFECT, context)
	await _dispatch_turn_end(actor, instance, context)
