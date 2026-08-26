class_name MouseDetectRect
extends Control

const CAMERA_SPEED: float = 0.4
const ARC_RADIUS: float = 200.0  # tune this — size of each corner arc zone
const DEADZONE_X: float = 0.75  # fraction of screen width — tune this
const DEADZONE_Y: float = 0.75  # fraction of screen height — tune this
const INVALID_STATES: Array[BattleManager.BattleState] = [BattleManager.BattleState.RESOLVING, BattleManager.BattleState.TERRAIN_TURN, BattleManager.BattleState.SETUP, BattleManager.BattleState.BATTLE_END]

var _camera: BattleCamera = null
var _input_handler: InputHandler = null
var _mouse_tracker: Node2D = null
var _in_zone: bool = false

func setup(camera: BattleCamera, input_handler: InputHandler) -> void:
	_camera = camera
	_input_handler = input_handler
	
	_input_handler.center_camera_called.connect(_on_center_camera_called)
	
#func _process(_delta: float) -> void:
	##var hovered = get_viewport().gui_get_hovered_control()
	##if hovered != null:
		##print("hovered control: ", hovered.name)
	#if _camera == null or _input_handler == null:
		#return
	#var mouse = get_viewport().get_mouse_position()
	#var screen = get_viewport_rect().size
	#var in_zone = not INVALID_STATES.has(BattleManager.current_state) and \
		#BattleManager.active_unit.data.is_player_controlled and \
		#not _is_ui_blocking() and \
		#not _is_in_deadzone(mouse, screen) and \
		#_is_in_arc_zone(mouse, screen)
#
	#if in_zone and not _in_zone:
		#_in_zone = true
		#_mouse_tracker = Node2D.new()
		#_mouse_tracker.global_position = _input_handler.get_mouse_global_pos()
		#add_child(_mouse_tracker)
#
	#elif not in_zone and _in_zone:
		#_in_zone = false
		#if _mouse_tracker != null:
			#_mouse_tracker.queue_free()
			#_mouse_tracker = null
		#await get_tree().create_timer(0.18).timeout
		#_camera.stop_following_instant()
#
	#if _in_zone and _mouse_tracker != null:
		#var screen_center = screen * 0.5
		#var normalized = (mouse - screen_center) / screen_center
		#var pan_distance = 200.0
		#_mouse_tracker.global_position = _camera.global_position + normalized * pan_distance
		#_camera.follow(_mouse_tracker, CAMERA_SPEED)
	
func _is_ui_blocking() -> bool:
	var hovered = get_viewport().gui_get_hovered_control()
	return hovered != null and hovered != self

func _is_in_arc_zone(mouse: Vector2, screen: Vector2) -> bool:
	var corners = [
		Vector2(0, 0),                    # top-left
		Vector2(screen.x, 0),             # top-right
		Vector2(0, screen.y),             # bottom-left
		Vector2(screen.x, screen.y),      # bottom-right
	]
	for corner in corners:
		if mouse.distance_to(corner) < ARC_RADIUS:
			return true
	return false
	
func _is_in_deadzone(mouse: Vector2, screen: Vector2) -> bool:
	var center = screen * 0.5
	var normalized_x = (mouse.x - center.x) / (screen.x * DEADZONE_X * 0.5)
	var normalized_y = (mouse.y - center.y) / (screen.y * DEADZONE_Y * 0.5)
	# ellipse equation: x² + y² < 1 means inside the ellipse
	return (normalized_x * normalized_x) + (normalized_y * normalized_y) < 1.0
	
func _on_center_camera_called() -> void:
	if not INVALID_STATES.has(BattleManager.BattleState):
		_camera.pan_to(BattleManager.active_unit.global_position)
