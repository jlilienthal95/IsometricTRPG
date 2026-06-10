class_name BattleManager
extends Node

enum BattleState {
	SETUP,			# units being placed, pre-battle
	ACTION_SELECT,	# player has selected a unit, choosing an action (move, attack, wait)
	ATTACK_SELECT,	# player has selected a unit, choosing an action (move, attack, wait)
	MOVE_SELECT,	# player is selecting a tile to move to
	TARGET_SELECT,	# player is selecting a target for an ability
	EQUIPMENT_SELECT,	#list of unit's equipped items
	RESOLVING,		# an action is executing, no input accepted
	ENEMY_TURN,		# AI is taking its turn
	BATTLE_END,		# battle is over, win or lose
}

signal state_changed(new_state: BattleState)
signal active_unit_changed(unit: Unit)
signal unit_moved(unit: Unit, to_cell: Vector3i)
signal move_consumed
signal attack_consumed
signal ability_selected(unit: Unit, origin_cell: Vector3i, ability: AbilityData)

var current_state: BattleState = BattleState.SETUP
var active_unit: Unit = null
var player_units: Array[Unit] = []
var enemy_units: Array[Unit] = []

var _grid: BattleGrid = null
var _unit_mover: UnitMover = null

func setup(grid: BattleGrid, unit_mover: UnitMover) -> void:
	_grid = grid
	_unit_mover = unit_mover
	
func change_state(new_state: BattleState) -> void:
	current_state = new_state
	emit_signal("state_changed", new_state)
	print("BattleManager state: ", BattleState.keys()[new_state])

func start_battle(p_units: Array[Unit], e_units: Array[Unit]) -> void:
	player_units = p_units
	enemy_units = e_units
	_start_next_turn()

func select_action_move() -> void:
	if current_state != BattleState.ACTION_SELECT:
		_state_error("select_action_move", BattleState.ACTION_SELECT)
		return
	if active_unit.can_move():
		change_state(BattleState.MOVE_SELECT)

func select_action_attack() -> void:
	if current_state != BattleState.ACTION_SELECT:
		_state_error("select_action_attack", BattleState.ACTION_SELECT)
		return
	#if active_unit.can_act():
		#TODO action handling logic goes here
	change_state(BattleState.ATTACK_SELECT)

func select_ability(ability: AbilityData):
	if current_state != BattleState.ATTACK_SELECT:
		_state_error("select_action_attack", BattleState.ACTION_SELECT)
		return
	emit_signal("ability_selected", active_unit, active_unit.grid_position, ability)
	print("ability selected: ", ability.ability_name)
	
func select_action_equipment() -> void:
	if current_state != BattleState.ACTION_SELECT:
		_state_error("select_action_attack", BattleState.ACTION_SELECT)
		return
	change_state(BattleState.EQUIPMENT_SELECT)
	
func cancel_action() -> void:
	if current_state != BattleState.MOVE_SELECT and \
	   current_state != BattleState.TARGET_SELECT and \
	   current_state != BattleState.EQUIPMENT_SELECT and \
	   current_state != BattleState.ATTACK_SELECT:
		_state_error("cancel_action", BattleState.MOVE_SELECT)
		return
	change_state(BattleState.ACTION_SELECT)

func confirm_move(target_cell: Vector3i) -> void:
	if current_state != BattleState.MOVE_SELECT:
		_state_error("confirm_move", BattleState.MOVE_SELECT)
		return
		
	var from_cell = active_unit.grid_position
	emit_signal("unit_moved", active_unit, target_cell)
	emit_signal("move_consumed")
	
	await _enter_resolving(_unit_mover.movement_complete, BattleState.ACTION_SELECT)

func confirm_target(target_cell: Vector3i) -> void:
	if current_state != BattleState.TARGET_SELECT:
		_state_error("confirm_target", BattleState.TARGET_SELECT)
		return
	if not active_unit.can_act():
		push_error("confirm_target called when active_unit cannot act")
		return
		
	emit_signal("attack_consumed")
	#TODO replace with _enter_resolving once action logic is implemented
	change_state(BattleState.RESOLVING)
	#await _enter_resolving(resolving_complete, BattleState.ACTION_SELECT)
		
func end_turn() -> void:
	if current_state != BattleState.ACTION_SELECT:
		_state_error("end_turn", BattleState.ACTION_SELECT)
		return
	active_unit = null
	#status effects or turn countdowns?
	change_state(BattleState.RESOLVING)
	#await _enter_resolving(resolving_complete, BattleState.ACTION_SELECT)
	# TurnQueue will call _start_next_turn() when ready
	_start_next_turn()	# temporary direct call until TurnQueue exists
	
func _state_error(func_name: String, expected: BattleState) -> void:
	push_error("BattleManager: %s called in wrong state. Expected %s, got %s" % [
		func_name,
		BattleState.keys()[expected],
		BattleState.keys()[current_state]
	])
	
var turn = -1

func _start_next_turn() -> void:
	# TurnQueue will replace this entire function later
	# for now just cycle back to the first player unit
	var players = player_units.size() - 1;
	if turn >= players:
		turn = 0
	else:
		turn += 1
	active_unit = player_units[turn]
	
	active_unit.reset_turn()
	#_hud.reset_turn()
	emit_signal("active_unit_changed", active_unit)
	# determine if next unit is player or enemy controlled
	if player_units.has(active_unit):
		change_state(BattleState.ACTION_SELECT)
	else:
		change_state(BattleState.ENEMY_TURN)

func _enter_resolving(completion_signal: Signal, next_state: BattleState) -> void:
	change_state(BattleState.RESOLVING)
	print("awaiting")
	await completion_signal
	print("complete")
	change_state(next_state)
