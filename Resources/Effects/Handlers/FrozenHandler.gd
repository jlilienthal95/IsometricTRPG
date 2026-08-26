class_name FrozenHandler
extends EffectHandler

const EFFECT = EffectId.Id.FROZEN

func get_propagation_config() -> PropagationConfig:
	var config = PropagationConfig.new()
	
	config.style = EffectHandler.PropagationStyle.GRADUAL
	config.propagates_vertically = true
	config.decrement_before_propagation = false
	config.spreads_to_occupants = true
	config.spreads_to_tile_on_turn_end = true
	config.min_ticks_before_spread = 1
	
	config.deals_damage = true
	config.damage_multiplier = 0.4
	config.damage_on_apply = false
	config.damage_every_tick = true
	config.respects_weaknesses = true
	config.respects_immunities = true
	
	config.converts_terrain = BattleTileData.TerrainType.ICE # -1 = no conversion
	config.converts_on_threshold = true  # true = converts when ticks_active hits threshold
	config.converts_instantly = true

	return config
