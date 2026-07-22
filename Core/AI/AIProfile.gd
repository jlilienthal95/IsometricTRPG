class_name AIProfile
extends Resource

enum Intelligence { DUMB, NORMAL, SMART }

@export var intelligence: Intelligence = Intelligence.NORMAL
@export var weights: Dictionary = {		# "weight" : score (max 3.0)
	# --- offensive — how aggressively this unit pursues dealing damage ---
	"expected_damage": 1.0,		# priority given to actions that deal more damage
	"kill_potential": 2.0,		# priority given to actions that could finish a target
	"target_weakness": 0.0,		# willingness to exploit elemental/material weaknesses; 0 = unaware
	"effect_synergy": 0.0,		# willingness to create/exploit hazards and effect combos; 0 = unaware

	# --- positioning — how this unit values where it ends up ---
	"destination_safety": 1.0,	# aversion to ending a turn on hazardous tiles
	"distance_to_target": 0.5,	# preference for closing distance to valid targets when unable to attack
	"ally_proximity": 0.0,		# preference for staying near allies; raise for healers and supports

	# --- support — how much this unit prioritizes helping allies ---
	"healing_value": 0.0,		# priority given to healing actions; raise for dedicated healers
	"buff_value": 0.0,			# priority given to buffing allies; raise for support roles
	"debuff_value": 0.0,		# priority given to inflicting debuffs; raise for disruptors

	# --- economy — how carefully this unit manages resources ---
	"resource_efficiency": 0.5,	# aversion to spending MP when the return is low
}
