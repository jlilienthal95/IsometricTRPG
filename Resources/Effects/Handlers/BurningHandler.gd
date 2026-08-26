class_name BurningHandler
extends EffectHandler

const EFFECT = EffectId.Id.BURNING
const TICK_DAMAGE_MULTIPLIER: float = 0.5

func get_propagation_config() -> PropagationConfig:
	var config = PropagationConfig.new()
	config.style = EffectHandler.PropagationStyle.GRADUAL
	config.spreads_to_tile_on_turn_end = true
	config.deals_damage = true
	config.damage_multiplier = 0.5
	config.respects_weaknesses = true
	config.min_ticks_before_spread = 1
	
	# --- terrain conversion ---
	config.converts_terrain = BattleTileData.TerrainType.ASH
	config.converts_on_threshold = true   # true = converts when ticks_active hits threshold
	config.converts_instantly = false     # true = converts immediately on application
	return config
	
