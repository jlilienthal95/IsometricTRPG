class_name BurningHandler
extends EffectHandler

const EFFECT = EffectId.Id.BURNING
const TICK_DAMAGE_MULTIPLIER: float = 0.5

func _resolve_tile(tile: BattleTileData, instance: EffectInstance, context: EffectContext) -> void:
	print("resolve tile: burning")
	await _resolve_tile_propagation(tile, instance, context)

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
	
func get_propagation_config() -> PropagationConfig:
	var config = PropagationConfig.new()
	config.style = EffectHandler.PropagationStyle.GRADUAL
	config.deals_damage = true
	config.damage_multiplier = 0.5
	config.respects_weaknesses = true
	config.min_ticks_before_spread = 1
	return config
