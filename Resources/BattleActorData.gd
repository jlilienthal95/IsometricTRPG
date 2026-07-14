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
@export var elemental_affinities: Dictionary = {}

# --- computed stats ---
var max_hp: int = 0
var current_hp: int = 0
var is_dead: bool = false

# --- effects ---
var active_effects: Array[EffectInstance] = []
var immunities: Array[EffectId.Id] = []
var weaknesses: Array[EffectId.Id] = []

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
