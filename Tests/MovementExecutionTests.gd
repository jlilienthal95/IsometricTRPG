class_name MovementExecutionTests
extends TestSuite

# Integration tests that drive the REAL UnitMover step pipeline with tweens.
# Uses BattleObject actors (no sprite assets required) so the suite runs even
# in an assets-stripped checkout; the pipeline is identical for units since
# UnitMover is actor-generic.

func _init() -> void:
	suite_name = "MovementExecution"

# minimal camera double satisfying UnitMover's pan_to call
class CameraDummy:
	extends Node2D
	var pan_calls: Array = []
	func pan_to(pos: Vector2) -> void:
		pan_calls.append(pos)

func run() -> void:
	await _test_object_slide_execution()
	await _test_damage_events()

func _world_pos(cell: Vector3i) -> Vector2:
	return Vector2(cell.x * 32, cell.y * 32)

func _test_object_slide_execution() -> void:
	var grid = TestSuite.make_flat_grid(3, 1)
	add_child(grid)
	var mover = UnitMover.new()
	add_child(mover)
	mover.setup(grid)
	var camera = CameraDummy.new()
	add_child(camera)

	var barrel = BattleObject.new()
	add_child(barrel)
	barrel.setup(TestSuite.make_object_data(false), Vector3i(0, 0, 0))
	grid.place_object(barrel, Vector3i(0, 0, 0))
	barrel.global_position = _world_pos(Vector3i(0, 0, 0))

	# build a two-step slide path by hand (a barrel rolling two tiles)
	var steps: Array[MovementStep] = []
	for cell in [Vector3i(1, 0, 0), Vector3i(2, 0, 0)]:
		var step = MovementStep.new()
		step.cell = cell
		steps.append(step)

	var completed: Array = []
	mover.movement_complete.connect(func(actor): completed.append(actor))

	mover.execute_movement(barrel, steps, _world_pos, camera)
	# examine the process, not just the outcome: the mover must be mid-flight now
	check(completed.is_empty(), "slide: movement_complete not fired synchronously")

	await mover.movement_complete

	check_eq(completed, [barrel], "slide: movement_complete fired exactly once, with the actor")
	check_eq(barrel.grid_position, Vector3i(2, 0, 0), "slide: actor grid_position at destination")
	check_null(grid.get_tile(Vector3i(0, 0, 0)).object_ref, "slide: origin occupancy cleared")
	check_null(grid.get_tile(Vector3i(1, 0, 0)).object_ref, "slide: intermediate occupancy cleared")
	check_eq(grid.get_tile(Vector3i(2, 0, 0)).object_ref, barrel, "slide: destination occupancy set")
	check_eq(barrel.global_position, _world_pos(Vector3i(2, 0, 0)), "slide: world position matches destination")
	check_eq(camera.pan_calls.size(), 2, "slide: camera panned once per step")
	if camera.pan_calls.size() == 2:
		check_eq(camera.pan_calls[0], _world_pos(Vector3i(1, 0, 0)), "slide: first pan targets step 1")
		check_eq(camera.pan_calls[1], _world_pos(Vector3i(2, 0, 0)), "slide: second pan targets step 2")

	# guard behavior: a second execute while idle works again
	var back: Array[MovementStep] = []
	var s = MovementStep.new()
	s.cell = Vector3i(1, 0, 0)
	back.append(s)
	mover.execute_movement(barrel, back, _world_pos, camera)
	await mover.movement_complete
	check_eq(barrel.grid_position, Vector3i(1, 0, 0), "slide: mover reusable after completion")

func _test_damage_events() -> void:
	var barrel = BattleObject.new()
	add_child(barrel)
	barrel.setup(TestSuite.make_object_data(false, 20), Vector3i.ZERO)

	var events: Array = []
	var on_hp = func(actor, amount, new_hp): events.append([actor, amount, new_hp])
	BattleEvents.hp_changed.connect(on_hp)

	await barrel.apply_damage(5)
	check_eq(events.size(), 1, "events: damage emitted exactly one hp_changed")
	if events.size() >= 1:
		check_eq(events[0][0], barrel, "events: payload carries the actor")
		check_eq(events[0][1], -5, "events: damage amount is negative")
		check_eq(events[0][2], 15, "events: payload carries post-mutation hp")
	check_eq(barrel.data.current_hp, 15, "events: data hp matches payload")

	await barrel.apply_heal(3)
	check_eq(events.size(), 2, "events: heal emitted exactly one hp_changed")
	if events.size() >= 2:
		check_eq(events[1][1], 3, "events: heal amount is positive")
		check_eq(events[1][2], 18, "events: heal payload hp correct")

	await barrel.apply_heal(100)
	check_eq(barrel.data.current_hp, 20, "events: heal clamped at max_hp")

	BattleEvents.hp_changed.disconnect(on_hp)
