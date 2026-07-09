class_name ActionResolver
extends Node

# Resolves an ability from caster against a target (Unit or BattleObject).
# Pure calculation — no animation, no HP mutation. Callers apply the result.
func resolve(caster: Unit, target, ability: AbilityData) -> ActionResult:
	# early return if ability misses
	var hit_roll = randf()
	if hit_roll > ability.base_hit_chance:
		return ActionResult.create(0, true)

	var damage_result = _calc_damage(caster, target, ability)
	return ActionResult.create(damage_result[0], false, damage_result[1], ability.element)

func _calc_damage(caster: Unit, target, ability: AbilityData) -> Array:
	# NOTE: named max_power, not "max" — shadowing the built-in max() with a
	# local variable makes the later maxi() call a runtime crash in GDScript
	var max_power: int = int(ability.base_power * caster.data.attack)
	var variance: int = int(max_power * Constants.POWER_VARIANCE)
	var raw: int = randi_range(max_power - variance, max_power)
	var is_critical: bool = false

	if randf() < (Constants.BASE_CRIT_CHANCE + ability.base_crit_chance):
		raw = int(raw * Constants.CRIT_MULTIPLIER)
		is_critical = true

	# computed defense (job-modified), never base_defense — base stats are
	# authoring inputs, all combat math reads resolved stats
	var mitigated: int = maxi(0, raw - target.data.defense)

	if target.data.elemental_affinities.has(ability.element):
		mitigated = int(mitigated * target.data.elemental_affinities[ability.element])

	return [mitigated, is_critical]
