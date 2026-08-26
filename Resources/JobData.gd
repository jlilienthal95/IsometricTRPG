class_name JobData
extends Resource

# Speed is intentionally simple: three ranks the turn queue sorts by.
# No combat math, no derived stats — a design decision to keep min-maxing out
# of the moment-to-moment experience.
enum SpeedRank { SLOW, NORMAL, FAST }

@export var job_name: String = ""
@export var job_id: int = 0  # permanent, never reuse — used only for save serialization
@export var portrait: Texture2D = null
@export var sprite_frames: SpriteFrames = null
@export var sprite_offset: Vector2 = Vector2.ZERO
@export var flip_offset: Vector2 = Vector2.ZERO
@export var shadow_scale: Vector2 = Vector2.ONE
@export var caster_impact_frames: Dictionary[AbilityData.UnitAnimation, int] = {
	AbilityData.UnitAnimation.ATTACK: 0,
	AbilityData.UnitAnimation.CAST_SPELL: 0,
}  # frame at which the caster spawns the effect

# --- stat modifiers applied to unit base stats (multipliers) ---
@export var hp_modifier: float = 1.0
@export var mp_modifier: float = 1.0
@export var attack_modifier: float = 1.0
@export var defense_modifier: float = 1.0

@export var ai_profile: AIProfile

# --- movement (flat bonuses added to unit base stats) ---
@export var move_range_bonus: int = 0
@export var jump_height_bonus: int = 0

# --- turn order ---
@export var speed_rank: SpeedRank = SpeedRank.NORMAL

# --- abilities ---
# direct resource references: drag .tres files in the inspector, no IDs
@export var fight_ability: AbilityData = null
@export var abilities: Array[AbilityData] = []
