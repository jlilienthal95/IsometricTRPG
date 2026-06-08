class_name Unit
extends Node2D

@onready var unit_sprite: AnimatedSprite2D = $UnitSprite

var data: UnitData = null
var grid_position: Vector3i = Vector3i.ZERO

func _ready() -> void:
	play_idle();

func setup(unit_data: UnitData, start_position: Vector3i) -> void:
	data = unit_data
	grid_position = start_position
	play_idle()
	
func _apply_job_sprite() -> void:
	var job = JobRegistry.get_job(data.job_id)
	if job != null and job.sprite_frames != null:
		unit_sprite.sprite_frames = job.sprite_frames

func play_idle() -> void:
	unit_sprite.play("idle")
	
func play_walk() -> void:
	unit_sprite.play("walk")

func play_jump() -> void:
	unit_sprite.play("jump")

func play_attack() -> void:
	unit_sprite.play("attack")
	# return to idle when attack animation finishes
	await unit_sprite.animation_finished
	play_idle()

func set_facing(flip: bool) -> void:
	unit_sprite.flip_h = flip
