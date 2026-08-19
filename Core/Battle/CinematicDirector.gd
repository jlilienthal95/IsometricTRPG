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
	_sequence_depth += 1
	if _sequence_depth == 1:
		await _ui.fade_bars_in()
		await _camera.zoom_in()
	if not focus == null and focus is Node2D:
		await _camera.pan_to(focus.global_position)
	elif focus is Vector2:
		await _camera.pan_to(focus)

func end_sequence() -> void:
	_sequence_depth = maxi(0, _sequence_depth - 1)
	if _sequence_depth == 0:
		await _camera.zoom_reset()
		await _ui.fade_bars_out()

func is_sequence_active() -> bool:
	return _sequence_depth > 0

func wait_until_idle() -> void:
	while _pumping or not _beat_queue.is_empty():
		await get_tree().process_frame

# =============================================================================
# TURN CHANGE
# =============================================================================

func _on_turn_changed(_unit) -> void:
	_beat_queue.clear()

# =============================================================================
# REACTIVE BEATS
# =============================================================================

func _on_hp_changed(actor, amount: int, new_hp: int) -> void:
	if not is_instance_valid(actor):
		return
	if actor is Unit and actor.data.is_dead:
		return
	var depth_at_enqueue = _sequence_depth
	_enqueue(func():
		if not is_instance_valid(actor):
			return
		if actor is Unit and actor.data.is_dead:
			return
		if _sequence_depth > 0:
			await _camera.play_shake()
		else:
			await begin_sequence(actor)
			await _camera.play_shake()
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
		print("[CD:tile_effect_beat] executing — effect: ", effect_name, " cell: ", target.cell, " depth: ", _sequence_depth)
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
		print("[CD:tile_effect_beat] complete")
	)

func _on_tile_effect_removed(target: BattleTileData, effect_id: EffectId.Id, reason: int, play_visual: Callable) -> void:
	var effect_name = EffectId.Id.keys()[effect_id]
	var world_pos = _get_world_pos.call(target.cell)
	var unit_on_tile = target.unit_ref
	var depth_at_enqueue = _sequence_depth
	_enqueue(func():
		print("[CD:tile_effect_removed_beat] executing — effect: ", effect_name, " cell: ", target.cell, " depth: ", _sequence_depth)
		var focus = unit_on_tile if unit_on_tile != null and is_instance_valid(unit_on_tile) else world_pos
		print("[CD:tile_effect_removed_beat] focus determined: ", focus)
		if _sequence_depth == 0:
			print("[CD:tile_effect_removed_beat] self-wrapping sequence")
			await begin_sequence(focus)
			print("[CD:tile_effect_removed_beat] sequence begun")
			await play_visual.call()
			print("[CD:tile_effect_removed_beat] visual complete")
			await get_tree().create_timer(DELAY_SHORT).timeout
			await end_sequence()
		else:
			print("[CD:tile_effect_removed_beat] inside sequence — panning")
			if focus is Node2D:
				await _camera.pan_to(focus.global_position)
			elif focus is Vector2:
				await _camera.pan_to(focus)
			print("[CD:tile_effect_removed_beat] pan complete")
			await get_tree().create_timer(DELAY_SHORT).timeout
			print("[CD:tile_effect_removed_beat] calling play_visual")
			await play_visual.call()
			print("[CD:tile_effect_removed_beat] play_visual complete")
		print("[CD:tile_effect_removed_beat] complete")
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
		var beat: Callable = _beat_queue.pop_front()
		await beat.call()
	_pumping = false


func get_sequence_depth() -> int:
	return _sequence_depth
