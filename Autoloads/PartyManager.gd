extends Node

# shared party inventory — stores item IDs
var inventory: Array[int] = []
# all units in the party — stores UnitData resources
var party: Array[UnitData] = []

func add_item(item_id: int) -> void:
	inventory.append(item_id)

func remove_item(item_id: int) -> void:
	inventory.erase(item_id)

func has_item(item_id: int) -> bool:
	return inventory.has(item_id)

func add_unit(unit_data: UnitData) -> void:
	if not party.has(unit_data):
		party.append(unit_data)

func remove_unit(unit_data: UnitData) -> void:
	party.erase(unit_data)

func equip_item(unit_data: UnitData, item_id: int) -> void:
	if not has_item(item_id):
		push_error("PartyManager: tried to equip item not in inventory: " + str(item_id))
		return
	# find and return currently equipped item of same type to inventory
	var item = ItemRegistry.get_item(item_id)
	if item == null:
		push_error("PartyManager: item not found in registry: " + str(item_id))
		return
	var current = unit_data.get_equipped_by_type(item.item_type)
	if current != null:
		add_item(current.item_id)
	# remove from inventory and equip
	remove_item(item_id)
	unit_data.equip(item_id)

func unequip_item(unit_data: UnitData, item_type: ItemData.ItemType) -> void:
	var current = unit_data.get_equipped_by_type(item_type)
	if current == null:
		return
	# return to inventory
	add_item(current.item_id)
	unit_data.equip(-1)

func get_party() -> Array[UnitData]:
	return party

func get_inventory() -> Array[int]:
	return inventory

func get_inventory_items() -> Array[ItemData]:
	var items: Array[ItemData] = []
	for id in inventory:
		var item = ItemRegistry.get_item(id)
		if item != null:
			items.append(item)
	return items
