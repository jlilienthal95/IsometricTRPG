class_name ElectrifiedHandler
extends EffectHandler

# Stub handler for ELECTRIFIED — registered so the effect system has full coverage,
# with no behavior yet. Implement the hooks below as the effect is designed.

const EFFECT = EffectId.Id.ELECTRIFIED

func _resolve_tile(tile: BattleTileData, instance: EffectInstance, context: EffectContext) -> void:
	print("resolve tile: eletrified_conducted")
	await _resolve_tile_propagation(tile, instance, context)

func on_unit_turn_end(unit: Unit, instance: EffectInstance, context: EffectContext) -> void:
	pass

func get_propagation_config() -> PropagationConfig:
	var config = PropagationConfig.new()
	config.style = EffectHandler.PropagationStyle.INSTANT
	config.propagates_vertically = true
	config.decrement_before_propagation = true
	config.spreads_to_occupants = true
	config.min_ticks_before_spread = 0
	return config
