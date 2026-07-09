class_name BattleGrid
extends Node

signal tile_occupancy_changed(tile: BattleTileData)

# =============================================================================
# STATE
# =============================================================================
var _grid: Dictionary = {}					# Vector3i -> BattleTileData
var occlusion_map: Dictionary = {}			# Vector3i -> Array[Vector3i] of occluding tiles
var active_effect_cells: Dictionary = {}	# EffectId.Id -> Array[Vector3i] (terrain)
var active_effect_units: Dictionary = {}	# EffectId.Id -> Array[Unit]
var active_effect_objects: Dictionary = {}	# EffectId.Id -> Array[BattleObject]

# =============================================================================
# GRID CONSTRUCTION
# =============================================================================

# reads all tiles from a TileMapLayer and adds them to the logical grid at the given elevation
# skips tiles marked as visual-only since they have no gameplay significance
func build_from_tilemap(tilemap: TileMapLayer, elevation: int) -> void:
	for c in tilemap.get_used_cells():
		var tile_data = tilemap.get_cell_tile_data(c)
		if tile_data == null:
			continue
		if tile_data.get_custom_data("is_visual_only"):
			continue
		var tile = BattleTileData.new()
		tile.elevation = elevation
		tile.terrain_type = tile_data.get_custom_data("terrain_type")
		tile.is_walkable = tile_data.get_custom_data("is_walkable")
		tile.atlas_source_id = tilemap.get_cell_source_id(c)
		tile.atlas_coords = tilemap.get_cell_atlas_coords(c)
		add_tile(Vector3i(c.x, c.y, elevation), tile)

# registers a single tile in the logical grid. Public so tests and future
# procedural maps can construct grids without a TileMapLayer.
func add_tile(cell: Vector3i, tile: BattleTileData) -> void:
	tile.cell = cell
	tile.elevation = cell.z
	tile._grid_ref = self
	_grid[cell] = tile

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

# =============================================================================
# TILE QUERIES
# =============================================================================

# returns the BattleTileData at the given grid cell, or null if the cell doesn't exist
func get_tile(cell: Vector3i) -> BattleTileData:
	return _grid.get(cell, null)

# returns true if the cell exists, its terrain is walkable, and no non-walkable
# object is sitting on it (a barrel makes an otherwise walkable tile unwalkable;
# a crate does not)
func is_walkable(cell: Vector3i) -> bool:
	var tile = get_tile(cell)
	if tile == null or not tile.is_walkable:
		return false
	if tile.object_ref != null and not tile.object_ref.data.is_walkable:
		return false
	return true

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

# =============================================================================
# OCCUPANCY — units and objects
# =============================================================================

# places a unit on the given cell and updates the unit's grid_position
func place_unit(unit: Unit, cell: Vector3i) -> void:
	var tile = get_tile(cell)
	if tile == null:
		push_error("Tried to place unit on invalid cell: " + str(cell))
		return
	tile.unit_ref = unit
	unit.grid_position = cell
	tile_occupancy_changed.emit(tile)

func remove_unit(cell: Vector3i) -> void:
	var tile = get_tile(cell)
	if tile == null:
		return
	tile.unit_ref = null
	tile_occupancy_changed.emit(tile)

# places an object on the given cell and updates the object's grid_position
func place_object(object: BattleObject, cell: Vector3i) -> void:
	var tile = get_tile(cell)
	if tile == null:
		push_error("Tried to place object on invalid cell: " + str(cell))
		return
	tile.object_ref = object
	object.grid_position = cell
	object._grid_ref = self
	tile_occupancy_changed.emit(tile)

func remove_object(cell: Vector3i) -> void:
	var tile = get_tile(cell)
	if tile == null:
		return
	tile.object_ref = null
	tile_occupancy_changed.emit(tile)

# moves whichever kind of actor (Unit or BattleObject) between cells.
# The single movement mutation point — UnitMover and push/slide actions all
# route through here so occupancy bookkeeping can never diverge by actor type.
func move_actor(actor, from: Vector3i, to: Vector3i) -> void:
	var from_tile = get_tile(from)
	var to_tile = get_tile(to)
	if from_tile == null or to_tile == null:
		push_error("Invalid move from " + str(from) + " to " + str(to))
		return
	if actor is Unit:
		if to_tile.unit_ref != null:
			push_error("Tried to move unit to occupied cell: " + str(to))
			return
		to_tile.unit_ref = actor
		from_tile.unit_ref = null
	elif actor is BattleObject:
		if to_tile.object_ref != null:
			push_error("Tried to move object to object-occupied cell: " + str(to))
			return
		to_tile.object_ref = actor
		from_tile.object_ref = null
	else:
		push_error("move_actor: unknown actor type")
		return
	actor.grid_position = to
	tile_occupancy_changed.emit(from_tile)
	tile_occupancy_changed.emit(to_tile)

# returns the Unit on the given cell, or null if unoccupied
func get_unit_at(cell: Vector3i) -> Unit:
	var tile = get_tile(cell)
	if tile == null:
		return null
	return tile.unit_ref

# returns the BattleObject on the given cell, or null
func get_object_at(cell: Vector3i) -> BattleObject:
	var tile = get_tile(cell)
	if tile == null:
		return null
	return tile.object_ref

# returns whichever actor occupies the cell — unit takes priority over object
func get_actor_at(cell: Vector3i):
	var tile = get_tile(cell)
	if tile == null:
		return null
	if tile.unit_ref != null:
		return tile.unit_ref
	return tile.object_ref

# returns true if the cell is occupied in a BLOCKING sense: a unit, or a
# non-walkable object. A walkable object (crate) does not count as occupied —
# units may stand on it.
func is_cell_occupied(cell: Vector3i) -> bool:
	var tile = get_tile(cell)
	if tile == null:
		return false
	if tile.unit_ref != null:
		return true
	return tile.object_ref != null and not tile.object_ref.data.is_walkable

# =============================================================================
# EFFECT PROPAGATION SUPPORT
# =============================================================================

# returns same-elevation cardinal neighbors plus one elevation up and down
# handlers filter the result based on their own directional rules (e.g. fire ignores "down")
func get_effect_neighbors(cell: Vector3i, include_elevation: bool = true) -> Array[Vector3i]:
	var neighbors: Array[Vector3i] = []
	neighbors.append(Vector3i(cell.x + 1, cell.y, cell.z))
	neighbors.append(Vector3i(cell.x - 1, cell.y, cell.z))
	neighbors.append(Vector3i(cell.x, cell.y + 1, cell.z))
	neighbors.append(Vector3i(cell.x, cell.y - 1, cell.z))
	if include_elevation:
		neighbors.append_array(Constants.get_elevation_neighbors_up(cell, 1))
		neighbors.append_array(Constants.get_elevation_neighbors_down(cell, 1))
	return neighbors

# --- terrain effect index — only call from BattleTileData.apply_effect/remove_effect ---

func register_effect_cell(effect_id: EffectId.Id, cell: Vector3i) -> void:
	if not active_effect_cells.has(effect_id):
		active_effect_cells[effect_id] = []
	if not active_effect_cells[effect_id].has(cell):
		active_effect_cells[effect_id].append(cell)

func unregister_effect_cell(effect_id: EffectId.Id, cell: Vector3i) -> void:
	if active_effect_cells.has(effect_id):
		active_effect_cells[effect_id].erase(cell)

func get_cells_with_effect(effect_id: EffectId.Id) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	var found = active_effect_cells.get(effect_id, [])
	for cell in found:
		result.append(cell)
	return result

# --- unit effect index — only call from Unit.apply_effect/remove_effect ---

func register_effect_unit(effect_id: EffectId.Id, unit: Unit) -> void:
	if not active_effect_units.has(effect_id):
		active_effect_units[effect_id] = []
	if not active_effect_units[effect_id].has(unit):
		active_effect_units[effect_id].append(unit)

func unregister_effect_unit(effect_id: EffectId.Id, unit: Unit) -> void:
	if active_effect_units.has(effect_id):
		active_effect_units[effect_id].erase(unit)

func get_units_with_effect(effect_id: EffectId.Id) -> Array[Unit]:
	var result: Array[Unit] = []
	var found = active_effect_units.get(effect_id, [])
	for unit in found:
		result.append(unit)
	return result

# --- object effect index — only call from BattleObject.apply_effect/remove_effect ---

func register_effect_object(effect_id: EffectId.Id, object: BattleObject) -> void:
	if not active_effect_objects.has(effect_id):
		active_effect_objects[effect_id] = []
	if not active_effect_objects[effect_id].has(object):
		active_effect_objects[effect_id].append(object)

func unregister_effect_object(effect_id: EffectId.Id, object: BattleObject) -> void:
	if active_effect_objects.has(effect_id):
		active_effect_objects[effect_id].erase(object)

func get_objects_with_effect(effect_id: EffectId.Id) -> Array[BattleObject]:
	var result: Array[BattleObject] = []
	var found = active_effect_objects.get(effect_id, [])
	for object in found:
		result.append(object)
	return result

# --- combined query ---

# returns terrain cells, units, and objects currently affected by the given effect
func get_all_affected_with_effect(effect_id: EffectId.Id) -> Dictionary:
	return {
		"cells": get_cells_with_effect(effect_id),
		"units": get_units_with_effect(effect_id),
		"objects": get_objects_with_effect(effect_id),
	}
