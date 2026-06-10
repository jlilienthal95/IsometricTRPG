class_name Pathfinder
extends Node

var _grid: BattleGrid = null

func setup(grid: BattleGrid) -> void:
	_grid = grid

func get_cells_in_range(origin: Vector3i, query: RangeQuery, acting_unit: Unit = null) -> Array[Vector3i]:
	var reachable: Array[Vector3i] = []
	var visited: Dictionary = {}
	var queue: Array = []

	visited[origin] = 0
	queue.append([origin, 0])

	while queue.size() > 0:
		# dijkstra - always process lowest cost first
		var lowest_idx = 0
		for i in range(queue.size()):
			if queue[i][1] < queue[lowest_idx][1]:
				lowest_idx = i
		var current = queue[lowest_idx]
		queue.remove_at(lowest_idx)

		var cell: Vector3i = current[0]
		var cost: int = current[1]

		# only add to results if within min/max range
		if cost >= query.min_range:
			if query.requires_unit and not _grid.is_cell_occupied(cell):
				pass
			elif query.requires_empty and _grid.is_cell_occupied(cell) and cell != origin:
				pass
			elif query.can_end_on_ally == false and _grid.is_cell_occupied(cell) and cell != origin:
				pass
			else:
				reachable.append(cell)

		if cost >= query.max_range:
			continue

		for neighbor in _get_neighbors(cell):
			if visited.has(neighbor):
				continue
			var tile = _grid.get_tile(neighbor)
			if tile == null:
				continue
			if query.blocked_by_enemies and _grid.is_cell_occupied(neighbor):
				var occupant = _grid.get_unit_at(neighbor)
				if occupant != null and not _is_ally(occupant, acting_unit):
					continue
			if query.blocked_by_allies and _grid.is_cell_occupied(neighbor):
				var occupant = _grid.get_unit_at(neighbor)
				if occupant != null and _is_ally(occupant, acting_unit):
					continue
			if query.blocked_by_unwalkable and not tile.is_walkable:
				continue
			if not query.ignore_elevation:
				var current_tile = _grid.get_tile(cell)
				var elevation_diff = abs(neighbor.z - cell.z)
				if elevation_diff > query.jump_height:
					continue
			var move_cost: int = _get_move_cost(tile) if query.respect_terrain_cost else 1
			# only penalize same-xy elevation changes (dropping straight down)
			if neighbor.x == cell.x and neighbor.y == cell.y:
				move_cost += 1
			var new_cost = cost + move_cost
			if not visited.has(neighbor):
				visited[neighbor] = new_cost
				queue.append([neighbor, new_cost])

	return reachable
	
func get_movement_path(origin: Vector3i, destination: Vector3i, query: RangeQuery, acting_unit: Unit = null) -> Array[MovementStep]:
	var visited: Dictionary = {}
	var came_from: Dictionary = {}
	var queue: Array = []
	
	visited[origin] = 0
	queue.append([origin, 0])
	
	while queue.size() > 0:
		# dijkstra - always process lowest cost first
		var lowest_idx = 0
		for i in range(queue.size()):
			if queue[i][1] < queue[lowest_idx][1]:
				lowest_idx = i
		var current = queue[lowest_idx]
		queue.remove_at(lowest_idx)
		
		var cell: Vector3i = current[0]
		var cost: int = current[1]
		
		# stop early if we reached destination
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
			if query.blocked_by_unwalkable and not tile.is_walkable:
				continue
			if not query.ignore_elevation:
				var elevation_diff = abs(neighbor.z - cell.z)
				if elevation_diff > query.jump_height:
					continue
			var move_cost: int = _get_move_cost(tile) if query.respect_terrain_cost else 1
			if neighbor.x == cell.x and neighbor.y == cell.y:
				move_cost += 1
			var new_cost = cost + move_cost
			visited[neighbor] = new_cost
			came_from[neighbor] = cell
			queue.append([neighbor, new_cost])
	
	# reconstruct path from came_from
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

func _get_neighbors(cell: Vector3i) -> Array[Vector3i]:
	var neighbors: Array[Vector3i] = []
	
	# cardinal neighbors at same elevation
	neighbors.append(Vector3i(cell.x + 1, cell.y, cell.z))
	neighbors.append(Vector3i(cell.x - 1, cell.y, cell.z))
	neighbors.append(Vector3i(cell.x, cell.y + 1, cell.z))
	neighbors.append(Vector3i(cell.x, cell.y - 1, cell.z))
	
	# elevation neighbors — up and down for each level within jump height
	for n in range(1, 15):	# check all possible elevation differences
		# going up (z+n)
		neighbors.append(Vector3i(cell.x - (n+1), cell.y - n, cell.z + n))	# front
		neighbors.append(Vector3i(cell.x - (n-1), cell.y - n, cell.z + n))	# behind
		neighbors.append(Vector3i(cell.x - n, cell.y - (n+1), cell.z + n))	# left
		neighbors.append(Vector3i(cell.x - n, cell.y - (n-1), cell.z + n))	# right
		# going down (z-n)
		neighbors.append(Vector3i(cell.x + (n+1), cell.y + n, cell.z - n))	# front inverse
		neighbors.append(Vector3i(cell.x + (n-1), cell.y + n, cell.z - n))	# behind inverse
		neighbors.append(Vector3i(cell.x + n, cell.y + (n+1), cell.z - n))	# left inverse
		neighbors.append(Vector3i(cell.x + n, cell.y + (n-1), cell.z - n))	# right inverse
	
	# same xy at adjacent elevations (for crate-top / ground same coordinate case)
	neighbors.append(Vector3i(cell.x, cell.y, cell.z + 1))
	neighbors.append(Vector3i(cell.x, cell.y, cell.z - 1))
	
	return neighbors

func _is_ally(unit_a: Unit, unit_b: Unit) -> bool:
	if unit_a == null or unit_b == null:
		return false
	return unit_a.data.is_player_controlled == unit_b.data.is_player_controlled

func _get_move_cost(tile: BattleTileData) -> int:
	match tile.terrain_type:
		BattleTileData.TerrainType.NORMAL:	return 1
		BattleTileData.TerrainType.SAND:	return 2
		BattleTileData.TerrainType.FOREST:	return 3
		BattleTileData.TerrainType.WATER:	return 2
		BattleTileData.TerrainType.ICE:		return 1
		BattleTileData.TerrainType.LAVA:	return 2
		BattleTileData.TerrainType.ROCK:	return 3
		_:									return 1

func build_move_query(unit_data: UnitData, is_player: bool) -> RangeQuery:
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

func build_ability_query(ability_data: AbilityData) -> RangeQuery:
	var query = RangeQuery.new()
	query.max_range = ability_data.max_range
	query.min_range = ability_data.min_range
	query.ignore_elevation = ability_data.ignores_elevation
	query.jump_height = ability_data.max_elevation_difference
	query.requires_unit = ability_data.target_type == AbilityData.TargetType.SINGLE_ENEMY
	return query
