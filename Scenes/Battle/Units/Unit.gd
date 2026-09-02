class_name Unit
extends BattleActor

# =============================================================================
# Unit — a player/enemy/neutral combatant.
#
# Adds everything BattleActor doesn't know about: MP, turn state (move/act),
# and the full attack/cast/hit/death animation set. HP mutation, effect
# storage, damage-number popups, and z-index are inherited unchanged.
#
# Follows BattleActor's three-layer split: DATA / ANIM / UNION. Every play_*
# function here is pure presentation — none of them touch `data`. See the
# note above the ANIMATIONS section for how the death-pose guard works now
# that play_death() no longer sets is_dead itself.
# =============================================================================

@onready var unit_visual_root: Node2D = $VisualRoot
@onready var unit_sprite: AnimatedSprite2D = $VisualRoot/UnitSprite
@onready var unit_shadow: Sprite2D = $VisualRoot/UnitSpriteShadow
@onready var unit_animation_player: AnimationPlayer = $UnitAnimation
@onready var gff_player: GFFPlayer = $VisualRoot/GFFPlayer

signal move_consumed
signal ability_consumed
signal ability_impact

const WATER_SHADER = preload("res://Assets/Shaders/Unit_Water.gdshader")

var _default_material: Material = null


# =============================================================================
# SETUP
# =============================================================================

func _ready() -> void:
	unit_sprite.material = unit_sprite.material.duplicate()
	_default_material = unit_sprite.material
	if data != null and is_alive():
		play_idle()

# initializes the unit with its data resource and places it at the given grid
# position. Sprite/frames/shadow are NOT touched here — they're already baked
# into whichever scene battle_scene._spawn_unit() instantiated.
func setup(unit_data: UnitData, start_position: Vector3i) -> void:
	data = unit_data
	grid_position = start_position
	_grid_ref = get_parent().get_node_or_null("BattleGrid")
	update_z_index()
	play_idle()


# =============================================================================
# DATA — MP and turn state. Units only; objects have neither.
# =============================================================================

func spend_mp(amount: int) -> void:
	if data.is_dead:
		return
	data.current_mp = maxi(0, data.current_mp - amount)

func restore_mp(amount: int) -> void:
	if data.is_dead:
		return
	data.current_mp = mini(data.max_mp, data.current_mp + amount)

func consume_move() -> void:
	if data.is_dead:
		return
	data.has_moved = true
	emit_signal("move_consumed")

func consume_ability() -> void:
	if data.is_dead:
		return
	data.has_acted = true
	emit_signal("ability_consumed")

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
# ANIM — pure presentation, no data mutation anywhere in this section.
#
# The old `if data.is_dead: return` guard is gone from the one-shot clips
# (death, hit, attack, cast): those are only ever played on deliberate
# request, so the caller's intent wins — that's what makes it possible to
# play a death animation without killing the unit, and to kill a unit
# without playing one.
#
# The guard is KEPT on the ambient locomotion clips (idle/walk/jump) because
# those get driven automatically by UnitMover and the turn loop, which would
# otherwise stomp a corpse's death pose back to standing. That's presentation
# logic reading state, not data mutation, so it stays on this side of the line.
# =============================================================================

func play_idle() -> void:
	if data.is_dead:
		return
	unit_sprite.play("idle")

func play_movement(type: MovementSequence.MovementType) -> void:
	if data.is_dead:
		return
	match type:
		MovementSequence.MovementType.WALK: unit_sprite.play("walk")
		MovementSequence.MovementType.FLY: unit_sprite.play("fly")
		MovementSequence.MovementType.SLIP: play_slip()
		MovementSequence.MovementType.WIND: unit_sprite.play("wind")
		MovementSequence.MovementType.MAGNET: unit_sprite.play("magnet")
		_: unit_sprite.play("walk")

func play_jump() -> void:
	if data.is_dead:
		return
	unit_sprite.play("jump")

func play_attack() -> void:
	unit_sprite.play("attack")
	await unit_animation_player.animation_finished

# stronger attack variant, played instead of "attack" when the blow is lethal
# (chosen by UnitAbilityExecutor, which only picks it when it exists)
func play_attack_finisher() -> void:
	unit_sprite.play("attack_finisher")
	await unit_animation_player.animation_finished

func play_cast_spell() -> void:
	unit_sprite.play("cast_spell")

# true if the unit's sprite actually has the named animation — lets callers
# fall back gracefully instead of playing a missing clip
func has_sprite_animation(anim_name: String) -> bool:
	return unit_sprite.sprite_frames != null and unit_sprite.sprite_frames.has_animation(anim_name)

func play_slip() -> void:
	await play_death()

# plays the appropriate cast/attack animation, waits the ability's authored
# impact delay, then fires ability_impact so the resolver applies the effect
# in sync with the animation rather than on a hardcoded timer
func play_attack_animation(cast_impact_delay: float, unit_anim: AbilityData.UnitAnimation) -> void:
	match unit_anim:
		AbilityData.UnitAnimation.CAST_SPELL: play_cast_spell()
		AbilityData.UnitAnimation.ATTACK: play_attack()
		AbilityData.UnitAnimation.ATTACK_FINISHER: play_attack_finisher()
		_: play_attack()  # default fallback
	await get_tree().create_timer(cast_impact_delay / 1000).timeout
	notify_ability_impact()

# plays the hit reaction and returns to idle. play_idle()'s own is_dead guard
# handles the case where something killed the unit while this was in flight.
func play_hit() -> void:
	unit_sprite.play("hit")
	await unit_sprite.animation_finished
	play_idle()

func play_missed() -> void:
	unit_animation_player.play("missed")
	await unit_animation_player.animation_finished
	play_idle()

# plays the death animation and leaves the unit in its final pose. Does NOT
# mark the unit dead — BattleActor._defeat() calls mark_dead() before this.
func play_death() -> void:
	unit_sprite.play("death")
	await unit_sprite.animation_finished

func play_recover() -> void:
	unit_sprite.play_backwards("death")
	await unit_sprite.animation_finished

func _play_hit_feedback() -> void:
	gff_player.play("flash_and_particles")
	_flash_red()

func _flash_red() -> void:
	if unit_sprite.material == null:
		return
	var tween = create_tween()
	tween.tween_method(func(v): unit_sprite.material.set_shader_parameter("flash_amount", v), 0.0, 1.0, 0.05)
	await tween.finished
	tween = create_tween()
	tween.tween_method(func(v): unit_sprite.material.set_shader_parameter("flash_amount", v), 1.0, 0.0, 0.15)
	await tween.finished

# spawns and plays a status-effect visual (e.g. "poisoned" sparkle) attached
# to this unit, fading it in and layering it just behind the unit's sprite
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

func _get_damage_anim_player() -> AnimationPlayer:
	return unit_animation_player

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

func on_terrain_changed(terrain_type: int) -> void:
	if terrain_type == BattleTileData.TerrainType.WATER:
		_apply_water_effect()
	else:
		_remove_water_effect()

func _apply_water_effect() -> void:
	unit_shadow.visible = false

func _remove_water_effect() -> void:
	unit_shadow.visible = true

func set_effect_alpha(alpha: float) -> void:
	var tween = create_tween()
	tween.tween_property(unit_visual_root, "modulate:a", alpha, 0.2)
	await tween.finished
