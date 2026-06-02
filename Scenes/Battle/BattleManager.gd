class_name BattleManager
extends Node

enum BattleState {
	SETUP,			# units being placed, pre-battle
	ACTION_SELECT,	# player has selected a unit, choosing an action (move, attack, wait)
	MOVE_SELECT,	# player is selecting a tile to move to
	TARGET_SELECT,	# player is selecting a target for an ability
	RESOLVING,		# an action is executing, no input accepted
	ENEMY_TURN,		# AI is taking its turn
	BATTLE_END,		# battle is over, win or lose
}

signal state_changed(new_state: BattleState)
signal active_unit_changed(unit: Unit)

var current_state: BattleState = BattleState.SETUP
var active_unit: Unit = null
var player_units: Array[Unit] = []
var enemy_units: Array[Unit] = []

func change_state(new_state: BattleState) -> void:
	current_state = new_state
	emit_signal("state_changed", new_state)
	print("BattleManager state: ", BattleState.keys()[new_state])

func _state_error(func_name: String, expected: BattleState) -> void:
	push_error("BattleManager: %s called in wrong state. Expected %s, got %s" % [
		func_name,
		BattleState.keys()[expected],
		BattleState.keys()[current_state]
	])

func start_battle(p_units: Array[Unit], e_units: Array[Unit]) -> void:
	player_units = p_units
	enemy_units = e_units
	_start_next_turn()

func select_action_move() -> void:
	if current_state != BattleState.ACTION_SELECT:
		_state_error("select_action_move", BattleState.ACTION_SELECT)
		return
	change_state(BattleState.MOVE_SELECT)

func select_action_attack() -> void:
	if current_state != BattleState.ACTION_SELECT:
		_state_error("select_action_attack", BattleState.ACTION_SELECT)
		return
	change_state(BattleState.TARGET_SELECT)
	
func cancel_action() -> void:
	if current_state != BattleState.MOVE_SELECT and current_state != BattleState.TARGET_SELECT:
		_state_error("cancel_action", BattleState.MOVE_SELECT)
		return
	change_state(BattleState.ACTION_SELECT)

func confirm_move(target_cell: Vector2i) -> void:
	if current_state != BattleState.MOVE_SELECT:
		_state_error("confirm_move", BattleState.MOVE_SELECT)
		return
	change_state(BattleState.RESOLVING)
	# movement execution will go here
	change_state(BattleState.ACTION_SELECT)

func _start_next_turn() -> void:
	# TurnQueue will replace this entire function later
	# for now just cycle back to the first player unit
	active_unit = player_units[0]
	emit_signal("active_unit_changed", active_unit)
	# determine if next unit is player or enemy controlled
	if player_units.has(active_unit):
		change_state(BattleState.ACTION_SELECT)
	else:
		change_state(BattleState.ENEMY_TURN)
	
func end_turn() -> void:
	if current_state != BattleState.ACTION_SELECT:
		_state_error("end_turn", BattleState.ACTION_SELECT)
		return
	active_unit = null
	change_state(BattleState.RESOLVING)
	# TurnQueue will call _start_next_turn() when ready
	_start_next_turn()	# temporary direct call until TurnQueue exists
