class_name CinematicBars
extends Control

@onready var black_bar_top: ColorRect = $BlackBarTop
@onready var black_bar_bottom: ColorRect = $BlackBarBottom

func _ready() -> void:
	#$BlackBarTop.position.y = get_viewport_rect().size.y - $BlackBarBottom.size.y
	black_bar_bottom.position.y = get_viewport_rect().size.y - black_bar_bottom.size.y
#
func fade_in() -> void:
	z_index = 4096
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	await tween.finished

func fade_out() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	z_index = -4096
	black_bar_top.global_position = Vector2(0,0)
	black_bar_bottom.position.y = get_viewport_rect().size.y - black_bar_bottom.size.y
