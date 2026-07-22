class_name DestinationSafety
extends Consideration


const DISABLING_EFFECTS: Array[EffectId.Id] = [
	# populated once handler query interface exists
]

const EFFECT_SAFETY_SCORES: Dictionary = { # effect : score
	EffectId.Id.BURNING: 0.3,
	EffectId.Id.BLAZING: 0.2,
	EffectId.Id.REDHOT: 0.5,
	EffectId.Id.SOAKED: 0.9,
	EffectId.Id.FROZEN: 0.8,
	EffectId.Id.SLIPPERY: 0.8,
	EffectId.Id.WINDY: 1.0,
	EffectId.Id.FEATHER: 0.8,
	EffectId.Id.ELECTRIFIED: 0.5,
	EffectId.Id.MAGNETISED: 0.9,
	EffectId.Id.INDUCTION: 0.9,
	EffectId.Id.PLAGUED: 0.5,
}

const DISABLE_FLOOR = 0.1
const ADDITIONAL_EFFECT_PENALTY = 0.1

# returns a raw score for this candidate; profile weight is applied by the scorer
func score(candidate: ActionCandidate, context: AIContext) -> float:
	var tile: BattleTileData = context.grid.get_tile(candidate.move_cell)
	var unit_immunities: Array[EffectId.Id] = context.acting_unit.data.immunities
	var unit_weaknesses: Array[EffectId.Id] = context.acting_unit.data.weaknesses
	var unit_effects: Array[EffectInstance] = context.acting_unit.data.active_effects
	var tile_effects: Array[EffectInstance] = tile.active_effects
	
	var value = 1.0
	
	if tile_effects.is_empty():
		return value
	
	var penalty_count = tile_effects.size() - 1
	
	for effect in tile_effects:
		var tile_effect = effect.effect_id
		var effect_score = EFFECT_SAFETY_SCORES.get(tile_effect, 1.0)
		
		# if unit is immune, effect has max safety score
		if unit_immunities.has(tile_effect):
			effect_score = 1.0
		# only check for weakness if unit is not immune to effect. Add penalty point.
		elif unit_weaknesses.has(tile_effect):
			# TODO: check DISABLING_EFFECTS here — return 0.0 if unit would be disabled
			
			effect_score *= 0.5
			penalty_count += 1
		
		# find lowest safety score from all effects
		if effect_score < value:
			value = effect_score
	
	# apply penalty points for additional effects
	if penalty_count > 0:
		var penalty = penalty_count * ADDITIONAL_EFFECT_PENALTY
		value -= penalty
		value = maxf(DISABLE_FLOOR, value)
		
		
	return value

#func _adjust_score_for_weakness() -> float:
	# TODO: implement disabling effect detection
	# approach: query each effect's handler for what it would apply to this specific unit
	# given their equipment/material profile, then check result against DISABLING_EFFECTS const
	# e.g. MAGNETISED + metal armor = disable, FEATHER unit + WINDY tile = disable
	# requires handler query interface to be built out first alongside remaining handlers
	#pass
	
# considerations can opt out entirely (cheap gate before scoring)
func is_relevant(context: AIContext) -> bool:
	return true

func get_consideration_name() -> String:
	return "destination_safety"
