extends Node2D

# =============================================================================
# TileEffectVisual — shared script for the looping visual effects that sit on
# a tile for the duration of a status effect (Burning, Electrified, etc).
#
# This used to be two byte-for-byte identical files (Burning.gd and
# Electrified.gd) with no effect-specific logic in either — a straight
# copy-paste that had already started to drift apart (Electrified.tscn had
# even been pointed at Burning.gd's script directly, leaving Electrified.gd
# completely dead). Consolidated into one shared script; each effect's .tscn
# still owns its own sprite frames/animation/scale, only the controlling
# script is now common. If an effect ever needs genuinely unique behavior,
# give IT its own script rather than copy-pasting this one again — that's
# the pattern that created the duplication in the first place.
# =============================================================================

@onready var sprite: AnimatedSprite2D = $"."
@onready var node: Node2D = $Node2D

const NORMAL_ALPHA: float = 1.0
const OCCUPIED_ALPHA: float = 0.7

# how many actors currently standing on this tile are "occupying" it for the
# purpose of the alpha fade (NORMAL_ALPHA vs OCCUPIED_ALPHA above) — not yet
# wired up to anything that reads/writes it; left as-authored from the
# original Burning/Electrified scripts rather than guessed at, since the
# intended trigger (probably: dim the effect when a unit stands on top of it)
# isn't implemented anywhere yet
var _occupant_count: int = 0
