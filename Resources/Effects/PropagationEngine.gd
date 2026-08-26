class_name PropagationEngine
extends RefCounted

# PULSE: flood fill through all contiguous susceptible cells, instantly, starting from origin
static func propagate_pulse(origin: Vector3i, grid: BattleGrid, susceptible_terrain: Array, include_elevation: bool = false) -> Array[Vector3i]:
	var visited: Dictionary = {}
	var queue: Array[Vector3i] = [origin]
	var affected: Array[Vector3i] = []
	while not queue.is_empty():
		var current = queue.pop_front()
		if visited.has(current):
			continue
		#mark current tile as visited
		visited[current] = true
		var tile = grid.get_tile(current)
		#if tiledata is null or terrain is not susceptible to effect, skip
		if tile == null or not susceptible_terrain.has(tile.terrain_type):
			continue
		#else add tile to affected array
		affected.append(current)
		for neighbor in grid.get_effect_neighbors(current, include_elevation):
			if not visited.has(neighbor):
				queue.append(neighbor)
	return affected

# GRADUAL: expand exactly one ring outward from the given active cells
# elevation_filter: optional callable(from_cell, to_cell) -> bool to apply directional rules (e.g. climbs but doesn't fall)
static func propagate_gradual(active_cells: Array[Vector3i], grid: BattleGrid, susceptible_terrain: Array, elevation_filter: Callable = Callable()) -> Array[Vector3i]:
	var new_cells: Array[Vector3i] = []
	for cell in active_cells:
		for neighbor in grid.get_effect_neighbors(cell, true):
			if elevation_filter.is_valid() and not elevation_filter.call(cell, neighbor):
				continue
			var tile = grid.get_tile(neighbor)
			if tile == null or not susceptible_terrain.has(tile.terrain_type):
				continue
			if not new_cells.has(neighbor):
				new_cells.append(neighbor)
	return new_cells

# returns only neighbors that are directly adjacent at the SAME elevation (no climb)
# used for conversions like stone -> lava which only check direct same-level contact
static func get_flat_neighbors(cell: Vector3i, grid: BattleGrid) -> Array[Vector3i]:
	return grid.get_effect_neighbors(cell, false)
