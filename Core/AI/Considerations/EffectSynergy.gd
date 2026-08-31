class_name EffectSynergy
extends Consideration

# Not implemented yet — correctly opted out via is_relevant() rather than
# silently running with a default score (see ResourceEfficiency.gd for what
# happens if a stub Consideration DOESN'T opt out this way: it still runs,
# just contributes nothing while polluting scores with an empty-string key).
# Every AIProfile already authors an "effect_synergy" weight, so implementing
# get_consideration_name() + score() here is enough to wire it up once
# there's real logic (e.g. reward candidates that apply an effect the target
# is already weak to, or that combo with an effect already on the target).
func is_relevant(context: AIContext) -> bool:
	return false
