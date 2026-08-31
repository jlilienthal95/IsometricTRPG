class_name  KillPotential
extends Consideration

# Scores how close this action's expected damage comes to actually killing
# the target this turn — the whole point of prioritizing kills over chip
# damage. Uses a tiered score rather than a smooth ratio since a near-kill's
# value is dominated by whether it *plausibly* finishes the target on a crit,
# not by the exact percentage of HP removed.
func score(candidate: ActionCandidate, context: AIContext) -> float:
	if candidate.ability == null:
		return 0.0
	var target = context.grid.get_actor_at(candidate.target_cell)
	if target == null:
		return 0.0
	var normal_damage = candidate.expected_damage["normal_damage"]
	var crit_damage = candidate.expected_damage["crit_damage"]
	var target_hp = target.data.current_hp

	if target_hp < normal_damage:
		return 1.0			# guaranteed kill even without a crit
	elif target_hp < (normal_damage + crit_damage):
		return 0.8			# kill possible if this hit crits
	elif target_hp < (normal_damage * Constants.CRIT_MULTIPLIER):
		return 0.4			# a crit alone still wouldn't finish it, but it's close

	return 0.0

func get_consideration_name() -> String:
	return "kill_potential"
