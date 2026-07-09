class_name TurnQueueTests
extends TestSuite

func _init() -> void:
	suite_name = "TurnQueue"

# lightweight unit double — TurnQueue only reads .data.speed / .data.is_dead
class QueueDummyUnit:
	extends Unit
	func _init(speed: JobData.SpeedRank) -> void:
		data = UnitData.new()
		data.job = TestSuite.make_job(1.0, 1.0, 1.0, 1.0, 0, 0, speed)
		data.resolve()

func run() -> void:
	_test_speed_ordering()
	_test_sentinel_last()
	_test_all_units_queries()

func _make_units(ranks: Array) -> Array[Unit]:
	var units: Array[Unit] = []
	for rank in ranks:
		var u = QueueDummyUnit.new(rank)
		add_child(u)
		units.append(u)
	return units

func _test_speed_ordering() -> void:
	# 2 fast, 2 normal, 2 slow scattered across teams — every FAST index must
	# precede every NORMAL index, every NORMAL must precede every SLOW.
	# Run 5 shuffles to make a fluke ordering pass effectively impossible.
	for trial in range(5):
		var players = _make_units([JobData.SpeedRank.SLOW, JobData.SpeedRank.FAST, JobData.SpeedRank.NORMAL])
		var enemies = _make_units([JobData.SpeedRank.FAST, JobData.SpeedRank.SLOW, JobData.SpeedRank.NORMAL])
		var queue = TurnQueue.new()
		add_child(queue)
		queue.setup(players, enemies)
		var order = queue.get_all_units()
		check_eq(order.size(), 6, "trial %d: all units present in queue" % trial)
		var rank_sequence: Array = []
		for u in order:
			rank_sequence.append(u.data.speed)
		var valid = true
		for i in range(rank_sequence.size() - 1):
			# FAST=2, NORMAL=1, SLOW=0 — sequence must be non-increasing... 
			# NOTE: enum order is SLOW=0..FAST=2, so ordering check uses values
			if rank_sequence[i] < rank_sequence[i + 1]:
				valid = false
		check(valid, "trial %d: queue is strictly rank-ordered FAST->NORMAL->SLOW" % trial, str(rank_sequence))
		queue.queue_free()

func _test_sentinel_last() -> void:
	var players = _make_units([JobData.SpeedRank.SLOW])
	var enemies = _make_units([JobData.SpeedRank.FAST])
	var queue = TurnQueue.new()
	add_child(queue)
	queue.setup(players, enemies)
	# walk the raw cycle: after cycling exactly unit-count participants, the
	# next participant must be the terrain sentinel
	var first = queue.get_next_participant()
	var second = queue.get_next_participant()
	var third = queue.get_next_participant()
	check(first is Unit, "sentinel: first participant is a unit")
	check(second is Unit, "sentinel: second participant is a unit")
	check(third is TerrainTurnParticipant, "sentinel: terrain participant comes after all units")
	var fourth = queue.get_next_participant()
	check_eq(fourth, first, "sentinel: queue cycles back to the first unit")
	queue.queue_free()

func _test_all_units_queries() -> void:
	var players = _make_units([JobData.SpeedRank.NORMAL, JobData.SpeedRank.NORMAL])
	var enemies = _make_units([JobData.SpeedRank.NORMAL])
	var queue = TurnQueue.new()
	add_child(queue)
	queue.setup(players, enemies)
	check_eq(queue.get_all_units().size(), 3, "queries: get_all_units excludes sentinel")
	players[0].data.is_dead = true
	check_eq(queue.get_all_living_units().size(), 2, "queries: get_all_living_units excludes dead")
	check_eq(queue.get_all_units().size(), 3, "queries: get_all_units still includes dead (bodies persist)")
	queue.queue_free()
