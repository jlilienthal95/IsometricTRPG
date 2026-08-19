class_name ObjectData
extends BattleActorData

# Authoring data for a battle Object: a movable/interactive stage element.
# Objects are treated like terrain for effect resolution (they hold effects and
# tick during the terrain turn), like units for damage (they have HP and can be
# destroyed), and can be moved by unit actions (pushed, rolled, slid).

@export var object_name: String = ""

# whether units can stand on / path through the tile this object occupies
# (crate = true, barrel = false)
@export var is_walkable: bool = false

# whether unit actions can push/slide this object
@export var is_movable: bool = true

#@export var base_max_hp: int = 10
#@export var defense: int = 0

# multipliers applied to incoming elemental damage — same semantics as UnitData
#@export var elemental_affinities: Dictionary = {}

# runtime state — never exported
#var max_hp: int = 0
#var current_hp: int = 0
#var is_dead: bool = false
#var active_effects: Array[EffectInstance] = []

# objects have no equipment, so these exist only to satisfy the shared
# damage-resolution interface with UnitData
#var immunities: Array[EffectId.Id] = []
#var weaknesses: Array[EffectId.Id] = []

func resolve() -> void:
	max_hp = base_max_hp
	current_hp = max_hp
	is_dead = false

func has_effect(effect_id: EffectId.Id) -> bool:
	return EffectStore.has_effect(active_effects, effect_id)

func get_effect(effect_id: EffectId.Id) -> EffectInstance:
	return EffectStore.get_effect(active_effects, effect_id)

func apply_effect(effect_id: EffectId.Id, ticks: int = -1) -> void:
	var actual_ticks = ticks
	if actual_ticks == -1:
		actual_ticks = EffectRules.DEFAULT_DURATION.get(effect_id, 1)
	EffectStore.apply_effect(active_effects, effect_id, actual_ticks)

func remove_effect(effect_id: EffectId.Id) -> void:
	EffectStore.remove_effect(active_effects, effect_id)
