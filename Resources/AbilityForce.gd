class_name AbilityForce
extends Node

enum Level {
	NONE,
	LIGHT,
	HEAVY,
	CRUSHING,
}

# How many tiles a hit of this force can shove a target — the cap on a knockback
# slide (e.g. across ice). NONE = no knockback at all. Tune freely; the actual
# slide still stops early at any obstacle or solid (non-slippery) footing.
static func slide_distance(level: Level) -> int:
	match level:
		Level.LIGHT: return 1
		Level.HEAVY: return 3
		Level.CRUSHING: return 5
		_: return 0	# NONE
