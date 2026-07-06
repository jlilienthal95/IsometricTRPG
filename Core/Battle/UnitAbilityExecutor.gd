class_name UnitAbilityExecutor
extends Node

signal ability_complete

var _grid: BattleGrid = null
var _is_executing: bool = false
var _caster: Unit = null
var _single_target: Unit = null
var _multi_target: Array[Unit] = []
var _ability: AbilityData = null
var _action_resolver: ActionResolver = null
var _effect_executor: EffectExecutor = null
var _camera: BattleCamera = null
var _battle_ui: BattleUI = null

# initializes the executor with a reference to the battle grid
func setup(grid: BattleGrid) -> void:
	_grid = grid

# begins ability execution — guards against concurrent executions
func execute_ability(caster: Unit, target_cell: Vector3i, ability: AbilityData, camera: BattleCamera, action_resolver: ActionResolver, battle_ui: BattleUI, effect_executor) -> void:
	if _is_executing:
		push_error("UnitAbilityExecutor: ability execution already in progress")
		return
	_is_executing = true
	_caster = caster
	_single_target = _grid.get_unit_at(target_cell)
	_ability = ability
	_camera = camera
	_action_resolver = action_resolver
	_battle_ui = battle_ui
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
	await _setup_cinematic()
	_face_target()
	var job = JobRegistry.get_job(_caster.data.job_id)
	var cast_impact_delay = job.cast_impact_delay if job != null else 0.0
	await _caster.play_attack_animation(cast_impact_delay, _ability.animation_id != "")
	await _execute_effect()
	await get_tree().create_timer((_ability.impact_delay - _ability.charge_delay) * .001).timeout
	await resolve_ability(_action_resolver)
	_caster.play_idle()
	await _teardown_cinematic()
	_is_executing = false
	emit_signal("ability_complete")
	_clear_context()

func _setup_cinematic() -> void:
	await _battle_ui.fade_bars_in()
	await _camera.zoom_in()

func _teardown_cinematic() -> void:
	await _camera.zoom_reset()
	await _battle_ui.fade_bars_out()
	_camera.follow(_caster)

func _face_target() -> void:
	if _single_target == null:
		return
	if _caster.grid_position.y > _single_target.grid_position.y or \
	_caster.grid_position.x < _single_target.grid_position.x:
		_caster.set_facing(false)
	else:
		_caster.set_facing(true)

func _execute_effect() -> void:
	if _ability.animation_id == "":
		return
	if AbilitySceneRegistry.SCENES.has(_ability.animation_id):
		var effect = AbilitySceneRegistry.SCENES[_ability.animation_id].instantiate()
		get_parent().add_child(effect)
		effect.global_position = _caster.global_position
		effect.z_index = _single_target.z_index + 1
		effect.play(_ability.animation_id)
		_camera.follow(effect)
		await get_tree().create_timer(_ability.charge_delay * .001).timeout
		_travel(effect)
	
# battle_scene calls this after ability_impact fires
# passes ActionResolver in so UnitAbilityExecutor can coordinate resolution internally
func resolve_ability(action_resolver: ActionResolver) -> void:
	if _single_target != null:
		var result = action_resolver.resolve(_caster, _single_target, _ability)
		_caster.adjust_mp(_ability.mp_cost)
		if not result.is_miss:
			_camera.play_shake()
			_single_target.adjust_hp(result.damage)
			_single_target.take_hit(result.damage)
			print("dealt ", result.damage, " damage. target HP: ", _single_target.data.current_hp)
			await get_tree().create_timer(1).timeout
			
			# apply effects from result
			print("checking for effect apply")
			if not _ability.effects.is_empty():
				print("applying effects")
				for effect in _ability.effects:
					var context = EffectContext.create(_grid, _effect_executor)
					await _effect_executor.apply_effect_to_unit_and_tile(_single_target, effect, context)
		else:
			_single_target.set_facing_toward(_single_target.grid_position, _caster.grid_position)
			_single_target.play_missed()
		# TODO: handle multi_target resolution

func _travel(effect: Node2D) -> void:
	match _ability.animation_path:
		AbilityData.AnimationPath.PROJECTILE:
			var tween = create_tween()
			tween.tween_property(effect, "global_position", _single_target.global_position, 0.4)
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
