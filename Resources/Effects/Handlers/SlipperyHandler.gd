class_name SlipperyHandler
extends EffectHandler

# SLIPPERY: usually accompanies FROZEN or SOAKED. An actor entering a slippery
# tile keeps sliding along its direction of travel until it comes to rest on a
# non-slippery tile (a "clean" stop) or is stopped by an obstacle (a "crash",
# which deals damage). The sliding mechanism itself is the shared ForcedMovement
# service — this handler just configures it (the slip knobs) and drives it from
# the triggers below.

const EFFECT = EffectId.Id.SLIPPERY
# TODO: damage scaling
const CRASH_DAMAGE: int = 5

# the configured slide, built once and reused for every trigger
var _slide: ForcedMovement = _build_slide()

func _build_slide() -> ForcedMovement:
	var force: ForcedMovement = ForcedMovement.new()
	force.movement_type = MovementSequence.MovementType.SLIP
	# suppress the ice effects so the slide doesn't re-trigger itself tile by tile
	# (.assign() populates the typed array reliably — see WindyHandler note)
	force.suppressed_effects.assign([EFFECT, EffectId.Id.FROZEN])
	force.crash_damage = CRASH_DAMAGE
	force.continues_past = _continues_past
	force.configure_sequence = MovementEasing.slip	# pick the slide feel by name
	force.on_downed = _play_downed
	force.on_rise = _play_rise
	return force

func get_propagation_config() -> PropagationConfig:
	var config = PropagationConfig.new()
	config.has_visual_effects = false
	config.style = EffectHandler.PropagationStyle.NONE
	return config

# =============================================================================
# TRIGGERS
# =============================================================================

# Movement-driven slip: the actor walked ONTO a slippery tile mid-move, so we
# redirect its in-progress movement (interrupt) along its travel direction.
# The slide is unbounded (999) — pure momentum, it goes until something stops it.
func on_actor_entered_tile(actor: BattleActor, tile: BattleTileData, instance: EffectInstance, context: EffectContext) -> void:
	if context.mover == null or context.mover.direction == Vector3i.ZERO:
		return
	await _slide.execute(actor, context.mover.direction, 999, context, true)

# Event-driven slip: something happened to the actor while it was STANDING on a
# slippery tile (e.g. struck by a forceful attack), so we START a fresh slide
# rather than redirecting a move that isn't happening. Distance is capped by the
# ability's force.
func on_tile_event(tile: BattleTileData, event: TileEvent, instance: EffectInstance, context: EffectContext) -> void:
	match event.type:
		TileEvent.Type.ABILITY_HIT:
			var target: BattleActor = context.grid.get_actor_at(tile.cell)
			if target == null or event.caster == null:
				return
			# the ability's force sets how far the hit can shove the target;
			# a forceless hit (NONE -> 0) doesn't knock them at all
			var distance := AbilityForce.slide_distance(event.force)
			if distance <= 0:
				return
			# knockback heads away from the caster, source -> target cell
			var direction := Constants.direction_between(event.caster.grid_position, tile.cell)
			if direction == Vector3i.ZERO:
				return
			await _slide.execute(target, direction, distance, context, false)
		TileEvent.Type.PROJECTILE_LANDED:
			pass
		_:
			pass

# =============================================================================
# SLIDE KNOBS — how a slip differs from a generic push (wired into _slide above)
# =============================================================================

# keep sliding only while the ground underfoot is still slippery
func _continues_past(tile: BattleTileData) -> bool:
	return tile.has_effect(EFFECT)

func _play_downed(actor: BattleActor) -> void:
	if actor is Unit:
		await actor.play_slip()

func _play_rise(actor: BattleActor) -> void:
	if actor is Unit and actor.is_alive():
		await actor.play_recover()
