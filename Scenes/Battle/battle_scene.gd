extends Node2D

# --- TEST HOOK ---
# Set BEFORE this scene is added to the tree to spawn a randomized scenario
# instead of the hardcoded Marta/Theo/Auburn setup. Used exclusively by
# Tests/BattleTestRunner.gd — never set during normal gameplay.
var test_scenario: BattleScenario = null

# --- node references ---
@onready var _battle_grid: BattleGrid = $BattleGrid
@onready var _action_resolver: ActionResolver = $ActionResolver
@onready var _input_handler: InputHandler = $InputHandler
@onready var _battle_ui: BattleUI = $CanvasLayer/BattleUI
@onready var _battle_hud: BattleHUD = $CanvasLayer/BattleUI/BattleHUD
@onready var _character_info: CharacterInfo = $CanvasLayer/BattleUI/CharacterInfo
@onready var _pathfinder: Pathfinder = $Pathfinder
@onready var _cursor: Cursor = $Cursor
@onready var _unit_mover: UnitMover = $UnitMover
@onready var _unit_ability_executor: UnitAbilityExecutor = $UnitAbilityExecutor
@onready var _tile_visual_manager: TileVisualManager = $TileVisualManager
@onready var _battle_camera: BattleCamera = $BattleCamera
@onready var _terrain_layers: Node2D = $TerrainLayers
@onready var _effect_executor: EffectExecutor = $EffectExecutor
@onready var _turn_queue: TurnQueue = $TurnQueue
@onready var _ai_brain: AIBrain = $AIBrain
@onready var _mouse_detect_rect: MouseDetectRect = $CanvasLayer/BattleUI/BattleHUD/MouseDetectRect

# units to spawn — preloaded so exports can never fail to find them
# TODO: replace with proper spawn system driven by battle/GameState configuration
const MARTA_DATA = preload("res://Scenes/Battle/Units/Marta/Marta.tres")
const THEO_DATA = preload("res://Scenes/Battle/Units/Theo/Theo.tres")
const AUBURN_DATA = preload("res://Scenes/Battle/Units/Auburn/Auburn.tres")

# --- state ---
# _turn_context is the single source of truth for "who's acting" plus all pathfinding
# data derived from them. It's built atomically in _on_active_unit_changed, the one signal
# BattleManager fires whenever the active unit changes — nothing else may assign to it,
# so there is no second cached unit reference that can desync from BattleManager.active_unit.
var _turn_context: TurnContext = null
#var _previous_unit: Unit = null
var _previous_cell: Vector3i = Vector3i(999,999,999)

# movement routing state (MOVE_SELECT only): the planner accumulates waypoints
# for the active move, and _pending_move_steps carries the confirmed route to
# _on_unit_moved so execution follows the player's chosen path, not a fresh
# shortest one. _last_move_preview_cell is the cell the hover preview last drew
# to, so a newly placed waypoint can redraw without waiting for mouse motion.
var _move_planner: MovePlanner = MovePlanner.new()
var _pending_move_steps: Array[MovementStep] = []
var _last_move_preview_cell: Vector3i = Vector3i(999, 999, 999)

# created in code (not the scene tree) so the scene file needs no edits;
# owns all cinematic presentation, reacting to BattleEvents
var _cinematic_director: CinematicDirector = null

# =============================================================================
# SETUP
# =============================================================================

func _ready() -> void:
	randomize()
	_build_grid()
	_setup_systems()
	if test_scenario != null:
		_spawn_from_scenario(test_scenario)
	else:
		_spawn_actors()

# builds the logical grid from all elevation layers and sets their z indices
func _build_grid() -> void:
	for layer in _terrain_layers.get_children():
		var layer_name = str(layer.name)
		var num_str = ""
		for c in layer_name:
			if c.is_valid_int():
				num_str += c
			elif num_str != "":
				break
		if num_str == "":
			continue
		var elevation = num_str.to_int()
		var z_offset = layer.get_meta("z_offset", 0)
		layer.z_index = elevation * Constants.Z_INDEX_LAYER_STRIDE + z_offset
		_battle_grid.build_from_tilemap(layer, elevation)
	_battle_grid.build_occlusion_map()

# wires up all system references and signal connections
func _setup_systems() -> void:
	# input
	_input_handler.setup(_terrain_layers.get_node("Elevation0"))
	_input_handler.cell_selected.connect(_on_cell_selected)
	_input_handler.cell_hovered.connect(_on_cell_hovered)
	_input_handler.cell_cancelled.connect(_on_cell_cancelled)
	_input_handler.waypoint_placed.connect(_on_waypoint_placed)

	# CharacterInfo follows the CURSOR's cell, not the raw mouse cell, so a
	# frozen cursor keeps the panel pinned to the tile it froze on
	_cursor.cell_changed.connect(_on_cursor_cell_changed)

	# cinematic director — reacts to BattleEvents on its own once set up
	_cinematic_director = CinematicDirector.new()
	_cinematic_director.name = "CinematicDirector"
	add_child(_cinematic_director)
	_cinematic_director.setup(_battle_ui, _battle_camera, grid_to_world)

	# camera panning — needs the director to know when a cinematic owns the camera
	_mouse_detect_rect.setup(_battle_camera, _input_handler, _cinematic_director)

	# hud — subscribes itself to BattleManager/BattleEvents signals (reactive)
	_battle_ui.setup()
	_character_info.refresh()

	# pathfinder
	_pathfinder.setup(_battle_grid)

	# tile visuals and effects
	_tile_visual_manager.setup(_battle_grid, _terrain_layers)

	# battle camera
	_battle_camera.setup(_cursor)

	# battle manager
	BattleManager.setup(_battle_grid, _battle_camera, _cinematic_director, _unit_mover, _unit_ability_executor, _effect_executor, _turn_queue, _input_handler)
	BattleManager.state_changed.connect(_on_battle_state_changed)
	BattleManager.active_unit_changed.connect(_on_active_unit_changed)
	BattleManager.unit_moved.connect(_on_unit_moved)
	BattleManager.ability_selected.connect(_on_ability_selected)
	BattleManager.unit_executed_ability.connect(_on_unit_ability)


	# unit ability executor
	_unit_ability_executor.setup(_battle_grid, _unit_mover, _cinematic_director)

	# effect executor
	_effect_executor.setup(_battle_grid, _unit_mover, _battle_camera, _tile_visual_manager)
	
	# unit mover
	_unit_mover.setup(_battle_grid, _effect_executor, grid_to_world, _battle_camera)

	_battle_grid.tile_occupancy_changed.connect(func(tile, _actor, entered):
		_tile_visual_manager.refresh(tile)
	)
	
	# ai systems
	_ai_brain.setup(_battle_grid, _pathfinder, _turn_queue, _input_handler)
	
	DebugLog.battle_state("battle_scene systems ready")

# TODO: replace with proper spawn system driven by battle/GameState configuration
#
# Walks every ActorMarker placed in the map, resolves it to a grid cell, and
# spawns whatever BattleActorData it holds — a Unit or a BattleObject, treated
# symmetrically here. Affiliation (player/enemy/neutral) is read directly from
# the actor's own data (BattleActorData.type), never from a second field on
# the marker — a marker used to carry its own separate actor_type export that
# defaulted to PLAYER and was never actually wired to the authored data, so
# every spawned actor silently registered as a player regardless of what its
# .tres said. Only Units currently join the turn queue (objects don't take
# turns), but both types go through the same affiliation read so a future
# object-based win condition (e.g. PROTECT_ONE on a barrel) has a real type
# to check instead of assuming "not player-controlled" means "enemy" — see
# BattleActorData.Type, which has three values, not two.
func _spawn_actors() -> void:
	var player_units: Array[BattleActor] = []
	var enemy_units: Array[BattleActor] = []

	for marker in get_tree().get_nodes_in_group("actor_markers"):
		if not marker is ActorMarker:
			continue
		if marker.actor_data == null:
			push_warning("battle_scene: ActorMarker '%s' has no actor_data assigned — skipping" % marker.name)
			continue

		var elevation := int(marker.get_parent().name.trim_prefix("Elevation"))
		var cell := world_to_grid(marker.global_position, elevation)
		#print("[SPAWN] marker: %s | global_pos: %s | elevation: %d | resolved_cell: %s" % [
			#marker.name,
			#marker.global_position,
			#elevation,
			#cell
		#])

		if marker.actor_data is UnitData:
			var unit_data: UnitData = marker.actor_data
			var unit: Unit = _spawn_unit(cell, unit_data)
			if unit == null:
				push_error("battle_scene: _spawn_unit returned null for '%s'" % unit_data.name)
				continue
			_register_by_affiliation(unit, unit_data.type, player_units, enemy_units)

		elif marker.actor_data is BattleObjectData:
			var object_data: BattleObjectData = marker.actor_data.duplicate_for_instance()
			var object := _spawn_object(cell, object_data, object_data.scene)
			if object == null:
				push_error("battle_scene: _spawn_object returned null for '%s'" % object_data.object_name)
				# objects don't join player_units/enemy_units — they don't take turns —
				# but they still exist on the grid and are affiliation-aware for
				# win-condition checks (see BattleManager.current_win_condition)

		else:
			push_warning("battle_scene: ActorMarker '%s' has unrecognized actor_data type" % marker.name)

	_turn_queue.setup(player_units, enemy_units)
	#TODO: Uncomment this before release/export
	#await _battle_ui.on_battle_start()
	BattleManager.call_deferred("start_battle", player_units, enemy_units)

# sorts a newly spawned unit into the correct turn-queue array based on its
# authored affiliation. Neutral units join neither queue and never take a turn,
# which is intentional (a NEUTRAL unit is not a lesser "not player" default —
# it's a distinct, deliberate third state — see BattleActorData.Type).
func _register_by_affiliation(unit: Unit, type: BattleActorData.Type, player_units: Array[BattleActor], enemy_units: Array[BattleActor]) -> void:
	match type:
		BattleActorData.Type.PLAYER:
			player_units.append(unit)
		BattleActorData.Type.ENEMY:
			enemy_units.append(unit)
		BattleActorData.Type.NEUTRAL:
			pass  # neutral units are on the grid but don't take turns

# instantiates a Unit scene, resolves its stats, and places it on the grid
# uses unit_data.get_scene() (unit override -> job scene -> generic Unit.tscn)
# rather than a single hardcoded scene, so each job/unit can carry its own
# inherited scene instead of swapping sprite_frames at runtime
func _spawn_unit(cell: Vector3i, unit_data: UnitData) -> BattleActor:
	var unit_scene: PackedScene = unit_data.get_scene()
	var unit: Unit = unit_scene.instantiate()
	unit_data.resolve()
	unit.global_position = grid_to_world(cell)
	add_child(unit)
	unit.setup(unit_data, cell)
	_battle_grid.place_unit(unit, cell)
	_battle_camera.snap_to(unit.global_position)
	return unit

# instantiates a BattleObject and places it on the grid — mirror of _spawn_unit
func _spawn_object(cell: Vector3i, object_data: BattleObjectData, scene: PackedScene) -> BattleObject:
	var object: BattleObject = scene.instantiate()
	var visual_pos := grid_to_world(Vector3i(cell.x, cell.y, cell.z))
	object.global_position = visual_pos
	add_child(object)
	object.setup(object_data, cell, _battle_grid)
	_battle_grid.place_object(object, cell)
	
	#print("[SPAWN] object: %s | grid_cell: %s | visual_pos: %s | tile_origin: %s" % [
		#object_data.object_name,
		#cell,
		#visual_pos,
		#grid_to_world(cell)
	#])
	
	return object
	
func _spawn_from_scenario(scenario: BattleScenario) -> void:
	var open_cells: Array[Vector3i] = []
	for cell in _battle_grid.get_all_cells():
		if _battle_grid.is_walkable(cell) and not _battle_grid.is_cell_occupied(cell):
			open_cells.append(cell)
	open_cells.shuffle()

	var player_units: Array[BattleActor] = []
	var enemy_units: Array[BattleActor] = []

	for spec in scenario.player_unit_specs:
		if open_cells.is_empty():
			push_warning("BattleTestRunner: ran out of open cells — player roster truncated")
			break
		var unit = _spawn_unit(open_cells.pop_back(), spec["unit_data"])
		var seed_effect: int = spec.get("seed_effect", EffectId.Id.NONE)
		if seed_effect != EffectId.Id.NONE:
			unit.data.apply_effect(seed_effect)
		player_units.append(unit)

	for spec in scenario.enemy_unit_specs:
		if open_cells.is_empty():
			push_warning("BattleTestRunner: ran out of open cells — enemy roster truncated")
			break
		var unit = _spawn_unit(open_cells.pop_back(), spec["unit_data"])
		var seed_effect: int = spec.get("seed_effect", EffectId.Id.NONE)
		if seed_effect != EffectId.Id.NONE:
			unit.data.apply_effect(seed_effect)
		enemy_units.append(unit)

	var object_scene_path := "res://Scenes/Battle/Objects/Object.tscn"
	if ResourceLoader.exists(object_scene_path):
		var object_scene: PackedScene = load(object_scene_path)
		for spec in scenario.object_specs:
			if open_cells.is_empty():
				break
			_spawn_object(open_cells.pop_back(), spec, object_scene)
	elif not scenario.object_specs.is_empty():
		push_warning("BattleTestRunner: no BattleObject.tscn found — skipping %d object spawns" % scenario.object_specs.size())

	_turn_queue.setup(player_units, enemy_units)
	BattleManager.call_deferred("start_battle", player_units, enemy_units)	

# =============================================================================
# GRID / WORLD
# =============================================================================

# converts a grid cell (Vector3i) to a world position using the correct elevation layer
func grid_to_world(cell: Vector3i) -> Vector2:
	#fetch BattleTileData from cell vector
	var tile = _battle_grid.get_tile(cell)
	if tile == null:
		return Vector2.ZERO
	var layer: TileMapLayer = _terrain_layers.get_node("Elevation" + str(cell.z))
	var local_pos = layer.map_to_local(Vector2i(cell.x, cell.y))
	var world_pos = layer.to_global(local_pos)
	world_pos.y -= Constants.TILE_ORIGIN_OFFSET
	return world_pos

# converts a world position (Vector2) to a grid cell (Vector3i) using the highest elevation layer
func world_to_grid(world_pos: Vector2, elevation: int) -> Vector3i:
	world_pos.y += Constants.TILE_ORIGIN_OFFSET
	var layer: TileMapLayer = _terrain_layers.get_node(
		"Elevation" + str(elevation)
	)
	var local_pos := layer.to_local(world_pos)
	var cell_2d := layer.local_to_map(local_pos)
	
	var cell := Vector3i(
		cell_2d.x,
		cell_2d.y,
		elevation
	)
	var tile = _battle_grid.get_tile(cell)
	if tile == null:
		return Vector3i.ZERO

	return cell

# finds the first valid reachable Vector3i cell matching the clicked Vector2i position
# returns null if no valid cell is found — always reads from _turn_context, so the check
# is always against whichever unit is actually active, never a stale reference
func _find_reachable_cell(cell: Vector2i):
	if _turn_context == null:
		return null
	var tile = _battle_grid.get_tile_at_highest_elevation(cell)
	if tile == null:
		return null
	var target = Vector3i(cell.x, cell.y, tile.elevation)
	var targeting = BattleManager.current_state == BattleManager.BattleState.TARGET_SELECT
	if _turn_context.is_reachable(target, targeting):
		return target
	return null

# =============================================================================
# INPUT HANDLERS
# =============================================================================

# moves the cursor to the hovered cell. CharacterInfo is NOT updated here — it
# reacts to the cursor's own cell_changed signal (see _on_cursor_cell_changed),
# so a frozen cursor (which we stop moving below) keeps the panel pinned.
func _on_cell_hovered(cell: Vector2i) -> void:
	if _battle_grid == null:
		return
	var tile = _battle_grid.get_tile_at_highest_elevation(cell)
	if tile == null:
		if _cursor.is_visible and not _cursor.get_is_frozen():
			_cursor.hide_cursor()
		return
	var destination = grid_to_world(Vector3i(cell.x, cell.y, tile.elevation))
	if not _cursor.is_visible:
		_cursor.show_cursor()

	if not _cursor.get_is_frozen():
		_cursor.move_cursor(destination, Vector3i(cell.x, cell.y, tile.elevation))

# reflects whatever the cursor is now pointing at in the CharacterInfo panel.
# get_actor_at checks both units AND objects (unit takes priority if both
# somehow occupy the same cell) — using get_unit_at here would silently never
# show CharacterInfo for objects at all.
func _on_cursor_cell_changed(cell: Vector3i) -> void:
	var actor: BattleActor = _battle_grid.get_actor_at(cell)
	if actor != null:
		_character_info.set_hovered_actor(actor)
	else:
		_character_info.clear_hovered_actor()

	if BattleManager.current_state == BattleManager.BattleState.MOVE_SELECT:
		_update_move_preview(cell)

# Draws the route the unit would take to the hovered cell — through any placed
# waypoints — so the player sees exactly which tiles (and hazards) they'll cross
# before committing. Only reachable cells preview; anything else clears it.
func _update_move_preview(cell: Vector3i) -> void:
	_last_move_preview_cell = cell
	if not _turn_context.reachable_move_cells.has(cell):
		_tile_visual_manager.clear_move_path()
		return
	var plan = _move_planner.plan_to(cell)
	var path_cells: Array = []
	for step in plan["steps"]:
		path_cells.append(step.cell)
	_tile_visual_manager.show_move_path(path_cells, plan["waypoint_cells"], grid_to_world, plan["valid"])

# routes cell selection to the appropriate BattleManager action based on current state
func _on_cell_selected(cell: Vector2i) -> void:
	match BattleManager.current_state:
		BattleManager.BattleState.MOVE_SELECT:
			var target = _find_reachable_cell(cell)
			if target != null:
				# commit the FULL planned route (through any waypoints), not a fresh
				# shortest path — but only if it fits range; an over-budget detour is
				# ignored so the click can't silently drop waypoints or overspend
				var plan = _move_planner.plan_to(target)
				if plan["valid"]:
					_previous_cell = _turn_context.unit.grid_position
					_pending_move_steps = plan["steps"]
					await BattleManager.confirm_move(target)
		BattleManager.BattleState.TARGET_SELECT:
			var target = _find_reachable_cell(cell)
			if target != null:
				await BattleManager.confirm_target(target)
		_:
			var tile: BattleTileData = _battle_grid.get_tile_at_highest_elevation(cell)
			if tile == null:
				return
			var full_cell := Vector3i(cell.x, cell.y, tile.elevation)
			var has_actor := tile.unit_ref != null or tile.object_ref != null
			# every click re-evaluates the clicked cell, overriding any prior
			# freeze: land on an actor -> (re)freeze the cursor there; land on
			# empty ground -> release the freeze so the cursor follows the mouse
			# again. Moving the cursor first covers the case where an existing
			# freeze had it parked on a different cell.
			_cursor.unfreeze_cursor()
			_cursor.move_cursor(grid_to_world(full_cell), full_cell)
			if has_actor:
				_cursor.freeze_cursor()

# Shift+click during move selection: add the clicked reachable cell as a route
# waypoint (if the detour through it still fits range), then redraw the preview.
func _on_waypoint_placed(cell: Vector2i) -> void:
	# waypoints are a move-selection concept only; a shift-click anywhere else
	# should behave like a plain click rather than being silently swallowed
	if BattleManager.current_state != BattleManager.BattleState.MOVE_SELECT:
		_on_cell_selected(cell)
		return
	var target = _find_reachable_cell(cell)
	if target == null:
		return
	if _move_planner.add_waypoint(target):
		# redraw against wherever the cursor currently points so the newly forced
		# detour is reflected immediately, without waiting for the next mouse move
		_update_move_preview(_last_move_preview_cell)

# cancels the current sub-selection and returns to ACTION_SELECT
func _on_cell_cancelled() -> void:
	# in move selection, cancel first peels back the most recent waypoint (undo)
	# and only falls through to leaving the move once no waypoints remain
	if BattleManager.current_state == BattleManager.BattleState.MOVE_SELECT and _move_planner.pop_waypoint():
		_update_move_preview(_last_move_preview_cell)
		return
	_cursor.unfreeze_cursor()
	# a move that struck a hazard along the way is locked in — no take-backs once
	# the unit has already paid the price for the path it chose
	if (BattleManager.current_state == BattleManager.BattleState.ACTION_SELECT and
		_previous_cell != Vector3i(999,999,999)) and \
		not _turn_context.unit.data.has_acted and \
		not _unit_mover.struck_hazard:
		_battle_grid.move_actor(_turn_context.unit, _turn_context.unit.grid_position, _previous_cell)
		_turn_context.unit.global_position = grid_to_world(_previous_cell)
		_battle_camera.pan_to(grid_to_world(_previous_cell))
		_turn_context.unit.reset_move()
		_battle_hud.refresh()
		_previous_cell = Vector3i(999, 999, 999)
	else:
		BattleManager.cancel_action()

# =============================================================================
# BATTLE STATE
# =============================================================================

# responds to battle state changes by updating highlights and clearing stale query data
func _on_battle_state_changed(new_state: BattleManager.BattleState) -> void:
	match new_state:
		BattleManager.BattleState.MOVE_SELECT:
			# move range was already computed atomically in _turn_context when the unit
			# became active — just display it, never recompute against a separate variable
			_tile_visual_manager.show_move_range(_turn_context.reachable_move_cells, grid_to_world)
			# arm the route planner for this move; waypoints start empty (fast/default
			# path is the plain shortest route until the player shift-clicks detours)
			_move_planner.begin(_pathfinder, _turn_context.unit, _turn_context.unit.grid_position, _turn_context.move_query)
			_last_move_preview_cell = Vector3i(999, 999, 999)
			await get_tree().create_timer(1).timeout
		BattleManager.BattleState.ACTION_SELECT:
			if not BattleManager.active_unit.is_alive():
				_turn_queue.start_next_turn()
			_move_planner.clear()
			_tile_visual_manager.clear()
			if _turn_context != null:
				_turn_context.clear_ability()
		BattleManager.BattleState.ABILITIES_SELECT:
			pass
		BattleManager.BattleState.TARGET_SELECT:
			_tile_visual_manager.show_move_range(_turn_context.reachable_target_cells, grid_to_world)
		BattleManager.BattleState.RESOLVING:
			_tile_visual_manager.clear()
			if _turn_context.unit.data.has_moved && _turn_context.unit.data.has_acted:
				_previous_cell = Vector3i(999,999,999)
		BattleManager.BattleState.TERRAIN_TURN:
			if _battle_grid.active_effect_cells.is_empty() and _battle_grid.active_effect_objects.is_empty():
				DebugLog.battle_state("terrain turn has nothing to tick — skipping straight to next turn")
				BattleManager.end_turn()
				return

			var processor = TerrainTurnProcessor.new()
			# the processor opens AND closes its own (lazy) cinematic sequence
			# via begin_batch/end_batch — no end_sequence() to balance here, or
			# the bars would fade out even on a turn that opened nothing.
			await processor.process_terrain_turn(_battle_grid, _unit_mover, _effect_executor, _cinematic_director)
			await _cinematic_director.wait_until_idle()
			await get_tree().create_timer(0.5).timeout
			BattleManager.end_turn()
		BattleManager.BattleState.BATTLE_END:
			BattleManager.reset()

# connects the new active unit's signals to the HUD and updates camera and turn state.
# this is the single authoritative point where "who's acting" is established for the scene —
# _turn_context is built here, atomically, from the same unit reference BattleManager just set
# as active_unit. No other function may assign _turn_context, so there is nowhere for a stale
# unit reference to leak in and desync from BattleManager.active_unit.
func _on_active_unit_changed(unit: Unit) -> void:
	_turn_context = TurnContext.for_unit(unit, _pathfinder)

	_battle_camera.pan_to(grid_to_world(unit.grid_position))
	#_previous_unit = unit
	_previous_cell = Vector3i(999,999,999)
# =============================================================================
# ABILITY / MOVEMENT EXECUTION
# =============================================================================

# stores the selected ability for use when TARGET_SELECT state is entered.
# guards against desync: if this ever fires for a unit other than _turn_context's own,
# that's a bug upstream — fail loudly here rather than silently computing a target range
# for the wrong unit (which is exactly how the original self-targeting bug slipped through).
func _on_ability_selected(unit: Unit, ability: AbilityData) -> void:
	if _turn_context == null or unit != _turn_context.unit:
		push_error("Ability selected for a unit that doesn't match the active turn context")
		return
	_turn_context.select_ability(ability, _pathfinder)

# kicks off unit movement animation via UnitMover using the turn context's move query.
# NOTE: no consume_move here — BattleManager.confirm_move owns turn-resource
# consumption; doing it in both places double-fired the move_consumed signal.
func _on_unit_moved(unit: Unit, to_cell: Vector3i) -> void:
	# prefer the route the player actually planned (through their waypoints);
	# fall back to a fresh shortest path for moves that set none (e.g. AI)
	var steps: Array[MovementStep] = _pending_move_steps
	if steps.is_empty():
		steps = _pathfinder.get_movement_path(unit.grid_position, to_cell, _turn_context.move_query, unit)
	_pending_move_steps = []
	var seq := MovementSequence.create(steps)
	_unit_mover.start_sequence(unit, seq)

# kicks off ability execution via UnitAbilityExecutor.
# NOTE: no consume_ability here — see note on _on_unit_moved.
func _on_unit_ability(caster: Unit, target_cell: Vector3i, ability: AbilityData, camera: BattleCamera) -> void:
	_unit_ability_executor.execute_ability(caster, target_cell, ability, camera, _action_resolver, _effect_executor)

# =============================================================================
# DEBUG
# =============================================================================

# prints all grid cells with their elevation, terrain type, and walkability
func _debug_print_grid() -> void:
	for cell in _battle_grid.get_all_cells():
		var tile = _battle_grid.get_tile(cell)
		print(cell, " → elevation: ", tile.elevation, " terrain: ", tile.terrain_type, " is_walkable: ", str(tile.is_walkable))
