class_name EffectStore
extends RefCounted

static func has_effect(effects: Array[EffectInstance], effect_id: EffectId.Id) -> bool:
	for e in effects:
		if e.effect_id == effect_id:
			return true
	return false

static func get_effect(effects: Array[EffectInstance], effect_id: EffectId.Id) -> EffectInstance:
	for e in effects:
		if e.effect_id == effect_id:
			return e
	return null

# returns the instance that was applied or refreshed — caller handles any side effects (e.g. grid indexing)
static func apply_effect(effects: Array[EffectInstance], effect_id: EffectId.Id, rounds: int) -> EffectInstance:
	var existing = get_effect(effects, effect_id)
	if existing != null:
		existing.rounds_remaining = rounds
		return existing
	var instance = EffectInstance.new()
	instance.effect_id = effect_id
	instance.rounds_remaining = rounds
	effects.append(instance)
	return instance

# returns true if an effect was actually found and removed
static func remove_effect(effects: Array[EffectInstance], effect_id: EffectId.Id) -> bool:
	for i in range(effects.size()):
		if effects[i].effect_id == effect_id:
			effects.remove_at(i)
			return true
	return false
