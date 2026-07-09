class_name EffectHandler
extends RefCounted

# Base class for all effect handlers. Subclasses declare:
#   const EFFECT = EffectId.Id.<THEIR_ID>
# and override the _resolve_* / on_unit_turn_end hooks they need.

# returns this handler's effect id. Prefers the explicit EFFECT const —
# required for multi-word ids (ATTACK_DOWN etc.) where name-derivation fails —
# and falls back to deriving from the class name ("BurningHandler" -> BURNING).
func get_effect_id() -> EffectId.Id:
	var consts: Dictionary = get_script().get_script_constant_map()
	if consts.has("EFFECT"):
		return consts["EFFECT"]
	var class_name_str: String = get_script().get_global_name()
	var id_name: String = class_name_str.replace("Handler", "").to_upper()
	if EffectId.Id.has(id_name):
		return EffectId.Id[id_name]
	return EffectId.Id.NONE

func get_neutralizes() -> Array[EffectId.Id]:
	var result: Array[EffectId.Id] = []
	var found = EffectRules.NEUTRALIZE_MAP.get(get_effect_id(), [])
	for id in found:
		result.append(id)
	return result

# single entry point — routes to the correct resolve method based on target type.
# Objects are handled exactly like terrain (they tick during the terrain turn),
# but get their own hook since they can also take damage and be destroyed.
func resolve(target, instance: EffectInstance, context) -> void:
	if target is Unit:
		await _resolve_unit(target, instance, context)
	elif target is BattleObject:
		await _resolve_object(target, instance, context)
	elif target is BattleTileData:
		await _resolve_tile(target, instance, context)

# override in subclasses that affect units
func _resolve_unit(unit: Unit, instance: EffectInstance, context) -> void:
	pass

# override in subclasses that affect terrain
func _resolve_tile(tile: BattleTileData, instance: EffectInstance, context) -> void:
	pass

# override in subclasses that affect objects — defaults to nothing
func _resolve_object(object: BattleObject, instance: EffectInstance, context) -> void:
	pass

# override in subclasses that need turn-boundary-specific logic (damage ticks, neutralization checks)
func on_unit_turn_end(unit: Unit, instance: EffectInstance, context) -> void:
	pass
