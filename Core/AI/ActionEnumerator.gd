class_name ActionEnumerator
extends RefCounted

# generates all legal ActionCandidates

static func enumerate_actions(unit: Unit, origin: BattleTileData, pathfinder: Pathfinder, context: TurnContext) -> Array[ActionCandidate]:
	#TODO take full advantage of turncontext to power this
	
	var actions: Array[ActionCandidate] = []
	# fetch all reachable tiles from pathfinder
	var reachable = get_reachable_tiles(unit, origin, pathfinder)
	# fetch all currently valid abilities qualified with prereqs like mp
	var abilities = get_unit_abilities(unit)
	# TODO: include actions with ability use and no movement
	for tile: Vector3i in reachable:
		#only check tiles with truthy value
		if reachable[tile]:
		# loop through each ability and test if there is a valid target in range
			for ability in abilities:
				context.select_ability(ability, pathfinder, tile)
				for cell in context.reachable_target_cells:
					var action = _generate_action(tile, ability, cell)
					if context.reachable_target_cells[cell]:
						# if there is, create a new ActionCandidate and store it in actions array
						actions.push_back(action)
						#print("action: ", action)
				# create action with no ability use
				actions.push_back(_generate_action(tile, null, Vector3i(999,999,999)))
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
	
static func _generate_action(move_cell: Vector3i, ability: AbilityData, target_cell: Vector3i) -> ActionCandidate:
	var action = ActionCandidate.new()
	action.move_cell = move_cell
	action.ability = ability
	action.target_cell = target_cell
	return action
