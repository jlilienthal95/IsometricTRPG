class_name BattleGrid
extends Node

signal tile_occupancy_changed(tile: BattleTileData, actor: BattleActor, entered: bool)
# a unit was standing on an object that got destroyed; it has been dropped onto
# the object's old base cell (grid-side), and needs its world position synced.
signal rider_dropped(rider: BattleActor, cell: Vector3i)

# =============================================================================
# STATE
# =============================================================================
var _grid: Dictionary = {}					# Vector3i -> BattleTileData
var _layers: Dictionary = {}				# int (elevation) -> TileMapLayer, cached as the grid is built
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
	_layers[elevation] = tilemap	# cache the source layer so get_layer() can hand it back
	for c in tilemap.get_used_cells():
		var tile = create_tile(c, tilemap, elevation)
		if tile == null:
			continue
		print("tile: ", tile)
		add_tile(Vector3i(c.x, c.y, elevation), tile)

# The TileMapLayer backing a given elevation, or null (procedural/test grids
# built via add_tile() have no source layers). Keyed by the real elevation the
# grid was built with — no "Elevation<z>" node-name lookup involved.
func get_layer(z: int) -> TileMapLayer:
	return _layers.get(z, null)

# Any cached layer. All elevation layers share position (0,0) and differ only by
# z_index, so any one maps a cell's (x,y) to the same screen point — used to
# position tiles at elevations that have no layer of their own (object tops).
func get_reference_layer() -> TileMapLayer:
	for layer in _layers.values():
		return layer
	return null

func create_tile(c: Vector2i, tilemap: TileMapLayer, elevation: int) -> BattleTileData:
		var tile_data = tilemap.get_cell_tile_data(c)
		if tile_data == null:
			return
		if tile_data.get_custom_data("is_visual_only"):
			return
		var tile = BattleTileData.new()
		tile.elevation = elevation
		tile.terrain_type = tile_data.get_custom_data("terrain_type")
		tile.is_walkable = tile_data.get_custom_data("is_walkable")
		tile.atlas_source_id = tilemap.get_cell_source_id(c)
		tile.atlas_coords = tilemap.get_cell_atlas_coords(c)
		return tile

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
	# ANY object blocks its own footprint at ground level. A "walkable" object
	# isn't walk-through — it's stand-on-TOP, and place_object() registers the
	# separate walkable tile at cell.z + height for units to path onto.
	if tile.object_ref != null:
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
func place_unit(unit: BattleActor, cell: Vector3i) -> void:
	var tile = get_tile(cell)
	if tile == null:
		push_error("Tried to place unit on invalid cell: " + str(cell))
		return
	tile.unit_ref = unit
	unit.grid_position = cell
	tile_occupancy_changed.emit(tile, unit, true)

func remove_unit(cell: Vector3i) -> void:
	var tile = get_tile(cell)
	if tile == null:
		return
	var unit = tile.unit_ref
	tile.unit_ref = null
	tile_occupancy_changed.emit(tile, unit, false)

# places an object on the given cell and updates the object's grid_position
func place_object(object: BattleObject, cell: Vector3i) -> void:
	var tile = get_tile(cell)
	if tile == null:
		push_error("Tried to place object on invalid cell: " + str(cell))
		return
	if object.data.is_walkable:
		_add_object_top(object, cell)
	tile.object_ref = object
	object.grid_position = cell
	object._grid_ref = self
	tile_occupancy_changed.emit(tile, object, true)

func remove_object(cell: Vector3i) -> void:
	var tile = get_tile(cell)
	if tile == null:
		return
	var object = tile.object_ref
	tile.object_ref = null
	# tear down the stand-on tile with the object. If a unit was riding it, the
	# platform is gone — drop it onto the object's old base cell (a real, in-bounds
	# tile) so it doesn't end up stranded at the erased top cell.
	var rider: BattleActor = null
	if object != null and object.data.is_walkable:
		rider = _remove_object_top(object, cell)
		if rider != null:
			tile.unit_ref = rider
			rider.grid_position = cell
	tile_occupancy_changed.emit(tile, object, false)
	if rider != null:
		rider_dropped.emit(rider, cell)	# world position synced by the scene

# =============================================================================
# OBJECT-TOP TILES — the synthetic stand-on tile a walkable object provides.
# Created/relocated/destroyed in lockstep with the object so it never lingers at
# a stale position (see place_object / move_actor / remove_object).
# =============================================================================

# the stand-on cell for a walkable object based at `base` — "straight up" h
# levels, which in this iso encoding is a (-h, -h, +h) shift (see place_object).
func _object_top_cell(object: BattleObject, base: Vector3i) -> Vector3i:
	var h: int = object.data.height
	return Vector3i(base.x - h, base.y - h, base.z + h)

func _add_object_top(object: BattleObject, base: Vector3i) -> void:
	var base_tile := get_tile(base)
	var top_tile := BattleTileData.new()
	top_tile.is_walkable = true
	top_tile.terrain_type = base_tile.terrain_type if base_tile != null else BattleTileData.TerrainType.GRASS
	top_tile.is_object_top = true	# overlays here must draw above the object
	add_tile(_object_top_cell(object, base), top_tile)

# Removes the object's stand-on tile. Returns the unit standing on it (or null),
# so a move can carry that rider along and a removal can decide its fate.
func _remove_object_top(object: BattleObject, base: Vector3i) -> BattleActor:
	var top := _object_top_cell(object, base)
	var top_tile := get_tile(top)
	if top_tile == null:
		return null
	var rider: BattleActor = top_tile.unit_ref
	_grid.erase(top)
	return rider

# moves whichever kind of actor (Unit or BattleObject) between cells.
# The single movement mutation point — UnitMover and push/slide actions all
# route through here so occupancy bookkeeping can never diverge by actor type.
# Returns the rider (a unit carried along on a walkable object's top) when the
# move relocated one, else null — so the mover can tween the rider in sync.
func move_actor(actor, from: Vector3i, to: Vector3i) -> BattleActor:
	var from_tile = get_tile(from)
	var to_tile = get_tile(to)
	if from_tile == null or to_tile == null:
		push_error("Invalid move from " + str(from) + " to " + str(to))
		return null

	var rider: BattleActor = null
	if actor is Unit:
		if to_tile.unit_ref != null:
			push_error("Tried to move unit to occupied cell: " + str(to))
			return null
		to_tile.unit_ref = actor
		from_tile.unit_ref = null
	elif actor is BattleObject:
		if to_tile.object_ref != null:
			push_error("Tried to move object to object-occupied cell: " + str(to))
			return null
		# relocate the object's stand-on tile, carrying any rider to the new top
		if actor.data.is_walkable:
			rider = _remove_object_top(actor, from)
			_add_object_top(actor, to)
			if rider != null:
				var new_top := get_tile(_object_top_cell(actor, to))
				new_top.unit_ref = rider
				rider.grid_position = new_top.cell	# world position is synced by UnitMover
		to_tile.object_ref = actor
		from_tile.object_ref = null
	else:
		push_error("move_actor: unknown actor type")
		return null

	actor.grid_position = to
	tile_occupancy_changed.emit(from_tile, actor, false)  # leaving
	tile_occupancy_changed.emit(to_tile, actor, true)     # entering
	return rider

# returns the Unit on the given cell, or null if unoccupied
func get_unit_at(cell: Vector3i) -> BattleActor:
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
func get_actor_at(cell: Vector3i) -> BattleActor:
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
	#if tile.unit_ref != null:
		#return true
	#return tile.object_ref != null and not tile.object_ref.data.is_walkable
	return tile.unit_ref != null or tile.object_ref != null

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
