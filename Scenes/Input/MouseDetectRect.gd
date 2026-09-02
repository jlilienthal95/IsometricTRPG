class_name MouseDetectRect
extends Control

# Free camera panning for the player. Originally this dragged the camera when
# the mouse was parked in a screen corner (found distracting in practice); it
# now maps the same "nudge the camera each frame" idea to WASD instead.
#
# Manual panning is only allowed while the player is actually in control of
# their own turn. During any scripted/automated sequence — enemy or AI turns,
# ability/effect resolution, the terrain turn, setup, battle end — this yields:
# BattleManager.current_state and the active unit's affiliation are the gate, so
# a scripted pan_to/follow always owns the camera during those moments and WASD
# can't fight it (see BattleCamera.pan_manual).

# panning speed in world pixels per second
const PAN_SPEED: float = 320.0
# how quickly the pan velocity eases toward its target (higher = snappier).
# Frame-rate independent via exp smoothing below — this gives a soft ramp up
# when a key is pressed and a short glide to a stop when it's released.
const PAN_SMOOTHING: float = 8.0

# states in which the player is NOT free to drive the camera
const INVALID_STATES: Array[BattleManager.BattleState] = [
	BattleManager.BattleState.RESOLVING,
	BattleManager.BattleState.TERRAIN_TURN,
	BattleManager.BattleState.SETUP,
	BattleManager.BattleState.BATTLE_END,
]

var _camera: BattleCamera = null
var _input_handler: InputHandler = null
var _director: CinematicDirector = null
# smoothed pan velocity (world px/sec), eased toward the input direction so
# panning ramps in and glides out instead of snapping on/off
var _pan_velocity: Vector2 = Vector2.ZERO
# true while a C-key recenter pan is in progress. Suppresses manual panning so
# it doesn't stomp the recenter tween every frame; cleared the moment the
# player deliberately grabs control again (a fresh pan-key press) or lets go.
var _centering: bool = false

const PAN_ACTIONS: Array[StringName] = [
	&"camera_pan_up", &"camera_pan_down", &"camera_pan_left", &"camera_pan_right",
]

func setup(camera: BattleCamera, input_handler: InputHandler, director: CinematicDirector) -> void:
	_camera = camera
	_input_handler = input_handler
	_director = director
	_input_handler.center_camera_called.connect(_on_center_camera_called)

func _process(delta: float) -> void:
	if not _player_controls_camera():
		# scripted sequence owns the camera — drop any residual velocity so we
		# don't lurch when control returns to the player
		_pan_velocity = Vector2.ZERO
		return

	var dir := Vector2.ZERO
	if Input.is_action_pressed("camera_pan_up"):
		dir.y -= 1.0
	if Input.is_action_pressed("camera_pan_down"):
		dir.y += 1.0
	if Input.is_action_pressed("camera_pan_left"):
		dir.x -= 1.0
	if Input.is_action_pressed("camera_pan_right"):
		dir.x += 1.0

	# a recenter (C) is running — leave its tween alone until the player either
	# lets go of every pan key or freshly presses one to reclaim control
	if _centering:
		if dir == Vector2.ZERO or _pan_key_just_pressed():
			_centering = false
		else:
			return

	# ease the velocity toward the target (zero when no key is held, so it
	# glides to a stop). exp form keeps the smoothing frame-rate independent.
	var target_velocity := dir.normalized() * PAN_SPEED if dir != Vector2.ZERO else Vector2.ZERO
	_pan_velocity = _pan_velocity.lerp(target_velocity, 1.0 - exp(-PAN_SMOOTHING * delta))

	if _pan_velocity.length() < 0.5:
		_pan_velocity = Vector2.ZERO
		return

	_camera.pan_manual(_pan_velocity * delta)

# true only when a human player is mid-turn and free to move the camera. Any
# scripted sequence (enemy/AI turns are non-PLAYER; resolution states are in
# INVALID_STATES) fails this check, ceding camera control back to the script.
func _player_controls_camera() -> bool:
	if _camera == null:
		return false
	if INVALID_STATES.has(BattleManager.current_state):
		return false
	# a cinematic can play (and own the camera) even in an otherwise-valid state
	# — e.g. a self-wrapping damage/effect beat during ACTION_SELECT
	if _director != null and _director.is_busy():
		return false
	var unit = BattleManager.active_unit
	if unit == null or not unit is Unit:
		return false
	return unit.data.type == BattleActorData.Type.PLAYER

func _pan_key_just_pressed() -> bool:
	for action in PAN_ACTIONS:
		if Input.is_action_just_pressed(action):
			return true
	return false

func _on_center_camera_called() -> void:
	if not _player_controls_camera():
		return
	# interrupt any in-progress manual pan and hand the camera to the recenter
	# tween; _process won't fight it while _centering is set
	_pan_velocity = Vector2.ZERO
	_centering = true
	_camera.pan_to(BattleManager.active_unit.global_position)
