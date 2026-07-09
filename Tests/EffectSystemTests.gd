class_name EffectSystemTests
extends TestSuite

func _init() -> void:
	suite_name = "EffectSystem"

func run() -> void:
	_test_registry_coverage()
	_test_store_apply_and_refresh()
	await _test_apply_and_neutralize()
	await _test_tick_lifecycle()
	await _test_burning_spread_step_by_step()
	await _test_object_effects()

func _test_registry_coverage() -> void:
	# every declared effect id must have a handler whose get_effect_id matches
	# its registry key — a mismatch means EFFECT consts or class names drifted
	var missing: Array = []
	var mismatched: Array = []
	for id in EffectId.Id.values():
		if id == EffectId.Id.NONE:
			continue
		var handler = EffectRegistry.get_handler(id)
		if handler == null:
			missing.append(EffectId.Id.keys()[id])
		elif handler.get_effect_id() != id:
			mismatched.append(EffectId.Id.keys()[id])
	check(missing.is_empty(), "registry: every EffectId has a handler", "missing: " + str(missing))
	check(mismatched.is_empty(), "registry: every handler's EFFECT matches its key", "mismatched: " + str(mismatched))

func _test_store_apply_and_refresh() -> void:
	var effects: Array[EffectInstance] = []
	var inst = EffectStore.apply_effect(effects, EffectId.Id.BURNING, 3)
	check_eq(effects.size(), 1, "store: apply adds exactly one instance")
	check_eq(inst.effect_id, EffectId.Id.BURNING, "store: instance carries the right id")
	check_eq(inst.rounds_remaining, 3, "store: instance carries the right duration")
	var refreshed = EffectStore.apply_effect(effects, EffectId.Id.BURNING, 5)
	check_eq(effects.size(), 1, "store: re-apply refreshes, does not stack")
	check_eq(refreshed, inst, "store: re-apply returns the same instance")
	check_eq(inst.rounds_remaining, 5, "store: re-apply resets duration")
	check(EffectStore.remove_effect(effects, EffectId.Id.BURNING), "store: remove reports success")
	check_eq(effects.size(), 0, "store: remove empties the list")
	check(not EffectStore.remove_effect(effects, EffectId.Id.BURNING), "store: removing absent effect reports failure")

func _make_executor(grid: BattleGrid) -> EffectExecutor:
	var executor = EffectExecutor.new()
	add_child(executor)
	executor.setup(grid, null, null)
	return executor

func _test_apply_and_neutralize() -> void:
	var grid = TestSuite.make_flat_grid(3, 3)
	add_child(grid)
	var executor = _make_executor(grid)
	var tile = grid.get_tile(Vector3i(1, 1, 0))

	await executor.apply_effect(tile, EffectId.Id.BURNING, 3)
	check(tile.has_effect(EffectId.Id.BURNING), "apply: tile stores burning")
	check_eq(grid.get_cells_with_effect(EffectId.Id.BURNING), [Vector3i(1, 1, 0)], "apply: grid index registered the cell")

	# SOAKED neutralizes BURNING per EffectRules.NEUTRALIZE_MAP —
	# verify BOTH halves: burning removed AND soaked present, plus index updates
	await executor.apply_effect(tile, EffectId.Id.SOAKED, 2)
	check(not tile.has_effect(EffectId.Id.BURNING), "neutralize: burning removed by soaked")
	check(tile.has_effect(EffectId.Id.SOAKED), "neutralize: soaked itself applied")
	check_eq(grid.get_cells_with_effect(EffectId.Id.BURNING), [], "neutralize: burning unregistered from grid index")
	check_eq(grid.get_cells_with_effect(EffectId.Id.SOAKED), [Vector3i(1, 1, 0)], "neutralize: soaked registered in grid index")

func _test_tick_lifecycle() -> void:
	var grid = TestSuite.make_flat_grid(3, 3)
	add_child(grid)
	var executor = _make_executor(grid)
	var tile = grid.get_tile(Vector3i(0, 0, 0))	# NORMAL terrain: burning won't spread/convert
	var context = EffectContext.create(grid, executor)

	await executor.apply_effect(tile, EffectId.Id.SOAKED, 2)
	var inst = tile.get_effect(EffectId.Id.SOAKED)
	check_eq(inst.ticks_active, 0, "tick: fresh instance has 0 ticks")
	check_eq(inst.rounds_remaining, 2, "tick: fresh instance has full duration")

	await executor.process_tick(tile, inst, context, true)
	check_eq(inst.ticks_active, 1, "tick 1: ticks_active incremented")
	check_eq(inst.rounds_remaining, 1, "tick 1: duration decremented")
	check(tile.has_effect(EffectId.Id.SOAKED), "tick 1: effect survives with duration left")

	await executor.process_tick(tile, inst, context, true)
	check_eq(inst.rounds_remaining, 0, "tick 2: duration reached zero")
	check(not tile.has_effect(EffectId.Id.SOAKED), "tick 2: effect removed at zero duration")
	check_eq(grid.get_cells_with_effect(EffectId.Id.SOAKED), [], "tick 2: grid index cleaned up")

func _test_burning_spread_step_by_step() -> void:
	# cross of wood: center burning must spread to exactly the 4 cardinal
	# neighbors after one tick — assert the exact affected set, not just "spread"
	var grid = TestSuite.make_flat_grid(3, 3, BattleTileData.TerrainType.WOOD)
	add_child(grid)
	var executor = _make_executor(grid)
	var context = EffectContext.create(grid, executor)
	var center = grid.get_tile(Vector3i(1, 1, 0))

	await executor.apply_effect(center, EffectId.Id.BURNING)
	check_eq(grid.get_cells_with_effect(EffectId.Id.BURNING).size(), 1, "spread: only origin burning before tick")

	var inst = center.get_effect(EffectId.Id.BURNING)
	await executor.process_tick(center, inst, context, false)	# no duration decrement — isolate spread

	var burning_cells = grid.get_cells_with_effect(EffectId.Id.BURNING)
	var expected = [Vector3i(1, 1, 0), Vector3i(2, 1, 0), Vector3i(0, 1, 0), Vector3i(1, 2, 0), Vector3i(1, 0, 0)]
	for cell in expected:
		check(burning_cells.has(cell), "spread: %s burning after 1 tick" % str(cell))
	check_eq(burning_cells.size(), expected.size(), "spread: EXACTLY the cross is burning (no diagonal leak)")
	var corner = grid.get_tile(Vector3i(0, 0, 0))
	check(not corner.has_effect(EffectId.Id.BURNING), "spread: diagonal corner NOT ignited")

	# threshold consequence: after DURATION_THRESHOLD_TICKS the wood converts to ash and fire dies
	var threshold = EffectRules.DURATION_THRESHOLD_TICKS[EffectId.Id.BURNING]
	while inst.ticks_active < threshold:
		await executor.process_tick(center, inst, context, false)
	check_eq(center.terrain_type, BattleTileData.TerrainType.ASH, "threshold: wood converted to ash at %d ticks" % threshold)
	check(not center.has_effect(EffectId.Id.BURNING), "threshold: burning expired on conversion")

func _test_object_effects() -> void:
	# objects are handled exactly like terrain for effects: they store
	# instances, register in the grid index, and tick via the handler
	var grid = TestSuite.make_flat_grid(2, 2)
	add_child(grid)
	var executor = _make_executor(grid)
	var context = EffectContext.create(grid, executor)

	var object = BattleObject.new()
	add_child(object)
	object.setup(TestSuite.make_object_data(false, 100), Vector3i(0, 0, 0))
	grid.place_object(object, Vector3i(0, 0, 0))

	await executor.apply_effect(object, EffectId.Id.BURNING, 3)
	check(object.has_effect(EffectId.Id.BURNING), "object: stores burning like a tile")
	check_eq(grid.get_objects_with_effect(EffectId.Id.BURNING), [object], "object: registered in grid object index")

	var hp_before = object.data.current_hp
	var inst = object.get_effect(EffectId.Id.BURNING)
	await executor.process_tick(object, inst, context, false)
	check(object.data.current_hp < hp_before, "object: burning tick dealt damage (%d -> %d)" % [hp_before, object.data.current_hp])
