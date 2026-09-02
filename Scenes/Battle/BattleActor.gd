class_name BattleActor
extends Node2D

# =============================================================================
# BattleActor — shared base for Unit and BattleObject.
#
# This class exists so that grid/turn/effect systems (UnitMover, EffectExecutor,
# BattleGrid, etc.) can treat units and battle objects identically wherever
# their behavior is genuinely identical.
#
# THREE-LAYER SPLIT — every state change in this file belongs to exactly one:
#   DATA   — mutates `data`, never touches visuals. Safe to call headlessly
#            (tests, AI lookahead, save/load, rewind).
#   ANIM   — plays visuals, never touches `data`. Safe to replay, skip, or
#            call out of order (previews, cutscenes, debug tools).
#   UNION  — the normal gameplay entry point: calls DATA then ANIM in the
#            right order and emits the right events.
#
# Callers should reach for the UNION function unless they specifically want
# one half without the other. Never mutate data.current_hp / data.is_dead
# directly from outside — go through the DATA functions so events stay honest.
# =============================================================================

@onready var damage_count: Control = $DamageCount/DamageLabel

var grid_position: Vector3i = Vector3i.ZERO
var data: BattleActorData = null

# Reference to the BattleGrid this actor is placed on, for occlusion lookups
# in update_z_index(). Subclasses must set this during their own setup().
var _grid_ref: BattleGrid = null

# Camera used for the impact shake that punctuates taking damage. Resolved
# lazily from the scene (sibling of every spawned actor) and cached; null in
# headless contexts (tests, AI lookahead), where apply_damage simply skips it.
var _camera_ref: BattleCamera = null


# =============================================================================
# DATA — pure state mutation. No visuals, no awaits, no scene-tree access.
# =============================================================================

# Applies a signed HP delta, clamped to [0, max_hp]. Returns the amount
# actually applied, which can differ from `delta` when clamping kicks in —
# callers use the return value for damage numbers so the popup matches what
# really happened rather than what was requested.
func modify_hp(delta: int) -> int:
	var before := data.current_hp
	data.current_hp = clampi(data.current_hp + delta, 0, data.max_hp)
	var applied := data.current_hp - before
	if applied != 0:
		BattleEvents.hp_changed.emit(self, applied, data.current_hp)
	return applied

func mark_dead() -> void:
	data.is_dead = true

func mark_alive() -> void:
	data.is_dead = false

func is_alive() -> bool:
	return not data.is_dead


# =============================================================================
# EFFECTS — data layer. Both Unit and BattleObject store effects on `data`
# identically, so the default read/write path lives here. BattleObject
# overrides apply/remove to additionally register with the grid.
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
# ANIM — pure presentation. Never reads or writes `data`.
#
# Defaults are no-ops: Units override with real sprite playback, and
# BattleObjects genuinely have no locomotion animations, so the no-op default
# already IS their correct behavior.
# =============================================================================

# BattleActor
func play_movement(_type: MovementSequence.MovementType) -> void:
	pass

func play_idle() -> void:
	pass

func play_walk() -> void:
	pass

func play_jump() -> void:
	pass

# one-shot defeat visual. Does NOT mark the actor dead — see mark_dead().
func play_death() -> void:
	pass

# one-shot damage-reaction visual (flinch, flash, particles)
func play_hit() -> void:
	pass

func set_facing_toward(_from_cell: Vector3i, _to_cell: Vector3i) -> void:
	pass

func set_effect_alpha(_alpha: float) -> void:
	pass

func on_terrain_changed(_terrain_type: int) -> void:
	pass

# Floating damage/heal number. Takes the SIGNED hp delta as applied (negative
# for damage, positive for healing) and handles its own colouring, so callers
# can pass modify_hp()'s return value straight through.
func play_damage_count(hp_delta: int) -> void:
	if hp_delta > 0:
		damage_count.add_theme_color_override("font_color", Color(0.0, 0.74, 0.0, 1.0))
	else:
		damage_count.add_theme_color_override("font_color", Color("ff003b"))
	damage_count.text = str(absi(hp_delta))
	var anim_player := _get_damage_anim_player()
	if anim_player != null:
		anim_player.play("damage_count")

# hook: return the AnimationPlayer that owns this actor's "damage_count" clip
func _get_damage_anim_player() -> AnimationPlayer:
	return null


# =============================================================================
# UNION — the normal gameplay path. DATA first, then ANIM.
# =============================================================================

# play_reaction=false suppresses only the hit clip (which ends by returning to
# idle) — used when the caller already owns the actor's pose and idle would
# stomp it, e.g. crash damage mid-slip, where the fallen pose must hold until
# the recovery clip. Impact shake, flash, damage number, and death still play.
func apply_damage(amount: int, play_reaction: bool = true) -> void:
	if data.is_dead:
		return
	# The shake is the impact: it leads, and the damage tally + hit reaction land
	# on it. Owned here (not the CinematicDirector) so it's synchronous with the
	# blow instead of trailing a moment behind on the director's beat queue.
	await _play_impact()
	var applied := modify_hp(-amount)
	_play_hit_feedback()
	play_damage_count(applied)
	if data.current_hp == 0:
		# play_reaction=false also skips the death clip: the actor is already
		# collapsed in its slip/fall pose, which reads as dead, so replaying it
		# would only re-animate a body that's already down.
		await _defeat(play_reaction)
	elif play_reaction:
		await play_hit()

# Camera shake marking the moment of impact. Awaited so the damage that follows
# is felt to land on it. No-op when no camera is reachable (headless).
func _play_impact() -> void:
	var cam := _get_camera()
	if cam != null:
		await cam.play_shake()

func _get_camera() -> BattleCamera:
	if _camera_ref == null:
		var parent := get_parent()
		if parent != null:
			_camera_ref = parent.get_node_or_null("BattleCamera")
	return _camera_ref

# Subclass hook: per-actor damage reaction (a unit flashes; an object doesn't).
# Fires at impact, right after the shake. Default no-op covers objects.
func _play_hit_feedback() -> void:
	pass

func apply_heal(amount: int) -> void:
	if data.is_dead:
		return
	var applied := modify_hp(amount)
	play_damage_count(applied)

# Shared defeat sequence: mark dead (data) -> announce -> play the visual
# (anim) -> subclass lifecycle cleanup. Kept as one function so the
# actor_defeated signal can't be skipped or double-fired by a subclass
# forgetting to call super(). play_anim=false skips only the death clip (the
# data/announce/lifecycle still run) for when the actor is already in a fallen
# pose the caller placed it in.
func _defeat(play_anim: bool = true) -> void:
	mark_dead()
	BattleEvents.actor_defeated.emit(self)
	if play_anim:
		await play_death()
	await _finalize_defeat()

# hook: post-death lifecycle (grid removal, queue_free). Data/lifecycle only,
# not visuals — those belong in play_death().
func _finalize_defeat() -> void:
	pass


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
