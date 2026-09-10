class_name TileVisualManager
extends Node

const HIGHLIGHT_SCENE = preload("res://Scenes/Battle/HighlightTile.tscn")
const TILE_TINT_SHADER = preload("res://Scenes/Battle/tile_tint.gdshader")

# The single source of truth for per-effect tile colors — used by the effect
# glow (_update_effect_light) AND the directional force arrows, so an effect
# reads one color everywhere. Add an entry here to give an effect its color.
const EFFECT_COLORS: Dictionary = {
	EffectId.Id.REDHOT: Color(1.0, 0.1, 0.0, 1.0),
	#EffectId.Id.BURNING: Color(1.0, 0.5, 0.0, 1.0),
	#EffectId.Id.SOAKED: Color(0.2, 0.4, 1.0, 1.0),
	EffectId.Id.DISEASED: Color(0.5, 0.0, 0.8, 1.0),
	#EffectId.Id.ELECTRIFIED: Color(0.9, 0.9, 0.0, 1.0),
	EffectId.Id.FROZEN: Color(0.5, 0.9, 1.0, 1.0),
	EffectId.Id.MAGNETISED: Color(0.55, 0.55, 0.62, 1.0),	# magnetics — grey
	EffectId.Id.WINDY: Color(0.78, 0.95, 0.25, 1.0),		# wind — yellow-green
}

# fallback for an effect with no authored color (keeps visuals from vanishing)
const DEFAULT_EFFECT_COLOR := Color(1.0, 1.0, 1.0, 1.0)

# the tile color for an effect, from the shared EFFECT_COLORS pipeline
func get_effect_color(effect_id: EffectId.Id) -> Color:
	return EFFECT_COLORS.get(effect_id, DEFAULT_EFFECT_COLOR)

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
# move-path preview overlays — a separate layer so the previewed route can be
# redrawn on every hover without disturbing the underlying range highlight
var _active_path_highlights: Array[Node2D] = []
# directional force arrows (wind/magnetics), keyed per cell like _effect_lights
# so a tile refresh updates just its own arrow. Cell -> arrow Node2D.
var _effect_direction_indicators: Dictionary = {}

# preview colors — chosen to read on TOP of the blue range highlight (so not
# blue). Applied via the tint shader, not modulate, so they actually show.
const PATH_COLOR := Color(0.25, 1.0, 0.35, 0.9)			# route tiles — green
const PATH_WAYPOINT_COLOR := Color(1.0, 0.8, 0.1, 0.98)	# waypoints — gold
const PATH_INVALID_COLOR := Color(1.0, 0.15, 0.15, 0.9)	# route exceeds range — red

# tint materials are built once and reused across the three route roles
var _path_material: ShaderMaterial = null
var _waypoint_material: ShaderMaterial = null
var _invalid_material: ShaderMaterial = null

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
		highlight.z_index = _highlight_z(cell, 1)
		if cells[cell] == false:
			highlight.modulate = Color(1, 0, 0, 0.75)
		_active_highlights.append(highlight)

# z-index for a tile highlight. Normally terrain-level (below actors). But an
# object-TOP tile sits under an object drawn at UNOCCLUDED_ACTOR_Z_INDEX, so its
# highlight must clear the object instead of hiding behind it. `tier` stacks
# range (1) < path (2) < arrows (3).
func _highlight_z(cell: Vector3i, tier: int) -> int:
	var tile := _grid.get_tile(cell)
	if tile != null and tile.is_object_top:
		return Constants.UNOCCLUDED_ACTOR_Z_INDEX + tier
	return cell.z * Constants.Z_INDEX_LAYER_STRIDE + tier

func clear_highlights() -> void:
	for highlight in _active_highlights:
		highlight.queue_free()
	_active_highlights.clear()

# Draws the previewed movement route on top of the range highlight: every tile
# the unit will cross, with player-placed waypoints tinted distinctly, and the
# whole route recolored when it overruns range. Cleared and redrawn per hover.
func show_move_path(path_cells: Array, waypoint_cells: Array, get_world_pos: Callable, valid: bool = true) -> void:
	clear_move_path()
	_ensure_path_materials()
	for cell in path_cells:
		var highlight: Node2D = HIGHLIGHT_SCENE.instantiate()
		add_child(highlight)
		highlight.global_position = get_world_pos.call(cell)
		highlight.z_index = _highlight_z(cell, 2)	# above the range highlight (tier 1)
		# recolor via the tint shader on the sprite itself (modulate can't override
		# the blue art); neutralize the scene's baked-in modulate so tint alpha wins
		var sprite: CanvasItem = highlight.get_node("Sprite2D")
		sprite.modulate = Color.WHITE
		if not valid:
			sprite.material = _invalid_material
		elif waypoint_cells.has(cell):
			sprite.material = _waypoint_material
		else:
			sprite.material = _path_material
		_active_path_highlights.append(highlight)

# builds the three reusable tint materials on first use
func _ensure_path_materials() -> void:
	if _path_material != null:
		return
	_path_material = _make_tint_material(PATH_COLOR)
	_waypoint_material = _make_tint_material(PATH_WAYPOINT_COLOR)
	_invalid_material = _make_tint_material(PATH_INVALID_COLOR)

func _make_tint_material(color: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = TILE_TINT_SHADER
	mat.set_shader_parameter("tint", color)
	return mat

func clear_move_path() -> void:
	for highlight in _active_path_highlights:
		highlight.queue_free()
	_active_path_highlights.clear()

# =============================================================================
# DIRECTIONAL FORCE INDICATORS (wind / magnetics)
#
# Part of the persistent effect-visual refresh (like the glow), NOT a
# handler-facing API: an effect opts in simply by setting a non-zero `direction`
# on its EffectInstance, and refresh() draws the matching arrow — colored from
# the shared EFFECT_COLORS pipeline and pointing that way. Handlers never touch
# the visual manager.
# =============================================================================

# Draws (or clears) this tile's force arrow. The first active effect carrying a
# non-zero direction wins; arbitration between stacked forces is a separate
# concern (see ForcedMovement). The screen-space heading is derived from
# the world delta to the neighbour cell, so it's correct under the iso skew.
func _refresh_direction_indicator(tile: BattleTileData) -> void:
	var directional: EffectInstance = null
	for instance in tile.active_effects:
		if instance.direction != Vector3i.ZERO:
			directional = instance
			break

	_remove_direction_indicator(tile.cell)	# clear any stale arrow first
	if directional == null:
		return

	var cell := tile.cell
	var from := _cell_to_world(cell)
	var to := _cell_to_world(cell + directional.direction)
	var arrow := _make_direction_arrow(get_effect_color(directional.effect_id))
	add_child(arrow)
	# lift onto the tile face — _cell_to_world sits near the tile's bottom origin,
	# so nudge up by the tile origin offset to center the arrow on the diamond
	arrow.global_position = from + Vector2(0, -(Constants.TILE_ORIGIN_OFFSET / 2))
	arrow.rotation = (to - from).angle()	# heading unaffected by the vertical nudge
	arrow.z_index = _highlight_z(cell, 3)	# above range (1) and path (2)
	_effect_direction_indicators[cell] = arrow

func _remove_direction_indicator(cell: Vector3i) -> void:
	if _effect_direction_indicators.has(cell):
		_effect_direction_indicators[cell].queue_free()
		_effect_direction_indicators.erase(cell)

# a flat chevron pointing along +X (screen right); rotation aims it at the flow.
# Half the previous size, with a dark outline so the fill (which shares its
# effect's glow color) still reads over that same-colored tile glow.
const ARROW_OUTLINE_COLOR := Color(0.05, 0.05, 0.05, 0.9)
const ARROW_OUTLINE_WIDTH := 2.0

func _make_direction_arrow(color: Color) -> Node2D:
	var shape := PackedVector2Array([
		Vector2(5, 0), Vector2(-3, -4), Vector2(-1, 0), Vector2(-3, 4)
	])
	var arrow := Node2D.new()

	# dark outline underneath (closed loop; append the first point to close it)
	var outline := Line2D.new()
	var loop := shape.duplicate()
	loop.append(shape[0])
	outline.points = loop
	outline.width = ARROW_OUTLINE_WIDTH
	outline.default_color = ARROW_OUTLINE_COLOR
	outline.joint_mode = Line2D.LINE_JOINT_ROUND
	outline.begin_cap_mode = Line2D.LINE_CAP_ROUND
	outline.end_cap_mode = Line2D.LINE_CAP_ROUND
	arrow.add_child(outline)

	# colored fill on top
	var fill := Polygon2D.new()
	fill.polygon = shape
	fill.color = color
	arrow.add_child(fill)

	return arrow

func clear() -> void:
	# selection overlays only — force indicators (like effect lights) are
	# persistent environmental visuals, cleared by their own effect's lifecycle,
	# not by a change of selection
	clear_highlights()
	clear_move_path()

# =============================================================================
# EFFECT VISUALS
# =============================================================================

func refresh(tile: BattleTileData) -> void:
	_refresh_tile_effect_visuals(tile)
	_refresh_terrain_visual(tile)
	_refresh_tile_occupancy(tile)
	_refresh_direction_indicator(tile)
	
func _refresh_tile_effect_visuals(tile: BattleTileData) -> void:
	if tile.active_effects.is_empty():
		_remove_effect_light(tile.cell)
	else:
		_update_effect_light(tile)
		
func _refresh_terrain_visual(tile: BattleTileData) -> void:
	var layer = _grid.get_layer(tile.cell.z)
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
	var layer = _grid.get_layer(cell.z)
	if layer == null:
		return Vector2.ZERO
	var world = layer.to_global(layer.map_to_local(Vector2i(cell.x, cell.y)))
	world.y += LIGHT_Y_OFFSET
	return world

func play_effect_apply_animation(tile: BattleTileData, effect_id: EffectId.Id) -> void:
	DebugLog.effects("spawning %s at cell %s (world %s)" % [EffectId.Id.keys()[effect_id], tile.cell, _cell_to_world(tile.cell)])
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
	# one z-slot below where an actor standing here would draw (Constants.
	# UNOCCLUDED_ACTOR_Z_INDEX / BattleActor.update_z_index use +3 / -1 for
	# actors themselves) — a tile effect should sit under, not on top of, a
	# unit or object occupying the same tile
	var occluders = _grid.occlusion_map.get(tile.cell, [])
	if occluders.is_empty():
		scene.z_index = Constants.MAX_ELEVATION * Constants.Z_INDEX_LAYER_STRIDE + 2
	else:
		var lowest_occluder = occluders[occluders.size() - 1]
		scene.z_index = lowest_occluder.z * Constants.Z_INDEX_LAYER_STRIDE - 2
	if not _effect_sprites.has(tile.cell):
		_effect_sprites[tile.cell] = {}
	_effect_sprites[tile.cell][effect_id] = scene

func play_effect_remove_animation(tile: BattleTileData, effect_id: EffectId.Id, reason: EffectExecutor.RemovalReason) -> void:
	if not _effect_sprites.has(tile.cell) or not _effect_sprites[tile.cell].has(effect_id):
		return
	var scene: Node2D = _effect_sprites[tile.cell][effect_id]
	scene.play("fade")
	var tween = create_tween()
	tween.tween_property(scene, "modulate:a", 0, Constants.FADE_TIMER)
	await tween.finished
	scene.queue_free()
	_effect_sprites[tile.cell].erase(effect_id)
	if _effect_sprites[tile.cell].is_empty():
		_effect_sprites.erase(tile.cell)
