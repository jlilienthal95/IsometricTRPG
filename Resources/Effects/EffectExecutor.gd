class_name EffectExecutor
extends Node

signal effect_resolved

enum RemovalReason { EXPIRED, NEUTRALIZED }

var _grid: BattleGrid = null
var _unit_mover: UnitMover = null
var _camera: BattleCamera = null
var _director: CinematicDirector
var _tile_visual_manager: TileVisualManager = null

func setup(grid: BattleGrid, mover: UnitMover, camera: BattleCamera, director: CinematicDirector, tile_visual_manager) -> void:
	_grid = grid
	_unit_mover = mover
	_camera = camera
	_director = director
	_tile_visual_manager = tile_visual_manager

# the single entry point for processing one tick on one target — applies, animates, resolves, in order.
# The handler's resolve is AWAITED: handlers spread fire, apply nested effects,
# and play animations; ticking must not race ahead and expire the instance
# while the handler is mid-flight.
func process_tick(target, instance: EffectInstance, context: EffectContext, decrement_duration: bool = true) -> void:
	instance.ticks_active += 1
	if decrement_duration and instance.rounds_remaining > 0:
		instance.rounds_remaining -= 1
	var handler = EffectRegistry.get_handler(instance.effect_id)
	if handler != null:
		await handler.resolve(target, instance, context)

	if instance.rounds_remaining == 0 and target.has_effect(instance.effect_id):
		await remove_effect(target, instance.effect_id, RemovalReason.EXPIRED)
	effect_resolved.emit()

# applies a new effect to a target (Unit, BattleObject, or BattleTileData),
# running immunity and neutralization checks and playing the apply animation
func apply_effect(target, effect_id: EffectId.Id, ticks: int = -1) -> void:
	if _is_immune(target, effect_id):
		await _play_immune_animation(target, effect_id)
		return
	var neutralized_effect = _check_neutralization(target, effect_id)
	if neutralized_effect != EffectId.Id.NONE:
		await remove_effect(target, neutralized_effect, RemovalReason.NEUTRALIZED)
	
	var is_new = not target.has_effect(effect_id)  # check BEFORE applying
	target.apply_effect(effect_id, ticks)
	
	if is_new:
		# only emit and play visual for genuinely new effects
		if target is BattleTileData:
			BattleEvents.tile_effect_applied.emit(target, effect_id, func(): await _play_apply_animation(target, effect_id))
			# run the handler immediately on first application so instant
			# propagation, entry reactions etc. fire without waiting for
			# the next terrain turn tick
			var instance = target.get_effect(effect_id)
			if instance != null:
				var handler = EffectRegistry.get_handler(effect_id)
				if handler != null:
					var context = EffectContext.create(_grid, _unit_mover, self)
					await handler.resolve(target, instance, context)
		else:
			BattleEvents.effect_applied.emit(target, effect_id)
			await _play_apply_animation(target, effect_id)

# calls apply effect once for the unit and once for the tile it occupies
func apply_effect_to_unit_and_tile(unit: Unit, effect_id: EffectId.Id, context: EffectContext) -> void:
	await apply_effect(unit, effect_id)
	var tile = context.grid.get_tile(unit.grid_position)
	if tile != null:
		_tile_visual_manager.refresh(tile)
		await apply_effect(tile, effect_id)

# removes an effect from a target — mutates, then plays the animation matching the reason
func remove_effect(target, effect_id: EffectId.Id, reason: RemovalReason = RemovalReason.EXPIRED) -> void:
	var effect_name = EffectId.Id.keys()[effect_id]
	target.remove_effect(effect_id)
	if target is BattleTileData:
		BattleEvents.tile_effect_removed.emit(target, effect_id, reason, func(): await _play_remove_animation(target, effect_id, reason))
	else:
		BattleEvents.effect_removed.emit(target, effect_id, reason)
		await _play_remove_animation(target, effect_id, reason)

func apply_tile_entry_effects(actor: BattleActor, tile: BattleTileData) -> void:
	if tile == null or tile.active_effects.is_empty():
		return
	var context = EffectContext.create(_grid, _unit_mover, self)
	for instance in tile.active_effects.duplicate():
		var handler = EffectRegistry.get_handler(instance.effect_id)
		if handler != null:
			await handler.on_actor_entered_tile(actor, tile, instance, context)

func convert_terrain(tile: BattleTileData, new_terrain: BattleTileData.TerrainType) -> void:
	tile.terrain_type = new_terrain
	if _tile_visual_manager != null:
		_tile_visual_manager.refresh(tile)

# --- internals ---
func _is_immune(target, effect_id: EffectId.Id) -> bool:
	# units and objects share the immunities interface via their data resource;
	# tiles have no immunity concept
	if target is Unit or target is BattleObject:
		return target.data.immunities.has(effect_id)
	return false

func _check_neutralization(target, incoming_effect_id: EffectId.Id) -> EffectId.Id:
	var incoming_handler = EffectRegistry.get_handler(incoming_effect_id)
	if incoming_handler != null:
		for existing_effect in incoming_handler.get_neutralizes():
			if target.has_effect(existing_effect):
				return existing_effect
	return EffectId.Id.NONE

func _play_apply_animation(target, effect_id: EffectId.Id) -> void:
	var effect_name = EffectId.Id.keys()[effect_id]
	if target is BattleTileData and _tile_visual_manager != null:
		await _tile_visual_manager.play_effect_apply_animation(target, effect_id)
		_tile_visual_manager.refresh(target)
	elif target is Unit:
		await target.play_effect_apply_animation(effect_id)
	elif target is BattleObject and target.has_method("play_effect_apply_animation"):
		await target.play_effect_apply_animation(effect_id)

func _play_remove_animation(target, effect_id: EffectId.Id, reason: RemovalReason) -> void:
	var effect_name = EffectId.Id.keys()[effect_id]
	if target is BattleTileData and _tile_visual_manager != null:
		await _tile_visual_manager.play_effect_remove_animation(target, effect_id, reason)
		_tile_visual_manager.refresh(target)

func _play_immune_animation(target, effect_id: EffectId.Id) -> void:
	pass
	
func apply_damage(actor: BattleActor, amount: int) -> void:
	await actor.apply_damage(amount)

func apply_heal(actor: BattleActor, amount: int) -> void:
	await actor.apply_heal(amount)
