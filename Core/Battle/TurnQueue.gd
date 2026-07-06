class_name TurnQueue
extends Node

const TURN_DRAFT_THRESHOLD: float = 0.5

var _queue: Array = []
var _player_units: Array[Unit] = []
var _enemy_units: Array[Unit] = []

func setup(player_units: Array[Unit], enemy_units: Array[Unit]) -> void:
	_player_units = player_units
	_enemy_units = enemy_units
	_queue = determine_turn_order()
	
func determine_turn_order() -> Array:
	var units_to_queue: Array[Unit] = _player_units + _enemy_units
	var turn_queue: Array = []
	while not units_to_queue.is_empty():
		var unit = units_to_queue.pop_front()
		var draft: float = randf()
		if draft >= TURN_DRAFT_THRESHOLD:
			turn_queue.push_front(unit)
		else:
			turn_queue.push_back(unit)
	var terrain_sentinal = TerrainTurnParticipant.new()
	print("terrain sentinal: ", terrain_sentinal)
	turn_queue.push_back(terrain_sentinal)
	return turn_queue
	
func start_next_turn() -> void:
	var new_unit = get_next_unit()
	print("starting turn: ", new_unit.data.unit_name)
	BattleManager.set_active_unit(new_unit)
	
func _end_turn() -> void:
	BattleManager.end_turn()
	
func get_next_unit():
	var participant = _queue.pop_front()
	_queue.push_back(participant)
	return participant
	
func get_all_living_units() -> Array[Unit]:
	var living_units: Array[Unit] = []
	for unit in _queue:
		if not unit is TerrainTurnParticipant:
			if not unit.data.is_dead:
				living_units.append(unit)
	return living_units
	
func get_all_units() -> Array[Unit]:
	var units: Array[Unit] = []
	for participant in _queue:
		if not participant is TerrainTurnParticipant:
			units.append(participant)
	return units
