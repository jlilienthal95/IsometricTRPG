class_name ActionCandidate
extends RefCounted

# one possible turn plan

var move_cell: Vector3i			# where to stand (may be current position)
var ability: AbilityData			# null = move-only / wait
var expected_damage: Dictionary	# calculated by ExpectedDamage consideration, used by KillPotential
var acts_first: bool = false		# flag as true when the unit should act before moving
var target_cell: Vector3i		# where the ability lands
var scores: Dictionary = {}		# consideration name -> raw score (debuggability!)
var total_score: float = 0.0

func debug_print() -> void:
	print("=== ActionCandidate ===")
	print("  move_cell:    ", move_cell)
	print("  target_cell:  ", target_cell)
	print("  ability:      ", ability.ability_name if ability != null else "none")
	print("  acts_first:   ", acts_first)
	print("  total_score:  ", snappedf(total_score, 0.01))
	print("  scores:")
	for key in scores:
		print("    ", key, ": ", snappedf(scores[key], 0.01))
	print("======================")
