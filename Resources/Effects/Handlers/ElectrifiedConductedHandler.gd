class_name ElectrifiedConductedHandler
extends EffectHandler

const EFFECT = EffectId.Id.ELECTRIFIED_CONDUCTED

func get_propagation_config() -> PropagationConfig:
	var config = PropagationConfig.new()
	config.style = EffectHandler.PropagationStyle.INSTANT
	config.propagates_vertically = true
	config.decrement_before_propagation = true
	config.spreads_to_occupants = true
	config.min_ticks_before_spread = 0
	return config

func _resolve_tile(tile: BattleTileData, instance: EffectInstance, context: EffectContext) -> void:
	await _resolve_tile_propagation(tile, instance, context)

func on_actor_entered_tile(actor: BattleActor, tile: BattleTileData, instance: EffectInstance, context: EffectContext) -> void:
	# conducted tile — spread real ELECTRIFIED to the actor, not the conducted marker
	await _spread_effect(actor, EffectId.Id.ELECTRIFIED, context)
	# actor spreads CONDUCTED to any susceptible neighbors
	var susceptible = EffectRules.SUSCEPTIBLE_TERRAIN.get(EffectId.Id.ELECTRIFIED, [])
	var neighbors = context.grid.get_effect_neighbors(actor.grid_position, true)
	for cell in neighbors:
		var neighbor_tile = context.grid.get_tile(cell)
		if neighbor_tile != null and susceptible.has(neighbor_tile.terrain_type):
			await _spread_effect(neighbor_tile, EFFECT, context, 1)

func on_unit_turn_end(unit: Unit, instance: EffectInstance, context: EffectContext) -> void:
	await _dispatch_turn_end(unit, instance, context)
