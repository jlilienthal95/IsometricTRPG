class_name SlipperyHandler
extends EffectHandler

# SLIPPERY: usually accompanies FROZEN or SOAKED. An actor entering a slippery
# tile keeps sliding along its direction of travel until it either comes to
# rest on a non-slippery tile (a "clean" stop) or is stopped by an obstacle
# (a "crash", which deals damage).
#
# The slide path is precomputed in one pass and handed to UnitMover as an
# interrupt sequence. SLIPPERY suppresses ITSELF on that sequence so it
# doesn't re-trigger on every tile of the path it just built — every other
# tile effect still fires normally as the actor slides across.

const EFFECT = EffectId.Id.SLIPPERY
const CRASH_DAMAGE: int = 5

func get_propagation_config() -> PropagationConfig:
	var config = PropagationConfig.new()
	config.has_visual_effects = false
	config.style = EffectHandler.PropagationStyle.NONE
	return config

# Movement-driven slip: the actor walked ONTO a slippery tile mid-move, so we
# redirect its in-progress movement (interrupt) along its travel direction.
func on_actor_entered_tile(actor: BattleActor, tile: BattleTileData, instance: EffectInstance, context: EffectContext) -> void:
	if context.mover == null or context.mover.direction == Vector3i.ZERO:
		return
	await _slip(actor, context.mover.direction, 999, context, true)

# Event-driven slip: something happened to the actor while it was STANDING on a
# slippery tile (e.g. struck by a forceful attack), so we START a fresh slide
# rather than redirecting a move that isn't happening.
func on_tile_event(tile: BattleTileData, event: TileEvent, instance: EffectInstance, context: EffectContext) -> void:
	match event.type:
		TileEvent.Type.ABILITY_HIT:
			var target: BattleActor = context.grid.get_actor_at(tile.cell)
			if target == null or event.caster == null:
				return
			# knockback heads away from the caster, source -> target cell
			var direction := Constants.direction_between(event.caster.grid_position, tile.cell)
			if direction == Vector3i.ZERO:
				return
			await _slip(target, direction, 999, context, false)
		TileEvent.Type.PROJECTILE_LANDED:
			pass
		_:
			pass

# Runs a slip for `actor` along `direction`. With room to move it slides and
# gets back up on landing; boxed in, it slips and falls on the spot. `redirect`
# picks the mover entry point: true interrupts an in-progress move (walked onto
# ice), false starts a fresh slide (struck while standing still).
func _slip(actor: BattleActor, direction: Vector3i, max_tiles: int, context: EffectContext, redirect: bool) -> void:
	var result := _build_slip_path(actor, direction, max_tiles, context)
	var path: Array[MovementStep] = result["path"]
	var crashed: bool = result["crashed"]

	# The slip always runs as a movement sequence — even when boxed in, where the
	# path is empty and it becomes a fall on the spot. Routing the fall through
	# the mover (rather than playing it directly) means an in-progress walk is
	# still aborted, so a unit that slips can't keep walking to where it was going.
	var falls_in_place := path.is_empty()
	var on_complete := func():
		# a slide plays its SLIP clip while travelling; a fall-in-place has no
		# steps, so play that clip explicitly here before getting back up
		if falls_in_place:
			await _play_fall(actor)
		elif crashed:
			# play_reaction=false: keep the crash damage's impact (shake, flash,
			# number) but skip the hit clip's return-to-idle, so the slip pose
			# holds straight into the recovery clip
			await context.executor.apply_damage(actor, CRASH_DAMAGE, false)
		await _recover(actor)

	var seq := MovementSequence.create(path, [EFFECT, EffectId.Id.FROZEN], on_complete)
	seq.movement_type = MovementSequence.MovementType.SLIP
	seq.first_step_duration = 0.8
	seq.first_step_ease = Tween.EASE_IN
	seq.first_step_trans = Tween.TRANS_QUINT
	seq.step_duration = 0.1
	if redirect:
		context.mover.interrupt_with_sequence(seq)
	else:
		await context.mover.start_sequence(actor, seq)

# Plays the slip/fall clip in place (no travel). Units only — objects have no
# fall clip.
func _play_fall(actor: BattleActor) -> void:
	if actor is Unit:
		await actor.play_slip()

# Gets a slipped actor back on its feet. Skipped when the actor isn't a unit or
# was defeated mid-slip (e.g. by crash damage), which has no "get up".
func _recover(actor: BattleActor) -> void:
	if actor is Unit and actor.is_alive():
		await actor.play_recover()

# Walks the direction of travel one tile at a time, collecting steps until the
# slide ends. Returns { "path": Array[MovementStep], "crashed": bool } —
# crashed distinguishes an impact (blocked by terrain/actor) from coasting to
# a natural stop on solid ground.
func _build_slip_path(actor: BattleActor, direction: Vector3i, max_tiles: int, context: EffectContext) -> Dictionary:
	var path: Array[MovementStep] = []
	var sliding := true
	var crashed := false
	var curr_pos: Vector3i = actor.grid_position + direction

	while sliding and path.size() < max_tiles:
		var curr_tile: BattleTileData = context.grid.get_tile(curr_pos)
		var prev_pos: Vector3i = curr_pos - direction

		# ran off the edge of the walkable grid
		if curr_tile == null or not curr_tile.is_walkable:
			crashed = true
			sliding = false
			continue

		# can't slide up a step; an object or another actor stops us dead.
		# In all three cases we stop BEFORE this tile, so nothing is appended.
		if curr_pos.z > prev_pos.z or curr_tile.object_ref != null or curr_tile.unit_ref != null:
			crashed = true
			sliding = false
			continue

		path.append(_make_step(curr_pos, curr_tile, prev_pos))

		# solid footing — we slide ONTO this tile and stop here, no damage
		if not curr_tile.has_effect(EFFECT):
			sliding = false
			continue

		curr_pos += direction

	return { "path": path, "crashed": crashed }

func _make_step(cell: Vector3i, tile: BattleTileData, from: Vector3i) -> MovementStep:
	var step := MovementStep.new()
	step.cell = cell
	step.is_jump = false
	step.terrain_type = tile.terrain_type
	step.elevation_delta = cell.z - from.z
	return step
