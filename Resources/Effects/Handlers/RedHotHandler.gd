class_name RedHotHandler
extends EffectHandler

const EFFECT = EffectId.Id.REDHOT
const TICK_DAMAGE_MULTIPLIER: float = 0.5

func _resolve_tile(tile: BattleTileData, instance: EffectInstance, context: EffectContext) -> void:
	# red-hot terrain ignites whoever/whatever stands on it.
	# NOTE: routed through the executor (not target.apply_effect directly) so
	# immunity, neutralization, and apply animations all run — applying raw
	# would silently skip all three.
	var occupant = context.grid.get_actor_at(tile.cell)
	if occupant != null:
		await context.executor.apply_effect(occupant, EffectId.Id.BURNING)
	if instance.ticks_active >= EffectRules.DURATION_THRESHOLD_TICKS.get(EFFECT, 999):
		context.executor.convert_terrain(tile, BattleTileData.TerrainType.LAVA)

# red-hot on a unit/object represents heated equipment — no tick damage of its
# own yet (burning does the damage); reserved for design iteration
func _resolve_unit(unit: Unit, instance: EffectInstance, context: EffectContext) -> void:
	pass

func _resolve_object(object: BattleObject, instance: EffectInstance, context: EffectContext) -> void:
	pass

# called at the end of an individual unit's turn — red-hot terrain damages whoever stands on it
func on_unit_turn_end(unit: Unit, instance: EffectInstance, context: EffectContext) -> void:
	var tile = context.grid.get_tile(unit.grid_position)
	if tile == null or not tile.has_effect(EFFECT):
		return
	var base_amount = int(Constants.BASE_DAMAGE_UNIT * TICK_DAMAGE_MULTIPLIER)
	var damage = EffectDamageResolver.resolve(unit, EFFECT, base_amount)
	await unit.apply_damage(damage)
