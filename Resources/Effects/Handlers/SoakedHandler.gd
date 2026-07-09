class_name SoakedHandler
extends EffectHandler

# Soaked has no active behavior of its own — its gameplay role is passive:
# it neutralizes BURNING on contact (see EffectRules.NEUTRALIZE_MAP) and
# expires after its duration. Hooks are stubbed for future design (e.g.
# soaked + ELECTRIFIED synergy).

const EFFECT = EffectId.Id.SOAKED

func _resolve_unit(unit: Unit, instance: EffectInstance, context: EffectContext) -> void:
	pass

func _resolve_tile(tile: BattleTileData, instance: EffectInstance, context: EffectContext) -> void:
	pass

func _resolve_object(object: BattleObject, instance: EffectInstance, context: EffectContext) -> void:
	pass
