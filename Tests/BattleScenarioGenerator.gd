class_name BattleScenarioGenerator
extends RefCounted

const MIN_PLAYER_UNITS := 1
const MAX_PLAYER_UNITS := 8
const MIN_ENEMY_UNITS := 1
const MAX_ENEMY_UNITS := 20
const MAX_OBJECTS := 6

# scan this directory for additional test maps; falls back to the default
# battle map if the directory doesn't exist yet or is empty
const MAPS_DIR := "res://Tests/TestMaps/"
const DEFAULT_MAP := "res://Scenes/Battle/testmap.tscn"

# effects safe to pre-seed on a unit at battle start, to fuzz "already
# afflicted" scenarios (independent from pipeline-driven application)
const SEEDABLE_EFFECTS: Array = [
	EffectId.Id.BURNING,
	EffectId.Id.SOAKED,
	EffectId.Id.REDHOT,
	EffectId.Id.ELECTRIFIED,
]

static func generate(rng_seed: int, stress: bool = false) -> BattleScenario:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	var scenario := BattleScenario.new()
	scenario.seed_value = rng_seed
	scenario.is_stress_test = stress
	scenario.map_scene_path = _pick_map(rng)

	var player_count: int = MAX_PLAYER_UNITS if stress else rng.randi_range(MIN_PLAYER_UNITS, MAX_PLAYER_UNITS)
	var enemy_count: int = MAX_ENEMY_UNITS if stress else rng.randi_range(MIN_ENEMY_UNITS, MAX_ENEMY_UNITS)
	var object_count: int = MAX_OBJECTS if stress else rng.randi_range(0, MAX_OBJECTS)

	for i in range(player_count):
		scenario.player_unit_specs.append(_generate_unit_spec(rng, "Player_%d" % i, true))
	for i in range(enemy_count):
		scenario.enemy_unit_specs.append(_generate_unit_spec(rng, "Enemy_%d" % i, false))
	for i in range(object_count):
		scenario.object_specs.append(_generate_object(rng, i))

	scenario.description = "seed=%d players=%d enemies=%d objects=%d stress=%s map=%s" % [
		rng_seed, player_count, enemy_count, object_count, str(stress), scenario.map_scene_path
	]
	return scenario

static func _pick_map(rng: RandomNumberGenerator) -> String:
	var dir := DirAccess.open(MAPS_DIR)
	var maps: Array[String] = []
	if dir != null:
		dir.list_dir_begin()
		var file := dir.get_next()
		while file != "":
			if file.ends_with(".tscn"):
				maps.append(MAPS_DIR + file)
			file = dir.get_next()
		dir.list_dir_end()
	if maps.is_empty():
		return DEFAULT_MAP
	return maps[rng.randi_range(0, maps.size() - 1)]

static func _generate_unit_spec(rng: RandomNumberGenerator, unit_name: String, is_player: bool) -> Dictionary:
	var data := _generate_unit_data(rng, unit_name, is_player)
	var seed_effect: int = EffectId.Id.NONE
	if rng.randf() < 0.15 and not SEEDABLE_EFFECTS.is_empty():
		seed_effect = SEEDABLE_EFFECTS[rng.randi_range(0, SEEDABLE_EFFECTS.size() - 1)]
	return {"unit_data": data, "seed_effect": seed_effect}

static func _generate_unit_data(rng: RandomNumberGenerator, unit_name: String, is_player: bool) -> UnitData:
	var data: UnitData = UnitData.new()
	data.name = unit_name
	data.type = BattleActorData.Type.PLAYER if is_player else BattleActorData.Type.ENEMY
	data.is_player_controlled = is_player

	if not JobRegistry.JOBS.is_empty():
		data.job = JobRegistry.JOBS[rng.randi_range(0, JobRegistry.JOBS.size() - 1)]

	data.base_max_hp = rng.randi_range(30, 80)
	data.base_max_mp = rng.randi_range(5, 20)
	data.base_attack = rng.randi_range(5, 15)
	data.base_defense = rng.randi_range(2, 10)
	data.base_move_range = rng.randi_range(2, 5)
	data.base_jump_height = rng.randi_range(1, 3)
	data.current_exp = Constants.BASE_EXP_PER_LEVEL * rng.randi_range(1, 5)

	if not EquipmentRegistry.EQUIPMENT.is_empty():
		var weapons: Array = EquipmentRegistry.EQUIPMENT.filter(func(e): return e.equipment_type == EquipmentData.Type.WEAPON)
		var armors: Array = EquipmentRegistry.EQUIPMENT.filter(func(e): return e.equipment_type == EquipmentData.Type.ARMOR)
		if not weapons.is_empty() and rng.randf() < 0.8:
			data.equipped_weapon = weapons[rng.randi_range(0, weapons.size() - 1)]
		if not armors.is_empty() and rng.randf() < 0.8:
			data.equipped_armor = armors[rng.randi_range(0, armors.size() - 1)]

	if data.job != null and not data.job.abilities.is_empty():
		var pool: Array = data.job.abilities.duplicate()
		# NOTE: uses global RNG, acceptable here since ability selection order
		# doesn't need to be reproducible independent of the wider test run
		pool.shuffle()
		var take: int = mini(pool.size(), rng.randi_range(0, 2))
		for i in range(take):
			data.granted_abilities.append(pool[i])

	return data

static func _generate_object(rng: RandomNumberGenerator, index: int) -> ObjectData:
	var data := ObjectData.new()
	data.object_name = "TestObject_%d" % index
	data.is_walkable = rng.randf() < 0.5
	data.is_movable = rng.randf() < 0.7
	data.base_max_hp = rng.randi_range(10, 50)
	data.defense = rng.randi_range(0, 5)
	return data
