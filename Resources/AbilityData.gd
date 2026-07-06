class_name AbilityData
extends Resource

enum AbilityType { PHYSICAL, MAGICAL, HEALING, STATUS, MOVEMENT }
enum TargetType { SINGLE_ENEMY, SINGLE_ALLY, SELF, AREA_ENEMY, AREA_ALLY, AREA_ALL }
enum RangeShape { STRAIGHT, DIAGONAL, ALL_DIRECTIONS, CROSS, AREA }
enum AnimationPath { PROJECTILE, INSTANT, PATH }

@export var ability_name: String = ""
@export var ability_id: = 0		# permanent, never reuse
@export var description: String = ""
@export var ability_type: AbilityType = AbilityType.PHYSICAL
@export var effects: Dictionary[EffectId.Id, int] = {} # Effect: Turns
@export var target_type: TargetType = TargetType.SINGLE_ENEMY

# Cost
@export var mp_cost: int = 0
@export var jp_cost: int = 0		# job points, if you use that system

# Range
@export var min_range: int = 1
@export var max_range: int = 1
@export var range_shape: RangeShape = RangeShape.ALL_DIRECTIONS
@export var area_of_effect: int = 0		# 0 = single tile, 1 = surrounding tiles, etc.

# Modifiers
@export var base_hit_chance: float = 1.0 # base hit chance as a percentage (1.0 = 100%, 0.85 = 85% etc.)
@export var base_crit_chance: float = 0.05 # base critical hit chance as a percentage

# Elevation rules
@export var ignores_elevation: bool = false
@export var max_elevation_difference: int = 2

# Effects
@export var base_power: int = 0         # damage or healing amount before modifiers
@export var element: ElementData.Element = ElementData.Element.NONE
#@export var status_effect_ids: Array[StatusEffect.StatusEffect] = []  # statuses this ability can apply

# Animation
@export var animation_id: String = ""   # reference to which animation to play
@export var impact_delay: int = 0 #time from ability anim start until ability impact
@export var charge_delay: int = 0  #if any, time from ability anim start until tween start
@export var animation_path: AnimationPath = AnimationPath.PROJECTILE #path ability anim tweens through
