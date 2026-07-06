class_name JobData
extends Resource

@export var job_name: String = ""
@export var job_id: int = 0  # permanent, never reuse if you add/remove jobs
@export var portrait: Texture2D = null  # permanent, never reuse if you add/remove jobs
@export var sprite_frames: SpriteFrames = null
@export var sprite_offset: Vector2 = Vector2.ZERO
@export var flip_offset: Vector2 = Vector2.ZERO
@export var shadow_scale: Vector2 = Vector2.ONE
@export var cast_impact_delay: float = 0.0 #time from caster anim start until ability anim start

# Stat modifiers this job applies to base stats
@export var hp_modifier: float = 1.0      # multiplier
@export var mp_modifier: float = 1.0
@export var attack_modifier: float = 1.0
@export var defense_modifier: float = 1.0
@export var speed_modifier: float = 1.0

# Abilities available to this job
@export var ability_ids: Array[int] = []

# Movement properties
@export var move_range: int = 3
@export var jump_height: int = 1
