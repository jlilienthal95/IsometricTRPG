class_name Pathfinder
extends Node

var _grid: BattleGrid = null

func setup(grid: BattleGrid) -> void:
	_grid = grid

# public interface
func get_cells_in_range(origin: Vector3i, query: RangeQuery, acting_unit: Unit = null) -> Dictionary:
	var result = _run_dijkstra(origin, query, acting_unit)
	var visited = result[0]
	var reachable: Dictionary = {} # Vector3i : target_isValid
	
	for cell in visited.keys():
		var cost = visited[cell]
		if cost < query.min_range:
			continue
		if cost > query.max_range:
			continue
		if cell == origin:
			continue
			
		reachable[cell] = true
			
		#if not query.show_full_range:
		if query.requires_unit and not _grid.is_cell_occupied(cell):
			reachable[cell] = false
			continue
		if query.requires_empty and _grid.is_cell_occupied(cell):
			reachable[cell] = false
			continue
		if _grid.is_cell_occupied(cell):
			var occupant = _grid.get_unit_at(cell)
			if occupant != null:
				# skip dead units unless ability explicitly allows targeting them
				if occupant.data.is_dead and not query.requires_dead:
					reachable[cell] = false
					continue
				if _is_ally(occupant, acting_unit):
					if not query.can_end_on_ally:
						reachable[cell] = false
						continue
				else:
					if query.requires_empty:
						reachable[cell] = false
						continue
					if not query.requires_enemy and not query.can_end_on_ally:
						reachable[cell] = false
						continue
	return reachable

func get_movement_path(origin: Vector3i, destination: Vector3i, query: RangeQuery, acting_unit: Unit = null) -> Array[MovementStep]:
	var result = _run_dijkstra(origin, query, acting_unit, destination)
	var came_from = result[1]
	
	if not came_from.has(destination) and destination != origin:
		push_error("Pathfinder: no path found to destination: " + str(destination))
		return []
	
	# walk backwards from destination to origin
	var raw_path: Array[Vector3i] = []
	var current = destination
	while current != origin:
		raw_path.append(current)
		current = came_from[current]
	raw_path.reverse()
	
	print("PATH: ", raw_path)
	
	# convert to MovementSteps
	var steps: Array[MovementStep] = []
	var prev = origin
	for cell in raw_path:
		var step = MovementStep.new()
		step.cell = cell
		step.elevation_delta = cell.z - prev.z
		step.is_jump = step.elevation_delta != 0
		var tile = _grid.get_tile(cell)
		step.terrain_type = tile.terrain_type if tile else 0
		steps.append(step)
		prev = cell
	
	return steps

# private helpers
func _run_dijkstra(origin: Vector3i, query: RangeQuery, acting_unit: Unit = null, destination: Vector3i = Vector3i(9999, 9999, 9999)) -> Array:
	var visited: Dictionary = {}
	var came_from: Dictionary = {}
	var queue: Array = []
	
	visited[origin] = 0
	queue.append([origin, 0])
	
	while queue.size() > 0:
		# always process lowest cost first
		var lowest_idx = 0
		for i in range(queue.size()):
			if queue[i][1] < queue[lowest_idx][1]:
				lowest_idx = i
		var current = queue[lowest_idx]
		queue.remove_at(lowest_idx)
		
		var cell: Vector3i = current[0]
		var cost: int = current[1]
		
		# early exit if we reached the destination
		if cell == destination:
			break
		
		if cost >= query.max_range:
			continue
		
		for neighbor in _get_neighbors(cell):
			if visited.has(neighbor):
				continue
			var tile = _grid.get_tile(neighbor)
			if tile == null:
				continue
			if not _passes_filters(neighbor, cell, query, acting_unit):
				continue
			var move_cost = _calculate_move_cost(neighbor, cell, query)
			var new_cost = cost + move_cost
			visited[neighbor] = new_cost
			came_from[neighbor] = cell
			queue.append([neighbor, new_cost])
	
	return [visited, came_from]

func _passes_filters(neighbor: Vector3i, cell: Vector3i, query: RangeQuery, acting_unit: Unit) -> bool:
	var tile = _grid.get_tile(neighbor)
	if query.blocked_by_unwalkable and not tile.is_walkable:
		return false
	if query.blocked_by_enemies and _grid.is_cell_occupied(neighbor):
		var occupant = _grid.get_unit_at(neighbor)
		if occupant != null and not _is_ally(occupant, acting_unit):
			return false
	if query.blocked_by_allies and _grid.is_cell_occupied(neighbor):
		var occupant = _grid.get_unit_at(neighbor)
		if occupant != null and _is_ally(occupant, acting_unit):
			return false
	if not query.ignore_elevation:
		var current_tile = _grid.get_tile(cell)
		var elevation_diff = abs(neighbor.z - cell.z)
		if elevation_diff > query.jump_height:
			return false
	return true

func _calculate_move_cost(neighbor: Vector3i, cell: Vector3i, query: RangeQuery) -> int:
	var tile = _grid.get_tile(neighbor)
	var move_cost: int = _get_move_cost(tile) if query.respect_terrain_cost else 1
	if neighbor.x == cell.x and neighbor.y == cell.y:
		move_cost += 1
	return move_cost

func _get_neighbors(cell: Vector3i) -> Array[Vector3i]:
	var neighbors: Array[Vector3i] = []
	
	# cardinal neighbors at same elevation
	neighbors.append(Vector3i(cell.x + 1, cell.y, cell.z))
	neighbors.append(Vector3i(cell.x - 1, cell.y, cell.z))
	neighbors.append(Vector3i(cell.x, cell.y + 1, cell.z))
	neighbors.append(Vector3i(cell.x, cell.y - 1, cell.z))
	
	# elevation neighbors
	for n in range(1, 15):
		neighbors.append(Vector3i(cell.x - (n+1), cell.y - n, cell.z + n))	# front up
		neighbors.append(Vector3i(cell.x - (n-1), cell.y - n, cell.z + n))	# behind up
		neighbors.append(Vector3i(cell.x - n, cell.y - (n+1), cell.z + n))	# left up
		neighbors.append(Vector3i(cell.x - n, cell.y - (n-1), cell.z + n))	# right up
		neighbors.append(Vector3i(cell.x + (n+1), cell.y + n, cell.z - n))	# front down
		neighbors.append(Vector3i(cell.x + (n-1), cell.y + n, cell.z - n))	# behind down
		neighbors.append(Vector3i(cell.x + n, cell.y + (n+1), cell.z - n))	# left down
		neighbors.append(Vector3i(cell.x + n, cell.y + (n-1), cell.z - n))	# right down
	
	# same xy vertical
	neighbors.append(Vector3i(cell.x, cell.y, cell.z + 1))
	neighbors.append(Vector3i(cell.x, cell.y, cell.z - 1))
	
	return neighbors

func _is_ally(unit_a: Unit, unit_b: Unit) -> bool:
	if unit_a == null or unit_b == null:
		return false
	var a_is_player = BattleManager.player_units.has(unit_a)
	var b_is_player = BattleManager.player_units.has(unit_b)
	return a_is_player == b_is_player

func _get_move_cost(tile: BattleTileData) -> int:
	match tile.terrain_type:
		BattleTileData.TerrainType.NORMAL:	return 1
		#BattleTileData.TerrainType.SAND:	return 2
		#BattleTileData.TerrainType.FOREST:	return 3
		#BattleTileData.TerrainType.WATER:	return 2
		#BattleTileData.TerrainType.ICE:		return 1
		#BattleTileData.TerrainType.LAVA:	return 2
		#BattleTileData.TerrainType.ROCK:	return 3
		_:									return 1

func build_move_query(unit_data: UnitData, is_player: bool) -> RangeQuery:
	return RangeQuery.for_movement(unit_data)

func build_ability_query(ability_data: AbilityData) -> RangeQuery:
	var query = RangeQuery.new()
	query.show_full_range = true
	query.max_range = ability_data.max_range
	query.min_range = ability_data.min_range
	query.ignore_elevation = ability_data.ignores_elevation
	query.jump_height = ability_data.max_elevation_difference
	query.requires_unit = ability_data.target_type == AbilityData.TargetType.SINGLE_ENEMY or \
		ability_data.target_type == AbilityData.TargetType.SINGLE_ALLY
	query.requires_enemy = ability_data.target_type == AbilityData.TargetType.SINGLE_ENEMY
	query.requires_ally = ability_data.target_type == AbilityData.TargetType.SINGLE_ALLY
	return query
	
func debug_reachable(origin: Vector3i, query: RangeQuery, acting_unit: Unit = null) -> void:
	var result = _run_dijkstra(origin, query, acting_unit)
	var visited = result[0]
	#print("=== PATHFINDER DEBUG ===")
	#print("Origin: ", origin)
	#print("Max range: ", query.max_range)
	#print("Jump height: ", query.jump_height)
	#print("Total visited cells: ", visited.size())
	
	var by_elevation: Dictionary = {}
	for cell in visited.keys():
		var cost = visited[cell]
		if not by_elevation.has(cell.z):
			by_elevation[cell.z] = []
		by_elevation[cell.z].append([cell, cost])
	
	#for elev in by_elevation.keys():
		#print("  Elevation ", elev, ": ", by_elevation[elev].size(), " cells")
		#for entry in by_elevation[elev]:
			#print("    ", entry[0], " cost: ", entry[1])
			
	var result2 = _run_dijkstra(origin, query, acting_unit)
	var visited2 = result2[0]
	#print("=== END DEBUG ===")
