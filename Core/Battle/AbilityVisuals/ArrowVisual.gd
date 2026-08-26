class_name ArrowVisual
extends AbilityVisual

func travel(target_pos: Vector2, ability: AbilityData, camera: BattleCamera) -> void:
	var start = global_position
	var end = target_pos
	var distance = start.distance_to(end)
	var max_range = ability.max_range * Constants.TILE_WORLD_SIZE
	var ratio = distance / max_range
	var arc_height = 40.0 * clampf(ratio, 0.0, 1.0)
	var duration = 0.625 + ratio * 0.4
	
	camera.follow(self)
	camera.zoom_for_projectile(distance, max_range)

	var tween = create_tween()
	var state := {"prev_pos": global_position}
	tween.tween_method(func(t: float):
		if not is_instance_valid(self):
			tween.kill()
			return
		var flat = start.lerp(end, t)
		flat.y -= arc_height * 4.0 * t * (1.0 - t)
		var direction = flat - state["prev_pos"]
		if direction.length() > 0.01:
			var angle = direction.angle()
			if scale.x < 0:
				get_child(0).rotation = PI - angle
			else:
				get_child(0).rotation = angle
		state["prev_pos"] = flat
		global_position = flat
	, 0.0, 1.0, duration)
	await tween.finished
	print("arrow at destination")
	visual_complete.emit()
	camera.stop_following()
	queue_free()
