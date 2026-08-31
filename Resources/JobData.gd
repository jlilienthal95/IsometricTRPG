class_name JobData
extends Resource

# Speed is intentionally simple: three ranks the turn queue sorts by.
# No combat math, no derived stats — a design decision to keep min-maxing out
# of the moment-to-moment experience.
enum SpeedRank { SLOW, NORMAL, FAST }

@export var job_name: String = ""
@export var job_id: int = 0  # permanent, never reuse — used only for save serialization
@export var portrait: Texture2D = null

# =============================================================================
# VISUALS
# The inherited Unit scene for this job (e.g. Knight.tscn) — an editor-authored
# scene that inherits Scenes/Battle/Units/Unit.tscn and overrides whatever
# actually differs (sprite_frames, the sprite's position, the shadow's scale)
# directly on its nodes, exactly like BattleObject's per-type scenes already
# do (see Scenes/Battle/Objects/Barrel/Barrel.tscn for the pattern this mirrors).
#
# There used to be separate sprite_frames / sprite_offset / shadow_scale /
# flip_offset data fields here that got applied to the sprite at runtime in
# Unit._apply_job_sprite(). That runtime swap was the direct cause of a bug
# where only a Knight-job unit's idle animation played correctly after
# spawning (reassigning a live AnimatedSprite2D's sprite_frames to a
# DIFFERENT resource than the one already on it stops playback; it doesn't
# for a job whose frames happen to already match the scene's baked-in
# default). flip_offset in particular was never even read anywhere — dead
# authored data. Scene inheritance replaces all of it: nothing to keep in
# sync at runtime, nothing that can silently do nothing for one job and
# something different for another.
# =============================================================================
@export var scene: PackedScene = null

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
