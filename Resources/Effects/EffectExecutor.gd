class_name EffectExecutor
extends Node

signal effect_resolved

enum RemovalReason { EXPIRED, NEUTRALIZED }

var _grid: BattleGrid = null
var _camera: BattleCamera = null
var _tile_visual_manager: TileVisualManager = null

func setup(grid: BattleGrid, camera: BattleCamera, tile_visual_manager) -> void:
	_grid = grid
	_camera = camera
	_tile_visual_manager = tile_visual_manager

# the single entry point for processing one tick on one target — applies, animates, resolves, in order
func process_tick(target, instance: EffectInstance, context: EffectContext, decrement_duration: bool = true) -> void:
	#print("target ticked: ", target)
	instance.ticks_active += 1
	if decrement_duration and instance.rounds_remaining > 0:
		instance.rounds_remaining -= 1
	#print("rounds remaining: ", instance.rounds_remaining)
	var handler = EffectRegistry.get_handler(instance.effect_id)
	if handler != null:
		handler.resolve(target, instance, context)

	if instance.rounds_remaining == 0:
		await remove_effect(target, instance.effect_id, RemovalReason.EXPIRED)

# applies a new effect to a target, playing the apply animation, then the neutralize animation if applicable
func apply_effect(target, effect_id: EffectId.Id, ticks: int = -1) -> void:
	print("apply_effect target cell: ", target.cell if target is BattleTileData else "unit")
	print("apply_effect called for: ", EffectId.Id.keys()[effect_id])
	#print(get_stack())
	if _is_immune(target, effect_id):
		await _play_immune_animation(target, effect_id)
		return

	var neutralized_effect = _check_neutralization(target, effect_id)
	if neutralized_effect != EffectId.Id.NONE:
		await remove_effect(target, neutralized_effect, RemovalReason.NEUTRALIZED)

	target.apply_effect(effect_id, ticks)
	await _play_apply_animation(target, effect_id)

# calls apply effect once for tile and the unit that occupies it	
func apply_effect_to_unit_and_tile(unit: Unit, effect_id: EffectId.Id, context: EffectContext) -> void:
	await apply_effect(unit, effect_id)
	var tile = context.grid.get_tile(unit.grid_position)
	_tile_visual_manager.refresh(tile)
	if tile != null:
		await apply_effect(tile, effect_id)
	
# removes an effect from a target — mutates, then plays the animation matching the reason
func remove_effect(target, effect_id: EffectId.Id, reason: RemovalReason = RemovalReason.EXPIRED) -> void:
	target.remove_effect(effect_id)
	await _play_remove_animation(target, effect_id, reason)

func _is_immune(target, effect_id: EffectId.Id) -> bool:
	if target is Unit:
		return target.data.immunities.has(effect_id)
	return false	# tiles don't currently have an immunity concept — only units, via equipment

func _check_neutralization(target, incoming_effect_id: EffectId.Id) -> EffectId.Id:
	var incoming_handler = EffectRegistry.get_handler(incoming_effect_id)
	if incoming_handler != null:
		for existing_effect in incoming_handler.get_neutralizes():
			if target.has_effect(existing_effect):
				return existing_effect
	return EffectId.Id.NONE

func _play_apply_animation(target, effect_id: EffectId.Id) -> void:
	if target is BattleTileData and _tile_visual_manager != null:
		await _tile_visual_manager.play_effect_apply_animation(target, effect_id)
		_tile_visual_manager.refresh(target)
	if target is Unit:
		await target.play_effect_apply_animation(effect_id)
		#unit.refresh_effect_visuals(target)
		
func _play_remove_animation(target, effect_id: EffectId.Id, reason: RemovalReason) -> void:
	if target is BattleTileData and _tile_visual_manager != null:
		await _tile_visual_manager.play_effect_remove_animation(target, effect_id, reason)
		_tile_visual_manager.refresh(target)
		
func _play_immune_animation(target, effect_id: EffectId.Id) -> void:
	pass

func convert_terrain(tile: BattleTileData, new_terrain: BattleTileData.TerrainType) -> void:
	tile.terrain_type = new_terrain
	if _tile_visual_manager != null:
		_tile_visual_manager.refresh(tile)
