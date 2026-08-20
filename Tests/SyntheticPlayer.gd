class_name SyntheticPlayer
extends Node

# Drives every player-controlled unit's turn through the exact same
# BattleManager calls a real player would make — select_action_move,
# confirm_move, select_ability, confirm_target, end_turn. Never touches the
# grid, units, or executors directly, so it exercises the identical code path
# as manual play (and AIBrain handles enemy-controlled units on its own,
# since it self-subscribes to the same active_unit_changed signal).

enum Strategy {
	FURTHEST_MOVE,
	CLOSEST_MOVE,
	HIGHEST_ELEVATION,
	LOWEST_ELEVATION,
	USE_EACH_ABILITY,
	WAIT_ONLY,
	USE_FIGHT_ABILITY
}

# suite-wide coverage counters — persist across scenarios (static), reset
# only at the start of a full suite run via reset_coverage(), so "eventually
# everything gets tested" holds across the whole run, not per scenario
static var _strategy_use_count: Dictionary = {}
static var _ability_use_count: Dictionary = {}	# AbilityData resource -> count

var _grid: BattleGrid = null
var _pathfinder: Pathfinder = null
var _rng: RandomNumberGenerator = null

func setup(grid: BattleGrid, pathfinder: Pathfinder, rng: RandomNumberGenerator) -> void:
	_grid = grid
	_pathfinder = pathfinder
	_rng = rng
	BattleManager.active_unit_changed.connect(_on_active_unit_changed, CONNECT_DEFERRED)

func teardown() -> void:
	if BattleManager.active_unit_changed.is_connected(_on_active_unit_changed):
		BattleManager.active_unit_changed.disconnect(_on_active_unit_changed)

func _on_active_unit_changed(actor) -> void:
	print("[SP] active_unit_changed received — actor: ", actor, " is_unit: ", actor is Unit)
	if not (actor is Unit) or not actor.data.is_player_controlled:
		print("[SP] skipping — not player controlled")
		return
	print("[SP] taking turn for: ", actor.data.name)
	await _take_turn(actor)

func _least_used_strategy() -> Strategy:
	var strategies: Array = Strategy.values()
	strategies.sort_custom(func(a, b): return _strategy_use_count.get(a, 0) < _strategy_use_count.get(b, 0))
	return strategies[0]

func _take_turn(actor: Unit) -> void:
	# wait for ACTION_SELECT in case we fired before BattleManager finished transitioning
	while BattleManager.current_state != BattleManager.BattleState.ACTION_SELECT:
		await get_tree().process_frame
		
	var strategy: Strategy = _least_used_strategy()
	print("[SP] taking turn for: ", actor.data.name, " strategy: ", Strategy.keys()[strategy])
	_strategy_use_count[strategy] = _strategy_use_count.get(strategy, 0) + 1

	match strategy:
		Strategy.WAIT_ONLY:
			print("[SP] waiting")
		Strategy.FURTHEST_MOVE, Strategy.CLOSEST_MOVE, Strategy.HIGHEST_ELEVATION, Strategy.LOWEST_ELEVATION:
			print("[SP] doing positional move")
			await _do_positional_move(actor, strategy)
			print("[SP] positional move complete")
		Strategy.USE_EACH_ABILITY:
			print("[SP] doing ability cycle")
			await _do_ability_cycle(actor)
			print("[SP] ability cycle complete")

	print("[SP] calling end_turn — state: ", BattleManager.BattleState.keys()[BattleManager.current_state])
	if BattleManager.current_state == BattleManager.BattleState.ACTION_SELECT:
		BattleManager.end_turn()
	print("[SP] end_turn called")

func _do_positional_move(actor: Unit, strategy: Strategy) -> void:
	if not actor.can_move():
		return
	var context := TurnContext.for_unit(actor, _pathfinder)
	var candidates: Array[Vector3i] = []
	for cell in context.reachable_move_cells.keys():
		if context.reachable_move_cells[cell]:
			candidates.append(cell)
	if candidates.is_empty():
		return

	# sort candidates by strategy
	match strategy:
		Strategy.FURTHEST_MOVE:
			candidates.sort_custom(func(a, b): return _dist(actor.grid_position, a) > _dist(actor.grid_position, b))
		Strategy.CLOSEST_MOVE:
			candidates.sort_custom(func(a, b): return _dist(actor.grid_position, a) < _dist(actor.grid_position, b))
		Strategy.HIGHEST_ELEVATION:
			candidates.sort_custom(func(a, b): return a.z > b.z)
		Strategy.LOWEST_ELEVATION:
			candidates.sort_custom(func(a, b): return a.z < b.z)

	var chosen: Vector3i = candidates[0]
	BattleManager.select_action_move()
	await get_tree().process_frame  # let state settle to MOVE_SELECT before confirming
	if BattleManager.current_state != BattleManager.BattleState.MOVE_SELECT:
		return  # state guard failed — bail out, end_turn will clean up
	await BattleManager.confirm_move(chosen)

func _do_fight_ability(actor: Unit) -> void:
	if not actor.can_act() or actor.data.job == null:
		return
	var fight: AbilityData = actor.data.job.fight_ability
	if fight == null:
		return
	var context := TurnContext.for_unit(actor, _pathfinder)
	context.select_ability(fight, _pathfinder)
	var targets: Array[Vector3i] = []
	for cell in context.reachable_target_cells.keys():
		if context.reachable_target_cells[cell]:
			targets.append(cell)
	if targets.is_empty():
		return

	_ability_use_count[fight] = _ability_use_count.get(fight, 0) + 1
	var target_cell: Vector3i = targets[_rng.randi_range(0, targets.size() - 1)]

	BattleManager.select_action_abilities()
	await get_tree().process_frame
	if BattleManager.current_state != BattleManager.BattleState.ABILITIES_SELECT:
		return
	BattleManager.select_ability(fight)
	await get_tree().process_frame
	if BattleManager.current_state != BattleManager.BattleState.TARGET_SELECT:
		return
	await BattleManager.confirm_target(target_cell)

func _do_ability_cycle(actor: Unit) -> void:
	if not actor.can_act():
		return
	var abilities: Array = actor.data.abilities.duplicate()
	if abilities.is_empty():
		return
	abilities.sort_custom(func(a, b):
		var a_is_fight = actor.data.job != null and a == actor.data.job.fight_ability
		var b_is_fight = actor.data.job != null and b == actor.data.job.fight_ability
		if a_is_fight != b_is_fight:
			return not a_is_fight
		return _ability_use_count.get(a, 0) < _ability_use_count.get(b, 0)
	)
	var ability: AbilityData = abilities[0]
	if actor.data.current_mp < ability.mp_cost:
		return

	var context := TurnContext.for_unit(actor, _pathfinder)
	context.select_ability(ability, _pathfinder)
	var targets: Array[Vector3i] = []
	for cell in context.reachable_target_cells.keys():
		if context.reachable_target_cells[cell]:
			targets.append(cell)
	if targets.is_empty():
		return

	_ability_use_count[ability] = _ability_use_count.get(ability, 0) + 1
	var target_cell: Vector3i = targets[_rng.randi_range(0, targets.size() - 1)]

	BattleManager.select_action_abilities()
	await get_tree().process_frame
	if BattleManager.current_state != BattleManager.BattleState.ABILITIES_SELECT:
		return
	BattleManager.select_ability(ability)
	await get_tree().process_frame
	if BattleManager.current_state != BattleManager.BattleState.TARGET_SELECT:
		return
	await BattleManager.confirm_target(target_cell)

func _dist(a: Vector3i, b: Vector3i) -> float:
	return Vector2(a.x - b.x, a.y - b.y).length() + absf(a.z - b.z) * Constants.ELEVATION_DISTANCE_MULTIPLIER

static func coverage_report() -> String:
	var lines: Array[String] = ["=== Synthetic Player Coverage (suite-wide) ==="]
	lines.append("Strategies used:")
	for s in Strategy.values():
		lines.append("  %s: %d" % [Strategy.keys()[s], _strategy_use_count.get(s, 0)])
	lines.append("Abilities exercised:")
	if _ability_use_count.is_empty():
		lines.append("  (none)")
	for ability in _ability_use_count.keys():
		lines.append("  %s: %d" % [ability.ability_name, _ability_use_count[ability]])
	return "\n".join(lines)

static func reset_coverage() -> void:
	_strategy_use_count.clear()
	_ability_use_count.clear()
