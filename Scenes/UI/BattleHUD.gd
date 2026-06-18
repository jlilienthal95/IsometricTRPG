class_name BattleHUD
extends Control

#ACTION MENU - main battle menu, choose between Move, Abilities, Equipment, and Wait
@onready var action_menu = $ActionMenu
#ACTION BUTTONS
@onready var move_button = $ActionMenu/VBoxContainer/MoveButton
@onready var abilities_button = $ActionMenu/VBoxContainer/AbilitiesButton
@onready var equipment_button = $ActionMenu/VBoxContainer/EquipmentButton
@onready var wait_button = $ActionMenu/VBoxContainer/WaitButton

#EQUIPMENT MENU - generated at runtime displaying equipment equipped by active unit
@onready var equipment_menu = $EquipmentMenu
@onready var equipment_vbox: VBoxContainer = $EquipmentMenu/EquipmentScroll/VBoxContainer

#ABILITIES MENU - choose between Fight, Job Abilities, or Items
@onready var abilities_menu = $AbilitiesMenu
#ABULTIES BUTTONS
@onready var fight_button = $AbilitiesMenu/VBoxContainer/FightButton
@onready var job_ability_button = $AbilitiesMenu/VBoxContainer/JobActionButton
@onready var items_button: Button = $AbilitiesMenu/VBoxContainer/ItemsButton

#INVENTORY MENU
#TODO create inventory list of buttons representing items available for use in battle

#JOB ABILITY MENU - generated at runtime displaying abilities available to cast by active unit
@onready var job_ability_menu = $JobAbilityMenu
@onready var job_ability_vbox: VBoxContainer = $JobAbilityMenu/JobAbilityScroll/VBoxContainer


const DISABLED_OPACITY = 0.4
const ENABLED_OPACITY = 1.0
const ENABLED_COLOR = Color(1, 1, 1, ENABLED_OPACITY)
const DISABLED_COLOR = Color(1, 1, 1, DISABLED_OPACITY)

var _active_unit: Unit = null
var _fight_ability: AbilityData = null

# connects all HUD buttons to BattleManager actions and hides all menus
# TODO: replace hardcoded Fight ability with proper AbilityRegistry lookup
func setup(battle_manager: BattleManager) -> void:
	battle_manager.state_changed.connect(_on_state_changed)
	#ACTION MENU
	move_button.pressed.connect(battle_manager.select_action_move)
	abilities_button.pressed.connect(battle_manager.select_action_abilities)
	equipment_button.pressed.connect(battle_manager.select_action_equipment)
	wait_button.pressed.connect(battle_manager.end_turn)
	
	#ABILITIES MENU
	fight_button.pressed.connect(_on_fight_pressed)
	job_ability_button.pressed.connect(battle_manager.select_job_ability)
	
	#EQUIPMENT MENU
	
	_hide_menu()

# refreshes button states from the active unit's current data
func refresh() -> void:
	if _active_unit == null:
		return
	if _active_unit.data.has_moved:
		move_button.disabled = true
		move_button.modulate = DISABLED_COLOR
	else:
		move_button.disabled = false
		move_button.modulate = ENABLED_COLOR
	if _active_unit.data.has_acted:
		abilities_button.disabled = true
		abilities_button.modulate = DISABLED_COLOR
	else:
		abilities_button.disabled = false
		abilities_button.modulate = ENABLED_COLOR
		
# updates the active unit reference and refreshes button states
func on_turn_changed(unit: Unit) -> void:
	_active_unit = unit
	_reset_turn()
	_generate_equipment_buttons(_active_unit.data.equipped_items)
	_generate_job_ability_buttons(_active_unit.data.abilities)
	_update_fight_ability()
	
# dynamically creates buttons for each equipped item in the equipment menu
func _generate_equipment_buttons(items: Array[ItemData]) -> void:
	for item in items:
		var button = Button.new()
		button.text = item.item_name
		button.custom_minimum_size.x = 335
		button.custom_minimum_size.y = 60
		equipment_vbox.add_child(button)
		
func _generate_job_ability_buttons(abilities: Array[AbilityData]) -> void:
	for ability in abilities:
		print("ability: ", ability)
		var ability_name: String = ability.ability_name.replace("_", " ")
		var button = Button.new()
		button.text = ability_name
		button.custom_minimum_size.x = 335
		button.custom_minimum_size.y = 33
		button.pressed.connect(BattleManager.select_ability.bind(ability))
		job_ability_vbox.add_child(button)
	
# shows and hides the appropriate menus based on the current battle state
func _on_state_changed(new_state: BattleManager.BattleState) -> void:
	match new_state:
		BattleManager.BattleState.ACTION_SELECT:
			_hide_menu()
			action_menu.show()
		BattleManager.BattleState.MOVE_SELECT:
			_hide_menu()
		BattleManager.BattleState.EQUIPMENT_SELECT:
			_hide_menu()
			equipment_menu.show()
		BattleManager.BattleState.ABILITIES_SELECT:
			_hide_menu()
			abilities_menu.show()
		BattleManager.BattleState.JOB_ABILITIES_SELECT:
			_hide_menu()
			job_ability_menu.show()
		_:
			_hide_menu()
			
func _on_fight_pressed() -> void:
	if _fight_ability == null:
		return
	print("fight: ", _fight_ability.ability_name)
	BattleManager.select_ability(_fight_ability)
		
func _update_fight_ability() -> void:
	if _active_unit == null:
		return
	var job = JobRegistry.get_job(_active_unit.data.job_id)
	if job == null:
		return
	_fight_ability = AbilityRegistry.get_ability_by_name("Fight_" + job.job_name)

# disables the abilities button to indicate the action has been used
func ability_consumed() -> void:
	abilities_button.disabled = true
	abilities_button.modulate = DISABLED_COLOR

# disables the move button to indicate movement has been used
func move_consumed() -> void:
	move_button.disabled = true
	move_button.modulate = DISABLED_COLOR

func _reset_turn() -> void:
	_move_reset()
	_abilities_reset()
	_equipment_reset()
	_job_ability_reset()

func _abilities_reset() -> void:
	abilities_button.disabled = false
	abilities_button.modulate = ENABLED_COLOR

func _move_reset() -> void:
	move_button.disabled = false
	move_button.modulate = ENABLED_COLOR

# clear dynamically generated buttons
func _equipment_reset() -> void:
	for child in equipment_vbox.get_children():
		child.queue_free()
		
func _job_ability_reset() -> void:
	for child in job_ability_vbox.get_children():
		child.queue_free()
		
func _hide_menu() -> void:
	action_menu.hide()
	equipment_menu.hide()
	abilities_menu.hide()
	job_ability_menu.hide()
