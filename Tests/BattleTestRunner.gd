class_name BattleTestRunner
extends Node

const BATTLE_SCENE_PATH := "res://Scenes/Battle/battle_scene.tscn"
const NUM_CORRECTNESS_SCENARIOS := 20
const WATCHDOG_TIMEOUT_SEC := 15.0

var _end_handler: Callable
var _loss_handler: Callable
var _state_handler: Callable

var _fps_samples: Array[float] = []
var _lowest_fps: float = 999999.0
var _highest_fps: float = 0.0
var _lowest_fps_snapshot: String = ""

func _ready() -> void:
	await run_full_suite()

func run_full_suite() -> void:
	SyntheticPlayer.reset_coverage()
	var run_id := Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	print("\n========== BATTLE TEST SUITE START (%s) ==========" % run_id)

	var total_passed := 0
	var total_failed := 0
	var scenarios_timed_out := 0

	for i in range(NUM_CORRECTNESS_SCENARIOS):
		var scenario := BattleScenarioGenerator.generate(i, false)
		var outcome := await _run_scenario(scenario, "%s_correctness_%02d" % [run_id, i], 10.0, false)
		total_passed += outcome.passed
		total_failed += outcome.failed
		if outcome.timed_out:
			scenarios_timed_out += 1

	print("\n--- Running max-stress performance scenario at 1x speed ---")
	var stress_scenario := BattleScenarioGenerator.generate(999999, true)
	var perf_outcome := await _run_scenario(stress_scenario, run_id + "_stress_perf", 1.0, true)
	total_passed += perf_outcome.passed
	total_failed += perf_outcome.failed
	if perf_outcome.timed_out:
		scenarios_timed_out += 1

	print("\n========== SUITE COMPLETE ==========")
	print("Scenarios run: ", NUM_CORRECTNESS_SCENARIOS + 1)
	print("Timed out (likely hangs): ", scenarios_timed_out)
	print("Assertions passed: ", total_passed)
	print("Assertions failed: ", total_failed)
	print(SyntheticPlayer.coverage_report())
	if not _fps_samples.is_empty():
		var avg_fps: float = 0.0
		for f in _fps_samples:
			avg_fps += f
		avg_fps /= _fps_samples.size()
		print("--- Performance (stress scenario, real-time 1x) ---")
		print("  Lowest FPS: ", _lowest_fps, "  (", _lowest_fps_snapshot, ")")
		print("  Highest FPS: ", _highest_fps)
		print("  Average FPS: ", snappedf(avg_fps, 0.1))
	print("=====================================\n")

func _run_scenario(scenario: BattleScenario, run_label: String, time_scale: float, track_perf: bool) -> Dictionary:
	var logger := BattleLogger.new(run_label)
	logger.log_line("Scenario: " + scenario.description)

	Constants.testing_mode = true
	Engine.time_scale = time_scale

	if not ResourceLoader.exists(BATTLE_SCENE_PATH):
		logger.log_line("!!! battle_scene.tscn not found at " + BATTLE_SCENE_PATH)
		logger.flush(false)
		Constants.testing_mode = false
		Engine.time_scale = 1.0
		return {"passed": 0, "failed": 1, "timed_out": false}

	var battle_scene_res: PackedScene = load(BATTLE_SCENE_PATH)
	var battle_instance = battle_scene_res.instantiate()

	if not ("test_scenario" in battle_instance):
		logger.log_line("!!! battle_scene.gd has no test_scenario hook yet")
		logger.flush(false)
		battle_instance.queue_free()
		Constants.testing_mode = false
		Engine.time_scale = 1.0
		return {"passed": 0, "failed": 1, "timed_out": false}

	# set scenario before adding to tree so _ready() sees it
	battle_instance.test_scenario = scenario

	# instantiate synthetic player before battle enters tree
	# so we can connect before start_battle fires active_unit_changed
	var synthetic_player := SyntheticPlayer.new()
	add_child(synthetic_player)
	var rng := RandomNumberGenerator.new()
	rng.seed = scenario.seed_value

	# add battle instance — this triggers _ready() and wires systems,
	# but start_battle is call_deferred so active_unit_changed hasn't fired yet
	add_child(battle_instance)

	# connect synthetic player immediately after _ready() runs but before
	# the deferred start_battle fires active_unit_changed
	synthetic_player.setup(
		battle_instance.get_node("BattleGrid"),
		battle_instance.get_node("Pathfinder"),
		rng
	)

	var grid: BattleGrid = battle_instance.get_node("BattleGrid")
	var turn_queue: TurnQueue = battle_instance.get_node("TurnQueue")
	var director: CinematicDirector = battle_instance.get_node_or_null("CinematicDirector")

	if director == null:
		logger.log_line("!!! CinematicDirector not found — sequence-depth checks skipped")

	var assertion := BattleAssertion.new(grid, turn_queue, director)

	var battle_ended := false
	var battle_won := false

	_end_handler = func(won: bool): battle_ended = true; battle_won = won
	_state_handler = func(s):
		assertion.assert_state_valid(s)
		assertion.assert_active_unit_not_dead()
		if track_perf:
			_sample_fps()

	BattleManager.battle_ended.connect(_end_handler)
	BattleManager.state_changed.connect(_state_handler)

	# one frame for deferred calls to settle
	await get_tree().process_frame

	var watchdog := Watchdog.new()
	add_child(watchdog)

	var run_result: Dictionary = await watchdog.run(func():
		while not battle_ended:
			await get_tree().process_frame
		return true
	, WATCHDOG_TIMEOUT_SEC)

	if run_result.timed_out:
		logger.log_line("!!! SCENARIO TIMED OUT after %.1f REAL seconds — likely infinite loop or deadlocked await" % run_result.elapsed_sec)
	else:
		logger.log_line("Battle ended — won: %s (elapsed real seconds: %.2f)" % [str(battle_won), run_result.elapsed_sec])
		for u in BattleManager.player_units:
			if u is Unit:
				assertion.assert_unit_integrity(u)
			elif u is BattleObject:
				assertion.assert_object_integrity(u)
		for u in BattleManager.enemy_units:
			if u is Unit:
				assertion.assert_unit_integrity(u)
			elif u is BattleObject:
				assertion.assert_object_integrity(u)
		assertion.assert_battle_end(battle_won, BattleManager.player_units, BattleManager.enemy_units)
		if director != null:
			assertion.assert_sequence_depth_zero("end of scenario")

	for r in assertion.results:
		var status: String = "PASS" if r.passed else "FAIL"
		logger.log_line("[%s] %s %s" % [status, r.label, r.detail])

	if BattleManager.battle_ended.is_connected(_end_handler):
		BattleManager.battle_ended.disconnect(_end_handler)
	if BattleManager.state_changed.is_connected(_state_handler):
		BattleManager.state_changed.disconnect(_state_handler)

	assertion.teardown()
	synthetic_player.teardown()
	watchdog.queue_free()
	synthetic_player.queue_free()
	battle_instance.queue_free()
	BattleManager.reset()

	Constants.testing_mode = false
	Engine.time_scale = 1.0

	var success: bool = assertion.failed_count() == 0 and not run_result.timed_out
	logger.flush(success)

	return {
		"passed": assertion.passed_count(),
		"failed": assertion.failed_count(),
		"timed_out": run_result.timed_out,
	}

func _sample_fps() -> void:
	var fps: float = Engine.get_frames_per_second()
	_fps_samples.append(fps)
	if fps < _lowest_fps:
		_lowest_fps = fps
		var active_desc: String = "none"
		if BattleManager.active_unit != null and BattleManager.active_unit is Unit:
			active_desc = BattleManager.active_unit.data.name
		_lowest_fps_snapshot = "active_unit=%s state=%s" % [
			active_desc, BattleManager.BattleState.keys()[BattleManager.current_state]
		]
	if fps > _highest_fps:
		_highest_fps = fps
