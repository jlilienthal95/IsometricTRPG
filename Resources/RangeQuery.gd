class_name RangeQuery
extends RefCounted

# range limits
var max_range: int = 1
var min_range: int = 0
var jump_height: int = 999

# filters
var show_full_range: bool = false
var respect_terrain_cost: bool = false
var blocked_by_enemies: bool = false		# can't move through enemies
var blocked_by_allies: bool = false			# can't move through allies (override for some abilities/jobs)
var can_end_on_ally: bool = false			# can't end movement on an ally regardless
var blocked_by_unwalkable: bool = false
var ignore_elevation: bool = false

# target filters
var requires_unit: bool = false
var requires_empty: bool = false
var requires_enemy: bool = false
var requires_ally: bool = false
var requires_dead: bool = false

static func for_movement(unit_data: UnitData) -> RangeQuery:
	var query = RangeQuery.new()
	query.max_range = unit_data.move_range
	query.jump_height = unit_data.jump_height
	query.respect_terrain_cost = true
	query.blocked_by_enemies = true
	query.blocked_by_allies = false
	query.can_end_on_ally = false
	query.blocked_by_unwalkable = true
	query.requires_empty = true
	return query
