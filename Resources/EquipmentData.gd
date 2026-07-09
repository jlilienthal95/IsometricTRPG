class_name EquipmentData
extends Resource

enum Type { WEAPON = 0, ARMOR = 1, SHIELD = 2, BOOTS = 3, ACCESSORY = 4 }

enum EquipmentMaterial {
	NONE = 0,
	WOOD = 1,
	METAL = 2,
	CLOTH = 3,
	LEATHER = 4,
	BONE = 5,
}

@export var equipment_name: String = ""
@export var equipment_id: int = 0		# permanent, never reuse
@export var equipment_type: Type = Type.WEAPON
@export var equipment_material: EquipmentMaterial = EquipmentMaterial.NONE
@export var description: String = ""

# Stat bonuses while equipped
@export var hp_bonus: int = 0
@export var mp_bonus: int = 0
@export var attack_bonus: int = 0
@export var defense_bonus: int = 0

# Abilities this equipment grants while equipped — direct resource references
@export var granted_abilities: Array[AbilityData] = []

# Weapons can deal elemental damage, armor can grant resistances
@export var element: ElementData.Element = ElementData.Element.NONE
@export var elemental_resistances: Dictionary = {}  # Element: float modifier

# How many uses to permanently learn each granted ability
@export var mastery_threshold: int = 10
