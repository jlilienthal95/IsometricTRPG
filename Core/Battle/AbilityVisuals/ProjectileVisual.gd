class_name ProjectileVisual
extends AbilityVisual

# A generic projectile: travels in a straight line from spawn to target at a
# constant rate (no arc) — for effects where ArrowVisual's parabolic arc
# doesn't apply (e.g. a bolt of magic).

func travel(target_pos: Vector2, ability: AbilityData, camera: BattleCamera) -> void:
	camera.follow(self)
	var distance = global_position.distance_to(target_pos)
	var duration = _calc_duration(distance, ability)
	var sprite: AnimatedSprite2D = get_node("AbilitySprite")

	sprite.play(ability.animation_id)
	var tween = create_tween()
	tween.tween_property(self, "global_position", target_pos, duration)
	await tween.finished
	await sprite.animation_finished
	visual_complete.emit()
	camera.stop_following()
	queue_free()
