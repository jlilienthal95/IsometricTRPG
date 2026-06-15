class_name UnitAbilityExecutor
extends Node

signal ability_impact()
signal ability_complete()

var _grid: BattleGrid = null
var _is_executing: bool = false

func setup(grid: BattleGrid) -> void:
	_grid = grid

func execute_ability(caster: Unit, target_cell: Vector3i, ability: AbilityData, camera: BattleCamera) -> void:
	print("executing ability: ", ability.ability_name)
	if _is_executing:
		push_error("UnitAbilityExecutor: ability execution already in progress")
		return
	_is_executing = true
	_execute_sequence(caster, target_cell, ability, camera)

func _execute_sequence(caster: Unit, target_cell: Vector3i, ability: AbilityData, camera: BattleCamera) -> void:
	var target = _grid.get_unit_at(target_cell)
	# 1. caster animation
	caster.play_attack()
	# 2. effect animation (placeholder for now)
	
	
	
	# 3. target reaction (placeholder for now)
	await get_tree().create_timer(ability.impact_delay).timeout
	if target != null:
		await target.play_hit()
		
	# 4. apply results (ActionResolver will go here)
	_is_executing = false
	emit_signal("ability_complete")
	
func _on_ability_impact() -> void:
	emit_signal("ability_impact")
	
