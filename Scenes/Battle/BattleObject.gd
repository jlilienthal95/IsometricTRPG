class_name BattleObject
extends Node2D

# A movable/interactive stage element (crate, barrel, boulder...).
# Deliberately implements the same duck-typed surface Unit exposes for the
# systems that treat the two identically:
# - movement execution (UnitMover): grid_position, play_walk/play_jump/play_idle,
#   set_facing_toward, update_z_index, set_effect_alpha, on_terrain_changed
# - damage pipeline: apply_damage / apply_heal -> BattleEvents
# - effect storage: has/get/apply/remove_effect via data (like a tile)
# Objects do NOT take turns; their effects tick during TERRAIN_TURN.

@onready var object_sprite: Sprite2D = get_node_or_null("Sprite2D")

var data: ObjectData = null
var grid_position: Vector3i = Vector3i.ZERO
var _grid_ref: BattleGrid = null

func setup(object_data: ObjectData, start_position: Vector3i) -> void:
	data = object_data
	data.resolve()
	grid_position = start_position

# =============================================================================
# DAMAGE — single entry point, mirrors Unit.apply_damage
# =============================================================================

func apply_damage(amount: int) -> void:
	if data.is_dead:
		return
	data.current_hp = maxi(0, data.current_hp - amount)
	BattleEvents.hp_changed.emit(self, -amount, data.current_hp)
	if data.current_hp == 0:
		await _destroy()

func apply_heal(amount: int) -> void:
	if data.is_dead:
		return
	data.current_hp = mini(data.max_hp, data.current_hp + amount)
	BattleEvents.hp_changed.emit(self, amount, data.current_hp)

func _destroy() -> void:
	data.is_dead = true
	if _grid_ref != null:
		_grid_ref.remove_object(grid_position)
	BattleEvents.actor_defeated.emit(self)
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	queue_free()

# =============================================================================
# EFFECTS — objects hold effects exactly like terrain does
# =============================================================================

func has_effect(effect_id: EffectId.Id) -> bool:
	return data.has_effect(effect_id)

func get_effect(effect_id: EffectId.Id) -> EffectInstance:
	return data.get_effect(effect_id)

func apply_effect(effect_id: EffectId.Id, ticks: int = -1) -> void:
	if data.is_dead:
		return
	data.apply_effect(effect_id, ticks)
	if _grid_ref != null:
		_grid_ref.register_effect_object(effect_id, self)

func remove_effect(effect_id: EffectId.Id) -> void:
	data.remove_effect(effect_id)
	if _grid_ref != null:
		_grid_ref.unregister_effect_object(effect_id, self)

# =============================================================================
# MOVEMENT INTERFACE — duck-typed surface shared with Unit so UnitMover can
# slide/push objects through the exact same step-execution pipeline
# =============================================================================

func play_idle() -> void:
	pass

func play_walk() -> void:
	pass

func play_jump() -> void:
	pass

func set_facing_toward(_from_cell: Vector3i, _to_cell: Vector3i) -> void:
	pass

func on_terrain_changed(_terrain_type: int) -> void:
	pass

func set_effect_alpha(_alpha: float) -> void:
	pass

func update_z_index() -> void:
	if _grid_ref == null:
		return
	var occluders = _grid_ref.occlusion_map.get(grid_position, [])
	if occluders.is_empty():
		z_index = 14 * 4 + 3
	else:
		var lowest_occluder = occluders[occluders.size() - 1]
		z_index = lowest_occluder.z * 4 - 1
