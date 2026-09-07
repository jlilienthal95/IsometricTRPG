class_name FeatherHandler
extends EffectHandler

# Stub handler for FEATHER — registered so the effect system has full coverage,
# with no behavior yet. Implement the hooks below as the effect is designed.

const EFFECT = EffectId.Id.FEATHER

func get_propagation_config() -> PropagationConfig:
	var config = PropagationConfig.new()
	config.style = PropagationStyle.NONE
	config.spreads_to_occupants = false
	config.spreads_to_tile_on_turn_end = false
	return config
