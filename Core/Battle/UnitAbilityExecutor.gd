class_name UnitAbilityExecutor
extends Node

signal ability_complete

var _grid: BattleGrid = null
var _is_executing: bool = false
var _caster: Unit = null
var _single_target = null				# Unit or BattleObject
var _multi_target: Array = []
var _ability: AbilityData = null
var _action_resolver: ActionResolver = null
var _effect_executor: EffectExecutor = null
var _camera: BattleCamera = null
var _director: CinematicDirector = null

# initializes the executor with references it needs every battle
func setup(grid: BattleGrid, director: CinematicDirector) -> void:
	_grid = grid
	_director = director

# begins ability execution — guards against concurrent executions
func execute_ability(caster: Unit, target_cell: Vector3i, ability: AbilityData, camera: BattleCamera, action_resolver: ActionResolver, effect_executor: EffectExecutor) -> void:
	if _is_executing:
		push_error("UnitAbilityExecutor: ability execution already in progress")
		return
	_is_executing = true
	_caster = caster
	_single_target = _grid.get_actor_at(target_cell)	# units and objects are both valid targets
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

func _execute_sequence() -> void:
	# all cinematic presentation is owned by the director — this executor only
	# choreographs the ability itself (animations, projectiles, resolution)
	await _director.begin_sequence(_caster)
	_face_target()
	var cast_impact_delay = _caster.data.job.cast_impact_delay if _caster.data.job != null else 0.0
	await _caster.play_attack_animation(cast_impact_delay, _ability.unit_animation)
	await _execute_effect()
	# wait time it takes from ability anim begin until timpact of ability, less any charge time if applicable
	await get_tree().create_timer(float((_ability.impact_delay - _ability.charge_delay) / 1000.0)).timeout
	await resolve_ability(_action_resolver)
	_caster.play_idle()
	# let every queued impact beat land inside the sequence before tearing down
	await _director.wait_until_idle()
	await _director.end_sequence()
	_is_executing = false
	emit_signal("ability_complete")
	_clear_context()

func _face_target() -> void:
	if _single_target == null:
		return
	print("x diff: ", _single_target.global_position.x - _caster.global_position.x)
	_caster.set_facing(_single_target.global_position.x < _caster.global_position.x + 8.0)

func _execute_effect() -> void:
	if _ability.animation_id == "":
		return
	if AbilitySceneRegistry.SCENES.has(_ability.animation_id):
		var effect = AbilitySceneRegistry.SCENES[_ability.animation_id].instantiate()
		get_parent().add_child(effect)
		effect.global_position = _caster.global_position
		effect.scale.x = abs(effect.scale.x) * _caster.unit_visual_root.scale.x
		if _single_target != null:
			effect.z_index = _single_target.z_index + 1
		effect.play(_ability.animation_id)
		_camera.follow(effect)
		# wait for ability/spell charge portion of anim, if applicable
		if _ability.charge_delay != 0:
			await get_tree().create_timer(_ability.charge_delay * .001).timeout
		_travel(effect)

# resolves the ability against its target(s).
# Damage flows exclusively through target.apply_damage — that single call
# mutates HP, announces the event (which the CinematicDirector turns into the
# camera shake), and plays the target's hit feedback. No separate shake /
# take_hit / HP bookkeeping calls to keep in sync.
func resolve_ability(action_resolver: ActionResolver) -> void:
	if _single_target == null:
		return
	var result = action_resolver.resolve(_caster, _single_target, _ability)
	_caster.spend_mp(_ability.mp_cost)
	if not result.is_miss:
		if _ability.ability_type == AbilityData.AbilityType.HEALING:
			await _single_target.apply_heal(result.damage)
		else:
			await _single_target.apply_damage(result.damage)
		await get_tree().create_timer(1).timeout

		# apply the ability's rider effects to the target and its tile
		if not _ability.effects.is_empty():
			for effect in _ability.effects:
				var context = EffectContext.create(_grid, _effect_executor)
				if _single_target is Unit:
					await _effect_executor.apply_effect_to_unit_and_tile(_single_target, effect, context)
				else:
					await _effect_executor.apply_effect(_single_target, effect)
	else:
		if _single_target is Unit:
			_single_target.set_facing_toward(_single_target.grid_position, _caster.grid_position)
			_single_target.play_missed()
	# TODO: handle multi_target resolution

func _travel(effect: Node2D) -> void:
	match _ability.animation_path:
		AbilityData.AnimationPath.PROJECTILE:
			var tween = create_tween()
			tween.tween_property(effect, "global_position", _single_target.global_position, 0.4)
			await tween.finished
		AbilityData.AnimationPath.PROJECTILE_ARROW:
			var tween = create_tween()
			var target_pos = _single_target.global_position
			target_pos.x -= 7
			#target_pos.y -= 8
			tween.tween_property(effect, "global_position", target_pos, 0.625)
			await tween.finished
		AbilityData.AnimationPath.INSTANT:
			effect.global_position = _single_target.global_position
		AbilityData.AnimationPath.PATH:
			_travel_path(effect)

func _travel_path(effect: Node2D, path: Array[Vector2] = []) -> void:
	pass # TODO: implement path-based travel

func _clear_context() -> void:
	_caster = null
	_single_target = null
	_multi_target.clear()
	_ability = null
