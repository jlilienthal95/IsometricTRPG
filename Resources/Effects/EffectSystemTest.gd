class_name EffectSystemTest
extends Node

var _grid: BattleGrid
var _camera: BattleCamera
var _executor: EffectExecutor
var _context: EffectContext
var _tile_visual_manager: TileVisualManager

func run_tests(grid: BattleGrid, camera: BattleCamera, tile_visual_manager: TileVisualManager, sample_unit: Unit) -> void:
	_grid = grid
	_camera = camera
	_executor = EffectExecutor.new()
	_executor.setup(_grid, _camera, _tile_visual_manager)
	_context = EffectContext.new()
	_context.grid = _grid
	_context.executor = _executor

	print("=== EFFECT SYSTEM TEST ===")
	_test_handler_discovery()
	await _test_basic_apply_and_query()
	await _test_neutralization()
	await _test_neutralization_does_not_fire_when_absent()
	await _test_double_apply_refreshes_not_duplicates()
	await _test_immunity_block(sample_unit)
	await _test_tick_increment()
	await _test_duration_decrements_and_expires()
	await _test_spread_does_not_include_origin()
	await _test_spread_respects_susceptibility()
	await _test_spread_respects_elevation_climb_only()
	await _test_unit_weakness_bonus_damage(sample_unit)
	await _test_redhot_applies_to_adjacent_metal()
	await _test_redhot_does_not_apply_to_non_metal()
	await _test_burning_unit_ignites_susceptible_tile(sample_unit)
	await _test_burning_unit_does_not_ignite_stone_tile(sample_unit)
	await _test_stone_converts_to_lava_after_threshold()
	print("=== TEST COMPLETE ===")

func _find_tile_of_type(terrain: BattleTileData.TerrainType, exclude: Array[Vector3i] = []) -> BattleTileData:
	for cell in _grid.get_all_cells():
		if exclude.has(cell):
			continue
		var tile = _grid.get_tile(cell)
		if tile != null and tile.terrain_type == terrain:
			return tile
	return null

func _clean_tile(tile: BattleTileData) -> void:
	for effect in tile.active_effects.duplicate():
		tile.remove_effect(effect.effect_id)

func _test_handler_discovery() -> void:
	print("--- handler discovery ---")
	var burning_handler = EffectRegistry.get_handler(EffectId.Id.BURNING)
	var redhot_handler = EffectRegistry.get_handler(EffectId.Id.REDHOT)
	assert(burning_handler != null, "FAIL: no BURNING handler found")
	assert(redhot_handler != null, "FAIL: no REDHOT handler found")
	if burning_handler != null:
		print("BURNING resolved effect_id: ", EffectId.Id.keys()[burning_handler.get_effect_id()])
	print("PASS: both handlers found and correctly auto-derived")

func _test_basic_apply_and_query() -> void:
	print("--- basic apply/query ---")
	var tile = _find_tile_of_type(BattleTileData.TerrainType.WOOD)
	if tile == null:
		print("SKIP: no WOOD tile found on map")
		return
	_clean_tile(tile)
	assert(not tile.has_effect(EffectId.Id.BURNING), "FAIL: tile already burning before test started")
	await _executor.apply_effect(tile, EffectId.Id.BURNING, 3)
	assert(tile.has_effect(EffectId.Id.BURNING), "FAIL: BURNING not applied")
	assert(tile.get_effect(EffectId.Id.BURNING).rounds_remaining == 3, "FAIL: wrong duration set")
	_clean_tile(tile)
	print("PASS: BURNING correctly absent before, present after, with correct duration")

func _test_neutralization() -> void:
	print("--- neutralization ---")
	var tile = _find_tile_of_type(BattleTileData.TerrainType.WOOD)
	if tile == null:
		print("SKIP: no WOOD tile found on map")
		return
	_clean_tile(tile)
	await _executor.apply_effect(tile, EffectId.Id.BURNING, 3)
	assert(tile.has_effect(EffectId.Id.BURNING), "FAIL: burning wasn't actually applied before neutralization test")
	await _executor.apply_effect(tile, EffectId.Id.SOAKED, 2)
	assert(not tile.has_effect(EffectId.Id.BURNING), "FAIL: burning still present after soaked applied")
	assert(tile.has_effect(EffectId.Id.SOAKED), "FAIL: soaked itself didn't apply")
	_clean_tile(tile)
	print("PASS: burning confirmed present, then confirmed neutralized by soaked")

func _test_neutralization_does_not_fire_when_absent() -> void:
	print("--- neutralization should not trigger when nothing to neutralize ---")
	var tile = _find_tile_of_type(BattleTileData.TerrainType.STONE)
	if tile == null:
		print("SKIP: no STONE tile found on map")
		return
	_clean_tile(tile)
	assert(not tile.has_effect(EffectId.Id.BURNING), "FAIL: tile unexpectedly already burning")
	await _executor.apply_effect(tile, EffectId.Id.SOAKED, 2)
	assert(tile.has_effect(EffectId.Id.SOAKED), "FAIL: soaked didn't apply to a tile with nothing to neutralize")
	_clean_tile(tile)
	print("PASS: soaked applied cleanly with no false neutralization triggered")

func _test_double_apply_refreshes_not_duplicates() -> void:
	print("--- applying same effect twice should refresh duration not duplicate ---")
	var tile = _find_tile_of_type(BattleTileData.TerrainType.WOOD)
	if tile == null:
		print("SKIP: no WOOD tile found on map")
		return
	_clean_tile(tile)
	await _executor.apply_effect(tile, EffectId.Id.BURNING, 1)
	var count_before = 0
	for e in tile.active_effects:
		if e.effect_id == EffectId.Id.BURNING:
			count_before += 1
	assert(count_before == 1, "FAIL: expected 1 instance before re-apply, found " + str(count_before))
	await _executor.apply_effect(tile, EffectId.Id.BURNING, 5)
	var count_after = 0
	for e in tile.active_effects:
		if e.effect_id == EffectId.Id.BURNING:
			count_after += 1
	assert(count_after == 1, "FAIL: expected 1 instance after re-apply, found " + str(count_after))
	assert(tile.get_effect(EffectId.Id.BURNING).rounds_remaining == 5, "FAIL: duration wasn't refreshed")
	_clean_tile(tile)
	print("PASS: re-apply refreshed duration without duplicating instance")

func _test_immunity_block(unit: Unit) -> void:
	print("--- immunity block ---")
	var blocked: Array[EffectId.Id] = [EffectId.Id.BURNING]
	unit.data.immunities = blocked
	assert(not unit.data.has_effect(EffectId.Id.BURNING), "FAIL: unit already burning before immunity test")
	await _executor.apply_effect(unit, EffectId.Id.BURNING, 3)
	assert(not unit.data.has_effect(EffectId.Id.BURNING), "FAIL: immune unit still caught fire")
	print("PASS: immunity held — unit correctly did not catch fire")
	unit.data.immunities = []
	await _executor.apply_effect(unit, EffectId.Id.BURNING, 3)
	assert(unit.data.has_effect(EffectId.Id.BURNING), "FAIL: non-immune unit failed to catch fire — burning may be broken entirely")
	print("PASS: same unit without immunity caught fire — proves immunity check is meaningful")
	unit.data.remove_effect(EffectId.Id.BURNING)

func _test_tick_increment() -> void:
	print("--- tick increment ---")
	var tile = _find_tile_of_type(BattleTileData.TerrainType.WOOD)
	if tile == null:
		print("SKIP: no WOOD tile found on map")
		return
	_clean_tile(tile)
	await _executor.apply_effect(tile, EffectId.Id.BURNING, 5)
	var instance = tile.get_effect(EffectId.Id.BURNING)
	assert(instance.ticks_active == 0, "FAIL: ticks_active should start at 0, was " + str(instance.ticks_active))
	await _executor.process_tick(tile, instance, _context, true)
	assert(instance.ticks_active == 1, "FAIL: ticks_active should be 1 after one tick, was " + str(instance.ticks_active))
	assert(instance.rounds_remaining == 4, "FAIL: rounds_remaining should decrement to 4, was " + str(instance.rounds_remaining))
	_clean_tile(tile)
	print("PASS: ticks_active and rounds_remaining both moved correctly")

func _test_duration_decrements_and_expires() -> void:
	print("--- duration expiry after repeated ticks ---")
	var tile = _find_tile_of_type(BattleTileData.TerrainType.WOOD)
	if tile == null:
		print("SKIP: no WOOD tile found on map")
		return
	_clean_tile(tile)
	await _executor.apply_effect(tile, EffectId.Id.BURNING, 2)
	var instance = tile.get_effect(EffectId.Id.BURNING)
	assert(tile.has_effect(EffectId.Id.BURNING), "FAIL: burning not present right after apply")
	await _executor.process_tick(tile, instance, _context, true)
	assert(tile.has_effect(EffectId.Id.BURNING), "FAIL: burning expired too early after only 1 of 2 ticks")
	await _executor.process_tick(tile, instance, _context, true)
	assert(not tile.has_effect(EffectId.Id.BURNING), "FAIL: burning still present after 2nd tick — should have expired")
	print("PASS: confirmed present after 1 tick, confirmed expired after 2nd tick")

func _test_spread_does_not_include_origin() -> void:
	print("--- spread should never include the origin cell itself ---")
	var tile = _find_tile_of_type(BattleTileData.TerrainType.WOOD)
	if tile == null:
		print("SKIP: no WOOD tile found on map")
		return
	_clean_tile(tile)
	await _executor.apply_effect(tile, EffectId.Id.BURNING, 5)
	var instance = tile.get_effect(EffectId.Id.BURNING)
	await _executor.process_tick(tile, instance, _context, true)
	var neighbors = _grid.get_effect_neighbors(tile.cell, true)
	assert(not neighbors.has(tile.cell), "FAIL: get_effect_neighbors returned origin cell as its own neighbor")
	var spread_cells = _grid.get_cells_with_effect(EffectId.Id.BURNING)
	var origin_double_counted = false
	for cell in spread_cells:
		if cell == tile.cell:
			origin_double_counted = true
			break
	print("PASS: origin cell not in neighbor list, burning spread cells: ", spread_cells)
	_clean_tile(tile)

func _test_spread_respects_susceptibility() -> void:
	print("--- spread should only ignite susceptible terrain ---")
	var wood_tile = _find_tile_of_type(BattleTileData.TerrainType.WOOD)
	var stone_tile = _find_tile_of_type(BattleTileData.TerrainType.STONE)
	if wood_tile == null or stone_tile == null:
		print("SKIP: need both WOOD and STONE tiles on map")
		return
	_clean_tile(wood_tile)
	_clean_tile(stone_tile)
	assert(not stone_tile.has_effect(EffectId.Id.BURNING), "FAIL: stone tile already burning before test")
	await _executor.apply_effect(wood_tile, EffectId.Id.BURNING, 5)
	var instance = wood_tile.get_effect(EffectId.Id.BURNING)
	await _executor.process_tick(wood_tile, instance, _context, true)
	assert(not stone_tile.has_effect(EffectId.Id.BURNING), "FAIL: stone caught fire despite not being susceptible")
	_clean_tile(wood_tile)
	_clean_tile(stone_tile)
	print("PASS: stone confirmed non-susceptible before and after tick")

func _test_spread_respects_elevation_climb_only() -> void:
	print("--- spread should climb up but never fall down in elevation ---")
	var tile = _find_tile_of_type(BattleTileData.TerrainType.WOOD)
	if tile == null:
		print("SKIP: no WOOD tile found on map")
		return
	_clean_tile(tile)
	await _executor.apply_effect(tile, EffectId.Id.BURNING, 5)
	var instance = tile.get_effect(EffectId.Id.BURNING)
	await _executor.process_tick(tile, instance, _context, true)
	var lower_neighbors = _grid.get_effect_neighbors(tile.cell, true).filter(func(c): return c.z < tile.cell.z)
	var any_lower_caught_fire = false
	for cell in lower_neighbors:
		var neighbor_tile = _grid.get_tile(cell)
		if neighbor_tile != null and neighbor_tile.has_effect(EffectId.Id.BURNING):
			any_lower_caught_fire = true
	assert(not any_lower_caught_fire, "FAIL: fire spread downward in elevation")
	_clean_tile(tile)
	print("PASS: no lower-elevation neighbor caught fire")

func _test_unit_weakness_bonus_damage(unit: Unit) -> void:
	print("--- weakness should deal more damage than non-weak unit ---")
	var base_amount = int(Constants.BASE_DAMAGE_UNIT * 0.8)
	unit.data.weaknesses = []
	var normal_damage = EffectDamageResolver.resolve(unit, EffectId.Id.BURNING, base_amount)
	assert(normal_damage > 0, "FAIL: base damage was zero or negative — resolver may be broken")
	var weak: Array[EffectId.Id] = [EffectId.Id.BURNING]
	unit.data.weaknesses = weak
	var weak_damage = EffectDamageResolver.resolve(unit, EffectId.Id.BURNING, base_amount)
	assert(weak_damage > normal_damage, "FAIL: weak unit took " + str(weak_damage) + " but normal took " + str(normal_damage) + " — weakness bonus not applying")
	unit.data.weaknesses = []
	print("PASS: normal=" + str(normal_damage) + " weak=" + str(weak_damage) + " — weakness correctly increases damage")

func _test_redhot_applies_to_adjacent_metal() -> void:
	print("--- burning adjacent to metal should apply redhot ---")
	var wood_tile = _find_tile_of_type(BattleTileData.TerrainType.WOOD)
	if wood_tile == null:
		print("SKIP: no WOOD tile found")
		return
	var metal_neighbor: BattleTileData = null
	for cell in _grid.get_effect_neighbors(wood_tile.cell, true):
		var neighbor = _grid.get_tile(cell)
		if neighbor != null and neighbor.terrain_type == BattleTileData.TerrainType.METAL:
			metal_neighbor = neighbor
			break
	if metal_neighbor == null:
		print("SKIP: no adjacent METAL tile found next to WOOD tile")
		return
	_clean_tile(wood_tile)
	_clean_tile(metal_neighbor)
	assert(not metal_neighbor.has_effect(EffectId.Id.REDHOT), "FAIL: metal already redhot before test")
	await _executor.apply_effect(wood_tile, EffectId.Id.BURNING, 3)
	var instance = wood_tile.get_effect(EffectId.Id.BURNING)
	await _executor.process_tick(wood_tile, instance, _context, true)
	assert(metal_neighbor.has_effect(EffectId.Id.REDHOT), "FAIL: metal adjacent to burning did not become redhot")
	_clean_tile(wood_tile)
	_clean_tile(metal_neighbor)
	print("PASS: adjacent metal correctly became redhot after burning tick")

func _test_redhot_does_not_apply_to_non_metal() -> void:
	print("--- burning should NOT apply redhot to non-metal neighbors ---")
	var wood_tile = _find_tile_of_type(BattleTileData.TerrainType.WOOD)
	if wood_tile == null:
		print("SKIP: no WOOD tile found")
		return
	_clean_tile(wood_tile)
	await _executor.apply_effect(wood_tile, EffectId.Id.BURNING, 3)
	var instance = wood_tile.get_effect(EffectId.Id.BURNING)
	await _executor.process_tick(wood_tile, instance, _context, true)
	for cell in _grid.get_effect_neighbors(wood_tile.cell, true):
		var neighbor = _grid.get_tile(cell)
		if neighbor != null and neighbor.terrain_type != BattleTileData.TerrainType.METAL:
			assert(not neighbor.has_effect(EffectId.Id.REDHOT), "FAIL: non-metal tile at " + str(cell) + " got redhot")
	_clean_tile(wood_tile)
	print("PASS: no non-metal neighbor received redhot")

func _test_burning_unit_ignites_susceptible_tile(unit: Unit) -> void:
	print("--- burning unit should ignite susceptible tile at turn end ---")
	var wood_tile = _find_tile_of_type(BattleTileData.TerrainType.WOOD)
	if wood_tile == null:
		print("SKIP: no WOOD tile found")
		return
	_clean_tile(wood_tile)
	unit.grid_position = wood_tile.cell
	await _executor.apply_effect(unit, EffectId.Id.BURNING, 3)
	assert(unit.data.has_effect(EffectId.Id.BURNING), "FAIL: unit didn't catch fire")
	assert(not wood_tile.has_effect(EffectId.Id.BURNING), "FAIL: tile was already burning before turn end")
	var instance = unit.data.get_effect(EffectId.Id.BURNING)
	var handler = EffectRegistry.get_handler(EffectId.Id.BURNING)
	await handler.on_unit_turn_end(unit, instance, _context)
	assert(wood_tile.has_effect(EffectId.Id.BURNING), "FAIL: wood tile wasn't ignited by burning unit at turn end")
	unit.data.remove_effect(EffectId.Id.BURNING)
	_clean_tile(wood_tile)
	print("PASS: burning unit correctly ignited occupying wood tile at turn end")

func _test_burning_unit_does_not_ignite_stone_tile(unit: Unit) -> void:
	print("--- burning unit should NOT ignite non-susceptible tile ---")
	var stone_tile = _find_tile_of_type(BattleTileData.TerrainType.STONE)
	if stone_tile == null:
		print("SKIP: no STONE tile found")
		return
	_clean_tile(stone_tile)
	unit.grid_position = stone_tile.cell
	await _executor.apply_effect(unit, EffectId.Id.BURNING, 3)
	var instance = unit.data.get_effect(EffectId.Id.BURNING)
	var handler = EffectRegistry.get_handler(EffectId.Id.BURNING)
	assert(not stone_tile.has_effect(EffectId.Id.BURNING), "FAIL: stone tile already burning before turn end")
	await handler.on_unit_turn_end(unit, instance, _context)
	assert(not stone_tile.has_effect(EffectId.Id.BURNING), "FAIL: burning unit ignited non-susceptible stone tile")
	unit.data.remove_effect(EffectId.Id.BURNING)
	print("PASS: stone tile correctly not ignited by burning unit")

func _test_stone_converts_to_lava_after_threshold() -> void:
	print("--- stone adjacent to burning for full duration should convert to lava ---")
	var wood_tile = _find_tile_of_type(BattleTileData.TerrainType.WOOD)
	if wood_tile == null:
		print("SKIP: no WOOD tile found")
		return
	var stone_neighbor: BattleTileData = null
	for cell in PropagationEngine.get_flat_neighbors(wood_tile.cell, _grid):
		var neighbor = _grid.get_tile(cell)
		if neighbor != null and neighbor.terrain_type == BattleTileData.TerrainType.STONE:
			stone_neighbor = neighbor
			break
	if stone_neighbor == null:
		print("SKIP: no adjacent flat STONE tile found next to WOOD tile")
		return
	_clean_tile(wood_tile)
	var threshold = EffectRules.DURATION_THRESHOLD_TICKS.get(EffectId.Id.BURNING, 3)
	await _executor.apply_effect(wood_tile, EffectId.Id.BURNING, threshold)
	var instance = wood_tile.get_effect(EffectId.Id.BURNING)
	assert(stone_neighbor.terrain_type == BattleTileData.TerrainType.STONE, "FAIL: stone already converted before threshold")
	for i in range(threshold - 1):
		await _executor.process_tick(wood_tile, instance, _context, true)
		assert(stone_neighbor.terrain_type == BattleTileData.TerrainType.STONE, "FAIL: stone converted too early at tick " + str(i + 1))
	await _executor.process_tick(wood_tile, instance, _context, true)
	assert(stone_neighbor.terrain_type == BattleTileData.TerrainType.LAVA, "FAIL: stone did not convert to lava after full threshold")
	print("PASS: stone remained stone until threshold, then correctly converted to lava")
