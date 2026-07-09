class_name TestSuite
extends Node

# Base class for all test suites. Non-assumptive testing contract:
# never assert only the final outcome — assert every intermediate state a
# process passes through, so a passing test proves the mechanism, not a
# coincidence. Helpers below are designed for that: check every step, and
# failures report expected vs actual with a label describing the step.

var suite_name: String = "TestSuite"
var results: Array = []	# { label: String, passed: bool, detail: String }

func run() -> void:
	push_error("TestSuite.run() not overridden in " + suite_name)

func check(condition: bool, label: String, detail: String = "") -> void:
	results.append({ "label": label, "passed": condition, "detail": detail })

func check_eq(actual, expected, label: String) -> void:
	var passed = actual == expected
	var detail = "" if passed else "expected %s, got %s" % [str(expected), str(actual)]
	results.append({ "label": label, "passed": passed, "detail": detail })

func check_ne(actual, not_expected, label: String) -> void:
	var passed = actual != not_expected
	var detail = "" if passed else "value should not equal %s" % str(not_expected)
	results.append({ "label": label, "passed": passed, "detail": detail })

func check_null(value, label: String) -> void:
	check_eq(value, null, label)

func check_not_null(value, label: String) -> void:
	var passed = value != null
	results.append({ "label": label, "passed": passed, "detail": "" if passed else "value was null" })

func skip(label: String, reason: String) -> void:
	results.append({ "label": label + " [SKIPPED]", "passed": true, "detail": reason })

func passed_count() -> int:
	var n = 0
	for r in results:
		if r.passed:
			n += 1
	return n

func failed_count() -> int:
	return results.size() - passed_count()

# =============================================================================
# SHARED FIXTURES
# =============================================================================

# builds a flat rectangular grid of walkable NORMAL tiles at elevation 0,
# spanning x in [0, width) and y in [0, height)
static func make_flat_grid(width: int, height: int, terrain: BattleTileData.TerrainType = BattleTileData.TerrainType.NORMAL) -> BattleGrid:
	var grid = BattleGrid.new()
	for x in range(width):
		for y in range(height):
			var tile = BattleTileData.new()
			tile.terrain_type = terrain
			tile.is_walkable = true
			grid.add_tile(Vector3i(x, y, 0), tile)
	return grid

static func make_job(hp_mod: float = 1.0, mp_mod: float = 1.0, atk_mod: float = 1.0, def_mod: float = 1.0, move_bonus: int = 0, jump_bonus: int = 0, speed: JobData.SpeedRank = JobData.SpeedRank.NORMAL) -> JobData:
	var job = JobData.new()
	job.job_name = "TestJob"
	job.hp_modifier = hp_mod
	job.mp_modifier = mp_mod
	job.attack_modifier = atk_mod
	job.defense_modifier = def_mod
	job.move_range_bonus = move_bonus
	job.jump_height_bonus = jump_bonus
	job.speed_rank = speed
	return job

static func make_unit_data(job: JobData = null) -> UnitData:
	var data = UnitData.new()
	data.unit_name = "TestUnit"
	data.job = job
	return data

static func make_object_data(walkable: bool, hp: int = 10) -> ObjectData:
	var data = ObjectData.new()
	data.object_name = "TestObject"
	data.is_walkable = walkable
	data.base_max_hp = hp
	return data

# instantiates a real Unit scene if its assets are available; returns null otherwise
# (the project zip omits assets, so integration tests self-skip gracefully)
static func try_make_unit(parent: Node, data: UnitData, grid: BattleGrid, cell: Vector3i) -> Unit:
	if not ResourceLoader.exists("res://Scenes/Battle/Unit.tscn"):
		return null
	var unit: Unit = load("res://Scenes/Battle/Unit.tscn").instantiate()
	data.resolve()
	parent.add_child(unit)
	unit.setup(data, cell)
	grid.place_unit(unit, cell)
	return unit
