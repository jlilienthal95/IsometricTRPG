class_name Consideration
extends RefCounted

# returns a raw score for this candidate; profile weight is applied by the scorer
func score(candidate: ActionCandidate, context: AIContext) -> float:
	return 0.0

# considerations can opt out entirely (cheap gate before scoring)
func is_relevant(context: AIContext) -> bool:
	return true
