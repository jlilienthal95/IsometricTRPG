class_name PropagationConfig
extends RefCounted

# --- propagation ---
var style: EffectHandler.PropagationStyle = EffectHandler.PropagationStyle.NONE
var propagates_vertically: bool = false
var decrement_before_propagation: bool = false
var spreads_to_occupants: bool = true			#effect spreads tile -> unit on turn end
var spreads_to_tile_on_turn_end: bool = false	#effect spreads unit -> tile on turn end
# if true, gradual/instant propagation only spreads to liquid terrain types
# (water, etc.) — the effect can still be applied to any susceptible terrain
# manually, it just won't self-propagate to non-liquid neighbors
var spreads_to_liquid_only: bool = false
var min_ticks_before_spread: int = 1

# --- damage ---
var deals_damage: bool = false
var damage_multiplier: float = 1.0		# multiplied against Constants.BASE_DAMAGE_UNIT
var damage_on_apply: bool = false		# deal damage when first applied
var damage_every_tick: bool = true		# deal damage each terrain turn tick
var respects_weaknesses: bool = true	# check unit weakness array
var respects_immunities: bool = true	# already handled in base resolve, but explicit here

# --- terrain conversion ---
var converts_terrain: BattleTileData.TerrainType = -1  # -1 = no conversion
var converts_on_threshold: bool = true   # true = converts when ticks_active hits threshold
var converts_instantly: bool = false     # true = converts immediately on application
