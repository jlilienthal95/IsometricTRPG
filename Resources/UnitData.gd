class_name UnitData
extends BattleActorData

@export var name: String = ""

# direct resource reference — drag the job .tres in the inspector.
# job.job_id is still available for save serialization.
@export var job: JobData = null

# =============================================================================
# BASE STATS — authored in the inspector, NEVER touched at runtime
# =============================================================================
@export var ai_profile_override: AIProfile = null
@export var caster_impact_frame_overrides: Dictionary[AbilityData.UnitAnimation, int] = {}  # UnitAnimation -> int 

@export var base_max_mp: int = Constants.UNIT_BASE_MP
@export var base_attack: int = Constants.UNIT_BASE_ATTACK
@export var base_defense: int = Constants.UNIT_BASE_DEFENSE
@export var base_move_range: int = Constants.UNIT_BASE_MOVE_RANGE
@export var base_jump_height: int = Constants.UNIT_BASE_JUMP_HEIGHT
@export var current_exp: int = Constants.BASE_EXP_PER_LEVEL

# elemental affinities — multipliers applied to incoming elemental damage
# 1.0 = normal, 0.5 = resistant, 2.0 = weak, 0.0 = immune, -1.0 = absorbs
#@export var elemental_affinities: Dictionary = {}

# =============================================================================
# EQUIPMENT — direct resource references (authoring); IDs derived for saves
# =============================================================================
@export var equipped_weapon: EquipmentData = null
@export var equipped_armor: EquipmentData = null
@export var equipped_shield: EquipmentData = null
@export var equipped_boots: EquipmentData = null
@export var equipped_accessory: EquipmentData = null

# abilities this specific unit knows beyond its job's list
@export var granted_abilities: Array[AbilityData] = []

# =============================================================================
# COMPUTED STATS — populated by resolve() at battle start; read during battle
# =============================================================================
var current_lvl: int = 1	# derived from current_exp
#var max_hp: int = 0
#var current_hp: int = 0
var max_mp: int = 0
var current_mp: int = 0
var attack: int = 0
#var defense: int = 0
var move_range: int = 0
var jump_height: int = 0
var speed: JobData.SpeedRank = JobData.SpeedRank.NORMAL

# =============================================================================
# RUNTIME STATE — never exported
# =============================================================================
var has_moved: bool = false
var has_acted: bool = false
@export var is_player_controlled: bool = false
#var is_dead: bool = false

var equipment: Array[EquipmentData] = []		# resolved flat list of equipped pieces
var abilities: Array[AbilityData] = []			# resolved: granted + job abilities
#var active_effects: Array[EffectInstance] = []
#var immunities: Array[EffectId.Id] = []			# precomputed from equipment materials
#var weaknesses: Array[EffectId.Id] = []

# =============================================================================
# RESOLUTION — the single pipeline that turns authored data into battle stats.
# Call resolve() once at battle start. Order matters: equipment first (stats
# may later read bonuses), then abilities, then stats.
# =============================================================================

func resolve() -> void:
	resolve_equipment()
	resolve_abilities()
	resolve_stats()

# flattens equipped slot references into the equipment array and refreshes
# material-based immunities/weaknesses
func resolve_equipment() -> void:
	equipment.clear()
	for piece in _get_equipped_pieces():
		if piece != null:
			equipment.append(piece)
	refresh_material_resistances()

# combines unit-specific and job abilities into the runtime ability list
func resolve_abilities() -> void:
	abilities.clear()
	for ability in granted_abilities:
		if ability != null and not abilities.has(ability):
			abilities.append(ability)
	if job != null:
		for ability in job.abilities:
			if ability != null and not abilities.has(ability):
				abilities.append(ability)

# computes all battle stats from base stats + job modifiers.
# base_* fields are read-only inputs here — resolve_stats() is idempotent and
# safe to call repeatedly (e.g. after a mid-battle job change).
func resolve_stats() -> void:
	current_lvl = Constants.level_from_xp(current_exp)

	var hp_mod: float = job.hp_modifier if job else 1.0
	var mp_mod: float = job.mp_modifier if job else 1.0
	var atk_mod: float = job.attack_modifier if job else 1.0
	var def_mod: float = job.defense_modifier if job else 1.0

	max_hp = int(base_max_hp * hp_mod)
	max_mp = int(base_max_mp * mp_mod)
	attack = int((base_attack * atk_mod) + (current_lvl * 1.3))
	defense = int(base_defense * def_mod)
	current_hp = max_hp
	current_mp = max_mp

	move_range = base_move_range + (job.move_range_bonus if job else 0)
	jump_height = base_jump_height + (job.jump_height_bonus if job else 0)
	speed = job.speed_rank if job else JobData.SpeedRank.NORMAL
	
	elemental_weaknesses.clear()
	for element:ElementData.Element in elemental_affinities:
		if elemental_affinities[element] > 1.0:
			elemental_weaknesses.append(element)

# =============================================================================
# EFFECTS
# =============================================================================

func has_effect(effect_id: EffectId.Id) -> bool:
	return EffectStore.has_effect(active_effects, effect_id)

func get_effect(effect_id: EffectId.Id) -> EffectInstance:
	return EffectStore.get_effect(active_effects, effect_id)

func apply_effect(effect_id: EffectId.Id, ticks: int = -1) -> void:
	var actual_ticks = ticks
	if actual_ticks == -1:
		actual_ticks = EffectRules.DEFAULT_DURATION.get(effect_id, 1)
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

# =============================================================================
# EQUIPMENT MANAGEMENT
# =============================================================================

func _get_equipped_pieces() -> Array[EquipmentData]:
	return [equipped_weapon, equipped_armor, equipped_shield, equipped_boots, equipped_accessory]

# returns equipped item IDs (for save serialization) — empty slots are -1
func get_equipped_ids() -> Array[int]:
	var ids: Array[int] = []
	for piece in _get_equipped_pieces():
		ids.append(piece.equipment_id if piece != null else -1)
	return ids

# returns the currently equipped EquipmentData for the given slot type, or null if empty
func get_equipped_by_type(equipment_type: EquipmentData.Type) -> EquipmentData:
	for piece in equipment:
		if piece.equipment_type == equipment_type:
			return piece
	return null

# equips a piece — updates the correct slot and refreshes the resolved list
func equip(piece: EquipmentData) -> void:
	if piece == null:
		push_error("UnitData: tried to equip null equipment")
		return
	match piece.equipment_type:
		EquipmentData.Type.WEAPON:		equipped_weapon = piece
		EquipmentData.Type.ARMOR:		equipped_armor = piece
		EquipmentData.Type.SHIELD:		equipped_shield = piece
		EquipmentData.Type.BOOTS:		equipped_boots = piece
		EquipmentData.Type.ACCESSORY:	equipped_accessory = piece
	resolve_equipment()

# unequips the piece in the given slot and refreshes the resolved list
func unequip(equipment_type: EquipmentData.Type) -> void:
	match equipment_type:
		EquipmentData.Type.WEAPON:		equipped_weapon = null
		EquipmentData.Type.ARMOR:		equipped_armor = null
		EquipmentData.Type.SHIELD:		equipped_shield = null
		EquipmentData.Type.BOOTS:		equipped_boots = null
		EquipmentData.Type.ACCESSORY:	equipped_accessory = null
	resolve_equipment()

func get_ai_profile() -> AIProfile:
	if ai_profile_override != null:
		return ai_profile_override
	if job != null and job.ai_profile != null:
		return job.ai_profile
	return null  # brain falls back to a default profile

func get_caster_impact_frame(anim: AbilityData.UnitAnimation) -> int:
	if caster_impact_frame_overrides.has(anim):
		return caster_impact_frame_overrides[anim]
	if job != null and job.caster_impact_frames.has(anim):
		return job.caster_impact_frames[anim]
	return 0
