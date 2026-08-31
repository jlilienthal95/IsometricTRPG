class_name BattleObject
extends BattleActor

# =============================================================================
# BattleObject — a movable/interactive stage element (crate, barrel, boulder...).
#
# Deliberately implements the same duck-typed surface Unit exposes for the
# systems that treat the two identically:
# - movement execution (UnitMover): grid_position, play_walk/play_jump/play_idle,
#   set_facing_toward, update_z_index, set_effect_alpha, on_terrain_changed
#   (all of these are inherited no-op/shared defaults from BattleActor — objects
#   have no locomotion animation today, so there's nothing to override yet)
# - damage pipeline: apply_damage / apply_heal -> BattleEvents (inherited)
# - effect storage: has/get/apply/remove_effect via data, like a tile
#
# Objects do NOT take turns; their effects tick during TERRAIN_TURN.
# Only what's genuinely different from a Unit lives in this file — see
# BattleActor.gd for the shared HP/effect/z-index/damage-number logic.
# =============================================================================

@onready var object_sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var gff_player: GFFPlayer = $VisualRoot/GFFPlayer
@onready var object_animation_player: AnimationPlayer = $ObjectAnimation


# =============================================================================
# SETUP
# =============================================================================

func setup(object_data: BattleObjectData, start_position: Vector3i, grid: BattleGrid) -> void:
	data = object_data
	data.resolve()
	grid_position = start_position
	_grid_ref = grid
	update_z_index()


# =============================================================================
# HP HOOKS — see BattleActor.apply_damage/apply_heal for the shared pipeline
# =============================================================================

func _play_hit_feedback() -> void:
	gff_player.play("hit")

func _on_defeated() -> void:
	await _destroy()

func _get_damage_anim_player() -> AnimationPlayer:
	return object_animation_player

# fades the object out, removes it from the grid, and frees it. Called once
# HP hits zero (see BattleActor.apply_damage -> _on_defeated).
func _destroy() -> void:
	data.is_dead = true
	if _grid_ref != null:
		_grid_ref.remove_object(grid_position)
	BattleEvents.actor_defeated.emit(self)
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	queue_free()


# =============================================================================
# EFFECTS — identical read path to BattleActor's default; apply/remove need
# to additionally register/unregister with the grid so effect propagation
# (e.g. fire spreading tile-to-tile) can find this object.
# =============================================================================

func apply_effect(effect_id: EffectId.Id, ticks: int = -1) -> void:
	if data.is_dead:
		return
	super.apply_effect(effect_id, ticks)
	if _grid_ref != null:
		_grid_ref.register_effect_object(effect_id, self)

func remove_effect(effect_id: EffectId.Id) -> void:
	super.remove_effect(effect_id)
	if _grid_ref != null:
		_grid_ref.unregister_effect_object(effect_id, self)
