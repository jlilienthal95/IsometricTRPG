extends Node

var _abilities: Dictionary = {} #ability_id: AbilityData

# scans the abilities folder and loads all .tres files into the registry
func _ready() -> void:
	_load_all_abilities()
	
func _load_all_abilities()-> void:
	var path = "res://Data/Abilities"
	var dir = DirAccess.open(path)
	if dir == null:
		push_error("AbilityRegistry: could not open Data/Abilities/")
		return
	dir.list_dir_begin()
	var file = dir.get_next()
	while file != "":
		if file.ends_with(".tres"):
			var ability: AbilityData = load(path + "/" + file)
			if ability != null:
				_abilities[ability.ability_id] = ability
		file = dir.get_next()

func get_ability(ability_id: int) -> AbilityData:
	return _abilities.get(ability_id, null)
	
func get_ability_by_name(ability_name: String) -> AbilityData:
	for ability: AbilityData in _abilities.values():
		if ability.ability_name == ability_name:
			return ability
	return null
	
func get_all_abilities() -> Array[AbilityData]:
	return _abilities.values()
