class_name BattleCamera
extends Camera2D

@export var pan_speed: float = 0.3	# seconds to pan to target
@onready var cam_animation_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	make_current()	# make this the active camera

func pan_to(target_pos: Vector2) -> void:
	var tween = create_tween()
	tween.tween_property(self, "position", target_pos, pan_speed)

func play_shake() -> void:
	cam_animation_player.play("shake")
	
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
	
