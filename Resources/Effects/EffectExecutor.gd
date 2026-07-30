class_name EffectExecutor
extends Node

signal effect_resolved

enum RemovalReason { EXPIRED, NEUTRALIZED }

var _grid: BattleGrid = null
var _camera: BattleCamera = null
var _director: CinematicDirector
var _tile_visual_manager: TileVisualManager = null

func setup(grid: BattleGrid, camera: BattleCamera, director: CinematicDirector, tile_visual_manager) -> void:
	_grid = grid
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
			print("[EE:apply_effect] emitting tile_effect_applied with visual callable")
			BattleEvents.tile_effect_applied.emit(target, effect_id, func(): await _play_apply_animation(target, effect_id))
		else:
			print("[EE:apply_effect] emitting effect_applied")
			BattleEvents.effect_applied.emit(target, effect_id)
			await _play_apply_animation(target, effect_id)
	else:
		print("[EE:apply_effect] refresh only — skipping visual and signal")
		
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
	print("[EE:remove_effect] target: ", target, " effect: ", effect_name, " reason: ", reason)
	target.remove_effect(effect_id)
	if target is BattleTileData:
		print("[EE:remove_effect] emitting tile_effect_removed with visual callable")
		BattleEvents.tile_effect_removed.emit(target, effect_id, reason, func(): await _play_remove_animation(target, effect_id, reason))
	else:
		print("[EE:remove_effect] emitting effect_removed")
		BattleEvents.effect_removed.emit(target, effect_id, reason)
		print("[EE:remove_effect] playing remove animation")
		await _play_remove_animation(target, effect_id, reason)
	print("[EE:remove_effect] complete — effect: ", effect_name)

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
	print("[EE:_play_apply_animation] target: ", target, " effect: ", effect_name)
	if target is BattleTileData and _tile_visual_manager != null:
		print("[EE:_play_apply_animation] playing tile animation")
		await _tile_visual_manager.play_effect_apply_animation(target, effect_id)
		_tile_visual_manager.refresh(target)
	elif target is Unit:
		print("[EE:_play_apply_animation] playing unit animation")
		await target.play_effect_apply_animation(effect_id)
	elif target is BattleObject and target.has_method("play_effect_apply_animation"):
		print("[EE:_play_apply_animation] playing object animation")
		await target.play_effect_apply_animation(effect_id)
	print("[EE:_play_apply_animation] complete")

func _play_remove_animation(target, effect_id: EffectId.Id, reason: RemovalReason) -> void:
	var effect_name = EffectId.Id.keys()[effect_id]
	print("[EE:_play_remove_animation] target: ", target, " effect: ", effect_name, " reason: ", reason)
	if target is BattleTileData and _tile_visual_manager != null:
		print("[EE:_play_remove_animation] playing tile remove animation")
		await _tile_visual_manager.play_effect_remove_animation(target, effect_id, reason)
		_tile_visual_manager.refresh(target)
	print("[EE:_play_remove_animation] complete")

func _play_immune_animation(target, effect_id: EffectId.Id) -> void:
	pass
