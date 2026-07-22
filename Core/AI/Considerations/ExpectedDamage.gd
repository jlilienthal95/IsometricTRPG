class_name ExpectedDamage
extends Consideration

func score_each(candidates: Array[ActionCandidate], context: AIContext) -> Array[ActionCandidate]:
	var candidate_damages: Dictionary = {}
	var max_damage = 0.0
	
	# create dictionary with candidates and estimated damage totals
	for candidate in candidates:
		var damage = calc_damage(candidate, context)
		if damage > max_damage:
			max_damage = damage
		candidate_damages[candidate] = damage
	
	# score each candidate, normalized from max_damage
	for candidate: ActionCandidate in candidate_damages:
		var consideration = get_consideration_name()
		var raw = normalize_score(candidate_damages[candidate], max_damage)
		candidate.scores[consideration] = raw
		candidate.scores[consideration + "_raw"] = candidate_damages[candidate]
		apply_weight(candidate, raw, context)
	
	# return scored candidates	
	return candidates
	
# determine rough expected damage from action and score candidate based on that
func calc_damage(candidate: ActionCandidate, context: AIContext) -> float:
	var caster: Unit = context.acting_unit
	var target: BattleActor = context.grid.get_actor_at(candidate.target_cell)
	var ability: AbilityData = candidate.ability
	
	if target == null or ability == null:
		return 0.0
	
	var max_power: int = int(ability.base_power * caster.data.attack)
	var variance: int = int(max_power * Constants.POWER_VARIANCE)
	var max_crit_chance: float =  Constants.BASE_CRIT_CHANCE + ability.base_crit_chance
	
	var expected_raw: int = int(max_power - (variance * 0.5))

	var damage: float = maxf(0.0, expected_raw - target.data.defense)
	if target.data.elemental_affinities.has(ability.element):
		damage *= target.data.elemental_affinities[ability.element]
	
	#normalized damage estimates
	var normal_damage: float = damage * (1.0 - max_crit_chance)
	var crit_damage: float = (damage * Constants.CRIT_MULTIPLIER) * max_crit_chance
	
	var normalized_damage: float = normal_damage + crit_damage
	
	# (damage if no crit * probability of no crit) + (damage if crit * probability of crit)
	return snappedf(normalized_damage, 0.01)

# considerations can opt out entirely (cheap gate before scoring)
func is_relevant(context: AIContext) -> bool:
	return true
	
func get_consideration_name() -> String:
	return "expected_damage"
