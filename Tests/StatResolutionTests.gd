class_name StatResolutionTests
extends TestSuite

func _init() -> void:
	suite_name = "StatResolution"

func run() -> void:
	_test_level_math()
	_test_stat_pipeline_step_by_step()
	_test_no_job_defaults()
	_test_resolve_idempotence()
	_test_equipment_resolution()
	_test_speed_propagation()

func _test_level_math() -> void:
	# verify the exp->level inverse against hand-computed values of
	# floori(pow(exp / BASE_EXP_PER_LEVEL, 1 / BASE_XP_REQ_MOD))
	check_eq(Constants.level_from_xp(Constants.BASE_EXP_PER_LEVEL), 1, "level_from_xp: exactly one level of exp = level 1")
	var lvl_low = Constants.level_from_xp(Constants.BASE_EXP_PER_LEVEL - 1)
	check(lvl_low <= 1, "level_from_xp: below one level of exp never exceeds level 1")
	# monotonicity: more exp never lowers level
	var prev = 0
	var monotonic = true
	for exp in [100, 300, 900, 2700, 9999]:
		var lvl = Constants.level_from_xp(exp)
		if lvl < prev:
			monotonic = false
		prev = lvl
	check(monotonic, "level_from_xp: level is monotonically non-decreasing in exp")

func _test_stat_pipeline_step_by_step() -> void:
	var job = TestSuite.make_job(1.2, 0.8, 1.5, 2.0, 2, 1)
	var data = TestSuite.make_unit_data(job)
	data.base_max_hp = 100
	data.base_max_mp = 20
	data.base_attack = 10
	data.base_defense = 10
	data.base_move_range = 3
	data.base_jump_height = 2
	data.current_exp = Constants.BASE_EXP_PER_LEVEL	# level 1 exactly

	data.resolve()

	# every intermediate output asserted independently — not just "it has stats"
	check_eq(data.current_lvl, 1, "resolve: level derived from exp")
	check_eq(data.max_hp, int(100 * 1.2), "resolve: max_hp = base * job hp_modifier")
	check_eq(data.current_hp, data.max_hp, "resolve: current_hp initialized to max_hp")
	check_eq(data.max_mp, int(20 * 0.8), "resolve: max_mp = base * job mp_modifier")
	check_eq(data.current_mp, data.max_mp, "resolve: current_mp initialized to max_mp")
	check_eq(data.attack, int((10 * 1.5) + (1 * 1.3)), "resolve: attack = base*mod + lvl*1.3")
	check_eq(data.defense, int(10 * 2.0), "resolve: defense = base * job defense_modifier")
	check_eq(data.move_range, 3 + 2, "resolve: move_range = base + flat job bonus")
	check_eq(data.jump_height, 2 + 1, "resolve: jump_height = base + flat job bonus")
	# authored inputs untouched — resource data integrity
	check_eq(data.base_max_hp, 100, "resolve: base_max_hp not mutated")
	check_eq(data.base_attack, 10, "resolve: base_attack not mutated")

func _test_no_job_defaults() -> void:
	var data = TestSuite.make_unit_data(null)
	data.base_max_hp = 50
	data.base_move_range = 3
	data.resolve()
	check_eq(data.max_hp, 50, "no job: hp modifier defaults to 1.0")
	check_eq(data.move_range, 3, "no job: move bonus defaults to 0")
	check_eq(data.speed, JobData.SpeedRank.NORMAL, "no job: speed defaults to NORMAL")

func _test_resolve_idempotence() -> void:
	var job = TestSuite.make_job(1.5)
	var data = TestSuite.make_unit_data(job)
	data.base_max_hp = 100
	data.resolve()
	var first_max = data.max_hp
	data.resolve()
	check_eq(data.max_hp, first_max, "resolve twice: identical result (no compounding on base stats)")
	check_eq(data.base_max_hp, 100, "resolve twice: base still untouched")

func _test_equipment_resolution() -> void:
	var data = TestSuite.make_unit_data(null)
	var sword = EquipmentData.new()
	sword.equipment_name = "Sword"
	sword.equipment_id = 7
	sword.equipment_type = EquipmentData.Type.WEAPON
	var armor = EquipmentData.new()
	armor.equipment_name = "Armor"
	armor.equipment_id = 8
	armor.equipment_type = EquipmentData.Type.ARMOR
	data.equipped_weapon = sword
	data.equipped_armor = armor
	data.resolve()
	check_eq(data.equipment.size(), 2, "equipment: both slots resolved into flat list")
	check_eq(data.get_equipped_by_type(EquipmentData.Type.WEAPON), sword, "equipment: weapon lookup by type")
	check_eq(data.get_equipped_by_type(EquipmentData.Type.ARMOR), armor, "equipment: armor lookup by type")
	check_null(data.get_equipped_by_type(EquipmentData.Type.BOOTS), "equipment: empty slot lookup returns null")
	check_eq(data.get_equipped_ids(), [7, 8, -1, -1, -1], "equipment: id serialization matches slots (empty = -1)")
	data.unequip(EquipmentData.Type.WEAPON)
	check_null(data.equipped_weapon, "unequip: slot cleared")
	check_eq(data.equipment.size(), 1, "unequip: flat list re-resolved")

func _test_speed_propagation() -> void:
	var job = TestSuite.make_job(1.0, 1.0, 1.0, 1.0, 0, 0, JobData.SpeedRank.FAST)
	var data = TestSuite.make_unit_data(job)
	data.resolve()
	check_eq(data.speed, JobData.SpeedRank.FAST, "speed: job rank propagates to unit")

func _test_material_resistances() -> void:
	pass
