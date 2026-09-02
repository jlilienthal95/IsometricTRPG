class_name MovePlanner
extends RefCounted

# Plans a movement route as an ordered chain of waypoints between the unit's
# origin and a destination. With no waypoints the route is just the shortest
# path (the fast/default move — straight through hazards if that's shortest).
# Each waypoint the player adds forces the route to detour through that tile,
# and the extra distance counts against movement range like any other tiles —
# so going *around* a hazard is a real trade of range for safety.
#
# The planner only computes and validates routes; rendering and input live in
# the battle scene, execution in UnitMover.

var _pathfinder: Pathfinder = null
var _unit: Unit = null
var _origin: Vector3i = Vector3i.ZERO
var _query: RangeQuery = null
var _waypoints: Array[Vector3i] = []

# (re)arms the planner for a fresh move selection, clearing any prior waypoints
func begin(pathfinder: Pathfinder, unit: Unit, origin: Vector3i, query: RangeQuery) -> void:
	_pathfinder = pathfinder
	_unit = unit
	_origin = origin
	_query = query
	_waypoints.clear()

func clear() -> void:
	_waypoints.clear()

func has_waypoints() -> bool:
	return not _waypoints.is_empty()

func waypoints() -> Array[Vector3i]:
	return _waypoints.duplicate()

# Builds the full route origin -> waypoints... -> destination by concatenating
# the shortest leg between each consecutive anchor. Returns:
#   { steps: Array[MovementStep], waypoint_cells: Array[Vector3i],
#     cost: int, valid: bool }
# valid is false when any leg is unreachable or the total cost exceeds range.
func plan_to(destination: Vector3i) -> Dictionary:
	var anchors: Array[Vector3i] = [_origin]
	anchors.append_array(_waypoints)
	if destination != anchors[-1]:
		anchors.append(destination)

	var steps: Array[MovementStep] = []
	var total_cost := 0
	for i in range(anchors.size() - 1):
		var leg = _pathfinder.get_movement_path_with_cost(anchors[i], anchors[i + 1], _query, _unit)
		if leg["cost"] < 0:
			return {"steps": [] as Array[MovementStep], "waypoint_cells": _waypoints.duplicate(), "cost": -1, "valid": false}
		steps.append_array(leg["steps"])
		total_cost += leg["cost"]

	return {
		"steps": steps,
		"waypoint_cells": _waypoints.duplicate(),
		"cost": total_cost,
		"valid": total_cost <= _query.max_range,
	}

# Appends a waypoint if the route THROUGH it still fits within range. Rejects
# (and leaves the chain unchanged) a redundant or over-budget waypoint, so the
# caller can treat a false return as "that waypoint isn't legal here".
func add_waypoint(cell: Vector3i) -> bool:
	if cell == _origin:
		return false
	if not _waypoints.is_empty() and _waypoints[-1] == cell:
		return false
	_waypoints.append(cell)
	if not plan_to(cell)["valid"]:
		_waypoints.pop_back()
		return false
	return true

# Removes the most recent waypoint. Returns false if there were none (so the
# caller knows a cancel gesture should fall through to leaving move selection).
func pop_waypoint() -> bool:
	if _waypoints.is_empty():
		return false
	_waypoints.pop_back()
	return true
