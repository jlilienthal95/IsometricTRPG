class_name EffectHandler
extends RefCounted

enum PropagationStyle {
	NONE,		# no spreading
	GRADUAL,	# spreads one tile per tick (fire)
	INSTANT,	# spreads to all susceptible neighbors immediately (electrified)
	PULSE,		# spreads outward in rings (shockwave)
	LINE,		# spreads in a straight line across terrain (wind, magnetics)
}

# returns this handler's effect id. Prefers the explicit EFFECT const —
# required for multi-word ids (ATTACK_DOWN etc.) where name-derivation fails —
# and falls back to deriving from the class name ("BurningHandler" -> BURNING).
func get_effect_id() -> EffectId.Id:
	var consts: Dictionary = get_script().get_script_constant_map()
	if consts.has("EFFECT"):
		return consts["EFFECT"]
	var class_name_str: String = get_script().get_global_name()
	var id_name: String = class_name_str.replace("Handler", "").to_upper()
	if EffectId.Id.has(id_name):
		return EffectId.Id[id_name]
	return EffectId.Id.NONE

func get_neutralizes() -> Array[EffectId.Id]:
	var result: Array[EffectId.Id] = []
	var found = EffectRules.NEUTRALIZE_MAP.get(get_effect_id(), [])
	for id in found:
		result.append(id)
	return result

# =============================================================================
# RESOLVE — single entry point, handles generic checks before dispatching
# to type-specific hooks. Subclasses override _resolve_* not this.
# =============================================================================

func resolve(target, instance: EffectInstance, context: EffectContext) -> void:
	# neutralization check — generic, runs for all targets
	var neutralizers = EffectRules.NEUTRALIZE_MAP.get(get_effect_id(), [])
	for neutralizer in neutralizers:
		if target.has_effect(neutralizer):
			await context.executor.remove_effect(target, get_effect_id(), EffectExecutor.RemovalReason.NEUTRALIZED)
			return

	if target is BattleTileData:
		# susceptibility check — extinguish if tile terrain can't sustain this effect
		var susceptible = EffectRules.SUSCEPTIBLE_TERRAIN.get(get_effect_id(), [])
		if not susceptible.is_empty() and not susceptible.has(target.terrain_type):
			await context.executor.remove_effect(target, get_effect_id(), EffectExecutor.RemovalReason.EXPIRED)
			return
		await _resolve_tile(target, instance, context)
	elif target is Unit or target is BattleObject:
		# immunity check — identical for both actor types since both read
		# immunities off the same BattleActorData base; a single check here
		# instead of one copy per branch
		if target.data.immunities.has(get_effect_id()):
			return
		if target is Unit:
			await _resolve_unit(target, instance, context)
		else:
			await _resolve_object(target, instance, context)

# =============================================================================
# TYPE-SPECIFIC HOOKS — override in subclasses
# =============================================================================

@warning_ignore("unused_parameter")
func _resolve_unit(unit: Unit, instance: EffectInstance, context: EffectContext) -> void:
	await _resolve_actor_damage(unit, context)

@warning_ignore("unused_parameter")
func _resolve_object(object: BattleObject, instance: EffectInstance, context: EffectContext) -> void:
	await _resolve_actor_damage(object, context)

func _resolve_tile(tile: BattleTileData, instance: EffectInstance, context: EffectContext) -> void:
	# if instant terrain conversion is necessary (like frozen), call conversion
	if get_propagation_config().converts_instantly:
		_call_tile_conversion(tile, context)
		
	if get_propagation_config().style != PropagationStyle.NONE:
		await _resolve_tile_propagation(tile, instance, context)
		
func on_unit_turn_end(actor, instance: EffectInstance, context: EffectContext) -> void:
	var config = get_propagation_config()
	if config.spreads_to_tile_on_turn_end:
		var tile = context.grid.get_tile(actor.grid_position)
		if tile != null:
			var susceptible = EffectRules.SUSCEPTIBLE_TERRAIN.get(get_effect_id(), [])
			if susceptible.has(tile.terrain_type):
				await _spread_effect(tile, get_effect_id(), context)
	await _dispatch_turn_end(actor, instance, context)
# =============================================================================
# PROPAGATION — generic spreading pipeline, driven by subclass overrides
# =============================================================================

# override to configure propagation behavior for this effect
func get_propagation_config() -> PropagationConfig:
	return PropagationConfig.new()
	
@warning_ignore("unused_parameter")
func on_actor_entered_tile(actor: BattleActor, tile: BattleTileData, instance: EffectInstance, context) -> void:
	await _spread_effect(actor, get_effect_id(), context)

# override to define what happens when ticks_active hits the threshold
@warning_ignore("unused_parameter")
func _on_threshold_reached(tile: BattleTileData, context: EffectContext) -> void:
	pass

# override to define per-neighbor interactions at tick >= 2
@warning_ignore("unused_parameter")
func _on_neighbor_tick(tile: BattleTileData, neighbor_tile: BattleTileData, context: EffectContext) -> void:
	pass

# generic spreading pipeline — call from _resolve_tile in subclasses that spread.
# handles threshold expiry, propagation style, neighbor tick interactions,
# and occupant spreading. subclasses only need to override the hooks above.
func _resolve_tile_propagation(tile: BattleTileData, instance: EffectInstance, context: EffectContext) -> void:
	var effect_id = get_effect_id()
	var config = get_propagation_config()

	# decrement-first effects expire before propagating — prevents instant effects re-spreading
	if config.decrement_before_propagation:
		if instance.rounds_remaining > 0:
			instance.rounds_remaining -= 1
		if instance.rounds_remaining == 0:
			@warning_ignore("redundant_await")
			await _on_threshold_reached(tile, context)
			await context.executor.remove_effect(tile, effect_id, EffectExecutor.RemovalReason.EXPIRED)
			# TODO: tile conversion goes here
			if get_propagation_config().converts_on_threshold:
				_call_tile_conversion(tile, context)
			return
	else:
		if instance.ticks_active >= EffectRules.DURATION_THRESHOLD_TICKS.get(effect_id, 999):
			@warning_ignore("redundant_await")
			await _on_threshold_reached(tile, context)
			await context.executor.remove_effect(tile, effect_id, EffectExecutor.RemovalReason.EXPIRED)
			if get_propagation_config().converts_on_threshold:
				_call_tile_conversion(tile, context)
			return

	# skip propagation until min_ticks_before_spread is reached
	if instance.ticks_active < config.min_ticks_before_spread:
		if config.spreads_to_occupants:
			await _spread_to_occupant(tile, effect_id, context)
		return

	var susceptible = EffectRules.SUSCEPTIBLE_TERRAIN.get(effect_id, [])
	match config.style:
		EffectHandler.PropagationStyle.GRADUAL:
			var new_cells = PropagationEngine.propagate_gradual(
				[tile.cell], context.grid, susceptible,
				func(from, to): return to.z >= from.z if not config.propagates_vertically else true
			)
			for cell in new_cells:
				var neighbor_tile = context.grid.get_tile(cell)
				if neighbor_tile != null:
					# if effect only propagates through liquid and terrain is not liquid, skip
					if config.spreads_to_liquid_only and not EffectRules.LIQUID_TERRAIN.has(neighbor_tile.terrain_type):
						continue
					await _spread_effect(neighbor_tile, effect_id, context)
		EffectHandler.PropagationStyle.INSTANT:
			var instant_neighbors = context.grid.get_effect_neighbors(tile.cell, config.propagates_vertically)
			for cell in instant_neighbors:
				var neighbor_tile = context.grid.get_tile(cell)
				if neighbor_tile != null and susceptible.has(neighbor_tile.terrain_type):
					await _spread_effect(neighbor_tile, effect_id, context)
		EffectHandler.PropagationStyle.PULSE:
			pass	# TODO: implement via PropagationEngine.propagate_pulse
		EffectHandler.PropagationStyle.NONE:
			pass

	var neighbors = context.grid.get_effect_neighbors(tile.cell, true)
	if instance.ticks_active >= 2:
		for cell in neighbors:
			var neighbor_tile = context.grid.get_tile(cell)
			if neighbor_tile != null:
				@warning_ignore("redundant_await")
				await _on_neighbor_tick(tile, neighbor_tile, context)

	if config.spreads_to_occupants:
		await _spread_to_occupant(tile, effect_id, context)

# =============================================================================
# SHARED HELPERS
# =============================================================================

@warning_ignore("unused_parameter")
func _resolve_actor_damage(actor: BattleActor, context: EffectContext) -> void:
	var config = get_propagation_config()
	if not config.deals_damage:
		return
	var base_amount = int(Constants.BASE_DAMAGE_UNIT * config.damage_multiplier)
	if config.respects_weaknesses and actor.data.weaknesses.has(get_effect_id()):
		base_amount *= 2
	var damage = EffectDamageResolver.resolve(actor, get_effect_id(), base_amount)
	@warning_ignore("redundant_await")
	await context.executor.apply_damage(actor,damage)

# safe spread — applies effect to target only if it doesn't already have it.
# use this instead of context.executor.apply_effect directly when spreading
# to neighbors so the duplicate-effect guard is never forgotten.
func _spread_effect(target, effect_id: EffectId.Id, context: EffectContext, ticks: int = -1) -> void:
	if target == null:
		return
	if target.has_effect(effect_id):
		DebugLog.effects("spread skipped — %s already present on target" % EffectId.Id.keys()[effect_id])
		return
	await context.executor.apply_effect(target, effect_id, ticks)

# spreads this effect to whoever occupies the given tile, respecting
# susceptible terrain rules — only ignites the occupant if the tile
# terrain is susceptible to this effect.
func _spread_to_occupant(tile: BattleTileData, effect_id: EffectId.Id, context: EffectContext) -> void:
	var occupant = context.grid.get_actor_at(tile.cell)
	if occupant == null:
		return
	var susceptible = EffectRules.SUSCEPTIBLE_TERRAIN.get(effect_id, [])
	if susceptible.is_empty() or susceptible.has(tile.terrain_type):
		await _spread_effect(occupant, effect_id, context)

# centralised turn-end dispatch — call from on_unit_turn_end instead of
# hand-rolling the if/elif so the await can never be accidentally omitted.
func _dispatch_turn_end(actor, instance: EffectInstance, context: EffectContext) -> void:
	if actor is Unit:
		await _resolve_unit(actor, instance, context)
	elif actor is BattleObject:
		await _resolve_object(actor, instance, context)

func _call_tile_conversion(tile: BattleTileData, context: EffectContext) -> void:
	context.executor.convert_terrain(tile, get_propagation_config().converts_terrain)
