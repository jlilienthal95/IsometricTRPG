class_name TurnQueue
extends Node

var _queue: Array = []
var _player_units: Array[BattleActor] = []
var _enemy_units: Array[BattleActor] = []

func setup(player_units: Array[BattleActor], enemy_units: Array[BattleActor]) -> void:
	_player_units = player_units
	_enemy_units = enemy_units
	_queue = determine_turn_order()
	
	BattleManager.turn_ended.connect(_on_turn_ended)

func reset() -> void:
	_queue.clear()
	_player_units.clear()
	_enemy_units.clear()

# Speed-rank ordering: all FAST units act before all NORMAL units, which act
# before all SLOW units. Order within a rank is randomized each battle.
# The terrain sentinel always goes last so terrain effects resolve after every
# unit has taken its turn in the round.
func determine_turn_order() -> Array:
	var buckets: Dictionary = {
		JobData.SpeedRank.FAST: [],
		JobData.SpeedRank.NORMAL: [],
		JobData.SpeedRank.SLOW: [],
	}
	for unit in _player_units + _enemy_units:
		buckets[unit.data.speed].append(unit)

	var turn_queue: Array = []
	for rank in [JobData.SpeedRank.FAST, JobData.SpeedRank.NORMAL, JobData.SpeedRank.SLOW]:
		var bucket: Array = buckets[rank]
		bucket.shuffle()
		turn_queue.append_array(bucket)

	turn_queue.push_back(TerrainTurnParticipant.new())
	return turn_queue
	
func _on_turn_ended() -> void:
	start_next_turn()

# advances to the next living participant's turn.
# Dead units stay in the queue (their bodies stay on the field) but are
# skipped here — the terrain sentinel guarantees the loop always terminates.
func start_next_turn() -> void:
	#print("starting next turn...")
	var participant = get_next_participant()
	while participant is Unit and participant.data.is_dead:
		participant = get_next_participant()
	if participant is Unit:
		print("setting active unit: ", participant.data.name)
	else:
		print("setting active participant.")
	BattleManager.set_active_unit(participant)

# pops the front participant and cycles it to the back. MUTATES the queue —
# never call this to "peek"; use get_all_units for non-mutating inspection.
func get_next_participant():
	var participant = _queue.pop_front()
	_queue.push_back(participant)
	return participant

func get_all_living_units() -> Array[Unit]:
	var living_units: Array[Unit] = []
	for unit in _queue:
		if unit is Unit and not unit.data.is_dead:
			living_units.append(unit)
	return living_units
	
func get_all_living_players() -> Array[Unit]:
	var living_players: Array[Unit] = []
	for unit in _queue:
		if not (unit is Unit):
			continue
		if unit.data.is_dead:
			continue
		for player in _player_units:
			if player == unit:
				living_players.append(unit)
				break
	return living_players

func get_all_living_enemies() -> Array[Unit]:
	var living_enemies: Array[Unit] = []
	for unit in _queue:
		if not (unit is Unit):
			continue
		if unit.data.is_dead:
			continue
		var is_player := false
		for player in _player_units:
			if player == unit:
				is_player = true
				break
		if not is_player:
			living_enemies.append(unit)
	return living_enemies

func get_all_units() -> Array[Unit]:
	var units: Array[Unit] = []
	for participant in _queue:
		if participant is Unit:
			units.append(participant)
	return units
	
func get_all_player_units() -> Array[BattleActor]:
	return _player_units

func get_all_enemy_units() -> Array[BattleActor]:
	return _enemy_units
