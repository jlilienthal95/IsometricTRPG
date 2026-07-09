class_name GridObjectTests
extends TestSuite

func _init() -> void:
	suite_name = "GridAndObjects"

var _occupancy_signal_count: int = 0

func run() -> void:
	_test_unit_placement_and_movement()
	_test_object_walkability()
	_test_unit_and_walkable_object_coexist()
	_test_move_actor_object()
	await _test_object_destruction()

func _count_signal(_tile) -> void:
	_occupancy_signal_count += 1

# a "unit" for grid bookkeeping tests only needs grid_position — using a real
# Unit scene would drag in sprite assets this suite doesn't test
class GridDummyUnit:
	extends Unit
	func _init() -> void:
		data = UnitData.new()

func _test_unit_placement_and_movement() -> void:
	var grid = TestSuite.make_flat_grid(3, 1)
	add_child(grid)
	_occupancy_signal_count = 0
	grid.tile_occupancy_changed.connect(_count_signal)

	var unit = GridDummyUnit.new()
	var a = Vector3i(0, 0, 0)
	var b = Vector3i(1, 0, 0)

	grid.place_unit(unit, a)
	# every intermediate: tile ref, back-reference, signal, occupancy query
	check_eq(grid.get_tile(a).unit_ref, unit, "place: tile holds unit ref")
	check_eq(unit.grid_position, a, "place: unit grid_position updated")
	check_eq(_occupancy_signal_count, 1, "place: occupancy signal fired exactly once")
	check(grid.is_cell_occupied(a), "place: cell reports occupied")

	grid.move_actor(unit, a, b)
	check_null(grid.get_tile(a).unit_ref, "move: origin tile cleared")
	check_eq(grid.get_tile(b).unit_ref, unit, "move: destination tile holds unit")
	check_eq(unit.grid_position, b, "move: unit grid_position updated")
	check_eq(_occupancy_signal_count, 3, "move: occupancy fired for both tiles")
	check(not grid.is_cell_occupied(a), "move: origin no longer occupied")
	check(grid.is_cell_occupied(b), "move: destination occupied")
	unit.free()

func _test_object_walkability() -> void:
	var grid = TestSuite.make_flat_grid(2, 1)
	add_child(grid)

	var barrel = BattleObject.new()
	add_child(barrel)
	barrel.setup(TestSuite.make_object_data(false), Vector3i(0, 0, 0))
	grid.place_object(barrel, Vector3i(0, 0, 0))

	var crate = BattleObject.new()
	add_child(crate)
	crate.setup(TestSuite.make_object_data(true), Vector3i(1, 0, 0))
	grid.place_object(crate, Vector3i(1, 0, 0))

	# blocking semantics asserted from BOTH query surfaces (walkability + occupancy)
	check(not grid.is_walkable(Vector3i(0, 0, 0)), "barrel: tile not walkable")
	check(grid.is_cell_occupied(Vector3i(0, 0, 0)), "barrel: tile counts as occupied")
	check(grid.is_walkable(Vector3i(1, 0, 0)), "crate: tile stays walkable")
	check(not grid.is_cell_occupied(Vector3i(1, 0, 0)), "crate: tile does NOT count as occupied")
	check_eq(grid.get_object_at(Vector3i(1, 0, 0)), crate, "crate: still queryable as object")
	check_eq(grid.get_actor_at(Vector3i(1, 0, 0)), crate, "crate: get_actor_at finds it")

func _test_unit_and_walkable_object_coexist() -> void:
	var grid = TestSuite.make_flat_grid(1, 1)
	add_child(grid)
	var crate = BattleObject.new()
	add_child(crate)
	crate.setup(TestSuite.make_object_data(true), Vector3i(0, 0, 0))
	grid.place_object(crate, Vector3i(0, 0, 0))

	var unit = GridDummyUnit.new()
	grid.place_unit(unit, Vector3i(0, 0, 0))
	var tile = grid.get_tile(Vector3i(0, 0, 0))
	check_eq(tile.unit_ref, unit, "coexist: tile holds unit")
	check_eq(tile.object_ref, crate, "coexist: tile still holds crate")
	check_eq(grid.get_actor_at(Vector3i(0, 0, 0)), unit, "coexist: unit takes actor priority")
	unit.free()

func _test_move_actor_object() -> void:
	var grid = TestSuite.make_flat_grid(2, 1)
	add_child(grid)
	var barrel = BattleObject.new()
	add_child(barrel)
	barrel.setup(TestSuite.make_object_data(false), Vector3i(0, 0, 0))
	grid.place_object(barrel, Vector3i(0, 0, 0))

	grid.move_actor(barrel, Vector3i(0, 0, 0), Vector3i(1, 0, 0))
	check_null(grid.get_tile(Vector3i(0, 0, 0)).object_ref, "object move: origin cleared")
	check_eq(grid.get_tile(Vector3i(1, 0, 0)).object_ref, barrel, "object move: destination set")
	check_eq(barrel.grid_position, Vector3i(1, 0, 0), "object move: grid_position updated")

func _test_object_destruction() -> void:
	var grid = TestSuite.make_flat_grid(1, 1)
	add_child(grid)
	var barrel = BattleObject.new()
	add_child(barrel)
	barrel.setup(TestSuite.make_object_data(false, 10), Vector3i(0, 0, 0))
	grid.place_object(barrel, Vector3i(0, 0, 0))

	var defeated: Array = []
	var on_defeat = func(actor): defeated.append(actor)
	BattleEvents.actor_defeated.connect(on_defeat)

	await barrel.apply_damage(4)
	check_eq(barrel.data.current_hp, 6, "destruction: partial damage applied exactly")
	check(not barrel.data.is_dead, "destruction: object alive above 0 hp")
	check(grid.is_cell_occupied(Vector3i(0, 0, 0)), "destruction: still occupies while alive")

	await barrel.apply_damage(6)
	check_eq(barrel.data.current_hp, 0, "destruction: hp floored at 0")
	check(barrel.data.is_dead, "destruction: object flagged dead")
	check_eq(defeated, [barrel], "destruction: actor_defeated fired exactly once with the object")
	check_null(grid.get_tile(Vector3i(0, 0, 0)).object_ref, "destruction: removed from grid")
	check(not grid.is_cell_occupied(Vector3i(0, 0, 0)), "destruction: cell freed")
	BattleEvents.actor_defeated.disconnect(on_defeat)
