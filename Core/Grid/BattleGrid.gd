class_name BattleGrid
extends Node

var _grid: Dictionary = {}	# Vector3i -> BattleTileData
var occlusion_map: Dictionary = {}	# Vector3i -> Array[Vector3i] of occluding tiles

# reads all tiles from a TileMapLayer and adds them to the logical grid at the given elevation
# skips tiles marked as visual-only since they have no gameplay significance
func build_from_tilemap(tilemap: TileMapLayer, elevation: int) -> void:
	for cell in tilemap.get_used_cells():
		var tile_data = tilemap.get_cell_tile_data(cell)
		if tile_data == null:
			continue
		if tile_data.get_custom_data("is_visual_only"):
			continue
		var tile = BattleTileData.new()
		tile.elevation = elevation
		tile.terrain_type = tile_data.get_custom_data("terrain_type")
		tile.is_walkable = tile_data.get_custom_data("is_walkable")
		_grid[Vector3i(cell.x, cell.y, elevation)] = tile

# --- query interface — all other systems call these ---

# returns the BattleTileData at the given grid cell, or null if the cell doesn't exist
func get_tile(cell: Vector3i) -> BattleTileData:
	return _grid.get(cell, null)

# returns true if the cell exists and is marked walkable
func is_walkable(cell: Vector3i) -> bool:
	var tile = get_tile(cell)
	return tile != null and tile.is_walkable

# returns the elevation of the given cell, or 0 if it doesn't exist
func get_elevation(cell: Vector3i) -> int:
	var tile = get_tile(cell)
	return tile.elevation if tile else 0

# returns all cell coordinates currently in the grid
func get_all_cells() -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	for key in _grid.keys():
		cells.append(key)
	return cells

# places a unit on the given cell and updates the unit's grid_position
func place_unit(unit: Unit, cell: Vector3i) -> void:
	var tile = get_tile(cell)
	if tile == null:
		push_error("Tried to place unit on invalid cell: " + str(cell))
		return
	tile.unit_ref = unit
	unit.grid_position = cell

# removes the unit reference from the given cell
func remove_unit(cell: Vector3i) -> void:
	var tile = get_tile(cell)
	if tile == null:
		return
	tile.unit_ref = null

# moves a unit from one cell to another, updating grid references and the unit's position
func move_unit(from: Vector3i, to: Vector3i) -> void:
	var from_tile = get_tile(from)
	var to_tile = get_tile(to)
	if from_tile == null or to_tile == null:
		push_error("Invalid move from " + str(from) + " to " + str(to))
		return
	if to_tile.unit_ref != null:
		push_error("Tried to move unit to occupied cell: " + str(to))
		return
	to_tile.unit_ref = from_tile.unit_ref
	to_tile.unit_ref.grid_position = to
	from_tile.unit_ref = null

# returns the Unit on the given cell, or null if unoccupied
func get_unit_at(cell: Vector3i) -> Unit:
	var tile = get_tile(cell)
	if tile == null:
		return null
	return tile.unit_ref

# returns true if a unit is currently on the given cell
func is_cell_occupied(cell: Vector3i) -> bool:
	var tile = get_tile(cell)
	if tile == null:
		return false
	return tile.unit_ref != null

# returns the highest-elevation tile at the given XY position, or null if none exist
func get_tile_at_highest_elevation(xy: Vector2i) -> BattleTileData:
	var highest_tile: BattleTileData = null
	var highest_elevation: int = -1
	for key in _grid.keys():
		if key.x == xy.x and key.y == xy.y:
			var tile = _grid[key]
			if tile.elevation > highest_elevation:
				highest_elevation = tile.elevation
				highest_tile = tile
	return highest_tile

# precomputes which cells are visually occluded by elevated tiles
# for each elevated tile, calculates its visual footprint at lower elevations
# and records which cells fall behind or beside it
# occluders are sorted descending by elevation so the highest occluder is always first
func build_occlusion_map() -> void:
	occlusion_map.clear()

	for other in _grid.keys():
		var other_z = other.z
		if other_z <= 1:
			continue

		for cell in _grid.keys():
			if cell.z >= other_z:
				continue

			# adjust the occluding tile's footprint to the cell's elevation level
			var cell_n = other_z - cell.z
			var adjusted_footprint_x = other.x + cell_n
			var adjusted_footprint_y = other.y + cell_n

			# a cell is occluded if it falls directly behind, to the right of,
			# or directly beneath the adjusted footprint
			var is_behind = cell.x == adjusted_footprint_x - 1 and cell.y == adjusted_footprint_y
			var is_right = cell.x == adjusted_footprint_x and cell.y == adjusted_footprint_y - 1
			var is_same = cell.x == adjusted_footprint_x and cell.y == adjusted_footprint_y

			if is_behind or is_right or is_same:
				if not occlusion_map.has(cell):
					occlusion_map[cell] = []
				if not occlusion_map[cell].has(other):
					occlusion_map[cell].append(other)

	for cell in occlusion_map.keys():
		occlusion_map[cell].sort_custom(func(a, b): return a.z > b.z)

	print("occlusion map built: ", occlusion_map.size(), " occluded cells")
