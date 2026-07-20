class_name AIContext
extends RefCounted

# Bundle of everything considerations need to evaluate the board —
# built fresh by EnemyBrain at the start of each enemy turn, same pattern
# as EffectContext. Read-only by convention: considerations evaluate,
# they never mutate.

var grid: BattleGrid = null
var acting_unit: Unit = null
var profile: AIProfile = null
var pathfinder: Pathfinder = null

# convenience partitions so considerations don't re-derive them per candidate
var player_units: Array[BattleActor] = []
var enemy_units: Array[BattleActor] = []
