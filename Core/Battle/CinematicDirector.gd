class_name CinematicDirector
extends Node

const DELAY_LONG: float = 0.5
const DELAY_MED: float = 0.3
const DELAY_SHORT: float = 0.1

var _ui: BattleUI = null
var _camera: BattleCamera = null
var _get_world_pos: Callable

var _sequence_depth: int = 0
var _beat_queue: Array[Callable] = []
var _pumping: bool = false

# --- deferred terrain batch ---
# The terrain turn wants a SINGLE cinematic sequence wrapping every beat it
# produces — but only if it produces any. A round where the only terrain
# effects are static (permanent FROZEN/SLIPPERY sitting there, adding and
# removing nothing) must not zoom the camera at all. So instead of opening a
# sequence up front, the processor arms a batch; the sequence is opened lazily
# the first time an actual beat runs, and end_batch() closes it only if it was
# opened.
var _batch_armed: bool = false
var _batch_opened: bool = false
var _batch_focus = null

func setup(ui: BattleUI, camera: BattleCamera, get_world_pos: Callable) -> void:
	_ui = ui
	_camera = camera
	_get_world_pos = get_world_pos
	BattleEvents.hp_changed.connect(_on_hp_changed)
	BattleEvents.tile_effect_applied.connect(_on_tile_effect_applied)
	BattleEvents.tile_effect_removed.connect(_on_tile_effect_removed)
	BattleManager.active_unit_changed.connect(_on_turn_changed)

# =============================================================================
# SEQUENCES
# =============================================================================

func begin_sequence(focus = null) -> void:
	_ui.fade_out()
	if not focus == null and focus is Node2D:
		await _camera.pan_to(focus.global_position)
	elif focus is Vector2:
		await _camera.pan_to(focus)
	_sequence_depth += 1
	if _sequence_depth == 1:
		await _ui.fade_bars_in()
		await _camera.zoom_in()

func begin_sequence_at_cell(cell: Vector3i) -> void:
	await begin_sequence(_get_world_pos.call(cell))

func end_sequence() -> void:
	_sequence_depth = maxi(0, _sequence_depth - 1)
	if _sequence_depth == 0:
		await _camera.zoom_reset()
		await _ui.fade_bars_out()

func is_sequence_active() -> bool:
	return _sequence_depth > 0

# True whenever the director owns the camera: a sequence is open, a beat is
# playing, or beats are still queued (or a batch is armed and could open one).
# Manual camera control must yield while this holds, or the player can pan away
# mid-beat and cancel the sequence (leaving the letterbox bars stuck on).
func is_busy() -> bool:
	return _sequence_depth > 0 or _pumping or not _beat_queue.is_empty() or _batch_armed

# Arms a lazy terrain-turn sequence. No camera work happens here — the sequence
# is only actually opened (see _pump) if a beat runs while it's armed. `focus`
# is where the camera pans when/if it opens (a Node2D or Vector2, or null to
# just zoom in place and let the beats pan themselves).
func begin_batch(focus = null) -> void:
	_batch_armed = true
	_batch_opened = false
	_batch_focus = focus

# Closes the terrain-turn sequence, but only if a beat ever opened it. If the
# terrain turn produced no beats, this is a no-op and the camera never moved.
func end_batch() -> void:
	_batch_armed = false
	_batch_focus = null
	if _batch_opened:
		_batch_opened = false
		await end_sequence()

func wait_until_idle() -> void:
	while _pumping or not _beat_queue.is_empty():
		await get_tree().process_frame

# =============================================================================
# TURN CHANGE
# =============================================================================

func _on_turn_changed(_unit) -> void:
	_beat_queue.clear()
	# a new turn cancels any armed-but-never-opened batch so it can't leak
	# across turns (an opened one is closed by its own end_batch before here)
	if not _batch_opened:
		_batch_armed = false
		_batch_focus = null


# =============================================================================
# REACTIVE BEATS
# =============================================================================

func _on_hp_changed(actor, amount: int, new_hp: int) -> void:
	if not is_instance_valid(actor):
		return
	if actor is Unit and actor.data.is_dead:
		return
	_enqueue(func():
		if not is_instance_valid(actor):
			return
		if actor is Unit and actor.data.is_dead:
			return
		# The impact shake is now owned by BattleActor.apply_damage (fired
		# synchronously with the blow). The director only frames a STANDALONE hp
		# change — one landing outside any active sequence/batch — so it still
		# gets a moment on camera; mid-sequence hits need nothing here.
		if _sequence_depth == 0:
			await begin_sequence(actor)
			await get_tree().create_timer(DELAY_LONG).timeout
			await end_sequence()
	)

func _on_effect_applied(target, effect_id: EffectId.Id) -> void:
	var effect_name = EffectId.Id.keys()[effect_id]
	if not target is BattleTileData:
		return
	var tile := target as BattleTileData
	var world_pos = _get_world_pos.call(tile.cell)
	var depth_at_enqueue = _sequence_depth
	var unit_on_tile_at_enqueue = tile.unit_ref	# captured at enqueue time — unit may move before beat executes
	_enqueue(func():
		if depth_at_enqueue > 0:
			return
		if unit_on_tile_at_enqueue != null and is_instance_valid(unit_on_tile_at_enqueue):
			# fire spread to a unit's tile — pan to the unit so the player sees
			# who is about to be in danger, even though the tile beat is redundant
			await begin_sequence(unit_on_tile_at_enqueue)
			await get_tree().create_timer(DELAY_MED).timeout
			await end_sequence()
		else:
			# empty tile caught fire — pan to the tile itself
			await begin_sequence(world_pos)
			await get_tree().create_timer(DELAY_MED).timeout
			await end_sequence()
	)

func _on_effect_removed(target, effect_id: EffectId.Id, reason: int) -> void:
	var effect_name = EffectId.Id.keys()[effect_id]
	if not target is BattleTileData:
		return
	var tile := target as BattleTileData
	var world_pos = _get_world_pos.call(tile.cell)
	var depth_at_enqueue = _sequence_depth
	_enqueue(func():
		if depth_at_enqueue > 0:
			return
		if tile.unit_ref != null:
			return
		await begin_sequence(world_pos)
		await get_tree().create_timer(DELAY_SHORT).timeout
		await end_sequence()
	)
	
func _on_tile_effect_applied(target: BattleTileData, effect_id: EffectId.Id, play_visual: Callable) -> void:
	var effect_name = EffectId.Id.keys()[effect_id]
	var world_pos = _get_world_pos.call(target.cell)
	var unit_on_tile = target.unit_ref
	_enqueue(func():
		DebugLog.effects("tile_effect_beat: %s at %s (depth %d)" % [effect_name, target.cell, _sequence_depth])
		var focus = unit_on_tile if unit_on_tile != null and is_instance_valid(unit_on_tile) else world_pos
		if _sequence_depth == 0:
			# outside terrain turn sequence — self wrap
			await begin_sequence(focus)
			await play_visual.call()
			await get_tree().create_timer(DELAY_SHORT).timeout
			await end_sequence()
		else:
			# inside terrain turn sequence — just pan and play
			if focus is Node2D:
				await _camera.pan_to(focus.global_position)
			elif focus is Vector2:
				await _camera.pan_to(focus)
			await get_tree().create_timer(0.1).timeout
			await play_visual.call()
	)

func _on_tile_effect_removed(target: BattleTileData, effect_id: EffectId.Id, reason: int, play_visual: Callable) -> void:
	var effect_name = EffectId.Id.keys()[effect_id]
	var world_pos = _get_world_pos.call(target.cell)
	var unit_on_tile = target.unit_ref
	_enqueue(func():
		DebugLog.effects("tile_effect_removed_beat: %s at %s (depth %d)" % [effect_name, target.cell, _sequence_depth])
		var focus = unit_on_tile if unit_on_tile != null and is_instance_valid(unit_on_tile) else world_pos
		if _sequence_depth == 0:
			# outside terrain turn sequence — self wrap
			await begin_sequence(focus)
			await play_visual.call()
			await get_tree().create_timer(DELAY_SHORT).timeout
			await end_sequence()
		else:
			# inside terrain turn sequence — just pan and play
			if focus is Node2D:
				await _camera.pan_to(focus.global_position)
			elif focus is Vector2:
				await _camera.pan_to(focus)
			await get_tree().create_timer(DELAY_SHORT).timeout
			await play_visual.call()
	)
	
# =============================================================================
# QUEUE
# =============================================================================

func _enqueue(beat: Callable) -> void:
	_beat_queue.append(beat)
	_pump()

func _pump() -> void:
	if _pumping:
		return
	_pumping = true
	while not _beat_queue.is_empty():
		# A beat is about to run. If a terrain batch is armed but not yet
		# opened, open the wrapping sequence now — so beats fold into one
		# zoom, while a beat-free terrain turn never opens anything at all.
		if _batch_armed and not _batch_opened and _sequence_depth == 0:
			_batch_opened = true
			await begin_sequence(_batch_focus)
		var beat: Callable = _beat_queue.pop_front()
		await beat.call()
	_pumping = false


func get_sequence_depth() -> int:
	return _sequence_depth
