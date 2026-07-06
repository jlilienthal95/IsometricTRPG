extends Node

var _equipment: Dictionary = {} # job_id: JobData
	
func load_equipment_for_battle(units: Array[Unit], inventory: Array[int]) -> void:
	_equipment.clear()
	var ids_to_load: Array[int] = []
	
	#collect equipped items to load
	for unit in units:
		for id in unit.data.get_equipped_ids():
			if id != -1 and not ids_to_load.has(id):
				ids_to_load.append(id)
	
	#collect inventory items to load
	for id in inventory:
		if not ids_to_load.has(id):
			ids_to_load.append(id)
	#load necessary items
	for id in ids_to_load:
		var path = "res://Data/Equipment/equipment_" + str(id) + ".tres"
		var equipment = load(path)
		if equipment != null:
			_equipment[id] = equipment
		else:
			push_error("ItemRegistry: failed to load equipment: " + str(id))

func get_equipment(equipment_id: int) -> EquipmentData:
	return _equipment.get(equipment_id, null)
