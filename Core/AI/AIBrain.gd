class_name AIBrain
extends Node

# =============================================================================
# AIBrain — drives a full turn for any non-player-controlled unit.
#
# Pipeline per turn (see _take_turn): enumerate every legal action -> filter
# out illegal/pointless ones -> score each with weighted Considerations ->
# pick one according to the acting unit's Intelligence -> play it out through
# the SAME BattleManager state machine a human player uses (so there's no
# separate "AI executes instantly" path to keep in sync with the real one).
# =============================================================================

# --- AUTO-GENERATED CONSIDERATIONS LIST START ---
const CONSIDERATIONS: Array[GDScript] = [
	preload("res://Core/AI/Considerations/DestinationSafety.gd"),
	preload("res://Core/AI/Considerations/DistanceToTarget.gd"),
	preload("res://Core/AI/Considerations/EffectSynergy.gd"),
	preload("res://Core/AI/Considerations/ExpectedDamage.gd"),
	preload("res://Core/AI/Considerations/KillPotential.gd"),
	preload("res://Core/AI/Considerations/ResourceEfficiency.gd"),
	preload("res://Core/AI/Considerations/TargetWeakness.gd"),
]
# --- AUTO-GENERATED CONSIDERATIONS LIST END ---

var _considerations: Array[Consideration] = []
var _grid: BattleGrid = null
var _pathfinder: Pathfinder = null
var _turn_queue: TurnQueue = null
var _input_handler: InputHandler = null
var _turn_context: TurnContext = null		# execution context — mirrors battle_scene's, built independently
var _board_context: AIContext = null		# board evaluation context — used by considerations and enumerator
var _action_scorer: ActionScorer = null

# delay inserted between each simulated input step (move select -> hover ->
# confirm, etc) so an AI turn is watchable rather than instant
const DEFAULT_DELAY: float = 1.5

# =============================================================================
# SETUP
# =============================================================================

func setup(grid: BattleGrid, pathfinder: Pathfinder, turn_queue: TurnQueue, input_handler: InputHandler) -> void:
	_grid = grid
	_pathfinder = pathfinder
	_turn_queue = turn_queue
	_input_handler = input_handler
	_action_scorer = _setup_action_scorer()

	BattleManager.active_unit_changed.connect(_on_active_unit_changed, CONNECT_DEFERRED)

func _setup_action_scorer() -> ActionScorer:
	var scorer = ActionScorer.new()

	for script in CONSIDERATIONS:
		_considerations.append(script.new())
	scorer.considerations = _considerations

	return scorer


# =============================================================================
# TURN FLOW
# =============================================================================

# any unit that isn't player-controlled (ENEMY or NEUTRAL — see
# BattleActorData.Type) gets its turn driven by this brain
func _on_active_unit_changed(actor: Unit) -> void:
	if actor.data.type != BattleActorData.Type.PLAYER:
		await _take_turn(actor)

func _take_turn(actor: Unit) -> void:
	# build both contexts independently — no coupling to battle_scene's turn context
	_turn_context = TurnContext.for_unit(actor, _pathfinder)
	_board_context = _build_board_context(actor)

	_simulate_cell_hover(actor.grid_position)

	# 1. enumerate every legal move+ability combination reachable this turn
	var origin: BattleTileData = _grid.get_tile(actor.grid_position)
	var actions: Array[ActionCandidate] = ActionEnumerator.enumerate_actions(actor, origin, _pathfinder, _turn_context)
	actions = _filter_actions(actions)

	if actions.is_empty():
		BattleManager.end_turn()
		return

	# 2. score every remaining candidate via weighted Considerations
	_score_actions(actions)

	# 3. pick one according to this unit's Intelligence, then actually play it
	#    out through BattleManager like a human player's input would
	var chosen: ActionCandidate = _choose_action(actions, _board_context.profile.intelligence)
	await _execute_action(actor, chosen)

# runs ActionScorer and alters the actions array in-place, attaching a score
# generated from the weighted Considerations for this unit's AIProfile
func _score_actions(actions: Array[ActionCandidate]) -> void:
	_action_scorer.score_actions(actions, _board_context)

# =============================================================================
# ACTION SELECTION
#
# Candidates are assumed pre-sorted worst -> best by score (ActionScorer's
# contract). Intelligence doesn't change WHETHER a unit attacks — if any
# ability-attached candidate exists, one is always chosen over a move-only
# candidate. What Intelligence changes is HOW GOOD the chosen action is:
# the sorted pool is split into as many equal buckets as there are
# Intelligence ranks, DUMB draws from the worst bucket, SMART from the best,
# and within its bucket a unit still picks randomly among the top 3 rather
# than always the single best — so same-intelligence units don't all play
# identically.
# =============================================================================

func _choose_action(actions: Array[ActionCandidate], intelligence: AIProfile.Intelligence) -> ActionCandidate:
	var ability_candidates = actions.filter(func(a): return a.ability != null)
	var move_only_candidates = actions.filter(func(a): return a.ability == null)

	# if attack candidates exist, always pick from those — intelligence determines
	# which attack is chosen, not whether to attack at all
	var pool = ability_candidates if not ability_candidates.is_empty() else move_only_candidates

	# too few candidates to meaningfully split into intelligence-sized buckets —
	# just take the single best (assumes ascending sort: last = best)
	if pool.size() < AIProfile.Intelligence.keys().size() * 2:
		return pool[pool.size() - 1]

	var split = split_array(pool, AIProfile.Intelligence.keys().size())
	match intelligence:
		AIProfile.Intelligence.DUMB:
			# worst bucket (split[0]) — pick randomly among its best 3
			var possible = split[0].slice(-3)
			return possible[randi_range(0, possible.size() - 1)]
		AIProfile.Intelligence.NORMAL:
			var possible = split[1].slice(-3)
			return possible[randi_range(0, possible.size() - 1)]
		AIProfile.Intelligence.SMART:
			# best bucket (split[2]) — pick randomly among its best 3
			var possible = split[2].slice(-3)
			return possible[randi_range(0, possible.size() - 1)]
		_:
			return pool[0]

# =============================================================================
# EXECUTION — replays the chosen action through BattleManager's real state
# machine (MOVE_SELECT -> confirm_move, ABILITIES_SELECT -> confirm_target),
# the same path a human player's input takes, with DEFAULT_DELAY pauses so
# the turn is watchable instead of instantaneous.
# =============================================================================

func _execute_action(actor: Unit, action: ActionCandidate) -> void:
	if action.acts_first:
		await _execute_ability(actor, action)
		await _execute_move(actor, action)
	else:
		await _execute_move(actor, action)
		await _execute_ability(actor, action)

	# TODO: replace with signal-driven end — listen for move_consumed + ability_consumed
	await get_tree().create_timer(5).timeout
	BattleManager.end_turn()

func _execute_move(actor: Unit, action: ActionCandidate) -> void:
	if actor.can_move():
		await _add_delay(DEFAULT_DELAY)
		BattleManager.change_state(BattleManager.BattleState.MOVE_SELECT)
		await _add_delay(DEFAULT_DELAY)
		_simulate_cell_hover(action.move_cell)
		await _add_delay(DEFAULT_DELAY)
		await BattleManager.confirm_move(action.move_cell)
		_simulate_cell_hover(actor.grid_position)

func _execute_ability(actor: Unit, action: ActionCandidate) -> void:
	if actor.can_act() and action.ability != null:
		await _add_delay(DEFAULT_DELAY)
		BattleManager.change_state(BattleManager.BattleState.ABILITIES_SELECT)
		BattleManager.select_ability(action.ability)
		await _add_delay(DEFAULT_DELAY)
		_simulate_cell_hover(action.target_cell)
		await _add_delay(DEFAULT_DELAY)
		await BattleManager.confirm_target(action.target_cell)
		_simulate_cell_hover(actor.grid_position)


# =============================================================================
# FILTERING / CONTEXT
# =============================================================================

# drops any ability-attached candidate whose target is dead, is the acting
# unit itself, or is an ally (same Type as the acting unit)
func _filter_actions(actions: Array[ActionCandidate]) -> Array[ActionCandidate]:
	return actions.filter(func(a: ActionCandidate) -> bool:
		if a.ability == null:
			return true
		var target = _grid.get_actor_at(a.target_cell)
		# target must exist and be alive
		if target == null or target.data.is_dead:
			return false
			
		if a.ability.intent == AbilityData.Intent.OFFENSIVE:
			# cannot target self for offensive
			if target == _board_context.acting_unit:
				return false
			# don't attack allies or neutral
			if target.data.type == _board_context.acting_unit.data.type or \
			target.data.type == BattleActorData.Type.NEUTRAL:
				return false
			return true
		elif a.ability.intent == AbilityData.Intent.SUPPORT:
			# don't heal enemies or neutral
			if target.data.type != _board_context.acting_unit.data.type:
				return false
			return true
		else:
			print("ERROR: Unmatched Ability Intent")
			return true
	)

func _build_board_context(acting_unit: Unit) -> AIContext:
	var context = AIContext.new()
	context.grid = _grid
	context.acting_unit = acting_unit
	context.profile = acting_unit.data.get_ai_profile()
	context.pathfinder = _pathfinder
	context.player_units = _turn_queue.get_all_player_units()
	context.enemy_units = _turn_queue.get_all_enemy_units()
	return context


# =============================================================================
# UTILITY
# =============================================================================

func _add_delay(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _simulate_cell_hover(cell: Vector3i) -> void:
	_input_handler.emit_signal("cell_hovered", Vector2i(cell.x, cell.y))

# splits arr into `chunks` roughly-equal, order-preserving slices (last slice
# may be shorter). Used to bucket sorted action candidates by intelligence
# rank — see _choose_action.
func split_array(arr: Array, chunks: int) -> Array:
	var size := arr.size()
	var chunk_size := int(ceil(float(size) / chunks))
	var result := []

	for i in range(chunks):
		var start := i * chunk_size
		var end: int = min(start + chunk_size, size)
		if start >= size:
			result.append([])  # empty chunk rather than breaking
		else:
			result.append(arr.slice(start, end))

	return result
