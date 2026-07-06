extends Node2D

@onready var _ability_sprite: AnimatedSprite2D = $AbilitySprite

func play(effect_name: String) -> void:
	_ability_sprite.play(effect_name)
	await _ability_sprite.animation_finished
	queue_free()
