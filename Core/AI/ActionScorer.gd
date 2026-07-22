class_name ActionScorer
extends RefCounted

var considerations: Array[Consideration]

# scores action candidates via Considerations
func score_actions(candidates: Array[ActionCandidate], context: AIContext) -> void:
	for consideration in considerations:
		if consideration.is_relevant(context):
			candidates = consideration.score_each(candidates, context)
