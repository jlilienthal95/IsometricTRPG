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
	WIND,
	MAGNET,
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
