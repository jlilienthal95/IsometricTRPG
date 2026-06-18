class_name UnitData
extends Resource

@export var unit_name: String = ""
@export var job_id: int = 0

# base stats — modified by job and equipment at runtime
@export var current_lvl: int = 1
@export var exp_to_lvl: int = 999
@export var max_hp: int = 100
@export var current_hp: int = 100
@export var max_mp: int = 15
@export var current_mp: int = 15
@export var move_range: int = 3
@export var jump_height: int = 2
@export var base_attack: int = 10
@export var base_defense: int = 5

# elemental affinities — values are multipliers applied to incoming elemental damage
# 1.0 = normal, 0.5 = resistant, 2.0 = weak, 0.0 = immune, -1.0 = absorbs
@export var elemental_affinities: Dictionary = {}

# runtime turn state — not exported, reset each turn
var has_moved: bool = false
var has_acted: bool = false
var is_dead: bool = false

# equipment slots — stored as IDs for saving, resolved to ItemData at battle start
@export var equipped_weapon_id: int = -1
@export var equipped_armor_id: int = -1
@export var equipped_shield_id: int = -1
@export var equipped_boots_id: int = -1
@export var equipped_accessory_id: int = -1

# resolved equipment references — populated at battle start via resolve_equipment()
var equipped_items: Array[ItemData] = []

# abilities available
@export var ability_ids: Array[int] = []

# resolve ability references
var abilities: Array[AbilityData] = []

# active status effects — key is StatusEffect enum value, value is turns remaining
var active_status_effects: Dictionary[StatusEffect.StatusEffect, int] = {}

# returns all equipped item IDs as an array, including empty slots as -1
func get_equipped_ids() -> Array[int]:
	return [equipped_weapon_id, equipped_armor_id, equipped_shield_id, equipped_boots_id, equipped_accessory_id]

# returns the currently equipped ItemData for the given slot type, or null if empty
func get_equipped_by_type(item_type: ItemData.ItemType) -> ItemData:
	for item in equipped_items:
		if item.item_type == item_type:
			return item
	return null

# populates equipped_items from the registry using stored IDs — called at battle start
func resolve_equipment() -> void:
	equipped_items.clear()
	for id in get_equipped_ids():
		if id == -1:
			continue
		var item = ItemRegistry.get_item(id)
		if item != null:
			equipped_items.append(item)
			
func resolve_abilities() -> void:
	ability_ids.clear()
	for id in ability_ids:
		var ability = AbilityRegistry.get_ability(id)
		if ability != null:
			abilities.append(ability)

# equips an item by ID — updates the correct slot and refreshes equipped_items
func equip(item_id: int) -> void:
	var item = ItemRegistry.get_item(item_id)
	if item == null:
		push_error("Tried to equip unknown item: " + str(item_id))
		return
	match item.item_type:
		ItemData.ItemType.WEAPON:	equipped_weapon_id = item_id
		ItemData.ItemType.ARMOR:	equipped_armor_id = item_id
		ItemData.ItemType.SHIELD:	equipped_shield_id = item_id
		ItemData.ItemType.BOOTS:	equipped_boots_id = item_id
		ItemData.ItemType.ACCESSORY: equipped_accessory_id = item_id
	# remove any existing item of the same type and add the new one
	equipped_items = equipped_items.filter(func(i): return i.item_type != item.item_type)
	equipped_items.append(item)

# unequips the item in the given slot and removes it from equipped_items
func unequip(item_type: ItemData.ItemType) -> void:
	match item_type:
		ItemData.ItemType.WEAPON:	equipped_weapon_id = -1
		ItemData.ItemType.ARMOR:	equipped_armor_id = -1
		ItemData.ItemType.SHIELD:	equipped_shield_id = -1
		ItemData.ItemType.BOOTS:	equipped_boots_id = -1
		ItemData.ItemType.ACCESSORY: equipped_accessory_id = -1
	equipped_items = equipped_items.filter(func(i): return i.item_type != item_type)
