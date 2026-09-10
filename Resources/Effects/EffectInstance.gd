# EffectInstance.gd
class_name EffectInstance
extends Resource

var effect_id: EffectId.Id = EffectId.Id.NONE
var rounds_remaining: int = -1
var ticks_active: int = 0	# increments on every tick, natural or externally triggered; untouched by direct neutralization
var direction: Vector3i = Vector3i.ZERO		# non-zero only for directional effects (wind/magnetics); drives the tile arrow
