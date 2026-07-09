class_name ProgressBarScene
extends ProgressBar

@onready var timer: Timer = $Timer
@onready var damage_bar: ProgressBar = $DamageBar

func setup(current: int, maximum: int) -> void:
	max_value = maximum
	damage_bar.max_value = maximum
	value = current
	damage_bar.value = current

func set_scene_value(new_value: int) -> void:
	var prev_value = value
	value = min(max_value, new_value)
	if value < prev_value:
		timer.start()
	else:
		damage_bar.value = new_value

func _on_timer_timeout() -> void:
	var difference: int = abs(int(damage_bar.value) - value)
	var tween = create_tween()
	tween.tween_property(damage_bar, "value", value, (difference * 0.1))
	# await the tween's finished SIGNAL — awaiting the tweener object itself
	# returns immediately and silently skips the wait
	await tween.finished
