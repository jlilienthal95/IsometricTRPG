class_name InstantVisual
extends AbilityVisual

# An effect with no travel step at all: pans the camera to the target, plays
# one animation in place, then completes (e.g. a melee hit spark, a
# self-cast buff glow).

func travel(target_pos: Vector2, ability: AbilityData, camera: BattleCamera) -> void:
	await camera.pan_to(target_pos)
	global_position = target_pos
	var sprite: AnimatedSprite2D = get_node("AbilitySprite")
	sprite.play(ability.animation_id)
	await sprite.animation_finished
	visual_complete.emit()
	queue_free()
