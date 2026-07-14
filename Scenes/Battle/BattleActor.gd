class_name BattleActor
extends Node2D

# shared interface contract — override in Unit and BattleObject
var grid_position: Vector3i = Vector3i.ZERO
var data: BattleActorData = null

func apply_damage(amount: int) -> void:
	pass

func apply_heal(amount: int) -> void:
	pass

func has_effect(effect_id: EffectId.Id) -> bool:
	return false

func get_effect(effect_id: EffectId.Id) -> EffectInstance:
	return null

func apply_effect(effect_id: EffectId.Id, ticks: int = -1) -> void:
	pass

func remove_effect(effect_id: EffectId.Id) -> void:
	pass

func play_idle() -> void:
	pass

func play_walk() -> void:
	pass

func play_jump() -> void:
	pass

func set_facing_toward(from_cell: Vector3i, to_cell: Vector3i) -> void:
	pass

func set_effect_alpha(alpha: float) -> void:
	pass

func update_z_index() -> void:
	pass

func on_terrain_changed(terrain_type: int) -> void:
	pass
