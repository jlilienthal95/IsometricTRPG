class_name CinematicDirector
extends Node

# Owns ALL battle cinematics: bars in, zoom, focus, impact shake, teardown.
# The same presentation applies to any damage/heal/stat-change source:
# abilities, terrain-turn effect ticks, object collisions, future counters.
#
# Reactivity contract: this node listens to BattleEvents.hp_changed /
# stat_changed. Nothing needs to call it to get impact presentation —
# mutating HP anywhere automatically produces the cinematic beat.
#
# Coroutine-safety design:
# - Event handlers NEVER await. They enqueue a beat and return, so emitters
#   (Unit.apply_damage etc.) are never blocked by presentation.
# - A single pump coroutine drains the queue serially. Two damage events in
#   the same frame produce two sequential beats, never two concurrent tweens
#   fighting over camera zoom.
# - Explicit sequences (ability execution) are ref-counted via _sequence_depth.
#   While a sequence is active, beats are just impact shakes inside it; when
#   no sequence is active (terrain-turn fire tick), a beat self-wraps in a
#   full bars+zoom sequence.
# - end_sequence never waits on the pump internally (the pump itself calls it
#   for auto-sequences — waiting there would deadlock). Callers that need
#   "all beats done" await wait_until_idle() BEFORE calling end_sequence.

var _ui: BattleUI = null
var _camera: BattleCamera = null

var _sequence_depth: int = 0
var _beat_queue: Array[Callable] = []
var _pumping: bool = false

func setup(ui: BattleUI, camera: BattleCamera) -> void:
	_ui = ui
	_camera = camera
	BattleEvents.hp_changed.connect(_on_hp_changed)
	BattleEvents.stat_changed.connect(_on_stat_changed)
	BattleEvents.effect_applied.connect(_on_effect_applied)
	BattleEvents.effect_removed.connect(_on_effect_removed)

# =============================================================================
# EXPLICIT SEQUENCES — used by UnitAbilityExecutor around ability execution
# =============================================================================

# begins (or joins) a cinematic sequence focused on the given actor.
# nested calls are ref-counted; only the outermost pair animates bars/zoom.
func begin_sequence(focus: Node2D) -> void:
	_sequence_depth += 1
	if _sequence_depth == 1:
		await _ui.fade_bars_in()
		await _camera.zoom_in()
	if focus != null:
		await _camera.pan_to(focus.global_position)

# ends one level of sequence. Await wait_until_idle() first if you need all
# queued impact beats to land inside the sequence.
func end_sequence() -> void:
	_sequence_depth = maxi(0, _sequence_depth - 1)
	if _sequence_depth == 0:
		await _camera.zoom_reset()
		await _ui.fade_bars_out()

func is_sequence_active() -> bool:
	return _sequence_depth > 0

# resolves once every queued beat has been processed
func wait_until_idle() -> void:
	while _pumping or not _beat_queue.is_empty():
		await get_tree().process_frame

# =============================================================================
# REACTIVE BEATS
# =============================================================================

func _on_hp_changed(actor, _amount: int, _new_hp: int) -> void:
	_enqueue(func(): await _impact_beat(actor))

func _on_stat_changed(actor, _stat_name: String, _old_value, _new_value) -> void:
	_enqueue(func(): await _impact_beat(actor))
	
func _on_effect_applied(target, effect_id: EffectId.Id) -> void:
	print("effect applied beat queued. Target: ", target)
	_enqueue(func(): await _impact_beat(target))

func _on_effect_removed(target, effect_id: EffectId.Id, reason: int) -> void:
	_enqueue(func(): await _impact_beat(target))

func _enqueue(beat: Callable) -> void:
	_beat_queue.append(beat)
	_pump()

# serial queue drain — the ONLY place beats execute, guaranteeing no two
# cinematic coroutines ever run concurrently
func _pump() -> void:
	if _pumping:
		return
	_pumping = true
	while not _beat_queue.is_empty():
		var beat: Callable = _beat_queue.pop_front()
		await beat.call()
	_pumping = false

func _impact_beat(actor) -> void:
	if not actor is Unit:
		return
	if not is_instance_valid(actor):
		return
	if _sequence_depth > 0:
		# inside an ability sequence — camera is already framed; just punctuate
		await _camera.play_shake()
	else:
		# out-of-turn damage (terrain tick, collision) — self-contained sequence
		# TODO: fix random shakes and zooms
		await begin_sequence(actor)
		#await _camera.play_shake()
		#await get_tree().create_timer(0.8).timeout
		await end_sequence()
