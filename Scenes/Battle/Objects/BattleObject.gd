class_name BattleObject
extends BattleActor

# =============================================================================
# BattleObject — a movable/interactive stage element (crate, barrel, boulder).
#
# Implements the same duck-typed surface Unit exposes for systems that treat
# the two identically: movement execution, the damage pipeline, and effect
# storage. Objects do NOT take turns; their effects tick during TERRAIN_TURN.
#
# Follows BattleActor's DATA / ANIM / UNION split — note in particular that
# the old _destroy() has been separated into play_death() (the fade, pure
# visual) and _finalize_defeat() (grid removal and queue_free, pure
# lifecycle), so an object can be faded out for a cutscene without being
# removed, or removed headlessly without a fade.
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
# ANIM — pure presentation, no data mutation.
# =============================================================================

func play_hit() -> void:
	gff_player.play("hit")

# fades the object out. Does NOT remove it from the grid or free it —
# see _finalize_defeat() for that half.
func play_death() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished

func _get_damage_anim_player() -> AnimationPlayer:
	return object_animation_player


# =============================================================================
# LIFECYCLE — runs after play_death() as part of BattleActor._defeat().
# =============================================================================

func _finalize_defeat() -> void:
	if _grid_ref != null:
		_grid_ref.remove_object(grid_position)
	queue_free()


# =============================================================================
# EFFECTS — identical read path to BattleActor's default; apply/remove
# additionally register with the grid so effect propagation (e.g. fire
# spreading tile-to-tile) can find this object.
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
