class_name ActionResolver
extends Node

const BASE_CRIT_CHANCE: float = 0.05
const CRIT_MULTIPLIER: float = 2.0
const VARIANCE_PERCENT: float = 0.2

func resolve(caster: Unit, target: Unit, ability: AbilityData) -> ActionResult:
	var result = ActionResult.new()
	
	#check if ability hits at all
	#TODO: incorperate unit speed/appropriate stat base mods
	if _check_miss(result, ability.base_hit_chance).is_miss:
		return result
	
	var damage_result = _calc_damage(caster, target, ability)
	result.damage = damage_result[0]
	result.is_critical = damage_result[1]
	result.element = ability.element
	print("ability resolve complete")
	return result
	
func _check_miss(result: ActionResult, hit_chance: float) -> ActionResult:
	#TODO: incorperate unit speed/appropriate stat base mods
	var hit_roll = randf()
	if hit_roll > hit_chance:
		result.is_miss = true
		result.damage = 0
	return result

func _calc_damage(caster: Unit, target: Unit, ability: AbilityData) -> Array:
	var job = JobRegistry.get_job(caster.data.job_id)
	var base = ability.base_power + caster.data.base_attack
	var variance = int(base * VARIANCE_PERCENT)
	var raw = randi_range(base - variance, base)
	var is_critical = false
	
	if job != null:
		raw = int(raw * job.attack_modifier)
	
	if randf() < (BASE_CRIT_CHANCE + ability.base_crit_chance):
		raw = int(raw * 2.0)
		is_critical = true
	
	var mitigated = max(0, raw - target.data.base_defense)
	
	if target.data.elemental_affinities.has(ability.element):
		mitigated = int(mitigated * target.data.elemental_affinities[ability.element])
	print("base: ", base, " raw: ", raw, " defense: ", target.data.base_defense, " mitigated: ", mitigated)
	return [mitigated, is_critical]

func _base_damage(caster: Unit, ability: AbilityData) -> int:
	var base = ability.base_power + caster.data.base_attack
	var variance = int(base * VARIANCE_PERCENT)
	return randi_range(base - variance, base)
