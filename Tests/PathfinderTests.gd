class_name PathfinderTests
extends TestSuite

func _init() -> void:
	suite_name = "Pathfinder"

class PathDummyUnit:
	extends Unit
	func _init() -> void:
		data = UnitData.new()
		data.resolve()

func run() -> void:
	_test_movement_range_exact()
	_test_blocking_object()
	_test_walkable_object_passthrough()
	_test_ability_targeting()
	_test_movement_path_steps()

func _make(grid_w: int, grid_h: int) -> Array:
	var grid = TestSuite.make_flat_grid(grid_w, grid_h)
	add_child(grid)
	var pf = Pathfinder.new()
	add_child(pf)
	pf.setup(grid)
	return [grid, pf]

func _move_query(range_val: int) -> RangeQuery:
	var data = UnitData.new()
	data.base_move_range = range_val
	data.resolve()
	return RangeQuery.for_movement(data)

func _test_movement_range_exact() -> void:
	var setup = _make(5, 5)
	var grid: BattleGrid = setup[0]
	var pf: Pathfinder = setup[1]
	var unit = PathDummyUnit.new()
	add_child(unit)
	grid.place_unit(unit, Vector3i(2, 2, 0))

	var cells = pf.get_cells_in_range(Vector3i(2, 2, 0), _move_query(1), unit)
	# range 1 from center of an open 5x5: exactly the 4 cardinals, origin excluded
	var expected = [Vector3i(3, 2, 0), Vector3i(1, 2, 0), Vector3i(2, 3, 0), Vector3i(2, 1, 0)]
	check_eq(cells.size(), 4, "range 1: exactly 4 reachable cells")
	for cell in expected:
		check(cells.has(cell) and cells[cell] == true, "range 1: %s reachable and valid" % str(cell))
	check(not cells.has(Vector3i(2, 2, 0)), "range 1: origin excluded")
	check(not cells.has(Vector3i(3, 3, 0)), "range 1: diagonal unreachable")

func _test_blocking_object() -> void:
	# 3x1 corridor with a barrel in the middle: the far cell must be unreachable
	var setup = _make(3, 1)
	var grid: BattleGrid = setup[0]
	var pf: Pathfinder = setup[1]
	var unit = PathDummyUnit.new()
	add_child(unit)
	grid.place_unit(unit, Vector3i(0, 0, 0))

	var barrel = BattleObject.new()
	add_child(barrel)
	barrel.setup(TestSuite.make_object_data(false), Vector3i(1, 0, 0))
	grid.place_object(barrel, Vector3i(1, 0, 0))

	var cells = pf.get_cells_in_range(Vector3i(0, 0, 0), _move_query(2), unit)
	check(not (cells.has(Vector3i(1, 0, 0)) and cells[Vector3i(1, 0, 0)] == true), "barrel: its cell not a valid destination")
	check(not (cells.has(Vector3i(2, 0, 0)) and cells[Vector3i(2, 0, 0)] == true), "barrel: corridor beyond it unreachable")

func _test_walkable_object_passthrough() -> void:
	var setup = _make(3, 1)
	var grid: BattleGrid = setup[0]
	var pf: Pathfinder = setup[1]
	var unit = PathDummyUnit.new()
	add_child(unit)
	grid.place_unit(unit, Vector3i(0, 0, 0))

	var crate = BattleObject.new()
	add_child(crate)
	crate.setup(TestSuite.make_object_data(true), Vector3i(1, 0, 0))
	grid.place_object(crate, Vector3i(1, 0, 0))

	var cells = pf.get_cells_in_range(Vector3i(0, 0, 0), _move_query(2), unit)
	check(cells.has(Vector3i(1, 0, 0)) and cells[Vector3i(1, 0, 0)] == true, "crate: its cell IS a valid destination")
	check(cells.has(Vector3i(2, 0, 0)) and cells[Vector3i(2, 0, 0)] == true, "crate: corridor beyond it reachable")

func _test_ability_targeting() -> void:
	var setup = _make(3, 1)
	var grid: BattleGrid = setup[0]
	var pf: Pathfinder = setup[1]
	var caster = PathDummyUnit.new()
	add_child(caster)
	grid.place_unit(caster, Vector3i(0, 0, 0))
	var enemy = PathDummyUnit.new()
	add_child(enemy)
	grid.place_unit(enemy, Vector3i(1, 0, 0))
	# enemy: not registered in BattleManager.player_units, so _is_ally == false

	var ability = AbilityData.new()
	ability.min_range = 1
	ability.max_range = 1
	ability.target_type = AbilityData.TargetType.SINGLE_ENEMY
	var query = pf.build_ability_query(ability)

	var cells = pf.get_cells_in_range(Vector3i(0, 0, 0), query, caster)
	check(cells.has(Vector3i(1, 0, 0)) and cells[Vector3i(1, 0, 0)] == true, "targeting: adjacent enemy is a VALID target")
	check(not cells.has(Vector3i(0, 0, 0)), "targeting: caster's own cell never targetable")
	# empty in-range cells appear but are marked invalid for requires_unit
	if cells.has(Vector3i(2, 0, 0)):
		check_eq(cells[Vector3i(2, 0, 0)], false, "targeting: empty in-range cell marked invalid")

func _test_movement_path_steps() -> void:
	var setup = _make(3, 1)
	var grid: BattleGrid = setup[0]
	var pf: Pathfinder = setup[1]
	var unit = PathDummyUnit.new()
	add_child(unit)
	grid.place_unit(unit, Vector3i(0, 0, 0))

	var steps = pf.get_movement_path(Vector3i(0, 0, 0), Vector3i(2, 0, 0), _move_query(3), unit)
	# assert the exact step sequence, not just arrival
	check_eq(steps.size(), 2, "path: two steps for two-cell move")
	if steps.size() == 2:
		check_eq(steps[0].cell, Vector3i(1, 0, 0), "path: first step is the intermediate cell")
		check_eq(steps[1].cell, Vector3i(2, 0, 0), "path: second step is the destination")
		check_eq(steps[0].is_jump, false, "path: flat step not flagged as jump")
		check_eq(steps[0].elevation_delta, 0, "path: flat step has zero elevation delta")
