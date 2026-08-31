class_name AbilityTimingTests
extends TestSuite

# Non-assumptive tests for the frame->seconds math in AbilityTiming (pulled
# out of UnitAbilityExecutor specifically so it could be tested like this —
# see that file's header comment). Every expected value here is hand-computed
# from the definition (frame / fps), not derived by calling the code under
# test a second time, so a bug in the formula can't accidentally cancel out
# against itself the way "check the result looks reasonable" assertions can.

func _init() -> void:
	suite_name = "AbilityTiming"

func run() -> void:
	_test_frame_to_seconds_worked_example()
	_test_frame_to_seconds_table()
	_test_frame_to_seconds_edge_cases()
	_test_effect_impact_delay_subtracts_charge()
	_test_effect_impact_delay_edge_cases()

# the exact worked example from the design spec this suite was written against:
# a casting animation with 30 frames at 30fps, impact frame 15, must resolve
# to an impact 0.5 seconds after the animation starts.
func _test_frame_to_seconds_worked_example() -> void:
	var fps := 30.0
	var impact_frame := 15
	var delay := AbilityTiming.frame_to_seconds(impact_frame, fps)
	check_eq(delay, 0.5, "worked example: frame 15 at 30fps = 0.5s")

# several more hand-computed points, at different fps and frame numbers, so
# the formula is checked across its input space rather than at one lucky value
func _test_frame_to_seconds_table() -> void:
	# [frame, fps, expected_seconds]
	var table := [
		[1, 30.0, 1.0 / 30.0],
		[30, 30.0, 1.0],
		[12, 12.0, 1.0],
		[6, 12.0, 0.5],
		[20, 60.0, 20.0 / 60.0],
		[45, 30.0, 1.5],
	]
	for row in table:
		var frame: int = row[0]
		var fps: float = row[1]
		var expected: float = row[2]
		var actual := AbilityTiming.frame_to_seconds(frame, fps)
		check(is_equal_approx(actual, expected),
			"table: frame %d at %.1ffps = %.4fs" % [frame, fps, expected],
			"got %.6f" % actual)

func _test_frame_to_seconds_edge_cases() -> void:
	check_eq(AbilityTiming.frame_to_seconds(0, 30.0), 0.0, "edge: frame 0 has no delay")
	check_eq(AbilityTiming.frame_to_seconds(-5, 30.0), 0.0, "edge: negative frame treated as no delay")
	check_eq(AbilityTiming.frame_to_seconds(15, 0.0), 0.0, "edge: zero fps does not divide by zero")
	check_eq(AbilityTiming.frame_to_seconds(15, -30.0), 0.0, "edge: negative fps does not invert sign")

# effect_impact_delay is measured from the EFFECT animation's own start, so a
# caster's charge-up time must be subtracted back out — verify the subtraction
# with an exact hand-computed result, not just "it's less than the raw value"
func _test_effect_impact_delay_subtracts_charge() -> void:
	# ability_fps=30, impact_frame=24 -> 0.8s from ability-anim start.
	# charge_delay=0.3s already elapsed before the effect anim began.
	# expected impact, measured from effect-anim start: 0.8 - 0.3 = 0.5s
	var result := AbilityTiming.effect_impact_delay(24, 30.0, 0.3)
	check(is_equal_approx(result, 0.5), "impact delay: 0.8s raw minus 0.3s charge = 0.5s", "got %.6f" % result)

	# zero charge_delay: impact delay should equal the raw frame conversion exactly
	var no_charge := AbilityTiming.effect_impact_delay(15, 30.0, 0.0)
	check_eq(no_charge, 0.5, "impact delay: no charge time means raw value unchanged")

func _test_effect_impact_delay_edge_cases() -> void:
	check_eq(AbilityTiming.effect_impact_delay(0, 30.0, 0.2), 0.0, "impact delay: frame 0 means no impact timing at all (ignores charge_delay too)")
	# a charge delay LONGER than the impact frame's own timing is legal input
	# (produces a negative delay, meaning impact already happened during the
	# charge) — the function must not clamp this away, since callers rely on
	# the sign to know whether to wait or fire immediately
	var negative := AbilityTiming.effect_impact_delay(6, 30.0, 1.0)
	check(negative < 0.0, "impact delay: charge longer than impact frame yields a negative delay, not clamped to 0")
