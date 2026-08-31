class_name ResourceEfficiency
extends Consideration

# Not implemented yet. Every AIProfile already authors a "resource_efficiency"
# weight (see e.g. Marta/Theo/Auburn's AIProfile sub-resource), but until this
# actually scores something that weight has no effect.
#
# Before this had is_relevant() overridden to false, it silently ran every
# scoring pass anyway (Consideration.is_relevant() defaults to true) using the
# base class's default get_consideration_name() == "" — which meant it wrote
# a spurious "" key into every candidate's scores dict for zero actual effect
# (score() also defaulted to 0.0). Harmless in practice, since 0 score * any
# weight is still 0, but confusing to debug and worth fixing properly rather
# than leaving a phantom dictionary key. Match EffectSynergy's pattern instead:
# opt out honestly via is_relevant() until real scoring logic exists.
func is_relevant(context: AIContext) -> bool:
	return false

func get_consideration_name() -> String:
	return "resource_efficiency"
