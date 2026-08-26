class_name InstantVisual
extends AbilityVisual

func travel(target_pos: Vector2, ability: AbilityData, camera: BattleCamera) -> void:
	print("instant effect travel start")
	await camera.pan_to(target_pos)
	
	global_position = target_pos
	var sprite: AnimatedSprite2D = get_node("AbilitySprite")
	print("playing effect anim")
	sprite.play(ability.animation_id)
	await sprite.animation_finished
	print("emitting visual_complete")
	visual_complete.emit()
	queue_free()
