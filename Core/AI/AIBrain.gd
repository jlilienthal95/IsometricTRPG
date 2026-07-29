class_name AIBrain
extends Node

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

const DEFAULT_DELAY: float = 1.5

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

func _on_active_unit_changed(actor: Unit) -> void:
	if not actor.data.is_player_controlled:
		await _take_turn(actor)

func _take_turn(actor: Unit) -> void:
	# build both contexts independently — no coupling to battle_scene's turn context
	_turn_context = TurnContext.for_unit(actor, _pathfinder)
	_board_context = _build_board_context(actor)

	_simulate_cell_hover(actor.grid_position)

	var origin: BattleTileData = _grid.get_tile(actor.grid_position)
	var actions: Array[ActionCandidate] = ActionEnumerator.enumerate_actions(actor, origin, _pathfinder, _turn_context)

	if actions.is_empty():
		BattleManager.end_turn()
		return

	# score candidates via considerations + _board_context
	_score_actions(actions)
	
	# choose action based on intelligence filter
	var chosen: ActionCandidate = _choose_action(actions, _board_context.profile.intelligence)
	print("Chosen Action:")
	chosen.debug_print()
	await _execute_action(actor, chosen)
	
# run ActionScorer and alter actions array in-place, adding scores generates from weighted Considerations
func _score_actions(actions: Array[ActionCandidate]) -> void:
	_action_scorer.score_actions(actions, _board_context)

# choose action, matching logic from intelligence in AIProfile
func _choose_action(actions: Array[ActionCandidate], intelligence: AIProfile.Intelligence) -> ActionCandidate:
	var ability_candidates = actions.filter(func(a): return a.ability != null)
	var move_only_candidates = actions.filter(func(a): return a.ability == null)
	
	# if attack candidates exist, always pick from those — intelligence determines
	# which attack is chosen, not whether to attack at all
	var pool = ability_candidates if not ability_candidates.is_empty() else move_only_candidates
	
	print("Ability candidates: ", ability_candidates.size(), " Move-only candidates: ", move_only_candidates.size())
	print("Using pool of size: ", pool.size())
	#print("ActionCandidates, ALL:")
	#for action in pool:
		#action.debug_print()
	
	if pool.size() < AIProfile.Intelligence.keys().size() * 2:
		print("Pool too small for meaningful split, returning best available:")
		pool[pool.size() - 1].debug_print()
		return pool[pool.size() - 1]
	
	var split = split_array(pool, AIProfile.Intelligence.keys().size())
	match intelligence:
		AIProfile.Intelligence.DUMB:
			var possible = split[0].slice(-3)
			print("Action Candidates, DUMB:")
			for action in possible:
				action.debug_print()
			return possible[randi_range(0, possible.size() - 1)]
		AIProfile.Intelligence.NORMAL:
			var possible = split[1].slice(-3)
			print("Action Candidates, NORMAL:")
			for action in possible:
				action.debug_print()
			return possible[randi_range(0, possible.size() - 1)]
		AIProfile.Intelligence.SMART:
			print("ALL Action Candidates, SMART:")
			for action in split[2]:
				action.debug_print()
			var possible = split[2].slice(-3)
			print("CHOSEN Action Candidates, SMART:")
			for action in possible:
				action.debug_print()
			return possible[randi_range(0, possible.size() - 1)]
		_:
			return pool[0]

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

func _build_board_context(acting_unit: Unit) -> AIContext:
	var context = AIContext.new()
	context.grid = _grid
	context.acting_unit = acting_unit
	context.profile = acting_unit.data.get_ai_profile()
	context.pathfinder = _pathfinder
	context.player_units = _turn_queue.get_all_player_units()
	context.enemy_units = _turn_queue.get_all_enemy_units()
	return context

func _add_delay(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _simulate_cell_hover(cell: Vector3i) -> void:
	_input_handler.emit_signal("cell_hovered", Vector2i(cell.x, cell.y))
	
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
