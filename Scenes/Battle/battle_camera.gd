class_name BattleCamera
extends Camera2D

@export var pan_speed: float = 0.3	# seconds to pan to target

func _ready() -> void:
	make_current()	# make this the active camera

func pan_to(target_pos: Vector2) -> void:
	var tween = create_tween()
	tween.tween_property(self, "position", target_pos, pan_speed)

func snap_to(target_pos: Vector2) -> void:
	position = target_pos
