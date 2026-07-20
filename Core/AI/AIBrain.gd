class_name AIBrain
extends Node
# orchestrator node — listens for ENEMY_TURN


var _grid: BattleGrid = null
var _pathfinder: Pathfinder = null
var _turn_queue: TurnQueue = null
var _unit_mover: UnitMover = null
var _unit_ability_executor: UnitAbilityExecutor = null
var _cursor: Cursor = null
var _input_handler: InputHandler = null

var _current_context: TurnContext = null

const default_delay: float = 1.5

func setup(grid: BattleGrid, pathfinder: Pathfinder, turn_queue: TurnQueue, unit_mover: UnitMover, unit_ability_executor: UnitAbilityExecutor, cursor: Cursor, input_handler: InputHandler) -> void:
	_grid = grid
	_pathfinder = pathfinder
	_turn_queue = turn_queue
	_unit_mover = unit_mover
	_unit_ability_executor = unit_ability_executor
	_cursor = cursor
	_input_handler = input_handler
	
	BattleManager.active_unit_changed.connect(_on_active_unit_changed, CONNECT_DEFERRED)
	
func refresh_context(context: TurnContext) -> void:
	_current_context = context
	
func _on_active_unit_changed(actor: Unit) -> void:
	if not actor.data.is_player_controlled:
		_simulate_cell_hover(actor.grid_position)
		var players = _turn_queue.get_all_player_units()
		var enemies = _turn_queue.get_all_enemy_units()
		var ai_context: AIContext = _build_ai_context(_grid, actor, _pathfinder, players, enemies)
		var origin: BattleTileData = _grid.get_tile(actor.grid_position)
		# use ActionEnumerator to return all valid ActionCandidates and their scores
		var actions: Array[ActionCandidate] = ActionEnumerator.enumerate_actions(actor, origin, _pathfinder, _current_context)
		# check if minimum viable ActionCandidates are present
		# fetch intelligence level from ai_turn_context.profile.intelligence
		# match intelligence level to appropriate filter for ActionCandidates
		# select appropriate action candidate
		var current_action = actions[0]
		# execute ActionCandidate
		if actor.can_move():
			print("current move cell: ", current_action.move_cell)
			print("current ability: ", current_action.ability)
			print("current target cell: ", current_action.target_cell)
			await _add_delay(default_delay)
			BattleManager.change_state(BattleManager.BattleState.MOVE_SELECT)
			await _add_delay(default_delay)
			_simulate_cell_hover(current_action.move_cell)
			await _add_delay(default_delay)
			await BattleManager.confirm_move(current_action.move_cell)
		
		if actor.can_act():	
			if current_action.ability:
				await _add_delay(default_delay)
				BattleManager.change_state(BattleManager.BattleState.ABILITIES_SELECT)			
				BattleManager.select_ability(current_action.ability)
			
				await _add_delay(default_delay)
				print("target cell: ", current_action.target_cell)
				print("unit at target cell:", _grid.get_unit_at(current_action.target_cell).name)
				_simulate_cell_hover(current_action.target_cell)
				await _add_delay(default_delay)
				BattleManager.confirm_target(current_action.target_cell)
		
		#TODO: put in separate function and power by listening for action and move consumed		
		await get_tree().create_timer(5).timeout
		BattleManager.end_turn()

		# build AIContext - use AIProfile from Unit or Job data
func _build_ai_context(grid: BattleGrid, acting_unit: Unit, pathfinder: Pathfinder, player_units: Array[BattleActor], enemy_units: Array[BattleActor]) -> AIContext:
	var context = AIContext.new()
	context.grid = grid
	context.acting_unit = acting_unit
	context.profile = acting_unit.data.get_ai_profile()
	context.pathfinder = pathfinder
	context.player_units = player_units
	context.enemy_units = enemy_units
	return context

func _add_delay(seconds: float) -> void:
	#await get_tree().create_timer(seconds).timeout
	pass
	
func _simulate_cell_hover(cell: Vector3i) -> void:
	_input_handler.emit_signal("cell_hovered", Vector2i(cell.x, cell.y))
