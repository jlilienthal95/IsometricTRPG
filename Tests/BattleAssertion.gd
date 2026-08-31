class_name BattleAssertion
extends RefCounted

# Collects pass/fail results for one scenario run. Two kinds of checks:
# - reactive invariants, subscribed to BattleEvents for the scenario's whole
#   lifetime (e.g. "hp never negative", "actor_defeated fires at most once")
# - explicit checkpoint checks, called by BattleTestRunner at specific points
#   (turn boundaries, battle end) since those require broader context this
#   class doesn't own (the grid, the unit list, etc.)

var results: Array[Dictionary] = []	# {label, passed, detail}

var _grid: BattleGrid = null
var _turn_queue: TurnQueue = null
var _director: CinematicDirector = null

var _actor_defeated_ids: Array = []

func _init(grid: BattleGrid, turn_queue: TurnQueue, director: CinematicDirector) -> void:
	_grid = grid
	_turn_queue = turn_queue
	_director = director
	BattleEvents.hp_changed.connect(_on_hp_changed)
	BattleEvents.actor_defeated.connect(_on_actor_defeated)

func teardown() -> void:
	if BattleEvents.hp_changed.is_connected(_on_hp_changed):
		BattleEvents.hp_changed.disconnect(_on_hp_changed)
	if BattleEvents.actor_defeated.is_connected(_on_actor_defeated):
		BattleEvents.actor_defeated.disconnect(_on_actor_defeated)

func check(condition: bool, label: String, detail: String = "") -> void:
	results.append({"label": label, "passed": condition, "detail": detail})

# =============================================================================
# REACTIVE INVARIANTS
# =============================================================================

func _on_hp_changed(actor, _amount: int, new_hp: int) -> void:
	check(new_hp >= 0, "hp_changed: new_hp never negative", "actor=%s new_hp=%d" % [str(actor), new_hp])
	if actor is Unit:
		check(new_hp <= actor.data.max_hp, "hp_changed: unit new_hp never exceeds max_hp",
			"%s new_hp=%d max=%d" % [actor.data.name, new_hp, actor.data.max_hp])
	elif actor is BattleObject:
		check(new_hp <= actor.data.max_hp, "hp_changed: object new_hp never exceeds max_hp",
			"%s new_hp=%d max=%d" % [actor.data.object_name, new_hp, actor.data.max_hp])

func _on_actor_defeated(actor) -> void:
	var id: int = actor.get_instance_id()
	check(not _actor_defeated_ids.has(id), "actor_defeated fires at most once per actor", str(actor))
	_actor_defeated_ids.append(id)

# =============================================================================
# CHECKPOINT ASSERTIONS — called explicitly by BattleTestRunner
# =============================================================================

func assert_unit_integrity(unit: Unit) -> void:
	var d := unit.data
	check(d.current_hp >= 0 and d.current_hp <= d.max_hp,
		"unit HP within bounds", "%s hp=%d/%d" % [d.name, d.current_hp, d.max_hp])
	check(d.current_mp >= 0 and d.current_mp <= d.max_mp,
		"unit MP within bounds", "%s mp=%d/%d" % [d.name, d.current_mp, d.max_mp])
	check(d.is_dead == (d.current_hp == 0),
		"unit is_dead matches hp==0", "%s is_dead=%s hp=%d" % [d.name, str(d.is_dead), d.current_hp])
	if d.is_dead:
		check(d.active_effects.is_empty(),
			"dead unit carries no lingering effects", "%s effect_count=%d" % [d.name, d.active_effects.size()])

func assert_object_integrity(object: BattleObject) -> void:
	var d := object.data
	check(d.current_hp >= 0 and d.current_hp <= d.max_hp,
		"object HP within bounds", "%s hp=%d/%d" % [d.object_name, d.current_hp, d.max_hp])
	check(d.is_dead == (d.current_hp == 0),
		"object is_dead matches hp==0", d.object_name)
	if d.is_dead:
		check(_grid.get_object_at(object.grid_position) != object,
			"dead object removed from grid", "%s at %s" % [d.object_name, str(object.grid_position)])
		check(d.active_effects.is_empty(),
			"dead object carries no lingering effects", d.object_name)

# a dead unit must never be the one currently taking a turn
func assert_active_unit_not_dead() -> void:
	var active = BattleManager.active_unit
	check(active == null or not (active is Unit and active.data.is_dead),
		"active_unit is never a dead unit", str(active))

func assert_state_valid(state) -> void:
	check(BattleManager.BattleState.values().has(state),
		"battle state is a recognized enum value", str(state))

func assert_sequence_depth_zero(context_label: String) -> void:
	var depth: int = _director.get_sequence_depth()
	check(depth == 0, "cinematic sequence_depth returns to 0: " + context_label, "depth=%d" % depth)

func assert_battle_end(won: bool, player_units: Array, enemy_units: Array) -> void:
	if won:
		check(enemy_units.all(func(u): return u.data.is_dead), "win: all enemies defeated")
		check(player_units.any(func(u): return not u.data.is_dead), "win: at least one player unit survives")
	else:
		check(player_units.all(func(u): return u.data.is_dead), "loss: all player units defeated")
	check(BattleManager.current_state == BattleManager.BattleState.BATTLE_END,
		"battle_end: state machine reflects BATTLE_END")

# =============================================================================
# SUMMARY
# =============================================================================

func passed_count() -> int:
	return results.filter(func(r): return r.passed).size()

func failed_count() -> int:
	return results.size() - passed_count()

func failures() -> Array[Dictionary]:
	return results.filter(func(r): return not r.passed)
