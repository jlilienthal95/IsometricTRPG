class_name Unit
extends Node2D

@onready var unit_sprite: AnimatedSprite2D = $VisualRoot/UnitSprite
@onready var unit_shadow: Sprite2D = $VisualRoot/UnitSpriteShadow

signal move_consumed
signal action_consumed

var data: UnitData = null
var grid_position: Vector3i = Vector3i.ZERO

func _ready() -> void:
	play_idle();

func setup(unit_data: UnitData, start_position: Vector3i) -> void:
	data = unit_data
	grid_position = start_position
	update_z_index()
	_apply_job_sprite()
	play_idle()
	
func _apply_job_sprite() -> void:
	var job = JobRegistry.get_job(data.job_id)
	if job == null:
		return
	if job.sprite_frames != null:
		unit_sprite.sprite_frames = job.sprite_frames
		$VisualRoot.position = job.sprite_offset ## This was previously commented out, and had an error
		unit_shadow.position = job.shadow_offset
		unit_shadow.scale = job.shadow_scale
		unit_shadow.z_index = unit_sprite.z_index - 1
#animations
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

#appearance
func set_facing(flip: bool) -> void:
	$VisualRoot.scale.x = -1 if flip else 1
	
func update_z_index() -> void:
	var base_z = grid_position.z
	
	# check tiles in the "behind" directions (lower x, lower y in your layout)
	var behind_cells = [
		Vector2i(grid_position.x - 2, grid_position.y),
		Vector2i(grid_position.x, grid_position.y - 2),
		Vector2i(grid_position.x - 2, grid_position.y - 2),
	]
	
	var highest_behind = base_z
	for xy in behind_cells:
		var tile = get_parent().get_node("BattleGrid").get_tile_at_highest_elevation(xy)
		if tile != null and tile.elevation > highest_behind:
			highest_behind = tile.elevation
	
	z_index = highest_behind + 1
	
#state
func consume_move() -> void:
	data.has_moved = true
	emit_signal("move_consumed")

func consume_action() -> void:
	data.has_acted = true
	emit_signal("action_consumed")

func reset_turn() -> void:
	data.has_moved = false
	data.has_acted = false

func can_move() -> bool:
	return not data.has_moved

func can_act() -> bool:
	return not data.has_acted
