class_name TileVisualManager
extends Node

const HIGHLIGHT_SCENE = preload("res://Scenes/Battle/HighlightTile.tscn")

const EFFECT_COLORS: Dictionary = {
	EffectId.Id.REDHOT: Color(1.0, 0.1, 0.0, 1.0),
	#EffectId.Id.BURNING: Color(1.0, 0.5, 0.0, 1.0),
	#EffectId.Id.SOAKED: Color(0.2, 0.4, 1.0, 1.0),
	EffectId.Id.DISEASED: Color(0.5, 0.0, 0.8, 1.0),
	#EffectId.Id.ELECTRIFIED: Color(0.9, 0.9, 0.0, 1.0),
	EffectId.Id.FROZEN: Color(0.5, 0.9, 1.0, 1.0),
}

# terrain type -> [atlas_source_id, atlas_coords] for converted terrain visuals
const TERRAIN_CONVERSION_TILES: Dictionary = {
	BattleTileData.TerrainType.LAVA: [0, Vector2i(13, 5)],	# replace with actual coords
	BattleTileData.TerrainType.ASH: [0, Vector2i(0, 5)],	# replace with actual coords
	BattleTileData.TerrainType.ICE: [0, Vector2i(13, 3)],	# replace with actual coords
}


const LIGHT_Y_OFFSET: float = -8.0
const LIGHT_SCALE: float = 1.0
const PULSE_ENERGY_MIN: float = 1.0
const PULSE_ENERGY_MAX: float = 3.5
const PULSE_DURATION: float = 0.6
const COLOR_CYCLE_DURATION: float = 1.2

var _terrain_layers: Node2D = null
var _grid: BattleGrid = null

# highlight overlays — cleared on selection change
var _active_highlights: Array[Node2D] = []

# effect lights — one PointLight2D per affected tile
# Vector3i -> PointLight2D
var _effect_lights: Dictionary = {}

# tweens per light — Vector3i -> Array[Tween] so we can kill them on refresh
var _effect_tweens: Dictionary = {}

# effect sprites — Vector3i -> Dictionary[EffectId.Id -> Node]
var _effect_sprites: Dictionary = {}

func setup(grid: BattleGrid, terrain_layers: Node2D) -> void:
	_grid = grid
	_terrain_layers = terrain_layers

# =============================================================================
# HIGHLIGHT (selection)
# =============================================================================

func show_move_range(cells: Dictionary, get_world_pos: Callable) -> void:
	clear_highlights()
	for cell in cells:
		var highlight: Node2D = HIGHLIGHT_SCENE.instantiate()
		add_child(highlight)
		highlight.global_position = get_world_pos.call(cell)
		highlight.z_index = cell.z * 4 + 1
		if cells[cell] == false:
			highlight.modulate = Color(1, 0, 0, 0.75)
		_active_highlights.append(highlight)

func clear_highlights() -> void:
	for highlight in _active_highlights:
		highlight.queue_free()
	_active_highlights.clear()

func clear() -> void:
	clear_highlights()

# =============================================================================
# EFFECT VISUALS
# =============================================================================

func refresh(tile: BattleTileData) -> void:
	_refresh_tile_effect_visuals(tile)
	_refresh_terrain_visual(tile)
	_refresh_tile_occupancy(tile)
	
func _refresh_tile_effect_visuals(tile: BattleTileData) -> void:
	if tile.active_effects.is_empty():
		_remove_effect_light(tile.cell)
	else:
		_update_effect_light(tile)
		
func _refresh_terrain_visual(tile: BattleTileData) -> void:
	var layer = _terrain_layers.get_node("Elevation" + str(tile.cell.z))
	if layer == null:
		return
	var cell_2d = Vector2i(tile.cell.x, tile.cell.y)
	if TERRAIN_CONVERSION_TILES.has(tile.terrain_type):
		var coords = TERRAIN_CONVERSION_TILES[tile.terrain_type]
		layer.set_cell(cell_2d, coords[0], coords[1])
	else:
		# restore original tile
		layer.set_cell(cell_2d, tile.atlas_source_id, tile.atlas_coords)
		
func _refresh_tile_occupancy(tile: BattleTileData) -> void:
	if not _effect_sprites.has(tile.cell):
		return
	var has_visual_effect = not _effect_sprites[tile.cell].is_empty()
	for effect_id in _effect_sprites[tile.cell]:
		var scene = _effect_sprites[tile.cell][effect_id]
		if scene.has_method("set_occupied"):
			scene.set_occupied(tile.unit_ref != null)

	if tile.unit_ref != null and has_visual_effect:
		await tile.unit_ref.set_effect_alpha(Constants.UNIT_ALPHA_FADE)

func _update_effect_light(tile: BattleTileData) -> void:
	# kill existing tweens for this cell
	if _effect_tweens.has(tile.cell):
		for tween in _effect_tweens[tile.cell]:
			if tween and tween.is_valid():
				tween.kill()
	_effect_tweens[tile.cell] = []

	# get or create the light
	var light: PointLight2D
	if _effect_lights.has(tile.cell):
		light = _effect_lights[tile.cell]
	else:
		light = _create_light(tile.cell)
		_effect_lights[tile.cell] = light

	# build color list from active effects
	var colors: Array[Color] = []
	for instance in tile.active_effects:
		if EFFECT_COLORS.has(instance.effect_id):
			colors.append(EFFECT_COLORS[instance.effect_id])

	if colors.is_empty():
		_remove_effect_light(tile.cell)
		return

	# start pulse tween
	var pulse_tween = get_tree().create_tween().set_loops()
	pulse_tween.tween_property(light, "energy", PULSE_ENERGY_MAX, PULSE_DURATION)
	pulse_tween.tween_property(light, "energy", PULSE_ENERGY_MIN, PULSE_DURATION)
	_effect_tweens[tile.cell].append(pulse_tween)

	# start color cycle tween if multiple effects
	if colors.size() > 1:
		var color_tween = get_tree().create_tween().set_loops()
		for color in colors:
			color_tween.tween_property(light, "color", color, COLOR_CYCLE_DURATION)
		_effect_tweens[tile.cell].append(color_tween)
	else:
		light.color = colors[0]

func _create_light(cell: Vector3i) -> PointLight2D:
	var world_pos = _cell_to_world(cell)

	var gradient = Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color.BLACK)
	var tex = GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 32
	tex.height = 32

	var light = PointLight2D.new()
	light.global_position = world_pos
	light.texture = load("res://Assets/Sprites/Tilesets/DiamondHighlight_Blue.png")
	light.texture_scale = LIGHT_SCALE
	light.energy = PULSE_ENERGY_MIN
	light.blend_mode = Light2D.BLEND_MODE_ADD
	light.z_index = cell.z * 4
	add_child(light)
	return light

func _remove_effect_light(cell: Vector3i) -> void:
	if _effect_tweens.has(cell):
		for tween in _effect_tweens[cell]:
			if tween and tween.is_valid():
				tween.kill()
		_effect_tweens.erase(cell)

	if _effect_lights.has(cell):
		_effect_lights[cell].queue_free()
		_effect_lights.erase(cell)

func _cell_to_world(cell: Vector3i) -> Vector2:
	var layer = _terrain_layers.get_node("Elevation" + str(cell.z))
	if layer == null:
		return Vector2.ZERO
	var world = layer.to_global(layer.map_to_local(Vector2i(cell.x, cell.y)))
	world.y += LIGHT_Y_OFFSET
	return world

func play_effect_apply_animation(tile: BattleTileData, effect_id: EffectId.Id) -> void:
	print("spawning ", EffectId.Id.keys()[effect_id], " at cell: ", tile.cell, " world: ", _cell_to_world(tile.cell))
	var scene_file: PackedScene = EffectSceneRegistry.get_scene(effect_id)
	if not scene_file:
		return
	var scene: Node2D = scene_file.instantiate()
	add_child(scene)
	scene.modulate.a = 0
	scene.global_position += _cell_to_world(tile.cell)
	scene.global_position.y -= Constants.TILE_ORIGIN_OFFSET
	var tween = create_tween()
	tween.tween_property(scene, "modulate:a", 1, 0.2)
	await tween.finished
	scene.z_as_relative = false
	var occluders = _grid.occlusion_map.get(tile.cell, [])
	if occluders.is_empty():
		scene.z_index = 14 * 4 + 2
	else:
		var lowest_occluder = occluders[occluders.size() - 1]
		scene.z_index = lowest_occluder.z * 4 - 2
	if not _effect_sprites.has(tile.cell):
		_effect_sprites[tile.cell] = {}
	_effect_sprites[tile.cell][effect_id] = scene

func play_effect_remove_animation(tile: BattleTileData, effect_id: EffectId.Id, reason: EffectExecutor.RemovalReason) -> void:
	if not _effect_sprites.has(tile.cell) or not _effect_sprites[tile.cell].has(effect_id):
		return
	_effect_sprites[tile.cell][effect_id].queue_free()
	_effect_sprites[tile.cell].erase(effect_id)
	if _effect_sprites[tile.cell].is_empty():
		_effect_sprites.erase(tile.cell)
