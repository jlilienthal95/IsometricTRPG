class_name ElectrifiedHandler
extends EffectHandler

# ELECTRIFIED: spreads INSTANTLY to all susceptible neighbors the moment it
# ticks (as opposed to BurningHandler's GRADUAL one-tile-per-tick spread),
# including vertically and onto any occupant standing on a newly-electrified
# tile (spreads_to_occupants) — see ElectrifiedConductedHandler for the
# variant applied to an occupant that got hit this way.

const EFFECT = EffectId.Id.ELECTRIFIED

func get_propagation_config() -> PropagationConfig:
	var config = PropagationConfig.new()
	config.style = EffectHandler.PropagationStyle.INSTANT
	config.spreads_to_tile_on_turn_end = true
	config.propagates_vertically = true
	config.decrement_before_propagation = true
	config.spreads_to_occupants = true
	config.damage_multiplier = 0.4
	config.min_ticks_before_spread = 0
	return config
