class_name CinematicBars
extends Control

@onready var black_bar_top: ColorRect = $BlackBarTop
@onready var black_bar_bottom: ColorRect = $BlackBarBottom

func _ready() -> void:
	#$BlackBarTop.position.y = get_viewport_rect().size.y - $BlackBarBottom.size.y
	black_bar_bottom.position.y = get_viewport_rect().size.y - black_bar_bottom.size.y

func fade_in() -> void:
	print("bars appear")
	z_index = 4096
	#black_bar_rect.global_position = Vector2(0,0)
	#black_bar_rect_2.global_position = Vector2(0,528)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(0.0, 0.0, 0.0, 1.0), 0.3)
	await tween.finished
	#black_bar_rect.modulate = Color(0,0,0,1)
	#black_bar_rect_2.modulate = Color(0,0,0,1) 

func fade_out() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(0.0, 0.0, 0.0, 0.0), 0.3)
	z_index = -4096
	black_bar_top.global_position = Vector2(0,0)
	black_bar_bottom.position.y = get_viewport_rect().size.y - black_bar_bottom.size.y
	#black_bar_rect.modulate = Color(0,0,0,0)
	#black_bar_rect_2.modulate = Color(0,0,0,0) 
