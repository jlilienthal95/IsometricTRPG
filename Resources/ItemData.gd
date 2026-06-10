class_name ItemData
extends Resource

enum ItemType { WEAPON = 0, ARMOR = 1, SHIELD = 2, BOOTS = 3, ACCESSORY = 4 }

@export var item_name: String = ""
@export var item_id: int = 0		# permanent, never reuse
@export var item_type: ItemType = ItemType.WEAPON
@export var description: String = ""

# Stat bonuses while equipped
@export var hp_bonus: int = 0
@export var mp_bonus: int = 0
@export var attack_bonus: int = 0
@export var defense_bonus: int = 0

# Abilities this item grants while equipped
@export var granted_ability_ids: Array[int] = []

# Weapons can deal elemental damage, armor can grant resistances
@export var element: ElementData.Element = ElementData.Element.NONE
@export var elemental_resistances: Dictionary = {}  # Element: float modifier

# How many uses to permanently learn each granted ability
@export var mastery_threshold: int = 10
