class_name TestRunner
extends Node

# Orchestrates every test suite and prints a full report.
# Run via Tests/TestRunner.tscn (F6 / "Run Current Scene" in the editor).

const SUITES: Array[GDScript] = [
	preload("res://Tests/StatResolutionTests.gd"),
	preload("res://Tests/TurnQueueTests.gd"),
	preload("res://Tests/GridObjectTests.gd"),
	preload("res://Tests/PathfinderTests.gd"),
	preload("res://Tests/EffectSystemTests.gd"),
	preload("res://Tests/MovementExecutionTests.gd"),
	preload("res://Tests/AbilityTimingTests.gd"),
]

func _ready() -> void:
	await run_all()

func run_all() -> void:
	var total_passed = 0
	var total_failed = 0
	print("\n================ TEST RUN ================")
	for suite_script in SUITES:
		var suite: TestSuite = suite_script.new()
		add_child(suite)
		await suite.run()
		var p = suite.passed_count()
		var f = suite.failed_count()
		total_passed += p
		total_failed += f
		print("\n--- %s: %d passed, %d failed ---" % [suite.suite_name, p, f])
		for r in suite.results:
			if r.passed:
				print("  [PASS] " + r.label)
			else:
				print("  [FAIL] " + r.label + ("  (" + r.detail + ")" if r.detail != "" else ""))
		suite.queue_free()
	print("\n================ SUMMARY ================")
	print("TOTAL: %d passed, %d failed" % [total_passed, total_failed])
	if total_failed == 0:
		print("ALL TESTS PASSED")
	else:
		print("!!! FAILURES PRESENT — see above !!!")
	print("=========================================\n")
