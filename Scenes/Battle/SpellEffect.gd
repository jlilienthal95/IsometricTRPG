extends Node2D

@onready var spell_sprite: AnimatedSprite2D = $SpellSprite

func play(effect_name: String) -> void:
	spell_sprite.play(effect_name)
	await spell_sprite.animation_finished
	queue_free()
