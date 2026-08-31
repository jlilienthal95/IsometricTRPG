class_name AbilityTiming
extends RefCounted

# =============================================================================
# Pure frame/fps -> seconds math for ability animation timing.
#
# Pulled out of UnitAbilityExecutor._execute_sequence() specifically so it can
# be unit-tested without spinning up a full caster + sprite + executor chain.
# Before this, the "is the impact frame converted to a delay correctly" logic
# only existed inline in a big async sequencing function — which meant nobody
# could actually test the arithmetic in isolation. See Tests/AbilityTimingTests.gd
# for the tests this made possible.
# =============================================================================

# converts a frame number into a delay in seconds, given the animation's fps.
# e.g. frame 15 at 30fps = 0.5 seconds. fps <= 0 is treated as "no timing data"
# and returns 0.0 rather than dividing by zero.
static func frame_to_seconds(frame: int, fps: float) -> float:
	if fps <= 0.0 or frame <= 0:
		return 0.0
	return frame / fps

# the effect's impact delay, measured from the moment the EFFECT animation
# itself starts (not from ability-cast start) — so the caster's own charge-up
# time is subtracted out. Mirrors the comment in UnitAbilityExecutor: "impact_delay
# measured from effect anim start — subtract charge_delay".
static func effect_impact_delay(impact_frame: int, ability_fps: float, charge_delay: float) -> float:
	if impact_frame <= 0:
		return 0.0
	return frame_to_seconds(impact_frame, ability_fps) - charge_delay
