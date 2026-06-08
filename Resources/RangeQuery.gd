class_name RangeQuery
extends RefCounted

# range limits
var max_range: int = 1
var min_range: int = 0
var jump_height: int = 999

# filters
var respect_terrain_cost: bool = false
var blocked_by_enemies: bool = false		# can't move through enemies
var blocked_by_allies: bool = false			# can't move through allies (override for some abilities/jobs)
var can_end_on_ally: bool = false			# can't end movement on an ally regardless
var blocked_by_unwalkable: bool = false
var ignore_elevation: bool = false

# target filters
var requires_unit: bool = false
var requires_empty: bool = false
