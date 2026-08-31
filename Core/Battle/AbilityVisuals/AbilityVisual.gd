class_name AbilityVisual
extends Node2D

# =============================================================================
# AbilityVisual — base for every ability's traveling effect visual
# (ArrowVisual, ProjectileVisual, InstantVisual...).
#
# spawn() and _calc_duration() are real, shared behavior every subclass gets
# for free. travel() is the one thing that's genuinely different per subclass
# (an arrow arcs, a generic projectile flies straight, an instant effect
# doesn't travel at all) — override it, but reuse _calc_duration() for the
# timing math rather than re-deriving the same formula (ArrowVisual used to
# do exactly that: copy-paste the same "0.625 + ratio * 0.4" line instead of
# calling this).
# =============================================================================

signal visual_complete

# override in subclasses to define travel behavior; the base implementation
# just completes immediately, for effects with no travel step at all
func travel(_target_pos: Vector2, _ability: AbilityData, _camera: BattleCamera) -> void:
	visual_complete.emit()

# shared travel-time formula: a short flat minimum (0.625s) plus a distance-
# scaled component, so a point-blank hit doesn't feel instant and a max-range
# hit doesn't take forever. Subclasses should call this, not re-derive it.
func _calc_duration(distance: float, ability: AbilityData) -> float:
	var max_range = ability.max_range * Constants.TILE_WORLD_SIZE
	var ratio = distance / max_range
	return 0.625 + ratio * 0.4

# called immediately on spawn — set initial position, facing (mirrored to
# match the caster's current facing), and draw above all terrain until travel
# repositions/removes this visual
func spawn(caster_pos: Vector2, caster: Unit) -> void:
	global_position = caster_pos
	scale.x = abs(scale.x) * caster.unit_visual_root.scale.x
	z_index = Constants.UNOCCLUDED_ACTOR_Z_INDEX
