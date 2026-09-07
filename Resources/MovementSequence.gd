class_name MovementSequence
extends RefCounted

# One contiguous run of movement. UnitMover executes these one at a time from
# its queue, so nothing ever runs re-entrantly — an effect that wants to
# redirect movement enqueues a new sequence rather than mutating the one
# that's currently mid-flight.

enum MovementType {
	WALK,
	FLY,
	SLIP,
	PUSH,
	PULL,
}

var steps: Array[MovementStep] = []

# Which locomotion animation the actor plays for this sequence. UnitMover
# passes this straight to actor.play_movement() — it never maps the enum to
# an animation name itself, so adding a type only touches Unit.play_movement.
var movement_type: MovementType = MovementType.WALK

# Effects that must NOT fire as tile-entry effects during this sequence.
# An effect that redirects movement lists ITSELF here, so it doesn't
# re-trigger on every tile of the path it just created. Every OTHER effect
# still fires normally on every tile passed through — sliding across a
# burning tile should still burn you.
var suppressed_effects: Array[EffectId.Id] = []

# Optional callback fired once this sequence finishes executing. Lets the
# effect that queued the sequence react to how it ended (e.g. SlipperyHandler
# applying collision damage) without UnitMover knowing anything about effects.
var on_complete: Callable = Callable()

# --- tween shaping ---
# Defaults reproduce uniform linear movement, so walking is unchanged.
# The FIRST step is shaped separately so a slide can accelerate INTO the
# slip: the actor is already moving and already playing its slip animation
# during that step, which avoids the halting look you get from inserting a
# pause before the sequence starts.
var first_step_duration: float = 0.15
var first_step_ease: Tween.EaseType = Tween.EASE_IN_OUT
var first_step_trans: Tween.TransitionType = Tween.TRANS_LINEAR

var step_duration: float = 0.15
var step_ease: Tween.EaseType = Tween.EASE_IN_OUT
var step_trans: Tween.TransitionType = Tween.TRANS_LINEAR

# --- whole-path easing (optional; overrides the per-step fields above) ---
# Set path_duration > 0 to ease across the ENTIRE path instead of per-tile. You
# describe the motion once for the whole slide — total time, plus what fraction
# of the path is spent ramping up (path_accel) and ramping down (path_decel) —
# and compute_step_durations() subdivides that into a duration for each
# tile-to-tile hop. The hops are linear; the VARYING durations are what make N
# straight tweens read as one smooth acceleration across the path.
#
# Because easing lives in the durations, this sidesteps the per-tile reset that
# limits the first_step/step fields to shaping only the first tile.
var path_duration: float = 0.0				# total seconds for the whole path; 0 = use per-step fields
var path_accel: float = 0.0					# fraction of the path spent ramping up   (0..1)
var path_decel: float = 0.0					# fraction of the path spent ramping down (0..1)
var path_edge_speed: float = 0.25			# start/end speed as a fraction of cruise (>0 so edges don't stall)

# True when this sequence should ease over the whole path rather than per-tile.
func uses_path_easing() -> bool:
	return path_duration > 0.0

# Subdivides the whole-path speed profile into one tween duration per tile. Each
# tile is treated as an equal slice of the path; its duration is proportional to
# how slow the profile is moving there (slow ramp regions get longer tweens),
# normalized so the durations sum to path_duration.
func compute_step_durations(step_count: int) -> Array[float]:
	var durations: Array[float] = []
	if step_count <= 0:
		return durations
	var weights: Array[float] = []
	var total := 0.0
	for k in range(step_count):
		var s := (float(k) + 0.5) / step_count	# this tile's midpoint along the path
		var w := 1.0 / _profile_speed(s)		# slower there -> longer tween
		weights.append(w)
		total += w
	for k in range(step_count):
		durations.append(path_duration * weights[k] / total)
	return durations

# Trapezoidal speed profile over the normalized path position s (0..1): ramp from
# path_edge_speed up to full (cruise) over the first path_accel, cruise, then ramp
# back down to path_edge_speed over the last path_decel. Speeds are relative — only
# their ratios matter, since compute_step_durations normalizes to path_duration.
func _profile_speed(s: float) -> float:
	var a := clampf(path_accel, 0.0, 1.0)
	var d := clampf(path_decel, 0.0, 1.0)
	if a + d > 1.0:							# overlapping ramps — scale to fit, no cruise
		var t := a + d
		a /= t
		d /= t
	var edge := maxf(path_edge_speed, 0.05)	# floor so an edge tile can't take ~forever
	if a > 0.0 and s < a:
		return lerpf(edge, 1.0, s / a)
	if d > 0.0 and s > 1.0 - d:
		return lerpf(1.0, edge, (s - (1.0 - d)) / d)
	return 1.0


# Builds a sequence with default (walk-like) shaping. Callers that want
# custom pacing set the tween fields on the returned object — keeping them
# off the parameter list avoids a six-argument constructor where every call
# site has to remember the order.
static func create(steps: Array[MovementStep], suppressed_effects: Array[EffectId.Id] = [], on_complete: Callable = Callable()) -> MovementSequence:
	var seq := MovementSequence.new()
	seq.steps = steps
	seq.suppressed_effects = suppressed_effects
	seq.on_complete = on_complete
	return seq
