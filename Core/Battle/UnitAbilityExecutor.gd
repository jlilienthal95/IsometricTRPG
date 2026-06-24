class_name UnitAbilityExecutor
extends Node

#signal ability_cast(caster: Unit)
signal ability_complete

var _grid: BattleGrid = null
var _is_executing: bool = false
var _caster: Unit = null
var _single_target: Unit = null
var _multi_target: Array[Unit] = []
var _ability: AbilityData = null
var _action_resolver: ActionResolver = null
var _camera: BattleCamera = null
var _bars: CinematicBars = null #cinematic bars that widen screen appearance during ability animations
# initializes the executor with a reference to the battle grid
func setup(grid: BattleGrid) -> void:
	_grid = grid

# begins ability execution — guards against concurrent executions
func execute_ability(caster: Unit, target_cell: Vector3i, ability: AbilityData, camera: BattleCamera, action_resolver: ActionResolver, bars: CinematicBars) -> void:
	if _is_executing:
		push_error("UnitAbilityExecutor: ability execution already in progress")
		return
	_is_executing = true
	_caster = caster
	_single_target = _grid.get_unit_at(target_cell)
	_ability = ability
	_camera = camera
	_action_resolver = action_resolver
	_bars = bars
	
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
	# 1. caster plays attack animation
	#y down, x up = face right
	if _single_target != null:
		if _caster.grid_position.y > _single_target.grid_position.y or \
		_caster.grid_position.x < _single_target.grid_position.x:
			_caster.set_facing(false)
		else:
			_caster.set_facing(true)

	_bars.fade_in()
	await _camera.zoom_in()
	# start cast animation — waits cast_impact_delay then notifies impact
	await _caster.play_attack_animation(_ability.cast_impact_delay, _ability.animation_id != "")
	# spawn effect after impact
	if _ability.animation_id != "":
		var effect: Node2D = preload("res://Scenes/Battle/SpellEffect.tscn").instantiate()
		get_parent().add_child(effect)
		effect.global_position = _caster.global_position
		effect.z_index = _single_target.z_index + 1
		effect.play(_ability.animation_id)
		_camera.follow(effect)
		# wait charge delay before tween begins
		await get_tree().create_timer(_ability.charge_delay * .001).timeout
		#var tween = create_tween()
		#tween.tween_property(effect, "global_position", _single_target.global_position, 0.4)
		#await tween.finished
		# wait remaining impact time
		_travel(effect)
	await get_tree().create_timer((_ability.impact_delay - _ability.charge_delay) * .001).timeout
	await resolve_ability(_action_resolver)
	
	_caster.play_idle()
	
	await _camera.zoom_reset()
	_bars.fade_out()
	_camera.follow(_caster)
	
	#reset executor and notify ability complete
	_is_executing = false
	emit_signal("ability_complete")
	_clear_context()
	
# battle_scene calls this after ability_impact fires
# passes ActionResolver in so UnitAbilityExecutor can coordinate resolution internally
func resolve_ability(action_resolver: ActionResolver) -> void:
	if _single_target != null:
		var result = action_resolver.resolve(_caster, _single_target, _ability)
		if not result.is_miss:
			_camera.play_shake()
			_single_target.adjust_hp(result.damage)
			_single_target.take_hit(result.damage)
			print("dealt ", result.damage, " damage. target HP: ", _single_target.data.current_hp)
			await get_tree().create_timer(1).timeout
		else:
			_single_target.set_facing_toward(_single_target.grid_position, _caster.grid_position)
			_single_target.play_missed()
		# TODO: handle multi_target resolution
		# TODO: apply status effects from result

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
