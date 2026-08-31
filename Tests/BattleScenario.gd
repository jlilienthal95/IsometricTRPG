class_name BattleScenario
extends RefCounted

# Describes one battle to spawn for testing. Contains no grid cells — cell
# assignment happens at spawn time against whichever grid actually got built,
# since the scenario is generated before the map (and its walkable cells) exist.

var seed_value: int = 0
var map_scene_path: String = ""
var is_stress_test: bool = false
var description: String = ""

# each entry: { "unit_data": UnitData, "seed_effect": EffectId.Id }
# seed_effect seeds INITIAL battlefield state directly onto the unit's data,
# distinct from pipeline-driven effect application (which is exercised
# separately whenever the synthetic player / AI uses an ability with rider
# effects, e.g. Flame applying BURNING through the real EffectExecutor path).
var player_unit_specs: Array[Dictionary] = []
var enemy_unit_specs: Array[Dictionary] = []

var object_specs: Array[BattleObjectData] = []
