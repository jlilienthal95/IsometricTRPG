extends Node

# Global battle event bus — the reactive backbone of the battle layer.
#
# Design contract:
# - Any mutation of battle-visible state (HP, death, stat changes, effect
#   application/removal) is announced here BY THE CODE THAT OWNS THE MUTATION,
#   at the moment it happens. Owners: Unit / BattleObject for HP and death,
#   EffectExecutor for effect lifecycle.
# - Listeners (UI panels, CinematicDirector, logging, future AI) subscribe and
#   react. They never poll and never need to be "remembered" by the mutating
#   code — new listeners can be added without touching any mutation site.
# - Emissions are synchronous; listeners must NOT block the emitter with long
#   awaits. Anything long-running (cinematics) should enqueue internally and
#   process on its own coroutine (see CinematicDirector._pump).

# actor is a Unit or BattleObject. amount is signed: negative = damage, positive = heal.
signal hp_changed(actor, amount: int, new_hp: int)

# fired once, after the death animation completes
signal actor_defeated(actor)

# fired when a non-HP stat is changed by an outside influence (buffs/debuffs)
signal stat_changed(actor, stat_name: String, old_value, new_value)

# effect lifecycle — target is a Unit, BattleObject, or BattleTileData
signal effect_applied(target, effect_id: EffectId.Id)
signal effect_removed(target, effect_id: EffectId.Id, reason: int)
