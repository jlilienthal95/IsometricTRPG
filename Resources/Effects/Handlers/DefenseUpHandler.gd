class_name DefenseUpHandler
extends EffectHandler

# Stub handler for DEFENSE_UP — registered so the effect system has full coverage,
# with no behavior yet. Implement the hooks below as the effect is designed.

const EFFECT = EffectId.Id.DEFENSE_UP

func _resolve_unit(unit: Unit, instance: EffectInstance, context: EffectContext) -> void:
	pass

func _resolve_tile(tile: BattleTileData, instance: EffectInstance, context: EffectContext) -> void:
	pass

func _resolve_object(object: BattleObject, instance: EffectInstance, context: EffectContext) -> void:
	pass

func on_unit_turn_end(unit: Unit, instance: EffectInstance, context: EffectContext) -> void:
	pass
