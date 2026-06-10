class_name BattleGrid
extends Node

var _grid: Dictionary = {}  # Vector3i -> BattleTileData

func build_from_tilemap(tilemap: TileMapLayer, elevation: int) -> void:
	for cell in tilemap.get_used_cells():
		var tile_data = tilemap.get_cell_tile_data(cell)
		if tile_data == null:
			continue
			
		var tile = BattleTileData.new()
		tile.elevation = elevation
		tile.terrain_type = tile_data.get_custom_data("terrain_type")
		tile.is_walkable = tile_data.get_custom_data("is_walkable")
			
		var key = Vector3i(cell.x, cell.y, elevation)
		_grid[key] = tile

# The query interface — this is what all other systems will call

func get_tile(cell: Vector3i) -> BattleTileData:
	return _grid.get(cell, null)

func is_walkable(cell: Vector3i) -> bool:
	var tile = get_tile(cell)
	return tile != null and tile.is_walkable

func get_elevation(cell: Vector3i) -> int:
	var tile = get_tile(cell)
	return tile.elevation if tile else 0

func get_all_cells() -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	for key in _grid.keys():
		cells.append(key)
	return cells

func place_unit(unit: Unit, cell: Vector3i) -> void:
	var tile = get_tile(cell)
	if tile == null:
		push_error("Tried to place unit on invalid cell: " + str(cell))
		return
	tile.unit_ref = unit
	unit.grid_position = cell

func remove_unit(cell: Vector3i) -> void:
	var tile = get_tile(cell)
	if tile == null:
		return
	tile.unit_ref = null

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

func get_unit_at(cell: Vector3i) -> Unit:
	var tile = get_tile(cell)
	if tile == null:
		return null
	return tile.unit_ref

func is_cell_occupied(cell: Vector3i) -> bool:
	var tile = get_tile(cell)
	if tile == null:
		return false
	return tile.unit_ref != null

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
