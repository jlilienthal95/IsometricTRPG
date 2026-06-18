extends Node

enum BattleState {
	SETUP,				# units being placed, pre-battle
	ACTION_SELECT,		# active unit's turn — player choosing an action (move, attack, equipment, wait)
	EQUIPMENT_SELECT,	# player browsing equipped items
	ATTACK_SELECT,		# player choosing which ability to use
	MOVE_SELECT,		# player selecting a destination tile
	TARGET_SELECT,		# player selecting a target for an ability
	RESOLVING,			# action is executing, no input accepted
	ENEMY_TURN,			# AI is taking its turn
	BATTLE_END,			# battle is over, win or lose
}

signal state_changed(new_state: BattleState)
signal active_unit_changed(unit: Unit)
signal unit_moved(unit: Unit, to_cell: Vector3i)
signal move_consumed
signal attack_consumed
signal ability_selected(unit: Unit, ability: AbilityData)
signal unit_executed_ability(caster: Unit, target_cell: Vector3i, ability: AbilityData, camera: BattleCamera)

var current_state: BattleState = BattleState.SETUP
var active_unit: Unit = null
var player_units: Array[Unit] = []
var enemy_units: Array[Unit] = []
var turn: int = -1

var _grid: BattleGrid = null
var _camera: BattleCamera = null
var _unit_mover: UnitMover = null
var _unit_ability_executor: Node = null
var _current_ability: AbilityData = null

# initializes battle manager with required system references
func setup(grid: BattleGrid, camera: BattleCamera, unit_mover: UnitMover, unit_ability_executor: Node) -> void:
	_grid = grid
	_camera = camera
	_unit_mover = unit_mover
	_unit_ability_executor = unit_ability_executor

# clears all battle state — call when leaving a battle scene
func reset() -> void:
	current_state = BattleState.SETUP
	active_unit = null
	player_units.clear()
	enemy_units.clear()
	turn = -1

# transitions to a new state and notifies all listeners
func change_state(new_state: BattleState) -> void:
	current_state = new_state
	emit_signal("state_changed", new_state)
	print("BattleManager state: ", BattleState.keys()[new_state])

# begins the battle with the given player and enemy unit arrays
func start_battle(p_units: Array[Unit], e_units: Array[Unit]) -> void:
	player_units = p_units
	enemy_units = e_units
	_start_next_turn()

# transitions to MOVE_SELECT if the active unit hasn't moved yet
func select_action_move() -> void:
	if current_state != BattleState.ACTION_SELECT:
		_state_error("select_action_move", BattleState.ACTION_SELECT)
		return
	if active_unit.can_move():
		change_state(BattleState.MOVE_SELECT)

# transitions to ATTACK_SELECT to show the ability list
func select_action_attack() -> void:
	if current_state != BattleState.ACTION_SELECT:
		_state_error("select_action_attack", BattleState.ACTION_SELECT)
		return
	# TODO: check active_unit.can_act() once action handling logic is implemented
	change_state(BattleState.ATTACK_SELECT)

# stores the chosen ability and transitions to TARGET_SELECT
func select_ability(ability: AbilityData) -> void:
	if current_state != BattleState.ATTACK_SELECT:
		_state_error("select_ability", BattleState.ATTACK_SELECT)
		return
	_current_ability = ability
	emit_signal("ability_selected", active_unit, ability)
	change_state(BattleState.TARGET_SELECT)
	print("ability selected: ", ability.ability_name)

# transitions to EQUIPMENT_SELECT to show the unit's equipped items
func select_action_equipment() -> void:
	if current_state != BattleState.ACTION_SELECT:
		_state_error("select_action_equipment", BattleState.ACTION_SELECT)
		return
	change_state(BattleState.EQUIPMENT_SELECT)

# returns to ACTION_SELECT from any sub-selection state
func cancel_action() -> void:
	if current_state != BattleState.MOVE_SELECT and \
	   current_state != BattleState.TARGET_SELECT and \
	   current_state != BattleState.EQUIPMENT_SELECT and \
	   current_state != BattleState.ATTACK_SELECT:
		_state_error("cancel_action", BattleState.MOVE_SELECT)
		return
	change_state(BattleState.ACTION_SELECT)

# executes unit movement to target_cell and awaits completion before returning to ACTION_SELECT
func confirm_move(target_cell: Vector3i) -> void:
	if current_state != BattleState.MOVE_SELECT:
		_state_error("confirm_move", BattleState.MOVE_SELECT)
		return
	emit_signal("unit_moved", active_unit, target_cell)
	emit_signal("move_consumed")
	await _enter_resolving(_unit_mover.movement_complete, BattleState.ACTION_SELECT)

# executes an ability against target_cell and awaits completion before returning to ACTION_SELECT
func confirm_target(target_cell: Vector3i) -> void:
	if current_state != BattleState.TARGET_SELECT:
		_state_error("confirm_target", BattleState.TARGET_SELECT)
		return
	if not active_unit.can_act():
		push_error("confirm_target called when active_unit cannot act")
		return
	# TODO: display target unit's info, expected damage, elemental effects, and hit chance
	emit_signal("unit_executed_ability", active_unit, target_cell, _current_ability, _camera)
	emit_signal("attack_consumed")
	await _enter_resolving(_unit_ability_executor.ability_complete, BattleState.ACTION_SELECT)

# ends the active unit's turn and advances to the next
func end_turn() -> void:
	if current_state != BattleState.ACTION_SELECT:
		_state_error("end_turn", BattleState.ACTION_SELECT)
		return
	active_unit = null
	# TODO: apply status effect ticks and turn countdowns here before advancing
	change_state(BattleState.RESOLVING)
	_start_next_turn()	# temporary — TurnQueue will replace this

# emits a push_error with context about which state was expected vs actual
func _state_error(func_name: String, expected: BattleState) -> void:
	push_error("BattleManager: %s called in wrong state. Expected %s, got %s" % [
		func_name,
		BattleState.keys()[expected],
		BattleState.keys()[current_state]
	])

# temporary turn cycling — will be replaced by TurnQueue using unit speed stats
func _start_next_turn() -> void:
	var players = player_units.size() - 1
	if turn >= players:
		turn = 0
	else:
		turn += 1
	active_unit = player_units[turn]
	active_unit.reset_turn()
	emit_signal("active_unit_changed", active_unit)
	if player_units.has(active_unit):
		change_state(BattleState.ACTION_SELECT)
	else:
		change_state(BattleState.ENEMY_TURN)

# transitions to RESOLVING, awaits a completion signal, then transitions to next_state
func _enter_resolving(completion_signal: Signal, next_state: BattleState) -> void:
	change_state(BattleState.RESOLVING)
	await completion_signal
	change_state(next_state)
