class_name UnitAbilityExecutor
extends Node

signal ability_complete

var _grid: BattleGrid = null
var _unit_mover: UnitMover = null
var _is_executing: bool = false
var _caster: Unit = null
var _single_target = null	# Unit/BattleObject/BattleTile
var _multi_target: Array = []
var _ability: AbilityData = null
var _action_resolver: ActionResolver = null
var _effect_executor: EffectExecutor = null
var _camera: BattleCamera = null
var _director: CinematicDirector = null

# initializes the executor with references it needs every battle
func setup(grid: BattleGrid, mover: UnitMover, director: CinematicDirector) -> void:
	_grid = grid
	_unit_mover = mover
	_director = director

# begins ability execution — guards against concurrent executions
func execute_ability(caster: Unit, target_cell: Vector3i, ability: AbilityData, camera: BattleCamera, action_resolver: ActionResolver, effect_executor: EffectExecutor) -> void:
	if _is_executing:
		push_error("UnitAbilityExecutor: ability execution already in progress")
		return
	_is_executing = true
	_caster = caster
	_single_target = _grid.get_actor_at(target_cell)	# units and objects are both valid targets
	if _single_target == null:
		_single_target = _grid.get_tile(target_cell)
	_ability = ability
	_camera = camera
	_action_resolver = action_resolver
	_effect_executor = effect_executor

	# populate multi-target for AoE abilities
	# TODO: expand to all cells within ability AoE range when AoE is implemented
	_multi_target.clear()
	if ability.target_type == AbilityData.TargetType.AREA_ENEMY or \
	   ability.target_type == AbilityData.TargetType.AREA_ALLY or \
	   ability.target_type == AbilityData.TargetType.AREA_ALL:
		if _single_target != null:
			_multi_target.append(_single_target)

	_execute_sequence()

	# all cinematic presentation is owned by the director — this executor only
	# choreographs the ability itself (animations, projectiles, resolution)
func _execute_sequence() -> void:
	await _director.begin_sequence(_caster)
	_face_target()

	# 1. calculate all timing values up front — see AbilityTiming for the pure
	#    frame->seconds math (kept separate from this sequencing function so
	#    it's actually unit-testable; see Tests/AbilityTimingTests.gd)
	var caster_anim_fps = _get_caster_anim_fps()
	var ability_anim_fps = _get_ability_anim_fps()
	var caster_impact_delay = AbilityTiming.frame_to_seconds(_caster.data.get_caster_impact_frame(_ability.unit_animation), caster_anim_fps)
	var charge_delay = AbilityTiming.frame_to_seconds(_ability.charge_frame, ability_anim_fps)
	# impact_delay measured from effect anim start — subtract charge_delay
	var impact_delay = AbilityTiming.effect_impact_delay(_ability.impact_frame, ability_anim_fps, charge_delay)

	DebugLog.ability("fps: caster=%.1f ability=%.1f | delays: caster_impact=%.3f charge=%.3f impact=%.3f" % [caster_anim_fps, ability_anim_fps, caster_impact_delay, charge_delay, impact_delay])

	# 2. caster animation starts — await until caster impact frame
	_caster.play_attack_animation(caster_impact_delay, _ability.unit_animation)
	await get_tree().create_timer(caster_impact_delay / Engine.time_scale).timeout

	# 3. spawn visual at caster impact frame
	var effect = _launch_effect()
	var visual_state := {"done": false}
	if effect != null:
		effect.visual_complete.connect(func(): visual_state["done"] = true)
		DebugLog.ability("effect spawned: %s" % effect)
	else:
		DebugLog.ability("no effect to spawn for this ability")

	# 4. charge delay — visual exists but travel hasn't started yet
	if charge_delay > 0:
		await get_tree().create_timer(charge_delay / Engine.time_scale).timeout

	# 5. travel starts — fire and forget, runs independently of damage timing
	if effect != null:
		effect.travel(_get_target_world_pos(), _ability, _camera)

	# 6 & 7. for arrival-based abilities, wait for visual first then resolve
	if _ability.impact_on_arrival:
		if effect != null and not visual_state["done"]:
			await effect.visual_complete
		await resolve_ability(_action_resolver)
	else:
		# frame-based impact — resolve at impact_delay then wait for visual cleanup
		if impact_delay > 0:
			await get_tree().create_timer(impact_delay / Engine.time_scale).timeout
		await resolve_ability(_action_resolver)
		if effect != null and not visual_state["done"]:
			await effect.visual_complete

	# 8. clean up
	_caster.play_idle()
	await _director.wait_until_idle()
	await _director.end_sequence()
	_camera.pan_to(_caster.global_position)
	_is_executing = false
	emit_signal("ability_complete")
	_clear_context()
	
func _face_target() -> void:
	if _single_target == null:
		return
	var target_pos = _get_target_world_pos()
	_caster.set_facing(target_pos.x < _caster.global_position.x + 8.0)

func _get_target_world_pos() -> Vector2:
	if _single_target is BattleActor:
		return _single_target.global_position
	elif _single_target is BattleTileData:
		var pos = get_parent().grid_to_world(_single_target.cell)
		return pos
	return Vector2.ZERO

func _execute_effect() -> void:
	DebugLog.ability("executing effect")
	if _ability.animation_id == "":
		return
	if not AbilitySceneRegistry.SCENES.has(_ability.animation_id):
		return
	
	var effect = AbilitySceneRegistry.SCENES[_ability.animation_id].instantiate() as AbilityVisual
	if effect == null:
		push_error("UnitAbilityExecutor: effect scene root is not an AbilityVisual — check scene: " + _ability.animation_id)
		return
	get_parent().add_child(effect)
	effect.z_index = Constants.UNOCCLUDED_ACTOR_Z_INDEX
	effect.global_position = _caster.global_position
	effect.scale.x = abs(effect.scale.x) * _caster.unit_visual_root.scale.x

	if _ability.charge_delay != 0:
		await get_tree().create_timer(_ability.charge_delay * 0.001).timeout

	await effect.travel(_get_target_world_pos(), _ability, _camera)

# resolves the ability against its target(s).
# Damage flows exclusively through target.apply_damage — that single call
# mutates HP, announces the event (which the CinematicDirector turns into the
# camera shake), and plays the target's hit feedback. No separate shake /
# take_hit / HP bookkeeping calls to keep in sync.
func resolve_ability(action_resolver: ActionResolver) -> void:
		# tiles don't participate in hit/miss resolution — apply effects directly
	if _single_target is BattleTileData:
		if not _ability.effects.is_empty():
			for effect_id in _ability.effects.keys():
				await _effect_executor.apply_effect(_single_target, effect_id)
		return
		
	if _single_target == null:
		return

	var result = action_resolver.resolve(_caster, _single_target, _ability)
	var tile = _grid.get_tile(_single_target.grid_position)
	
	_caster.spend_mp(_ability.mp_cost)
	if not result.is_miss:
		if _ability.ability_type == AbilityData.AbilityType.HEALING:
			await _single_target.apply_heal(result.damage)
		else:
			await _single_target.apply_damage(result.damage)
		await get_tree().create_timer(1).timeout

		# apply the ability's rider effects to the target and its tile
		if not _ability.effects.is_empty():
			for effect in _ability.effects.keys():
				var context = EffectContext.create(_grid, _unit_mover, _effect_executor)
				if is_instance_valid(_single_target):
					if _single_target is Unit:
						await _effect_executor.apply_effect_to_unit_and_tile(_single_target, effect, context)
					else:
						await _effect_executor.apply_effect(_single_target, effect)
				else:
					await _effect_executor.apply_effect(tile, effect)
	else:
		if _single_target is Unit:
			_single_target.set_facing_toward(_single_target.grid_position, _caster.grid_position)
			_single_target.play_missed()
	# TODO: handle multi_target resolution

func _launch_effect() -> AbilityVisual:
	if _ability.animation_id == "" or not AbilitySceneRegistry.SCENES.has(_ability.animation_id):
		DebugLog.ability("no registered animation for ability '%s' — skipping visual" % _ability.animation_id)
		return null
	var effect = AbilitySceneRegistry.SCENES[_ability.animation_id].instantiate() as AbilityVisual
	if effect == null:
		push_error("UnitAbilityExecutor: effect scene root is not an AbilityVisual — check scene: " + _ability.animation_id)
		return null
	effect.visible = false
	get_parent().add_child(effect)
	effect.spawn(_caster.global_position, _caster)
	effect.visible = true
	return effect

func _travel_path(effect: Node2D, path: Array[Vector2] = []) -> void:
	pass # TODO: implement path-based travel
	
func _get_caster_anim_fps() -> float:
	var sprite = _caster.get_node_or_null("VisualRoot/UnitSprite")
	if sprite is AnimatedSprite2D and sprite.sprite_frames != null:
		var anim_name = AbilityData.UnitAnimation.keys()[_ability.unit_animation].to_lower()
		if sprite.sprite_frames.has_animation(anim_name):
			return sprite.sprite_frames.get_animation_speed(anim_name)
	return 12.0  # fallback if sprite or animation not found

func _get_ability_anim_fps() -> float:
	return _ability.animation_fps if _ability.animation_fps > 0 else 12.0

func _clear_context() -> void:
	_caster = null
	_single_target = null
	_multi_target.clear()
	_ability = null
