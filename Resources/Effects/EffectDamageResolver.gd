class_name EffectDamageResolver
extends RefCounted

const VARIANCE_PERCENT: float = 0.2

# base_amount: the flat damage this effect deals (e.g. burning's per-tick fire damage)
# returns final damage after variance and weakness bonus
static func resolve(target: Unit, effect_id: EffectId.Id, base_amount: int) -> int:
	var variance = int(base_amount * VARIANCE_PERCENT)
	var raw = randi_range(base_amount - variance, base_amount)
	if target.data.weaknesses.has(effect_id):
		raw = int(raw * 1.5)	# bonus damage multiplier — tune during playtesting
	return raw
