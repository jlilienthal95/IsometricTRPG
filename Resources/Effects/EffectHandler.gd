class_name EffectHandler
extends RefCounted

# derives the effect id from the handler's class name — "BurningHandler" -> "BURNING"
func get_effect_id() -> EffectId.Id:
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
	
# single entry point — routes to the correct resolve method based on target type
func resolve(target, instance: EffectInstance, context) -> void:
	if target is Unit:
		_resolve_unit(target, instance, context)
	elif target is BattleTileData:
		_resolve_tile(target, instance, context)

# override in subclasses that affect units
func _resolve_unit(unit: Unit, instance: EffectInstance, context) -> void:
	pass

# override in subclasses that affect terrain
func _resolve_tile(tile: BattleTileData, instance: EffectInstance, context) -> void:
	pass

# override in subclasses that need turn-boundary-specific logic (damage ticks, neutralization checks)
func on_unit_turn_end(unit: Unit, instance: EffectInstance, context) -> void:
	pass
