class_name MovementEasing
extends RefCounted

# A small library of named easing presets for a MovementSequence — pick a feel
# by name instead of hand-tuning six fields. Each preset takes a sequence (with
# its `steps` already assigned) and sets its tween-shaping fields, matching the
# (seq) -> void shape of ForcedMovement.configure_sequence. Two ways to use one:
#
#   force.configure_sequence = MovementEasing.slip   # wire it as the Callable
#   MovementEasing.slip(seq)                          # or apply it inline
#
# PER-STEP presets shape each tile (constant per-tile pacing — total time scales
# with path length). WHOLE-PATH presets ease across the entire path as one curve;
# they set path_duration from the tile count, so length still scales the timing.

# =============================================================================
# PER-STEP presets
# =============================================================================

# brisk and uniform, no flourish — the plain walk
static func walk(seq: MovementSequence) -> void:
	seq.path_duration = 0.0
	seq.first_step_duration = 0.15
	seq.step_duration = 0.15
	_linear(seq)

# ice slide: a long ramp INTO motion on the first tile, then a fast even coast
static func slip(seq: MovementSequence) -> void:
	seq.path_duration = 0.0
	seq.first_step_duration = 0.8
	seq.first_step_ease = Tween.EASE_IN
	seq.first_step_trans = Tween.TRANS_QUINT
	seq.step_duration = 0.1
	seq.step_ease = Tween.EASE_IN_OUT
	seq.step_trans = Tween.TRANS_LINEAR

# ratcheting march: each tile lunges forward and stops dead at its boundary
static func stutter(seq: MovementSequence) -> void:
	seq.path_duration = 0.0
	seq.first_step_duration = 0.12
	seq.first_step_ease = Tween.EASE_OUT
	seq.first_step_trans = Tween.TRANS_QUINT
	seq.step_duration = 0.12
	seq.step_ease = Tween.EASE_OUT
	seq.step_trans = Tween.TRANS_QUINT

# =============================================================================
# WHOLE-PATH presets (one ease across the whole path)
# =============================================================================

# constant speed the whole way — a clean, even glide-through
static func even(seq: MovementSequence) -> void:
	_whole_path(seq, 0.14, 0.0, 0.0)

# graceful: accelerate in, cruise, ease out — smooth on both ends
static func glide(seq: MovementSequence) -> void:
	_whole_path(seq, 0.14, 0.30, 0.30)

# wind shove: snaps up to speed fast, brief settle at the end
static func gust(seq: MovementSequence) -> void:
	_whole_path(seq, 0.10, 0.10, 0.20)

# magnetic pull: builds speed toward the destination, barely slowing at the end
static func drawn_in(seq: MovementSequence) -> void:
	_whole_path(seq, 0.13, 0.65, 0.05)

# fast off the line, long deceleration into rest (logarithmic-ish)
static func coast(seq: MovementSequence) -> void:
	_whole_path(seq, 0.13, 0.0, 0.85, 0.12)

# =============================================================================
# HELPERS
# =============================================================================

# whole-path setup: total time = per_tile * tiles, so a longer path still takes
# proportionally longer (the ease shape is what stays constant, not the speed).
static func _whole_path(seq: MovementSequence, per_tile: float, accel: float, decel: float, edge: float = 0.25) -> void:
	seq.path_duration = per_tile * maxi(seq.steps.size(), 1)
	seq.path_accel = accel
	seq.path_decel = decel
	seq.path_edge_speed = edge

# resets per-step curves to plain constant-velocity tiles
static func _linear(seq: MovementSequence) -> void:
	seq.first_step_ease = Tween.EASE_IN_OUT
	seq.first_step_trans = Tween.TRANS_LINEAR
	seq.step_ease = Tween.EASE_IN_OUT
	seq.step_trans = Tween.TRANS_LINEAR
