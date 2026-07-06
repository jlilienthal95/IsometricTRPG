class_name EffectContext
extends RefCounted

var grid: BattleGrid
var round_number: int = 0
var executor: EffectExecutor

static func create(grid: BattleGrid, executor: EffectExecutor, round_number: int = 0) -> EffectContext:
	var context = EffectContext.new()
	context.grid = grid
	context.executor = executor
	context.round_number = round_number
	return context
