class_name BattleCamera
extends Camera2D

@export var pan_speed: float = 0.3	# seconds to pan to target
@export var follow_speed: float = 6.0
@onready var cam_animation_player: AnimationPlayer = $AnimationPlayer

var _follow_target: Node2D = null

func _ready() -> void:
	make_current()	# make this the active camera

func _process(delta: float) -> void:
	if _follow_target != null:
		position = position.lerp(_follow_target.global_position, follow_speed * delta)

func follow(node: Node2D) -> void:
	await pan_to(node.global_position)
	_follow_target = node

func stop_following(active_unit: Unit) -> void:
	_follow_target = active_unit

func pan_to(target_pos: Vector2) -> void:
	var tween = create_tween()
	tween.tween_property(self, "position", target_pos, pan_speed)
	await tween.finished

func play_shake() -> void:
	cam_animation_player.play("shake")
	await cam_animation_player.animation_finished
	
func snap_to(target_pos: Vector2) -> void:
	position = target_pos
	
func zoom_in()-> void:
	var tween = create_tween()
	tween.tween_property(self, "zoom", Vector2(1.5,1.5), 0.3)
	await tween.finished

func zoom_reset() -> void:
	var tween = create_tween()
	tween.tween_property(self, "zoom", Vector2(1,1), 0.3)
	await tween.finished
	
