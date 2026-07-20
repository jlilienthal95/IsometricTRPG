class_name DistanceToThreat
extends Consideration

func is_relevant(context: AIContext) -> bool:
	var intelligence = context.profile.intelligence
	
	return true
	
func score(candidate: ActionCandidate, context: AIContext) -> float:
	pass
