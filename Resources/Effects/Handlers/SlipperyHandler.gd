class_name SlipperyHandler
extends EffectHandler

# SLIPPERY: An effect that usually accompanies FROZEN or SOAKED.
# Causes BattleActors to SLIP along SLIPPERY tiles until a non-slippery
# tile is reached, or the path is blocked.

const EFFECT = EffectId.Id.SLIPPERY

func on_actor_entered_tile(actor: BattleActor, tile: BattleTileData, instance: EffectInstance, context: EffectContext) -> void:
	var slip_path: Array[MovementStep] = []
	context.mover.is_interrupted = true
	if context.mover.direction != Vector3i(999,999,999):
		var direction = context.mover.direction
		var curr_pos: Vector3i = actor.grid_position
		while curr_pos != Vector3i(999,999,999):
			var next_pos = curr_pos + direction
			var next_tile = context.grid.get_tile(next_pos)
			# next tile must:
				# exist
				# have SLIPPERY effect
				# be lower or equal elevation
				# not be occupied
			if next_tile == null or \
			not next_tile.active_effects.has(EFFECT) or \
			next_pos.z > curr_pos.z or \
			next_tile.unit_ref != null and next_tile.object_ref != null:
				curr_pos = Vector3i(999,999,999)
				continue
			slip_path.append(curr_pos)
	print("slip path: ", slip_path)
