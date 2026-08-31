class_name BattleActorData
extends Resource

# --- Affiliation ---
enum Type { PLAYER, ENEMY, NEUTRAL }

@export var type: Type = Type.NEUTRAL

# Shared base for UnitData and ObjectData — properties every battle actor has
# regardless of whether it's a unit or an object.

# --- base stats (never touched at runtime) ---
@export var base_max_hp: int = 100
@export var defense: int = 0
@export var elemental_affinities: Dictionary[ElementData.Element, float] = {}

# --- computed stats ---
var max_hp: int = 0
var current_hp: int = 0
var is_dead: bool = false

# --- effects ---
var active_effects: Array[EffectInstance] = []
var immunities: Array[EffectId.Id] = []
var weaknesses: Array[EffectId.Id] = []
var elemental_weaknesses: Array[ElementData.Element]

func has_effect(effect_id: EffectId.Id) -> bool:
	return EffectStore.has_effect(active_effects, effect_id)

func get_effect(effect_id: EffectId.Id) -> EffectInstance:
	return EffectStore.get_effect(active_effects, effect_id)

func apply_effect(effect_id: EffectId.Id, ticks: int = -1) -> void:
	var actual_ticks = ticks
	if actual_ticks == -1:
		actual_ticks = EffectRules.DURATION_THRESHOLD_TICKS.get(effect_id, 1)
	EffectStore.apply_effect(active_effects, effect_id, actual_ticks)

func remove_effect(effect_id: EffectId.Id) -> void:
	EffectStore.remove_effect(active_effects, effect_id)

# Duplicates this resource for a newly spawned actor. A shallow duplicate()
# alone isn't sufficient — Array/Dictionary properties are shared by
# reference even under a shallow duplicate, so each mutable container needs
# its own explicit .duplicate() call, or "independent" instances would still
# share one active_effects array etc. Reference fields that are genuinely
# shared TEMPLATE data (scene, job, portrait) are deliberately left alone.
func duplicate_for_instance() -> BattleActorData:
	var copy: BattleActorData = duplicate(false)
	copy.elemental_affinities = elemental_affinities.duplicate()
	copy.active_effects = active_effects.duplicate()
	copy.immunities = immunities.duplicate()
	copy.weaknesses = weaknesses.duplicate()
	copy.elemental_weaknesses = elemental_weaknesses.duplicate()
	return copy
