extends Node

# shared party inventory — stores consumable item IDs accessible to all units
var inventory: Array[int] = []

# shared equipment pool — stores equipment IDs accessible to all units
var equipment_pool: Array[int] = []

# all units in the party — stores UnitData resources
var party: Array[UnitData] = []

func add_item(item_id: int) -> void:
	inventory.append(item_id)

func remove_item(item_id: int) -> void:
	inventory.erase(item_id)

func has_item(item_id: int) -> bool:
	return inventory.has(item_id)

func add_equipment(equipment_id: int) -> void:
	equipment_pool.append(equipment_id)

func remove_equipment(equipment_id: int) -> void:
	equipment_pool.erase(equipment_id)

func has_equipment(equipment_id: int) -> bool:
	return equipment_pool.has(equipment_id)

func add_unit(unit_data: UnitData) -> void:
	if not party.has(unit_data):
		party.append(unit_data)

func remove_unit(unit_data: UnitData) -> void:
	party.erase(unit_data)

# equips gear from the shared pool onto a unit, returning any displaced equipment to the pool
func equip_item(unit_data: UnitData, equipment_id: int) -> void:
	if not has_equipment(equipment_id):
		push_error("PartyManager: tried to equip item not in pool: " + str(equipment_id))
		return
	var piece = EquipmentRegistry.get_equipment(equipment_id)
	if piece == null:
		push_error("PartyManager: equipment not found in registry: " + str(equipment_id))
		return
	# return currently equipped gear of the same type to the pool
	# (property is equipment_type — the old .type access crashed at runtime)
	var current = unit_data.get_equipped_by_type(piece.equipment_type)
	if current != null:
		add_equipment(current.equipment_id)
	remove_equipment(equipment_id)
	unit_data.equip(piece)

# unequips the gear in the given slot and returns it to the shared pool
func unequip_item(unit_data: UnitData, equipment_type: EquipmentData.Type) -> void:
	var current = unit_data.get_equipped_by_type(equipment_type)
	if current == null:
		return
	add_equipment(current.equipment_id)
	unit_data.unequip(equipment_type)

func get_party() -> Array[UnitData]:
	return party

func get_inventory() -> Array[int]:
	return inventory

func get_equipment_pool() -> Array[int]:
	return equipment_pool

# returns full ItemData objects for all consumables currently in the inventory
#func get_inventory_items() -> Array[ItemData]:
	#var items: Array[ItemData] = []
	#for id in inventory:
		#var item = ItemRegistry.get_item(id)
		#if item != null:
			#items.append(item)
	#return items

# returns full EquipmentData objects for all gear currently in the pool
func get_equipment_pool_items() -> Array[EquipmentData]:
	var pieces: Array[EquipmentData] = []
	for id in equipment_pool:
		var piece = EquipmentRegistry.get_equipment(id)
		if piece != null:
			pieces.append(piece)
	return pieces
