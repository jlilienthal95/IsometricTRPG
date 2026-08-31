class_name BattleActor
extends Node2D

# =============================================================================
# BattleActor — shared base for Unit and BattleObject.
#
# This class exists so that grid/turn/effect systems (UnitMover, EffectExecutor,
# BattleGrid, etc.) can treat units and battle objects identically wherever
# their behavior is genuinely identical — they don't need to know or care
# which subclass they're holding.
#
# Ownership rule for this file: if the SAME logic would otherwise be copy-pasted
# into both Unit.gd and BattleObject.gd, it belongs here instead, with small
# "hook" functions (the underscore-prefixed ones below) for subclasses to
# plug in the one or two lines that actually differ (e.g. which local visual
# effect plays, or what happens to the AnimationPlayer). Keep it that way —
# this class drifting back into a stub of pass-only functions while the real
# logic duplicates in subclasses is exactly the bug pattern we're avoiding.
# =============================================================================

@onready var damage_count: Control = $DamageCount/DamageLabel

# --- shared interface contract ---
var grid_position: Vector3i = Vector3i.ZERO
var data: BattleActorData = null

# Reference to the BattleGrid this actor is placed on, for occlusion lookups
# in update_z_index(). Subclasses must set this during their own setup().
var _grid_ref: BattleGrid = null


# =============================================================================
# HP — the single mutation points for actor health, shared by units and
# objects alike. All damage and healing flows through apply_damage / apply_heal,
# which:
#   1. mutate data.current_hp (the single source of truth)
#   2. announce the change on BattleEvents (UI panels and the CinematicDirector
#      react on their own — no caller has to remember to trigger them)
#   3. play local feedback via the hooks below (damage number always; the
#      rest is subclass-specific, since a Unit flashes/plays a hit animation
#      and a BattleObject currently doesn't)
# Callers must never write data.current_hp directly.
# =============================================================================

func apply_damage(amount: int) -> void:
	if data.is_dead:
		return
	data.current_hp = maxi(0, data.current_hp - amount)
	BattleEvents.hp_changed.emit(self, -amount, data.current_hp)
	play_damage_count(amount)
	_play_hit_feedback()
	if data.current_hp == 0:
		await _on_defeated()
	else:
		await _on_damaged()

func apply_heal(amount: int) -> void:
	if data.is_dead:
		return
	data.current_hp = mini(data.max_hp, data.current_hp + amount)
	BattleEvents.hp_changed.emit(self, amount, data.current_hp)
	play_damage_count(-amount)

# --- hooks: subclasses override to add their own local reaction to damage ---

# immediate visual feedback the instant damage lands (flash, particles, sfx)
func _play_hit_feedback() -> void:
	pass

# non-lethal reaction — e.g. a "hit" animation. Awaited before control returns.
func _on_damaged() -> void:
	pass

# lethal reaction — MUST end by emitting BattleEvents.actor_defeated (the base
# implementation does this; override and call it, or replicate it, but never
# skip it — turn queue / win-condition checks depend on this signal firing
# exactly once per actor death).
func _on_defeated() -> void:
	BattleEvents.actor_defeated.emit(self)


# =============================================================================
# EFFECTS — both Unit and BattleObject store their active effects on `data`
# (BattleActorData) identically, so the default read/write path lives here.
# A subclass only needs to override apply_effect/remove_effect if it must also
# do something extra beyond the data mutation (BattleObject additionally
# registers itself with the grid, so effect propagation can find it).
# =============================================================================

func has_effect(effect_id: EffectId.Id) -> bool:
	return data.has_effect(effect_id)

func get_effect(effect_id: EffectId.Id) -> EffectInstance:
	return data.get_effect(effect_id)

func apply_effect(effect_id: EffectId.Id, ticks: int = -1) -> void:
	if data.is_dead:
		return
	data.apply_effect(effect_id, ticks)

func remove_effect(effect_id: EffectId.Id) -> void:
	data.remove_effect(effect_id)


# =============================================================================
# ANIMATION — default no-ops. Units override these with real sprite playback;
# BattleObjects currently have no locomotion animations, so the no-op default
# already IS their correct behavior (no need to re-declare empty overrides —
# see the note in BattleObject.gd if you're tempted to add one back).
# =============================================================================

func play_idle() -> void:
	pass

func play_walk() -> void:
	pass

func play_jump() -> void:
	pass

func set_facing_toward(_from_cell: Vector3i, _to_cell: Vector3i) -> void:
	pass

func set_effect_alpha(_alpha: float) -> void:
	pass

func on_terrain_changed(_terrain_type: int) -> void:
	pass

# shared damage-number popup — the label/tween logic is identical for every
# actor type; only the AnimationPlayer that owns the "damage_count" animation
# differs, so subclasses point us at their own via _get_damage_anim_player().
func play_damage_count(damage: int) -> void:
	if damage < 0:
		var heal_color: Color = Color(0.0, 0.74, 0.0, 1.0)
		damage_count.add_theme_color_override("font_color", heal_color)
	else:
		var damage_color: Color = Color("ff003b")
		damage_count.add_theme_color_override("font_color", damage_color)
	damage_count.text = str(absi(damage))
	var anim_player := _get_damage_anim_player()
	if anim_player != null:
		anim_player.play("damage_count")

# hook: return the AnimationPlayer that owns this actor's "damage_count" clip
func _get_damage_anim_player() -> AnimationPlayer:
	return null


# =============================================================================
# Z-INDEX — every actor draws below its lowest occluder, or above all terrain
# if nothing occludes it. Requires _grid_ref to be set by the subclass's setup().
# =============================================================================

func update_z_index() -> void:
	if _grid_ref == null:
		return
	var occluders = _grid_ref.occlusion_map.get(grid_position, [])
	if occluders.is_empty():
		z_index = Constants.UNOCCLUDED_ACTOR_Z_INDEX
	else:
		var lowest_occluder = occluders[occluders.size() - 1]
		z_index = lowest_occluder.z * Constants.Z_INDEX_LAYER_STRIDE - 1
