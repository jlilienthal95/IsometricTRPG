class_name UnitData
extends Resource

@export var unit_name: String = ""
@export var is_player_controlled: bool = true

@export var job_id: int = 0

@export var max_hp: int = 100
@export var current_hp: int = 100
@export var max_mp: int = 15
@export var current_mp: int = 15
@export var move_range: int = 3
@export var jump_height: int = 2  # max elevation difference for movement
@export var base_attack: int = 10  

# Elemental affinities — values are multipliers
# 1.0 = normal, 0.5 = resistant, 2.0 = weak, 0.0 = immune, -1.0 = absorbs
@export var elemental_affinities: Dictionary = {}  # Element: float

#state
var has_moved: bool = false
var has_acted: bool = false

#equipment
@export var equipped_weapon_id = -1
@export var equipped_armor_id = -1
@export var equipped_shield_id = -1
@export var equipped_boots_id = -1
@export var equipped_accessory_id = -1

var equipped_items: Array[ItemData] = []

func get_equipped_ids() -> Array[int]:
	return [equipped_weapon_id, equipped_armor_id, equipped_shield_id, equipped_boots_id, equipped_accessory_id]
	
func get_equipped_by_type(item_type: ItemData.ItemType) -> ItemData:
	for item in equipped_items:
		if item.item_type == item_type:
			return item
	return null
	
func resolve_equipment() -> void:
	equipped_items.clear()
	for id in get_equipped_ids():
		if id == -1:
			continue
		var item = ItemRegistry.get_item(id)
		if item != null:
			equipped_items.append(item)

func equip(item_id: int) -> void:
	var item =  ItemRegistry.get_item(item_id)
	if item == null:
		push_error("Tried to equip unknown item: " + str(item_id))
		return
	match item.item_type:
		ItemData.ItemType.WEAPON: equipped_weapon_id = item_id
		ItemData.ItemType.ARMOR: equipped_armor_id = item_id
		ItemData.ItemType.SHIELD: equipped_shield_id = item_id
		ItemData.ItemType.BOOTS: equipped_boots_id = item_id
		ItemData.ItemType.ACCESSORY: equipped_accessory_id = item_id
		
	equipped_items = equipped_items.filter(func(i): return i.item_type != item.item_type)
	equipped_items.append(item)

func unequip(item_type: ItemData.ItemType) -> void:
	match item_type:
		ItemData.ItemType.WEAPON: equipped_weapon_id = -1
		ItemData.ItemType.ARMOR: equipped_armor_id = -1
		ItemData.ItemType.SHIELD: equipped_shield_id = -1
		ItemData.ItemType.BOOTS: equipped_boots_id = -1
		ItemData.ItemType.ACCESSORY: equipped_accessory_id = -1
	equipped_items = equipped_items.filter(func(i): return i.item_type != item_type)
