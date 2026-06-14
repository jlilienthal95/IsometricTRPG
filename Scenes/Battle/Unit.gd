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
		$VisualRoot/UnitSprite.position += job.sprite_offset ## This was previously commented out, and had an error
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
	var job = JobRegistry.get_job(data.job_id)
	
func update_z_index() -> void:
	var battle_grid = get_parent().get_node("BattleGrid")
	var occluders = battle_grid.occlusion_map.get(grid_position, [])
	
	if occluders.is_empty():
		z_index = 14 * 4 + 3
	else:
		# use lowest elevation occluder so unit draws behind all occluders
		var lowest_occluder = occluders[occluders.size() - 1]
		z_index = lowest_occluder.z * 4 - 1
			
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
