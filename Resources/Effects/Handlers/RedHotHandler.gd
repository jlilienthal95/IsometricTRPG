class_name RedHotHandler
extends EffectHandler

const TICK_DAMAGE_MULTIPLIER: float = 0.5

# called at the end of an individual unit's turn — red-hot terrain damages whoever stands on it
func on_unit_turn_end(unit: Unit, instance: EffectInstance, context: EffectContext) -> void:
	var tile = context.grid.get_tile(unit.grid_position)
	if tile == null or not tile.has_effect(EffectId.Id.REDHOT):
		return
	#var damage = EffectDamageResolver.resolve(unit, EffectId.Id.RED_HOT, TICK_DAMAGE_MULTIPLIER)
	#unit.adjust_hp(damage)
