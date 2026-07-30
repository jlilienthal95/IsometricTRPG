class_name CinematicDirector
extends Node

var _ui: BattleUI = null
var _camera: BattleCamera = null
var _get_world_pos: Callable

var _sequence_depth: int = 0
var _beat_queue: Array[Callable] = []
var _pumping: bool = false

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
	_sequence_depth += 1
	print("[CD:begin_sequence] depth now: ", _sequence_depth, " focus: ", focus)
	if _sequence_depth == 1:
		print("[CD:begin_sequence] fading bars in + zooming")
		await _ui.fade_bars_in()
		await _camera.zoom_in()
	if focus is Node2D:
		print("[CD:begin_sequence] panning to actor: ", focus.name)
		await _camera.pan_to(focus.global_position)
	elif focus is Vector2:
		print("[CD:begin_sequence] panning to world pos: ", focus)
		await _camera.pan_to(focus)
	print("[CD:begin_sequence] complete — camera settled")

func end_sequence() -> void:
	_sequence_depth = maxi(0, _sequence_depth - 1)
	print("[CD:end_sequence] depth now: ", _sequence_depth)
	if _sequence_depth == 0:
		print("[CD:end_sequence] zooming out + fading bars")
		await _camera.zoom_reset()
		await _ui.fade_bars_out()
		print("[CD:end_sequence] complete")

func is_sequence_active() -> bool:
	return _sequence_depth > 0

func wait_until_idle() -> void:
	print("[CD:wait_until_idle] called — pumping: ", _pumping, " queue: ", _beat_queue.size())
	while _pumping or not _beat_queue.is_empty():
		await get_tree().process_frame
	print("[CD:wait_until_idle] idle confirmed")

# =============================================================================
# TURN CHANGE
# =============================================================================

func _on_turn_changed(_unit) -> void:
	print("[CD:turn_changed] clearing ", _beat_queue.size(), " stale beats — sequence_depth: ", _sequence_depth)
	_beat_queue.clear()

# =============================================================================
# REACTIVE BEATS
# =============================================================================

func _on_hp_changed(actor, amount: int, new_hp: int) -> void:
	print("[CD:hp_changed] actor: ", actor.data.name if actor else "null", " amount: ", amount, " new_hp: ", new_hp, " sequence_depth_AT_ENQUEUE: ", _sequence_depth)
	if not is_instance_valid(actor):
		print("[CD:hp_changed] skipped — invalid actor")
		return
	if actor is Unit and actor.data.is_dead:
		print("[CD:hp_changed] skipped — actor dead")
		return
	var depth_at_enqueue = _sequence_depth
	_enqueue(func():
		print("[CD:hp_beat] executing — depth_at_enqueue: ", depth_at_enqueue, " current_depth: ", _sequence_depth, " actor: ", actor.data.name if is_instance_valid(actor) else "FREED")
		if not is_instance_valid(actor):
			print("[CD:hp_beat] skipped — actor freed before execution")
			return
		if actor is Unit and actor.data.is_dead:
			print("[CD:hp_beat] skipped — actor dead at execution time")
			return
		if _sequence_depth > 0:
			print("[CD:hp_beat] inside sequence — shaking only")
			await _camera.play_shake()
		else:
			print("[CD:hp_beat] outside sequence — self-wrapping")
			await begin_sequence(actor)
			await _camera.play_shake()
			await get_tree().create_timer(0.5).timeout
			await end_sequence()
		print("[CD:hp_beat] complete")
	)

func _on_effect_applied(target, effect_id: EffectId.Id) -> void:
	var effect_name = EffectId.Id.keys()[effect_id]
	print("[CD:effect_applied] target: ", target, " effect: ", effect_name, " is_tile: ", target is BattleTileData, " sequence_depth: ", _sequence_depth)
	if not target is BattleTileData:
		print("[CD:effect_applied] skipped — not a tile")
		return
	var tile := target as BattleTileData
	var world_pos = _get_world_pos.call(tile.cell)
	var depth_at_enqueue = _sequence_depth
	var unit_on_tile_at_enqueue = tile.unit_ref	# captured at enqueue time — unit may move before beat executes
	_enqueue(func():
		print("[CD:effect_applied_beat] executing — effect: ", effect_name, " cell: ", tile.cell, " depth_at_enqueue: ", depth_at_enqueue, " current_depth: ", _sequence_depth, " unit_on_tile_at_enqueue: ", unit_on_tile_at_enqueue != null, " unit_on_tile_now: ", tile.unit_ref != null)
		if depth_at_enqueue > 0:
			print("[CD:effect_applied_beat] skipped — inside sequence")
			return
		if unit_on_tile_at_enqueue != null and is_instance_valid(unit_on_tile_at_enqueue):
			# fire spread to a unit's tile — pan to the unit so the player sees
			# who is about to be in danger, even though the tile beat is redundant
			print("[CD:effect_applied_beat] unit on tile at enqueue — panning to unit: ", unit_on_tile_at_enqueue.data.name)
			await begin_sequence(unit_on_tile_at_enqueue)
			await get_tree().create_timer(0.3).timeout
			await end_sequence()
		else:
			# empty tile caught fire — pan to the tile itself
			print("[CD:effect_applied_beat] empty tile — panning to tile: ", tile.cell)
			await begin_sequence(world_pos)
			await get_tree().create_timer(0.3).timeout
			await end_sequence()
		print("[CD:effect_applied_beat] complete")
	)

func _on_effect_removed(target, effect_id: EffectId.Id, reason: int) -> void:
	var effect_name = EffectId.Id.keys()[effect_id]
	print("[CD:effect_removed] target: ", target, " effect: ", effect_name, " reason: ", reason, " sequence_depth: ", _sequence_depth)
	if not target is BattleTileData:
		print("[CD:effect_removed] skipped — not a tile")
		return
	var tile := target as BattleTileData
	var world_pos = _get_world_pos.call(tile.cell)
	print("[CD:effect_removed] cell: ", tile.cell, " world_pos: ", world_pos)
	var depth_at_enqueue = _sequence_depth
	_enqueue(func():
		print("[CD:effect_removed_beat] executing — effect: ", effect_name, " cell: ", tile.cell, " depth_at_enqueue: ", depth_at_enqueue, " current_depth: ", _sequence_depth, " unit_on_tile: ", tile.unit_ref != null)
		if depth_at_enqueue > 0:
			print("[CD:effect_removed_beat] skipped — inside sequence")
			return
		if tile.unit_ref != null:
			print("[CD:effect_removed_beat] skipped — unit on tile covers it")
			return
		print("[CD:effect_removed_beat] opening self-sequence for tile: ", tile.cell)
		await begin_sequence(world_pos)
		await get_tree().create_timer(0.3).timeout
		await end_sequence()
		print("[CD:effect_removed_beat] complete")
	)
	
func _on_tile_effect_applied(target: BattleTileData, effect_id: EffectId.Id, play_visual: Callable) -> void:
	var effect_name = EffectId.Id.keys()[effect_id]
	print("[CD:tile_effect_applied] effect: ", effect_name, " cell: ", target.cell, " sequence_depth: ", _sequence_depth)
	var world_pos = _get_world_pos.call(target.cell)
	var unit_on_tile = target.unit_ref
	var depth_at_enqueue = _sequence_depth
	_enqueue(func():
		print("[CD:tile_effect_beat] executing — effect: ", effect_name, " cell: ", target.cell, " depth: ", _sequence_depth)
		if depth_at_enqueue > 0:
			print("[CD:tile_effect_beat] inside sequence — playing visual only")
			await play_visual.call()
			return
		var focus = unit_on_tile if unit_on_tile != null and is_instance_valid(unit_on_tile) else world_pos
		print("[CD:tile_effect_beat] opening sequence — focus: ", focus)
		await begin_sequence(focus)
		print("[CD:tile_effect_beat] playing visual inside sequence")
		await play_visual.call()
		await get_tree().create_timer(0.3).timeout
		await end_sequence()
		print("[CD:tile_effect_beat] complete")
	)

func _on_tile_effect_removed(target: BattleTileData, effect_id: EffectId.Id, reason: int, play_visual: Callable) -> void:
	var effect_name = EffectId.Id.keys()[effect_id]
	print("[CD:tile_effect_removed] effect: ", effect_name, " cell: ", target.cell, " reason: ", reason, " sequence_depth: ", _sequence_depth)
	var world_pos = _get_world_pos.call(target.cell)
	var unit_on_tile = target.unit_ref
	var depth_at_enqueue = _sequence_depth
	_enqueue(func():
		print("[CD:tile_effect_removed_beat] executing — effect: ", effect_name, " cell: ", target.cell, " depth_at_enqueue: ", depth_at_enqueue, " current_depth: ", _sequence_depth)
		if depth_at_enqueue > 0:
			print("[CD:tile_effect_removed_beat] inside sequence — playing visual only")
			await play_visual.call()
			return
		var focus = unit_on_tile if unit_on_tile != null and is_instance_valid(unit_on_tile) else world_pos
		print("[CD:tile_effect_removed_beat] opening sequence — focus: ", focus)
		await begin_sequence(focus)
		await play_visual.call()
		await get_tree().create_timer(0.3).timeout
		await end_sequence()
		print("[CD:tile_effect_removed_beat] complete")
	)
	
# =============================================================================
# QUEUE
# =============================================================================

func _enqueue(beat: Callable) -> void:
	print("[CD:enqueue] queue size before: ", _beat_queue.size(), " pumping: ", _pumping)
	_beat_queue.append(beat)
	_pump()

func _pump() -> void:
	if _pumping:
		print("[CD:pump] already running — queued: ", _beat_queue.size())
		return
	_pumping = true
	print("[CD:pump] started — beats: ", _beat_queue.size())
	while not _beat_queue.is_empty():
		var beat: Callable = _beat_queue.pop_front()
		print("[CD:pump] executing beat — remaining after pop: ", _beat_queue.size())
		await beat.call()
	print("[CD:pump] finished")
	_pumping = false
