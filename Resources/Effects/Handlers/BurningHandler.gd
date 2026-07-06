class_name BurningHandler
extends EffectHandler

const TICK_DAMAGE_MULTIPLIER: float = 0.8

func _resolve_tile(tile: BattleTileData, instance: EffectInstance, context: EffectContext) -> void:
	if tile.has_effect(EffectId.Id.SOAKED):
		await context.executor.remove_effect(tile, EffectId.Id.BURNING, EffectExecutor.RemovalReason.NEUTRALIZED)
		return

	# check threshold consequences before spreading
	if instance.ticks_active >= EffectRules.DURATION_THRESHOLD_TICKS.get(EffectId.Id.BURNING, 999):
		var flat_neighbors = PropagationEngine.get_flat_neighbors(tile.cell, context.grid)
		for cell in flat_neighbors:
			var neighbor_tile = context.grid.get_tile(cell)
			if neighbor_tile != null and neighbor_tile.terrain_type == BattleTileData.TerrainType.STONE:
				context.executor.convert_terrain(neighbor_tile, BattleTileData.TerrainType.LAVA)
		if tile.terrain_type == BattleTileData.TerrainType.WOOD or tile.terrain_type == BattleTileData.TerrainType.GRASS or tile.terrain_type == BattleTileData.TerrainType.DRY_GRASS:
			context.executor.convert_terrain(tile, BattleTileData.TerrainType.ASH)
		# fire expires — do not spread
		await context.executor.remove_effect(tile, EffectId.Id.BURNING, EffectExecutor.RemovalReason.EXPIRED)
		return

	# only spread if still alive
	var susceptible = EffectRules.SUSCEPTIBLE_TERRAIN.get(EffectId.Id.BURNING, [])
	var new_cells = PropagationEngine.propagate_gradual(
		[tile.cell], context.grid, susceptible,
		func(from, to): return to.z >= from.z
	)
	
	for cell in new_cells:
		var neighbor_tile = context.grid.get_tile(cell)
		if neighbor_tile != null and not neighbor_tile.has_effect(EffectId.Id.BURNING):
			await context.executor.apply_effect(neighbor_tile, EffectId.Id.BURNING)

	var metal_neighbors = context.grid.get_effect_neighbors(tile.cell, true)
	if instance.ticks_active >= 2:
		for cell in metal_neighbors:
			var neighbor_tile = context.grid.get_tile(cell)
			if neighbor_tile != null and neighbor_tile.terrain_type == BattleTileData.TerrainType.METAL:
				await context.executor.apply_effect(neighbor_tile, EffectId.Id.REDHOT, 1)

	if tile.unit_ref != null:
		var susceptible_terrain = EffectRules.SUSCEPTIBLE_TERRAIN.get(EffectId.Id.BURNING, [])
		if susceptible_terrain.has(tile.terrain_type):
			await context.executor.apply_effect(tile.unit_ref, EffectId.Id.BURNING)

func _resolve_unit(unit: Unit, instance: EffectInstance, context: EffectContext) -> void:
	print("unit ", unit.data.unit_name, " is burning!")
	var base_amount = int(Constants.BASE_DAMAGE_UNIT * TICK_DAMAGE_MULTIPLIER)
	var damage = EffectDamageResolver.resolve(unit, EffectId.Id.BURNING, base_amount)
	unit.adjust_hp(damage)

func on_unit_turn_end(unit: Unit, instance: EffectInstance, context: EffectContext) -> void:
	var tile = context.grid.get_tile(unit.grid_position)
	if tile == null:
		return
	var susceptible = EffectRules.SUSCEPTIBLE_TERRAIN.get(EffectId.Id.BURNING, [])
	if susceptible.has(tile.terrain_type):
		await context.executor.apply_effect(tile, EffectId.Id.BURNING, instance.rounds_remaining)
