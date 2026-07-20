class_name ActionCandidate
extends RefCounted

# one possible turn plan

var move_cell: Vector3i        # where to stand (may be current position)
var ability: AbilityData       # null = move-only / wait
var target_cell: Vector3i      # where the ability lands
var scores: Dictionary = {}    # consideration name -> raw score (debuggability!)
var total_score: float = 0.0
