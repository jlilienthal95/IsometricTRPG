class_name Unit
extends Node2D

@onready var unit_visual_root: Node2D = $VisualRoot
@onready var unit_sprite: AnimatedSprite2D = $VisualRoot/UnitSprite
@onready var unit_shadow: Sprite2D = $VisualRoot/UnitSpriteShadow
@onready var unit_animation_player: AnimationPlayer = $UnitAnimation

signal move_consumed
signal action_consumed
signal ability_impact

var data: UnitData = null
var grid_position: Vector3i = Vector3i.ZERO

func _ready() -> void:
	if data != null:
		play_idle()

# initializes the unit with its data resource and places it at the given grid position
func setup(unit_data: UnitData, start_position: Vector3i) -> void:
	data = unit_data
	grid_position = start_position
	update_z_index()
	_apply_job_sprite()
	play_idle()

# applies the sprite frames and visual offsets defined by the unit's current job
func _apply_job_sprite() -> void:
	var job = JobRegistry.get_job(data.job_id)
	if job == null:
		return
	if job.sprite_frames != null:
		unit_sprite.sprite_frames = job.sprite_frames
		unit_sprite.position += job.sprite_offset
		unit_shadow.scale = job.shadow_scale
		unit_shadow.z_index = unit_sprite.z_index - 1

# =============================================================================
# ANIMATIONS
# =============================================================================

func play_idle() -> void:
	if data.is_dead:
		return
	unit_sprite.play("idle")

func play_walk() -> void:
	if data.is_dead:
		return
	unit_sprite.play("walk")

func play_jump() -> void:
	if data.is_dead:
		return
	unit_sprite.play("jump")

func play_attack() -> void:
	if data.is_dead:
		return
	unit_sprite.play("attack")
	await unit_animation_player.animation_finished

func play_attack_animation(impact_delay: float) -> void:
	if not data.is_dead:
		unit_sprite.play("attack")
		await get_tree().create_timer(impact_delay * .001).timeout
		notify_ability_impact()
		await unit_sprite.animation_finished
		play_idle()

# plays the hit reaction animation and returns to idle when finished
func play_hit() -> void:
	if data.is_dead:
		return
	unit_sprite.play("hit")
	await unit_sprite.animation_finished
	play_idle()
	
func play_missed() -> void:
	print("playing missed")
	unit_animation_player.play("missed")
	await unit_animation_player.animation_finished
	play_idle()

# plays the death animation and marks the unit as dead — does not return to idle
func play_death() -> void:
	if not data.is_dead:
		data.is_dead = true
		unit_sprite.play("death")
		await unit_sprite.animation_finished
	return

# =============================================================================
# APPEARANCE
# =============================================================================

# flips the unit horizontally to face the direction of movement
func set_facing(flip: bool) -> void:
	unit_visual_root.scale.x = -1 if flip else 1

# updates the unit's z_index based on the precomputed occlusion map
# units with no occluders draw above all terrain; occluded units draw below their lowest occluder
func update_z_index() -> void:
	var battle_grid = get_parent().get_node("BattleGrid")
	var occluders = battle_grid.occlusion_map.get(grid_position, [])
	if occluders.is_empty():
		z_index = 14 * 4 + 3
	else:
		var lowest_occluder = occluders[occluders.size() - 1]
		z_index = lowest_occluder.z * 4 - 1

# =============================================================================
# TURN STATE
# =============================================================================

# marks the unit's move as used and notifies listeners
func consume_move() -> void:
	if data.is_dead:
		return
	data.has_moved = true
	emit_signal("move_consumed")

# marks the unit's action as used and notifies listeners
func consume_action() -> void:
	if data.is_dead:
		return
	data.has_acted = true
	emit_signal("action_consumed")

# resets move and action availability at the start of the unit's turn
func reset_turn() -> void:
	if data.is_dead:
		return
	data.has_moved = false
	data.has_acted = false

func reset_move() -> void:
	data.has_moved = false
	
func can_move() -> bool:
	return not data.has_moved and not data.is_dead
	

func can_act() -> bool:
	return not data.has_acted and not data.is_dead

# =============================================================================
# BATTLE
# =============================================================================

# adjusts HP by the given amount — positive heals, negative damages when is_damage is false
func adjust_hp(amount: int, is_damage: bool = true) -> void:
	if data.is_dead:
		return
	if is_damage:
		data.current_hp = max(0, data.current_hp - amount)
	else:
		data.current_hp += amount

# adjusts MP by the given amount — positive restores, negative drains when is_damage is false
func adjust_mp(amount: int, is_damage: bool = true) -> void:
	if data.is_dead:
		return
	if is_damage:
		data.current_mp = max(0, data.current_mp - amount)
	else:
		data.current_mp += amount
		
func take_hit() -> void:
	if data.current_hp == 0:
		await play_death()
	else:
		await play_hit()

# applies a status effect for the given number of turns, overwriting any existing duration
func apply_status(effect: StatusEffect.StatusEffect, turns: int) -> void:
	if data.is_dead:
		return
	data.active_status_effects[effect] = turns

# fires the ability_impact signal — called by AnimationPlayer at the impact frame
func notify_ability_impact() -> void:
	emit_signal("ability_impact")
