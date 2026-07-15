extends Node

enum BattleState {
	SETUP,				# units being placed, pre-battle
	ACTION_SELECT,		# active unit's turn — player choosing an action (move, abilities, equipment, wait)
	EQUIPMENT_SELECT,	# player browsing equipped items
	ABILITIES_SELECT,	# player choosing which ability to use
	JOB_ABILITIES_SELECT,
	MOVE_SELECT,		# player selecting a destination tile
	TARGET_SELECT,		# player selecting a target for an ability
	RESOLVING,			# action is executing, no input accepted
	ENEMY_TURN,			# AI is taking its turn
	TERRAIN_TURN,		# resolving all round-based terrain effects and visuals
	BATTLE_END,			# battle is over, win or lose
}

enum BattleWinCondition {
	DEFEAT_ALL,			# Player must defeat all enemies
	DEFEAT_ONE,			# Player must defeat specific enemy
	SURVIVE,				# Player must survive until a certain condition is met, usually round based
	PROTECT_ONE,			# Player must prevent a unit or object from being defeated/destroyed
	REACH_LOCATION		# Player must reach a specific tile/set of tiles with one or more units
}

signal state_changed(new_state: BattleState)
signal active_unit_changed(unit: Unit)
signal unit_moved(unit: Unit, to_cell: Vector3i)
signal ability_selected(unit: Unit, ability: AbilityData)
signal unit_executed_ability(caster: Unit, target_cell: Vector3i, ability: AbilityData, camera: BattleCamera)
signal turn_ended(unit: Unit)

signal battle_ended(isWin: bool)

var current_state: BattleState = BattleState.SETUP
var active_unit: BattleActor = null
var player_units: Array[BattleActor] = []
var enemy_units: Array[BattleActor] = []
var current_round: int = 1

#TODO: create in BattleEndConditionContext
var current_win_condition: BattleWinCondition = BattleWinCondition.DEFEAT_ALL
var defeat_target: BattleActor = null
var protect_target: BattleActor = null
var survive_rounds: int = -1
var reach_tile: BattleTileData = null
var reach_requires_all: bool = false
var reach_arrived: Array[Unit] = []  # units that have already reached the tile


var _grid: BattleGrid = null
var _camera: BattleCamera = null
var _unit_mover: UnitMover = null
var _unit_ability_executor: UnitAbilityExecutor = null
var _effect_executor: EffectExecutor = null
var _current_ability: AbilityData = null
var _turn_queue: TurnQueue = null

# =============================================================================
# SETUP / LIFECYCLE
# =============================================================================

# initializes battle manager with required system references.
# Note: no UI reference — the UI reacts to state_changed / turn signals on its
# own. BattleManager never drives presentation directly.
func setup(grid: BattleGrid, camera: BattleCamera, unit_mover: UnitMover, unit_ability_executor: UnitAbilityExecutor, effect_executor: EffectExecutor, turn_queue: TurnQueue) -> void:
	_grid = grid
	_camera = camera
	_unit_mover = unit_mover
	_unit_ability_executor = unit_ability_executor
	_effect_executor = effect_executor
	_turn_queue = turn_queue
	
	#TODO: fetch this information from battle instance .tres file on setup
	current_win_condition = BattleWinCondition.DEFEAT_ALL

# clears all battle state — call when leaving a battle scene
func reset() -> void:
	current_state = BattleState.SETUP
	active_unit = null
	player_units.clear()
	enemy_units.clear()
	if _turn_queue != null:
		_turn_queue.reset()

# begins the battle with the given player and enemy unit arrays
func start_battle(p_units: Array[BattleActor], e_units: Array[BattleActor]) -> void:
	player_units = p_units
	enemy_units = e_units
	_turn_queue.call_deferred("start_next_turn")

# =============================================================================
# STATE MACHINE
# =============================================================================

# transitions to a new state and notifies all listeners
func change_state(new_state: BattleState) -> void:
	current_state = new_state
	state_changed.emit(new_state)

func set_active_unit(participant) -> void:
	if participant is TerrainTurnParticipant:
		change_state(BattleState.TERRAIN_TURN)
		current_round += 1
		return
	active_unit = participant
	active_unit.reset_turn()
	print("emitting active unit changed")
	active_unit_changed.emit(active_unit)
	if player_units.has(active_unit):
		change_state(BattleState.ACTION_SELECT)
	else:
		change_state(BattleState.ENEMY_TURN)

# =============================================================================
# PLAYER ACTIONS
# =============================================================================

# transitions to MOVE_SELECT if the active unit hasn't moved yet
func select_action_move() -> void:
	if current_state != BattleState.ACTION_SELECT:
		_state_error("select_action_move", BattleState.ACTION_SELECT)
		return
	if active_unit.can_move():
		change_state(BattleState.MOVE_SELECT)

# transitions to ABILITIES_SELECT to show the ability list
func select_action_abilities() -> void:
	if current_state != BattleState.ACTION_SELECT:
		_state_error("select_action_abilities", BattleState.ACTION_SELECT)
		return
	if active_unit.can_act():
		change_state(BattleState.ABILITIES_SELECT)

# transitions to EQUIPMENT_SELECT to show the unit's equipped items
func select_action_equipment() -> void:
	if current_state != BattleState.ACTION_SELECT:
		_state_error("select_action_equipment", BattleState.ACTION_SELECT)
		return
	change_state(BattleState.EQUIPMENT_SELECT)

func select_job_ability() -> void:
	if current_state != BattleState.ABILITIES_SELECT:
		_state_error("select_job_ability", BattleState.ABILITIES_SELECT)
		return
	change_state(BattleState.JOB_ABILITIES_SELECT)

# stores the chosen ability and transitions to TARGET_SELECT
func select_ability(ability: AbilityData) -> void:
	if current_state != BattleState.JOB_ABILITIES_SELECT and \
	current_state != BattleState.ABILITIES_SELECT:
		_state_error("select_ability", BattleState.JOB_ABILITIES_SELECT)
		return

	_current_ability = ability
	ability_selected.emit(active_unit, ability)
	change_state(BattleState.TARGET_SELECT)

# returns to ACTION_SELECT from any sub-selection state
func cancel_action() -> void:
	if current_state != BattleState.MOVE_SELECT and \
	   current_state != BattleState.TARGET_SELECT and \
	   current_state != BattleState.EQUIPMENT_SELECT and \
	   current_state != BattleState.ABILITIES_SELECT and \
	   current_state != BattleState.JOB_ABILITIES_SELECT:
		_state_error("cancel_action", BattleState.MOVE_SELECT)
		return
	if current_state == BattleState.JOB_ABILITIES_SELECT:
		change_state(BattleState.ABILITIES_SELECT)
	else:
		change_state(BattleState.ACTION_SELECT)

# executes unit movement to target_cell and awaits completion before returning to ACTION_SELECT.
# consume_move happens HERE and only here — the single point where the turn
# resource is spent (it previously happened both here and in battle_scene,
# firing the move_consumed signal twice per move).
func confirm_move(target_cell: Vector3i) -> void:
	if current_state != BattleState.MOVE_SELECT:
		_state_error("confirm_move", BattleState.MOVE_SELECT)
		return
	unit_moved.emit(active_unit, target_cell)
	active_unit.consume_move()
	await _enter_resolving(_unit_mover.movement_complete, BattleState.ACTION_SELECT)

# executes an ability against target_cell and awaits completion before returning to ACTION_SELECT.
# consume_ability likewise happens only here.
func confirm_target(target_cell: Vector3i) -> void:
	if current_state != BattleState.TARGET_SELECT:
		_state_error("confirm_target", BattleState.TARGET_SELECT)
		return
	if not active_unit.can_act():
		push_error("confirm_target called when active_unit cannot act")
		return
	# TODO: display target unit's info, expected damage, elemental effects, and hit chance
	unit_executed_ability.emit(active_unit, target_cell, _current_ability, _camera)
	active_unit.consume_ability()
	await _enter_resolving(_unit_ability_executor.ability_complete, BattleState.ACTION_SELECT)

# ends the active unit's turn and advances to the next
func end_turn() -> void:
	if current_state != BattleState.ACTION_SELECT:
		_state_error("end_turn", BattleState.ACTION_SELECT)
		return

	_process_unit_turn_end_effects(active_unit)

	turn_ended.emit(active_unit)
	active_unit = null
	await get_tree().create_timer(Constants.FADE_OUT_TIMER).timeout
	_turn_queue.start_next_turn()

# =============================================================================
# INTERNALS
# =============================================================================

# transitions to RESOLVING, awaits a completion signal, then transitions to next_state
func _enter_resolving(completion_signal: Signal, next_state: BattleState) -> void:
	change_state(BattleState.RESOLVING)
	await completion_signal
	_check_for_battle_end()
	change_state(next_state)

func _process_unit_turn_end_effects(unit: Unit) -> void:
	var context = EffectContext.new()
	context.grid = _grid
	context.executor = _effect_executor
	var tile = _grid.get_tile(unit.grid_position)
	# process tile effects on the unit
	if tile != null:
		for instance in tile.active_effects.duplicate():
			var handler = EffectRegistry.get_handler(instance.effect_id)
			if handler != null:
				handler.on_unit_turn_end(unit, instance, context)
	# process unit's own effects
	for instance in unit.data.active_effects.duplicate():
		var handler = EffectRegistry.get_handler(instance.effect_id)
		if handler != null:
			handler.on_unit_turn_end(unit, instance, context)
			
func _check_for_battle_end() -> void:
	#check loss conditions
	if not _turn_queue.get_all_living_players().is_empty():
		#check win condition and match to appropriete conditional check
		match current_win_condition:
			BattleWinCondition.DEFEAT_ALL:
				if not _turn_queue.get_all_living_enemies().is_empty():
					return
			BattleWinCondition.DEFEAT_ONE:
				if _turn_queue.get_all_living_enemies().has(defeat_target):
					return
			BattleWinCondition.PROTECT_ONE:
				if _turn_queue.get_all_living_units().has(protect_target):
					return
			BattleWinCondition.REACH_LOCATION:
				if not player_units.has(reach_tile.unit_ref):
					return
			BattleWinCondition.SURVIVE:
				if current_round < survive_rounds:
					return
		emit_signal("battle_ended", true)
	else:
		emit_signal("battle_ended", false)
	change_state(BattleState.BATTLE_END)

# emits a push_error with context about which state was expected vs actual
func _state_error(func_name: String, expected: BattleState) -> void:
	push_error("BattleManager: %s called in wrong state. Expected %s, got %s" % [
		func_name,
		BattleState.keys()[expected],
		BattleState.keys()[current_state]
	])
