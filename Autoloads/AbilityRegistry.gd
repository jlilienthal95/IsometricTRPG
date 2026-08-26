extends Node

# List of every ability: preloaded

# --- AUTO-GENERATED ABILITIES LIST START ---
const ABILITIES: Array[AbilityData] = [
	preload("res://Data/Abilities/Fight_Archer.tres"),
	preload("res://Data/Abilities/Fight_Knight.tres"),
	preload("res://Data/Abilities/Fight_Pirate.tres"),
	preload("res://Data/Abilities/Flame.tres"),
	preload("res://Data/Abilities/Freeze.tres"),
	preload("res://Data/Abilities/Last_Ditch_Effort.tres"),
	preload("res://Data/Abilities/Spark.tres"),
]
# --- AUTO-GENERATED ABILITIES LIST END ---

var _abilities: Dictionary = {} # ability_id: AbilityData

func _ready() -> void:
	_load_all_abilities()

func _load_all_abilities() -> void:
	for ability in ABILITIES:
		if ability != null:
			_abilities[ability.ability_id] = ability

func get_ability(ability_id: int) -> AbilityData:
	return _abilities.get(ability_id, null)

func get_ability_by_name(ability_name: String) -> AbilityData:
	for ability: AbilityData in _abilities.values():
		if ability.ability_name == ability_name:
			return ability
	return null

func get_all_abilities() -> Array[AbilityData]:
	return _abilities.values()
