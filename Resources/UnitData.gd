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

# equipment slots — stored as IDs for saving, resolved to EquipmentData at battle start
@export var equipped_weapon_id: int = -1
@export var equipped_armor_id: int = -1
@export var equipped_shield_id: int = -1
@export var equipped_boots_id: int = -1
@export var equipped_accessory_id: int = -1

# resolved equipment references — populated at battle start via resolve_equipment()
var equipment: Array[EquipmentData] = []

# abilities available
@export var ability_ids: Array[int] = []

# resolve ability references
var abilities: Array[AbilityData] = []

# active  effects — key is StatusEffect enum value, value is turns remaining
var active_effects: Array[EffectInstance] = []

# precomputed from equipment — refreshed via refresh_material_resistances()
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
	
# recalculates immunities and weaknesses based on currently equipped gear materials
func refresh_material_resistances() -> void:
	immunities.clear()
	weaknesses.clear()
	var material_counts: Dictionary = {}
	for piece in equipment:
		var mat = piece.equipment_material
		if mat == EquipmentData.EquipmentMaterial.NONE:
			continue
		material_counts[mat] = material_counts.get(mat, 0) + 1
	for mat in material_counts:
		if material_counts[mat] >= 3:
			if MaterialRules.IMMUNITIES.has(mat):
				immunities.append_array(MaterialRules.IMMUNITIES[mat])
			if MaterialRules.WEAKNESSES.has(mat):
				weaknesses.append_array(MaterialRules.WEAKNESSES[mat])

# returns all equipped item IDs as an array, including empty slots as -1
func get_equipped_ids() -> Array[int]:
	return [equipped_weapon_id, equipped_armor_id, equipped_shield_id, equipped_boots_id, equipped_accessory_id]

# returns the currently equipped EquipmentData for the given slot type, or null if empty
func get_equipped_by_type(equipment_type: EquipmentData.Type) -> EquipmentData:
	for piece in equipment:
		if piece.type == equipment_type:
			return piece
	return null

# populates equipment from the registry using stored IDs — called at battle start
func resolve_equipment() -> void:
	equipment.clear()
	for id in get_equipped_ids():
		if id == -1:
			continue
		var piece = EquipmentRegistry.get_equipment(id)
		if piece != null:
			equipment.append(piece)

func resolve_abilities() -> void:
	abilities.clear()
	for id in ability_ids:
		var ability = AbilityRegistry.get_ability(id)
		if ability != null:
			abilities.append(ability)

# equips an item by ID — updates the correct slot and refreshes equipment
func equip(equipment_id: int) -> void:
	var piece = EquipmentRegistry.get_equipment(equipment_id)
	if piece == null:
		push_error("Tried to equip unknown item: " + str(equipment_id))
		return
	match piece.type:
		EquipmentData.Type.WEAPON:		equipped_weapon_id = equipment_id
		EquipmentData.Type.ARMOR:		equipped_armor_id = equipment_id
		EquipmentData.Type.SHIELD:		equipped_shield_id = equipment_id
		EquipmentData.Type.BOOTS:		equipped_boots_id = equipment_id
		EquipmentData.Type.ACCESSORY:	equipped_accessory_id = equipment_id
	# remove any existing item of the same type and add the new one
	equipment = equipment.filter(func(i): return i.type != piece.type)
	equipment.append(piece)

# unequips the item in the given slot and removes it from equipment
func unequip(equipment_type: EquipmentData.Type) -> void:
	match equipment_type:
		EquipmentData.Type.WEAPON:		equipped_weapon_id = -1
		EquipmentData.Type.ARMOR:		equipped_armor_id = -1
		EquipmentData.Type.SHIELD:		equipped_shield_id = -1
		EquipmentData.Type.BOOTS:		equipped_boots_id = -1
		EquipmentData.Type.ACCESSORY:	equipped_accessory_id = -1
	equipment = equipment.filter(func(i): return i.type != equipment_type)
