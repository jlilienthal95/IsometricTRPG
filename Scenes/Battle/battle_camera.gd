class_name BattleCamera
extends Camera2D

#signal camera_settled
#signal zoom_settled

@export var pan_speed: float = 0.3       # default seconds to pan to target
@export var follow_speed: float = 10.0   # follow re-pan interval reference — see follow()
@onready var cam_animation_player: AnimationPlayer = $AnimationPlayer

var _cursor: Node2D = null
var _follow_target: Node2D = null
var _following: bool = false

# owned tweens — one authority per animated property. Any call that wants to
# move position/zoom kills whatever tween currently owns that property first,
# so two movement commands can never fight over the same property on the
# same frame. This replaces the old _process-based follow, which had no way
# to yield priority to pan_to/zoom_for_projectile and silently fought them.
var _position_tween: Tween = null
var _zoom_tween: Tween = null

func _ready() -> void:
	make_current()

func setup(cursor: Node2D) -> void:
	_cursor = cursor

# =============================================================================
# POSITION
# =============================================================================

# pans to a fixed world position. Cancels any in-progress pan OR follow —
# whichever was last driving position, this call takes ownership.
func pan_to(target_pos: Vector2, duration: float = pan_speed) -> void:
	stop_following()
	if _position_tween != null and _position_tween.is_valid():
		_position_tween.kill()
	_position_tween = create_tween()
	_position_tween.tween_property(self, "position", target_pos, duration)
	await _position_tween.finished
	#print("pan to emits camera_settled")
	#camera_settled.emit()

	
# continuously tracks a moving node (e.g. a flying projectile) by re-issuing
# short pans toward its current position every frame. This is now just a
# repeated, ownership-respecting pan rather than a separate _process authority —
# it goes through the same _position_tween slot, so nothing else can silently
# fight it, and pan_to()/snap_to() calling stop_following() first is always
# enough to take control back.
func follow(node: Node2D) -> void:
	stop_following()
	_follow_target = node
	_following = true
	while _following and is_instance_valid(node):
		if _position_tween != null and _position_tween.is_valid():
			_position_tween.kill()
		_position_tween = create_tween()
		_position_tween.tween_property(self, "position", node.global_position, 1.0 / follow_speed)
		await _position_tween.finished
		await get_tree().process_frame

func stop_following() -> void:
	_following = false
	_follow_target = null

func snap_to(target_pos: Vector2) -> void:
	stop_following()
	if _position_tween != null and _position_tween.is_valid():
		_position_tween.kill()
	position = target_pos
	#camera_settled.emit()

# =============================================================================
# ZOOM
# =============================================================================

func _tween_zoom(target: Vector2, duration: float) -> void:
	if _zoom_tween != null and _zoom_tween.is_valid():
		_zoom_tween.kill()
	_zoom_tween = create_tween()
	_zoom_tween.tween_property(self, "zoom", target, duration)
	await _zoom_tween.finished
	#zoom_settled.emit()

func zoom_in() -> void:
	await _tween_zoom(Vector2(1.5, 1.5), 0.3)

func zoom_for_projectile(distance: float, max_range: float) -> void:
	var zoom_amount = lerpf(1.5, 0.8, distance / max_range)
	await _tween_zoom(Vector2(zoom_amount, zoom_amount), 0.2)

func zoom_reset() -> void:
	await _tween_zoom(Vector2(1, 1), 0.3)

# =============================================================================
# EFFECTS
# =============================================================================

func play_shake() -> void:
	cam_animation_player.play("shake")
	await cam_animation_player.animation_finished
