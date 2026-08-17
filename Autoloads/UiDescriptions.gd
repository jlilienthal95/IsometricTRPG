extends Node

enum action_description {
	MOVE,
	ABILITIES,
	EQUIPMENT,
	WAIT,
	FIGHT,
	JOB_ABILITY,
	ITEMS,
}

func get_action_description(action: action_description) -> String:
	match action:
		action_description.MOVE:
			return "Select a new tile and move this unit to a new position."
		action_description.ABILITIES:
			return "Open the abilities menu and initiate an action."
		action_description.EQUIPMENT:
			return "Open the equipment menu to view this unit's active equipment."
		action_description.WAIT:
			return "End this unit's turn immediately."
		action_description.FIGHT:
			return "A basic attack using this unit's equipped weapon."
		action_description.JOB_ABILITY:
			return "Open the Job Abilities menu and access this unit's unique actions."
		action_description.ITEMS:
			return "Open the Items menu and use a consumable item with special effects."
		_:
			return ""
