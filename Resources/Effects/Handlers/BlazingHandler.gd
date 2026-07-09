class_name BlazingHandler
extends EffectHandler

# Stub handler for BLAZING — registered so the effect system has full coverage,
# with no behavior yet. Implement the hooks below as the effect is designed.

const EFFECT = EffectId.Id.BLAZING

func _resolve_unit(unit: Unit, instance: EffectInstance, context: EffectContext) -> void:
	pass

func _resolve_tile(tile: BattleTileData, instance: EffectInstance, context: EffectContext) -> void:
	pass

func _resolve_object(object: BattleObject, instance: EffectInstance, context: EffectContext) -> void:
	pass

func on_unit_turn_end(unit: Unit, instance: EffectInstance, context: EffectContext) -> void:
	var tile = context.grid.get_tile(unit.grid_position)
	if tile == null:
		return
	var susceptible = EffectRules.SUSCEPTIBLE_TERRAIN.get(EFFECT, [])
	if susceptible.has(tile.terrain_type):
		await context.executor.apply_effect(tile, EFFECT, instance.rounds_remaining)
		
	var damage = randi() % 10 + 1
	if unit.data.weaknesses.has(EFFECT):
		damage *= 2
	if unit.data.immunities.has(EFFECT):
		damage *= 0
	unit.apply_damage(damage)
	pass
