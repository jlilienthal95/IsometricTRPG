class_name BattleGrid
extends Node

var _grid: Dictionary = {}  # Vector2i -> BattleTileData

func build_from_tilemap(tilemap: TileMapLayer, elevation: int) -> void:
	for cell in tilemap.get_used_cells():
		var tile_data = tilemap.get_cell_tile_data(cell)
		if tile_data == null:
			continue
		var tile = _grid.get(cell, BattleTileData.new())
		if elevation > tile.elevation:
			tile.elevation = elevation
			tile.terrain_type = tile_data.get_custom_data("terrain_type")
			tile.is_walkable = tile_data.get_custom_data("is_walkable")
		_grid[cell] = tile

# The query interface — this is what all other systems will call

func get_tile(cell: Vector2i) -> BattleTileData:
	return _grid.get(cell, null)

func is_walkable(cell: Vector2i) -> bool:
	var tile = get_tile(cell)
	return tile != null and tile.is_walkable

func get_elevation(cell: Vector2i) -> int:
	var tile = get_tile(cell)
	return tile.elevation if tile else 0

func get_all_cells() -> Array:
	return _grid.keys()


func place_unit(unit: Unit, cell: Vector2i) -> void:
	var tile = get_tile(cell)
	if tile == null:
		push_error("Tried to place unit on invalid cell: " + str(cell))
		return
	tile.unit_ref = unit
	unit.grid_position = cell

func remove_unit(cell: Vector2i) -> void:
	var tile = get_tile(cell)
	if tile == null:
		return
	tile.unit_ref = null

func move_unit(from: Vector2i, to: Vector2i) -> void:
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

func get_unit_at(cell: Vector2i) -> Unit:
	var tile = get_tile(cell)
	if tile == null:
		return null
	return tile.unit_ref

func is_cell_occupied(cell: Vector2i) -> bool:
	var tile = get_tile(cell)
	if tile == null:
		return false
	return tile.unit_ref != null
