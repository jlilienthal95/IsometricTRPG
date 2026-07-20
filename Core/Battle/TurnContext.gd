class_name TurnContext
extends RefCounted

# bundles "who's acting" together with the pathfinding data derived from them.
# unit is set once, at construction, and never reassigned — every range query below
# is always computed FROM this unit, so there is no separate variable that can drift
# out of sync with whoever BattleManager actually considers active.

var unit: Unit = null

var move_query: RangeQuery = null
var reachable_move_cells: Dictionary = {}

var ability: AbilityData = null
var ability_query: RangeQuery = null
var reachable_target_cells: Dictionary = {}

# builds a context for the given unit, computing its movement range.
# this is the only constructor — a TurnContext cannot exist without a unit and
# matching move data computed for that exact unit.
static func for_unit(new_unit: Unit, pathfinder: Pathfinder) -> TurnContext:
	var context = TurnContext.new()
	context.unit = new_unit
	context.refresh_move_range(pathfinder)
	return context

# recomputes movement range — always keyed off this context's own unit, never an external variable
func refresh_move_range(pathfinder: Pathfinder) -> void:
	move_query = pathfinder.build_move_query(unit.data, true)
	reachable_move_cells = pathfinder.get_cells_in_range(unit.grid_position, move_query, unit)
	reachable_move_cells.erase(unit.grid_position)

# selects an ability and eagerly computes its target range — always keyed off this context's own unit
func select_ability(ability_data: AbilityData, pathfinder: Pathfinder, origin: Vector3i = unit.grid_position) -> void:
	ability = ability_data
	ability_query = pathfinder.build_ability_query(ability_data)
	reachable_target_cells = pathfinder.get_cells_in_range(origin, ability_query, unit)

# clears the ability selection — called when returning to ACTION_SELECT
func clear_ability() -> void:
	ability = null
	ability_query = null
	reachable_target_cells = {}

# returns true if the given cell is a valid destination for whichever range is currently active
func is_reachable(cell: Vector3i, targeting: bool) -> bool:
	var cells = reachable_target_cells if targeting else reachable_move_cells
	return cells.has(cell) and cells[cell] == true
