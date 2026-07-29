class_name ActionEnumerator
extends RefCounted

# generates all legal ActionCandidates

static func enumerate_actions(unit: Unit, origin: BattleTileData, pathfinder: Pathfinder, context: TurnContext) -> Array[ActionCandidate]:
	#TODO take full advantage of turncontext to power this
	
	var actions: Array[ActionCandidate] = []
	# fetch all reachable tiles from pathfinder + origin
	var reachable = get_reachable_tiles(unit, origin, pathfinder)
	# fetch all currently valid abilities qualified with prereqs like mp
	var abilities = get_unit_abilities(unit)

	for move_tile: Vector3i in reachable:
		#only check tiles with truthy value
		if reachable[move_tile]:
		# loop through each ability and test if there is a valid target in range
			for ability in abilities:
				context.select_ability(ability, pathfinder, move_tile)
				for target_tile in context.reachable_target_cells:
					if context.reachable_target_cells[target_tile]:
						var action = _generate_action(move_tile, ability, target_tile)
						# if there is, create a new ActionCandidate and store it in actions array
						actions.push_back(action)
						#print("action: ", action)
			# create action with no ability use for each move_tile
			actions.push_back(_generate_action(move_tile, null, Vector3i(999,999,999)))
	
	# generate actions with ability use from origin tile, and subsequent move
	for ability in abilities:
		#select_ability uses origin tile by default if no third arg exists
		context.select_ability(ability, pathfinder)
		print("ability: ", ability.ability_name, " targets: ", context.reachable_target_cells.size(), " valid: ", context.reachable_target_cells.values().count(true))
		# loop through target_tiles from origin tile
		for target_tile in context.reachable_target_cells:
			if context.reachable_target_cells[target_tile]:
				# if valid target exists, loop through move_tiles from reachable
				for move_tile in reachable:
					# create action for each viable move AFTER ability and store it in actions array. Set acts_first to true
					var action = _generate_action(move_tile, ability, target_tile, true)
					actions.push_back(action)
					#print("action: ", action)
	return actions

static func get_reachable_tiles(unit: Unit, origin: BattleTileData, pathfinder: Pathfinder) -> Dictionary:
	var query = RangeQuery.for_movement(unit.data)
	var reachable = pathfinder.get_cells_in_range(origin.cell, query, unit)
	return reachable
	
static func get_unit_abilities(unit: Unit) -> Array[AbilityData]:
	var possible_abilities = unit.data.abilities
	var abilities: Array[AbilityData] = []
	
	abilities.push_back(unit.data.job.fight_ability)
	for ability: AbilityData in possible_abilities:
		# check any ability reqs before adding to list
		if unit.data.current_mp >= ability.mp_cost:
			abilities.push_back(ability)
	return abilities
	
static func _generate_action(move_cell: Vector3i, ability: AbilityData, target_cell: Vector3i, acts_first: bool = false) -> ActionCandidate:
	var action = ActionCandidate.new()
	action.move_cell = move_cell
	action.ability = ability
	action.target_cell = target_cell
	action.acts_first = acts_first
	return action
