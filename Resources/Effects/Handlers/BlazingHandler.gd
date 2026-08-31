class_name BlazingHandler
extends EffectHandler

# BLAZING: a fast-spreading, instant fire-like effect at full damage
# (damage_multiplier 1.0 — the hottest of the fire-family effects; compare
# BurningHandler at 0.5). GRADUAL style: spreads one tile per tick, same as
# Burning, just hits harder and doesn't convert terrain to ash.

const EFFECT = EffectId.Id.BLAZING

func get_propagation_config() -> PropagationConfig:
	var config = PropagationConfig.new()
	config.style = EffectHandler.PropagationStyle.GRADUAL
	config.spreads_to_tile_on_turn_end = true
	config.deals_damage = true
	config.damage_multiplier = 1
	config.respects_weaknesses = true
	config.min_ticks_before_spread = 1
	return config
