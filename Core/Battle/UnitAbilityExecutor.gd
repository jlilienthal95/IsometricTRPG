extends Node

signal ability_cast(caster: Unit)
signal ability_complete

var _grid: BattleGrid = null
var _is_executing: bool = false
var _caster: Unit = null
var _single_target: Unit = null
var _multi_target: Array[Unit] = []
var _ability: AbilityData = null
var _camera: BattleCamera = null

# initializes the executor with a reference to the battle grid
func setup(grid: BattleGrid) -> void:
	_grid = grid

# begins ability execution — guards against concurrent executions
func execute_ability(caster: Unit, target_cell: Vector3i, ability: AbilityData, camera: BattleCamera) -> void:
	if _is_executing:
		push_error("UnitAbilityExecutor: ability execution already in progress")
		return
	_is_executing = true
	_caster = caster
	_single_target = _grid.get_unit_at(target_cell)
	_ability = ability
	_camera = camera
	
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
	if _caster.grid_position.y > _single_target.grid_position.y || \
	_caster.grid_position.x < _single_target.grid_position.x:
		_caster.set_facing(false)
	else:
		_caster.set_facing(true)

	await _caster.play_attack_animation(_ability.impact_delay)
	#await _caster.ability_impact

	# TODO: add anim displaying ability power numerically above target

	##TODO play damage count animation and refresh character info pane state
	_is_executing = false
	emit_signal("ability_complete")
	
# battle_scene calls this after ability_impact fires
# passes ActionResolver in so UnitAbilityExecutor can coordinate resolution internally
func resolve_ability(action_resolver: ActionResolver) -> void:
	if _single_target != null:
		var result = action_resolver.resolve(_caster, _single_target, _ability)
		if not result.is_miss:
			_single_target.adjust_hp(result.damage)
			_single_target.take_hit()
			print("dealt ", result.damage, " damage. target HP: ", _single_target.data.current_hp)
		# TODO: add miss animation
		# TODO: handle multi_target resolution
		# TODO: apply status effects from result
	
func _clear_context() -> void:
	_caster = null
	_single_target = null
	_multi_target.clear()
	_ability = null
	_camera = null
