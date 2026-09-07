class_name FrozenHandler
extends EffectHandler

# FROZEN: damaging, terrain-converting cold effect. Converts its tile to ICE
# instantly on application (converts_instantly = true — contrast
# Damages every tick and spreads gradually through liquids only.

const EFFECT = EffectId.Id.FROZEN

# turns a unit stays frozen AFTER stepping off the ice before it breaks free.
# On an ice tile FROZEN is permanent (kept refreshed); off it, this many of the
# unit's own turn-ends thaw it out.
const THAW_TURNS: int = 2

func get_propagation_config() -> PropagationConfig:
	var config = PropagationConfig.new()
	
	config.style = EffectHandler.PropagationStyle.GRADUAL
	config.propagates_vertically = true
	config.decrement_before_propagation = false
	config.spreads_to_occupants = true
	config.spreads_to_tile_on_turn_end = false
	config.spreads_to_liquid_only = true
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
	# ice is a REVERSIBLE override: the tile remembers what it was (or defaults to
	# grass if born frozen) and melts back to it when FROZEN is removed
	config.reverts_terrain_on_removal = true

	return config
	
func _resolve_tile(tile: BattleTileData, instance: EffectInstance, context: EffectContext) -> void:
	await context.executor.apply_effect(tile, EffectId.Id.SLIPPERY)
	await super._resolve_tile(tile, instance, context)

# FROZEN does NOT catch a passer-by. Unlike fire, merely walking or sliding
# across an icy tile mid-move must not apply the effect — a unit only becomes
# frozen if it is STILL on the tile when the terrain turn ticks (i.e. it ended
# its turn there), which the generic occupant spread in _resolve_tile_propagation
# handles. So the default on-entry spread is deliberately suppressed here.
@warning_ignore("unused_parameter")
func on_actor_entered_tile(actor: BattleActor, tile: BattleTileData, instance: EffectInstance, context) -> void:
	pass

# A frozen unit stays frozen solid while it stands on ice (the tile keeps it
# permanent), but begins to thaw the moment it's off the ice — breaking free
# after THAW_TURNS of its own turn-ends. This is what makes unit-freeze temporary
# even though the ice TILE itself is permanent.
func on_unit_turn_end(unit, instance: EffectInstance, context: EffectContext) -> void:
	var tile = context.grid.get_tile(unit.grid_position)
	var on_ice: bool = tile != null and tile.has_effect(EFFECT)
	if on_ice:
		# still on the ice — frozen solid, any partial thaw is undone
		instance.rounds_remaining = -1
	else:
		# stepped off — start the thaw clock (permanent -> finite), then count down
		if instance.rounds_remaining < 0:
			instance.rounds_remaining = THAW_TURNS
		instance.rounds_remaining -= 1
		if instance.rounds_remaining <= 0:
			await context.executor.remove_effect(unit, EFFECT, EffectExecutor.RemovalReason.EXPIRED)
			return
	await super.on_unit_turn_end(unit, instance, context)

# Melting undoes the ice. The terrain reverts automatically (reverts_terrain_on_
# removal above); here we also strip the SLIPPERY that FROZEN laid down, so the
# thawed tile isn't left permanently slick. SLIPPERY is itself permanent, so it
# would otherwise never clear on its own.
func on_removed(target, instance: EffectInstance, context: EffectContext, reason) -> void:
	if target is BattleTileData and target.has_effect(EffectId.Id.SLIPPERY):
		await context.executor.remove_effect(target, EffectId.Id.SLIPPERY, reason)
