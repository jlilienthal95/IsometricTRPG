class_name PropagationConfig
extends RefCounted

# --- propagation ---
var style: EffectHandler.PropagationStyle = EffectHandler.PropagationStyle.NONE
var propagates_vertically: bool = false
var decrement_before_propagation: bool = false
var spreads_to_occupants: bool = true			#effect spreads tile -> unit on turn end
var spreads_to_tile_on_turn_end: bool = false	#effect spreads unit -> tile on turn end
var min_ticks_before_spread: int = 1

# --- damage ---
var deals_damage: bool = false
var damage_multiplier: float = 1.0		# multiplied against Constants.BASE_DAMAGE_UNIT
var damage_on_apply: bool = false		# deal damage when first applied
var damage_every_tick: bool = true		# deal damage each terrain turn tick
var respects_weaknesses: bool = true	# check unit weakness array
var respects_immunities: bool = true	# already handled in base resolve, but explicit here
