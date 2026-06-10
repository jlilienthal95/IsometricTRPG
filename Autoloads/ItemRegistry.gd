extends Node

var _items: Dictionary = {} # job_id: JobData
	
func load_items_for_battle(units: Array[Unit], inventory: Array[int]) -> void:
	_items.clear()
	var ids_to_load: Array[int] = []
	
	#collect equiped items to load
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
		var path = "res://Data/Items/Item_" + str(id) + ".tres"
		var item = load(path)
		if item != null:
			_items[id] = item
		else:
			push_error("ItemRegistry: failed to load item: " + str(id))

func get_item(item_id: int) -> ItemData:
	return _items.get(item_id, null)
