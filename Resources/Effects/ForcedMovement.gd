class_name ForcedMovement
extends RefCounted

# A reusable mechanism for shoving an actor along a direction — the shared core
# of a slip on ice, a wind gust, a magnetic pull/push. It is NOT an effect and
# NOT an EffectHandler; it's a service those handlers COMPOSE and drive. The
# mechanics are identical between them:
#
#   1. walk a straight line from the actor, one tile at a time, collecting steps
#      until the push ends (the owning effect decides when a tile lets it
#      continue via `continues_past`);
#   2. stops are either CLEAN (coasted to rest on valid ground) or a CRASH
#      (blocked by an edge, a step up, or another body);
#   3. hand the path to UnitMover as one sequence, suppressing the driving
#      effect so it can't re-trigger itself tile by tile;
#   4. on landing, optionally deal crash damage and play downed/rise animations.
#
# The owning handler configures the fields below (plain data + a few Callables
# bound to its own methods) and calls execute(). Only the KNOBS differ between
# forces — everything mechanical lives here, once.
#
# NOTE: momentum / force-hierarchy arbitration (unit under wind AND on ice, or
# pulled by two magnets) is intentionally NOT solved here — each force acts in
# isolation. That resolution layer sits ABOVE this, deciding which force wins
# before execute() is called.

# --- configuration (set by the owning effect) ---
var movement_type: MovementSequence.MovementType = MovementSequence.MovementType.WALK
var suppressed_effects: Array[EffectId.Id] = []
var crash_damage: int = 0							# 0 = a harmless bump
var continues_past: Callable = Callable()			# (tile: BattleTileData) -> bool; empty = always
var configure_sequence: Callable = Callable()		# (seq: MovementSequence) -> void
var on_downed: Callable = Callable()				# (actor) -> void, awaitable — fell in place
var on_rise: Callable = Callable()					# (actor) -> void, awaitable — got back up

# Shoves `actor` along `direction` for up to `max_tiles`. With room it slides and
# rises on landing; boxed in (empty path) it goes down on the spot. `redirect`
# picks the mover entry point: true interrupts an in-progress move (the actor
# walked into the force mid-move), false starts a fresh push (it was standing
# still when the force hit).
func execute(actor: BattleActor, direction: Vector3i, max_tiles: int, context: EffectContext, redirect: bool) -> void:
	var result := _build_path(actor, direction, max_tiles, context)
	var path: Array[MovementStep] = result["path"]
	var crashed: bool = result["crashed"]
	
	print("path: ", path)
	# always run as a movement sequence — even the empty (fall-in-place) case, so
	# routing it through the mover still aborts an in-progress walk (a shoved unit
	# can't keep strolling to where it was going).
	var falls_in_place := path.is_empty()
	var on_complete := func():
		if falls_in_place:
			if on_downed.is_valid():
				await on_downed.call(actor)
		elif crashed and crash_damage > 0:
			# play_reaction=false: keep the impact (shake, flash, number) but skip
			# the hit clip's return-to-idle, so the downed pose holds into the rise
			await context.executor.apply_damage(actor, crash_damage, false)
		if on_rise.is_valid():
			await on_rise.call(actor)

	var seq := MovementSequence.create(path, suppressed_effects, on_complete)
	seq.movement_type = movement_type
	if configure_sequence.is_valid():
		configure_sequence.call(seq)
	if redirect:
		context.mover.interrupt_with_sequence(seq)
	else:
		await context.mover.start_sequence(actor, seq)

# Walks the push direction one tile at a time, collecting steps until it ends.
# Returns { "path": Array[MovementStep], "crashed": bool } — crashed distinguishes
# an impact (blocked by terrain/actor) from coasting to a clean stop on valid
# ground (where continues_past returned false).
func _build_path(actor: BattleActor, direction: Vector3i, max_tiles: int, context: EffectContext) -> Dictionary:
	var path: Array[MovementStep] = []
	var moving := true
	var crashed := false
	var curr_pos: Vector3i = actor.grid_position + direction

	while moving and path.size() < max_tiles:
		var curr_tile: BattleTileData = context.grid.get_tile(curr_pos)
		var prev_pos: Vector3i = curr_pos - direction

		# ran off the edge of the walkable grid
		if curr_tile == null or not curr_tile.is_walkable:
			crashed = true
			moving = false
			continue

		# can't be shoved up a step; an object or another actor stops us dead.
		# In all three cases we stop BEFORE this tile, so nothing is appended.
		if curr_pos.z > prev_pos.z or curr_tile.object_ref != null or curr_tile.unit_ref != null:
			crashed = true
			moving = false
			continue

		path.append(_make_step(curr_pos, curr_tile, prev_pos))

		# landed on valid ground — does the force keep pushing past here? An empty
		# rule means "keep going" (a fixed-distance push runs until max_tiles).
		if continues_past.is_valid() and not continues_past.call(curr_tile):
			moving = false
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
