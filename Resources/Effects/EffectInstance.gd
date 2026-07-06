# EffectInstance.gd
class_name EffectInstance
extends Resource

var effect_id: EffectId.Id = EffectId.Id.NONE
var rounds_remaining: int = -1
var ticks_active: int = 0	# increments on every tick, natural or externally triggered; untouched by direct neutralization
