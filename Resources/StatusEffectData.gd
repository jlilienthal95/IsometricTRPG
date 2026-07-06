#class_name StatusEffectData
#extends Resource
#
#enum StackBehavior { REFRESH, STACK, IGNORE }  # what happens if applied twice
#enum TriggerTiming { START_OF_TURN, END_OF_TURN, ON_HIT, ON_MOVE }
#
#@export var effect_name: String = ""
#@export var effect_id: int = 0          # permanent, never reuse
#@export var description: String = ""
#
## Duration
#@export var duration_turns: int = 1     # -1 = permanent until cleansed
#@export var stack_behavior: StackBehavior = StackBehavior.REFRESH
#
## Timing
#@export var trigger_timing: TriggerTiming = TriggerTiming.END_OF_TURN
#
## Stat modifications while active
#@export var attack_modifier: float = 1.0
#@export var defense_modifier: float = 1.0
#@export var speed_modifier: float = 1.0
#@export var move_range_modifier: int = 0
#
## Per-turn effects
#@export var hp_change_per_turn: int = 0     # negative = damage, positive = healing
#@export var mp_change_per_turn: int = 0
#
## Behavioral flags
#@export var prevents_movement: bool = false
#@export var prevents_actions: bool = false
#@export var prevents_magic: bool = false
#@export var causes_confusion: bool = false  # acts randomly
#@export var causes_charm: bool = false      # acts for the other team
#
## Visual
#@export var icon_id: String = ""
#@export var animation_id: String = ""
