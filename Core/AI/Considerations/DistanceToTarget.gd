class_name DistanceToTarget
extends Consideration

# if no targets exist, consideration is meaningless
func is_relevant(context: AIContext) -> bool:
	return context.enemy_units.any(func(u): return not u.data.is_dead)
	
func score_each(candidates: Array[ActionCandidate], context: AIContext) -> Array[ActionCandidate]:
	var consideration = get_consideration_name()
	var candidate_distances: Dictionary = {}
	var lowest_distance: float = 999.0
	var highest_distance: float = 0.0
	
	for candidate: ActionCandidate in candidates:
		# only score higher than 0.0 if action does not include an ability
		if candidate.ability != null:
			candidate.scores[consideration] = 0.0
			candidate_distances[candidate] = 0.0
			continue
		var unit_tile = candidate.move_cell
		var targets = context.enemy_units.filter(func(u): return not u.data.is_dead)
		var distance = _find_closest_target_distance(unit_tile, targets)
		candidate_distances[candidate] = distance
		if distance < lowest_distance:
			lowest_distance = distance
		if distance > highest_distance:
			highest_distance = distance
	
	# all destinations score a 1.0 if they are all equally close to a target, or no target exists
	if highest_distance == lowest_distance and highest_distance != 0.0:
		for candidate in candidate_distances:
			candidate.scores[consideration] = 1.0
			apply_weight(candidate, 1.0, context)
		return candidates
			
	# score each candidate, normalized from lowest_distance
	for candidate: ActionCandidate in candidate_distances:
		var raw: float = (highest_distance - candidate_distances[candidate]) / (highest_distance - lowest_distance)
		candidate.scores[consideration] = snappedf(raw, 0.01)
		apply_weight(candidate, raw, context)
	return candidates
	
func _find_closest_target_distance(unit_tile: Vector3i, targets: Array[BattleActor]) -> int:
	var closest_distance: float = 999.0
	for target in targets:
		var target_tile = target.grid_position
		var distance: float = _grid_distance(unit_tile, target_tile)
		if distance < closest_distance:
			closest_distance = distance
	return closest_distance

func get_consideration_name() -> String:
	return "distance_to_target"
