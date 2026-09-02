class_name UnitMover
extends Node

# Executes step-by-step grid movement for ANY battle actor — units walking,
# but also objects being pushed, rolled, or sliding on ice. Actors implement
# the shared movement interface (play_walk/play_jump/play_idle,
# set_facing_toward, update_z_index, set_effect_alpha, on_terrain_changed);
# BattleObject stubs the visual calls it doesn't need.
#
# Movement runs as a QUEUE of MovementSequences rather than a single steps
# array. Effects that redirect movement (SlipperyHandler, and later knockback
# / magnetism / etc) call interrupt_with() to replace what's pending, instead
# of mutating in-flight state. Because a sequence always finishes its current
# step before the queue advances, nothing can re-enter mid-execution and no
# "am I currently slipping" flags are needed.

signal movement_complete(actor)

var _grid: BattleGrid = null
var _effect_executor: EffectExecutor = null
var _is_moving: bool = false
var _get_world_pos: Callable
var _camera: BattleCamera = null

var _queue: Array[MovementSequence] = []
var _abort_current: bool = false

# True when the most recent movement session crossed a tile carrying a live
# (non-suppressed) effect — i.e. the actor struck a hazard along the way. Reset
# at the start of each movement session; read afterwards (e.g. to forbid undoing
# a move that already exposed the unit to a hazard). Committing to a risky path
# is a real decision — you don't get to take it back once it's paid off.
var struck_hazard: bool = false

# Direction of the step currently being executed, as a unit Vector3i on the
# XY plane. Vector3i.ZERO means "not moving" — a real direction is never zero.
# Effects read this to know which way an actor was travelling when it entered
# their tile.
var direction: Vector3i = Vector3i.ZERO

func setup(grid, effect_executor, get_world_pos: Callable, camera: BattleCamera) -> void:
	_grid = grid
	_effect_executor = effect_executor
	_get_world_pos = get_world_pos
	_camera = camera


# =============================================================================
# PUBLIC API
# =============================================================================

# Starts a prebuilt sequence from idle (append + drain). The sibling of
# interrupt_with_sequence, for effects that move a STANDING actor (a hit-slip,
# knockback) rather than redirecting one already in motion.
func start_sequence(actor, sequence: MovementSequence) -> void:
	_queue.append(sequence)
	if not _is_moving:
		await _drain_queue(actor)

# Replaces everything still pending with a new sequence, and stops the current
# sequence after the step it's on finishes. This is what movement-modifying
# effects call — the actor abandons wherever it was headed and follows the new
# path instead. An effect passes its own id in suppressed_effects so the path
# it just built doesn't re-trigger it tile by tile.
func interrupt_with_sequence(sequence: MovementSequence) -> void:
	_queue.clear()
	_queue.append(sequence)
	_abort_current = true

# =============================================================================
# EXECUTION
# =============================================================================

func _drain_queue(actor) -> void:
	_is_moving = true
	# fresh movement session — forget any hazard struck on the previous one
	struck_hazard = false
	while not _queue.is_empty():
		var sequence: MovementSequence = _queue.pop_front()
		var completed: bool = await _execute_sequence(actor, sequence)
		# on_complete fires ONLY for a sequence that ran to its natural end.
		# A sequence cut short by interrupt_with_sequence() (e.g. a slip
		# redirected by wind, or a walk redirected into a slip) is abandoned —
		# its callback (crash damage, recovery anim) must not fire, since it
		# never actually reached the outcome that callback represents.
		if completed and sequence.on_complete.is_valid():
			await sequence.on_complete.call()

	actor.play_idle()
	direction = Vector3i.ZERO
	_is_moving = false
	emit_signal("movement_complete", actor)

# Runs one sequence to completion. Returns true if every step played out, or
# false if an entry effect interrupted it mid-flight (interrupt_with_sequence),
# so the caller knows whether the sequence's on_complete callback is meaningful.
func _execute_sequence(actor, sequence: MovementSequence) -> bool:
	_abort_current = false
	# The locomotion animation is started ONCE and left to run for the whole
	# run of steps, rather than restarted every step. This is what lets a
	# one-shot clip (a slip) play through instead of resetting to frame 0 each
	# tile, while a looping clip (walk) simply keeps looping. Jumps are discrete
	# hops, so each one replays and then hands back to the movement clip.
	var movement_playing := false
	for i in range(sequence.steps.size()):
		var step: MovementStep = sequence.steps[i]

		# restore alpha to neutral — refresh_tile_occupancy will re-dim if needed
		actor.set_effect_alpha(1.0)

		var from: Vector3i = actor.grid_position
		var delta: Vector3i = step.cell - from
		direction = Constants.direction_step(delta)

		_grid.move_actor(actor, from, step.cell)
		actor.update_z_index()
		actor.set_facing_toward(from, step.cell)
		if step.is_jump:
			actor.play_jump()
			movement_playing = false
		elif not movement_playing:
			actor.play_movement(sequence.movement_type)
			movement_playing = true

		var target_pos: Vector2 = _get_world_pos.call(step.cell)
		var is_first := i == 0
		var duration: float = sequence.first_step_duration if is_first else sequence.step_duration
		var ease_type: Tween.EaseType = sequence.first_step_ease if is_first else sequence.step_ease
		var trans_type: Tween.TransitionType = sequence.first_step_trans if is_first else sequence.step_trans

		var tween = actor.create_tween()
		tween.set_ease(ease_type).set_trans(trans_type)
		tween.tween_property(actor, "global_position", target_pos, duration)
		await tween.finished
		_camera.pan_to(target_pos)

		_update_water_state(actor, step.cell)

		# Tile-entry effects fire after the actor has actually arrived, on
		# EVERY tile — a slide still burns you, still gets caught by wind.
		# Only the interrupting effect itself is filtered out, per sequence.
		await _apply_entry_effects(actor, step.cell, sequence.suppressed_effects)

		# An entry effect may have called interrupt_with() just above; bail out
		# so the queue can advance to whatever it queued.
		if _abort_current:
			_abort_current = false
			return false

	return true

func _apply_entry_effects(actor, cell: Vector3i, suppressed: Array[EffectId.Id]) -> void:
	if _effect_executor == null:
		return
	var tile: BattleTileData = _grid.get_tile(cell)
	if tile != null:
		if _tile_has_live_effect(tile, suppressed):
			struck_hazard = true
		await _effect_executor.apply_tile_entry_effects(actor, tile, suppressed)

# true if the tile carries any effect that would actually fire on entry — i.e.
# an active effect not being suppressed for this sequence (a slide suppresses
# the very effect that launched it, so those don't re-count as fresh strikes)
func _tile_has_live_effect(tile: BattleTileData, suppressed: Array[EffectId.Id]) -> bool:
	for instance in tile.active_effects:
		if not suppressed.has(instance.effect_id):
			return true
	return false

# dims/undims the actor when passing beneath a water tile one elevation up
func _update_water_state(actor, cell: Vector3i) -> void:
	var above := Vector3i(cell.x - 1, cell.y - 1, cell.z + 1)
	var above_tile: BattleTileData = _grid.get_tile(above)
	if above_tile != null and above_tile.terrain_type == BattleTileData.TerrainType.WATER:
		actor.on_terrain_changed(BattleTileData.TerrainType.WATER)
	else:
		actor.on_terrain_changed(BattleTileData.TerrainType.NORMAL)
