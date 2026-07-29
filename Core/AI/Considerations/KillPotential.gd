class_name  KillPotential
extends Consideration

func score(candidate: ActionCandidate, context: AIContext) -> float:
	if candidate.ability == null:
		return 0.0
	var target = context.grid.get_actor_at(candidate.target_cell)
	if target == null:
		return 0.0
	var normal_damage = candidate.expected_damage["normal_damage"]
	var crit_damage = candidate.expected_damage["crit_damage"]
	var target_hp = target.data.current_hp
	print("kill potential normal damage: ", normal_damage)
	print("kill potential crit damage: ", crit_damage)
	print("kill potential target hp: ", target_hp)
	if target_hp < normal_damage:
		return 1.0
	elif target_hp < (normal_damage + crit_damage):
		return 0.8
	elif target_hp < (normal_damage * Constants.CRIT_MULTIPLIER):
		return 0.4
	
	return 0.0

func get_consideration_name() -> String:
	return "kill_potential"
