class_name Unit
extends BattleActor

@onready var unit_visual_root: Node2D = $VisualRoot
@onready var unit_sprite: AnimatedSprite2D = $VisualRoot/UnitSprite
@onready var unit_shadow: Sprite2D = $VisualRoot/UnitSpriteShadow
@onready var unit_animation_player: AnimationPlayer = $UnitAnimation
@onready var damage_count: Control = $DamageCount/DamageLabel

signal move_consumed
signal ability_consumed
signal ability_impact

const WATER_SHADER = preload("res://Assets/Shaders/Unit_Water.gdshader")

#var data: UnitData = null
#var grid_position: Vector3i = Vector3i.ZERO
var _default_material: Material = null

func _ready() -> void:
	_default_material = unit_sprite.material
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
	if data.job == null:
		return
	if data.job.sprite_frames != null:
		unit_sprite.sprite_frames = data.job.sprite_frames
		unit_sprite.position += data.job.sprite_offset
		unit_shadow.scale = data.job.shadow_scale
		unit_shadow.z_index = unit_sprite.z_index - 1

# =============================================================================
# HP / MP — the single mutation points for unit health.
# All damage and healing flows through apply_damage / apply_heal, which:
#   1. mutate data.current_hp (the single source of truth)
#   2. announce the change on BattleEvents (UI panels and the CinematicDirector
#      react on their own — no caller has to remember to trigger them)
#   3. play the unit's own local feedback (damage number, flash, hit/death anim)
# Callers must never write data.current_hp directly.
# =============================================================================

func apply_damage(amount: int) -> void:
	if data.is_dead:
		return
	data.current_hp = maxi(0, data.current_hp - amount)
	BattleEvents.hp_changed.emit(self, -amount, data.current_hp)
	play_damage_count(amount)
	_flash_red()
	if data.current_hp == 0:
		await play_death()
		BattleEvents.actor_defeated.emit(self)
	else:
		await play_hit()

func apply_heal(amount: int) -> void:
	if data.is_dead:
		return
	data.current_hp = mini(data.max_hp, data.current_hp + amount)
	BattleEvents.hp_changed.emit(self, amount, data.current_hp)
	play_damage_count(-amount)

# spends MP for an ability cost — no event, self-inflicted costs get no cinematic
func spend_mp(amount: int) -> void:
	if data.is_dead:
		return
	data.current_mp = maxi(0, data.current_mp - amount)

func restore_mp(amount: int) -> void:
	if data.is_dead:
		return
	data.current_mp = mini(data.max_mp, data.current_mp + amount)

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
func consume_ability() -> void:
	if data.is_dead:
		return
	data.has_acted = true
	emit_signal("ability_consumed")

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
# EFFECTS
# =============================================================================

func has_effect(effect_id: EffectId.Id) -> bool:
	return data.has_effect(effect_id)

func get_effect(effect_id: EffectId.Id) -> EffectInstance:
	return data.get_effect(effect_id)

func apply_effect(effect_id: EffectId.Id, rounds: int = -1) -> void:
	if data.is_dead:
		return
	data.apply_effect(effect_id, rounds)

func remove_effect(effect_id: EffectId.Id) -> void:
	data.remove_effect(effect_id)

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

func play_cast_spell() -> void:
	if data.is_dead:
		return
	unit_sprite.play("cast_spell")

func play_attack_animation(cast_impact_delay: float, unit_anim: AbilityData.UnitAnimation) -> void:
	if data.is_dead:
		return
	match unit_anim:
		AbilityData.UnitAnimation.SPELL: play_cast_spell()
		AbilityData.UnitAnimation.ATTACK: play_attack()
		_: play_attack()  # default fallback
	await get_tree().create_timer(cast_impact_delay / 1000).timeout
	print("arrow fires")
	notify_ability_impact()

# plays the hit reaction animation and returns to idle when finished
func play_hit() -> void:
	if data.is_dead:
		return
	unit_sprite.play("hit")
	await unit_sprite.animation_finished
	play_idle()

func play_missed() -> void:
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

func play_damage_count(damage: int) -> void:
	if damage < 0:
		var heal_color: Color = Color(0.0, 0.74, 0.0, 1.0)
		damage_count.add_theme_color_override("font_color", heal_color)
	else:
		var damage_color: Color = Color("ff003b")
		damage_count.add_theme_color_override("font_color", damage_color)
	damage_count.text = str(absi(damage))
	unit_animation_player.play("damage_count")

func _flash_red() -> void:
	if unit_sprite.material == null:
		return
	var tween = create_tween()
	tween.tween_method(func(v): unit_sprite.material.set_shader_parameter("flash_amount", v), 0.0, 1.0, 0.05)
	await tween.finished
	tween = create_tween()
	tween.tween_method(func(v): unit_sprite.material.set_shader_parameter("flash_amount", v), 1.0, 0.0, 0.15)
	await tween.finished

func play_effect_apply_animation(effect_id: EffectId.Id) -> void:
	var scene_file: PackedScene = EffectSceneRegistry.get_scene(effect_id)
	if not scene_file:
		return
	var scene: Node2D = scene_file.instantiate()
	unit_visual_root.add_child(scene)
	scene.modulate.a = 0
	scene.play(str(EffectId.Id.keys()[effect_id]).to_lower() + "_unit")
	scene.global_position = global_position
	scene.global_position.y -= Constants.UNIT_EFFECT_OFFSET
	var tween = create_tween()
	tween.tween_property(scene, "modulate:a", 1, 0.2)
	await tween.finished
	scene.z_as_relative = true
	scene.z_index = unit_visual_root.z_index - 1

# fires the ability_impact signal — called by AnimationPlayer at the impact frame
func notify_ability_impact() -> void:
	emit_signal("ability_impact")

# =============================================================================
# APPEARANCE
# =============================================================================

# sets facing direction based on movement from one cell to another
# accounts for elevation differences in the isometric coordinate system
func set_facing_toward(from_cell: Vector3i, to_cell: Vector3i) -> void:
	var elevation_diff = to_cell.z - from_cell.z

	# for same elevation, compare XY directly
	if elevation_diff == 0:
		var should_flip = from_cell.x > to_cell.x or from_cell.y < to_cell.y
		unit_visual_root.scale.x = -1 if should_flip else 1
		return

	# for elevation changes, adjust target XY using the elevation neighbor formula
	# to get the "flat equivalent" position we're actually moving toward
	var n = abs(elevation_diff)
	var dir = sign(elevation_diff)
	var adjusted_x = to_cell.x + (n + 1) * dir
	var adjusted_y = to_cell.y + n * dir

	var should_flip = from_cell.x > adjusted_x or from_cell.y < adjusted_y
	unit_visual_root.scale.x = -1 if should_flip else 1

# flips the unit horizontally to face the direction of movement
func set_facing(flip: bool) -> void:
	unit_visual_root.scale.x = -1 if flip else 1

# updates the unit's z_index based on the precomputed occlusion map
# units with no occluders draw above all terrain; occluded units draw below their lowest occluder
func update_z_index() -> void:
	var battle_grid = get_parent().get_node_or_null("BattleGrid")
	if battle_grid == null:
		return
	var occluders = battle_grid.occlusion_map.get(grid_position, [])
	if occluders.is_empty():
		z_index = 14 * 4 + 3
	else:
		var lowest_occluder = occluders[occluders.size() - 1]
		z_index = lowest_occluder.z * 4 - 1

func on_terrain_changed(terrain_type: int) -> void:
	if terrain_type == BattleTileData.TerrainType.WATER:
		_apply_water_effect()
	else:
		_remove_water_effect()

func _apply_water_effect() -> void:
	unit_shadow.visible = false

func _remove_water_effect() -> void:
	unit_shadow.visible = true
	unit_sprite.material = _default_material

func set_effect_alpha(alpha: float) -> void:
	var tween = create_tween()
	tween.tween_property(unit_visual_root, "modulate:a", alpha, 0.2)
	await tween.finished
