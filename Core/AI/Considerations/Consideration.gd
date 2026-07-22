class_name Consideration
extends RefCounted

func score_each(candidates: Array[ActionCandidate], context: AIContext) -> Array[ActionCandidate]:
	for candidate in candidates:
		var raw = score(candidate, context)
		candidate.scores[get_consideration_name()] = raw
		apply_weight(candidate, raw, context)
	return candidates
	
# returns a raw score for this candidate; profile weight is applied by the scorer
func score(candidate: ActionCandidate, context: AIContext) -> float:
	return 0.0
	
# considerations can opt out entirely (cheap gate before scoring)
func is_relevant(context: AIContext) -> bool:
	return true
	
func normalize_score(current: float, max_value: float) -> float:
	if max_value > 0.0:
		var normalized = current / max_value
		return snappedf(normalized, 0.01)
	else:
		return 0.0

func apply_weight(candidate: ActionCandidate, value: float, context: AIContext) -> void:
	var weight = context.profile.weights.get(get_consideration_name(), 1.0)
	candidate.total_score += snappedf((value * weight), 0.01)

func get_consideration_name() -> String:
	return ""

#for use with DistanceToTargets / DistanceToAlly
func _grid_distance(a: Vector3i, b: Vector3i) -> int:
	var flat = abs(a.x - b.x) + abs(a.y - b.y)
	var elev = abs(a.z - b.z) * Constants.ELEVATION_DISTANCE_MULTIPLIER
	return flat + elev
