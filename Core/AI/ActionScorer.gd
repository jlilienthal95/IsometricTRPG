class_name ActionScorer
extends RefCounted

var considerations: Array[Consideration]

var sort_func = func(a, b): return a.total_score < b.total_score

# scores action candidates via Considerations
func score_actions(candidates: Array[ActionCandidate], context: AIContext) -> void:
	for consideration in considerations:
		if consideration.is_relevant(context):
			candidates = consideration.score_each(candidates, context)
	candidates.sort_custom(sort_func)
