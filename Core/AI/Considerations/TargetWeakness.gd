class_name TargetWeakness
extends Consideration

func score(candidate: ActionCandidate, context: AIContext) -> float:
	if candidate.ability == null:
		return 0.0
	var ability: AbilityData = candidate.ability
	var target: BattleActor = context.grid.get_actor_at(candidate.target_cell)
	if target == null:
		return 0.0

	for effect in ability.effects.keys():
		if target.data.immunities.has(effect):
			return 0.0
	for effect in ability.effects.keys():
		if target.data.weaknesses.has(effect):
			return 1.0
	
	if target.data.elemental_weaknesses.has(ability.element):
		return 1.0
		
	return 0.5
	
func get_consideration_name() -> String:
	return "target_weakness"
