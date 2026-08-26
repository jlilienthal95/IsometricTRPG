class_name AbilityVisual
extends Node2D

signal visual_complete

# Override in subclasses to define travel behavior.
# Called by UnitAbilityExecutor after the effect is spawned and positioned.
func travel(target_pos: Vector2, ability: AbilityData, camera: BattleCamera) -> void:
	visual_complete.emit()

func _calc_duration(distance: float, ability: AbilityData) -> float:
	var max_range = ability.max_range * Constants.TILE_WORLD_SIZE
	var ratio = distance / max_range
	return 0.625 + ratio * 0.4

# called immediately on spawn — set initial position, facing, camera follow
func spawn(caster_pos: Vector2, caster: Unit) -> void:
	global_position = caster_pos
	scale.x = abs(scale.x) * caster.unit_visual_root.scale.x
	z_index = Constants.MAX_ELEVATION * 4 + 3
