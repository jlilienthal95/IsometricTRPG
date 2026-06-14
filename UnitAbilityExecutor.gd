class_name UnitAbilityExecutor
extends Node

signal ability_complete(unit: Unit)

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
	
	await _execute_sequence(caster, target_cell, ability, camera)

func _execute_sequence(caster: Unit, target_cell: Vector3i, ability: AbilityData, camera: BattleCamera) -> void:
	# 1. caster animation
	await caster.play_attack()
	# 2. effect animation (placeholder for now)
	
	# 3. apply results (ActionResolver will go here)
	
	# 4. target reaction (placeholder for now)
	_is_executing = false
	emit_signal("ability_complete", caster)
