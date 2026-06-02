class_name Unit
extends Node2D

@onready var unit_sprite: AnimatedSprite2D = $UnitSprite

var data: UnitData = null
var grid_position: Vector2i = Vector2i.ZERO

func _ready() -> void:
	print("ready");
	play_idle();

func setup(unit_data: UnitData, start_position: Vector2i) -> void:
	data = unit_data
	grid_position = start_position
	play_idle()

func play_idle() -> void:
	unit_sprite.play("idle")

func play_attack() -> void:
	unit_sprite.play("attack")
	# return to idle when attack animation finishes
	await unit_sprite.animation_finished
	play_idle()
