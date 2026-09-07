class_name WindyHandler
extends EffectHandler

# Stub handler for WINDY — registered so the effect system has full coverage,
# with no behavior yet. Implement the hooks below as the effect is designed.

const EFFECT = EffectId.Id.WINDY
# TODO: damage scaling
const CRASH_DAMAGE: int = 5

var _push: ForcedMovement = _build_push()

func _build_push() -> ForcedMovement:
	var force: ForcedMovement = ForcedMovement.new()
	force.movement_type = MovementSequence.MovementType.PUSH
	force.suppressed_effects = [EFFECT, EffectId.Id.FEATHER, EffectId.Id.SLIPPERY]
	force.crash_damage = 0
	force.continues_past = _continues_past
	force.configure_sequence = MovementEasing.gust
	return force

func get_propagation_config() -> PropagationConfig:
	var config = PropagationConfig.new()
	config.style = PropagationStyle.NONE
	config.has_visual_effects = true
	config.spreads_to_occupants = false
	return config

func on_actor_entered_tile(actor: BattleActor, tile: BattleTileData, instance: EffectInstance, context: EffectContext) -> void:
	await _spread_effect(actor, EffectId.Id.FEATHER, context)
	if actor.has_effect(EffectId.Id.FEATHER):
		print("feathered unit")
		#if context.mover == null or context.mover.direction == Vector3i.ZERO:
			#return
		print("direction: ", instance.direction)
		_push.execute(actor, instance.direction, 999, context, true)

func _continues_past(tile: BattleTileData) -> bool:
	return tile.has_effect(EFFECT)
