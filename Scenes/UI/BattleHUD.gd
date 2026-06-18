class_name BattleHUD
extends Control

@onready var action_menu = $ActionMenu
@onready var move_button = $ActionMenu/VBoxContainer/MoveButton
@onready var attack_button = $ActionMenu/VBoxContainer/AttackButton
@onready var equipment_button = $ActionMenu/VBoxContainer/EquipmentButton
@onready var wait_button = $ActionMenu/VBoxContainer/WaitButton
@onready var inventory_menu = $InventoryMenu/VBoxContainer
@onready var attack_menu = $AttackMenu
@onready var fight_button = $AttackMenu/VBoxContainer/FightButton

const DISABLED_OPACITY = 0.4
const ENABLED_OPACITY = 1.0
const ENABLED_COLOR = Color(1, 1, 1, ENABLED_OPACITY)
const DISABLED_COLOR = Color(1, 1, 1, DISABLED_OPACITY)

var _active_unit: Unit = null
var _active_unit_equipment: Array[ItemData] = []
var _fight_ability: AbilityData = null

# connects all HUD buttons to BattleManager actions and hides all menus
# TODO: replace hardcoded Fight ability with proper AbilityRegistry lookup
func setup(battle_manager: BattleManager) -> void:
	battle_manager.state_changed.connect(_on_state_changed)
	move_button.pressed.connect(battle_manager.select_action_move)
	attack_button.pressed.connect(battle_manager.select_action_attack)
	equipment_button.pressed.connect(battle_manager.select_action_equipment)
	wait_button.pressed.connect(battle_manager.end_turn)
	fight_button.pressed.connect(_on_fight_pressed)
	action_menu.hide()
	inventory_menu.hide()
	attack_menu.hide()

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
		attack_button.disabled = true
		attack_button.modulate = DISABLED_COLOR
	else:
		attack_button.disabled = false
		attack_button.modulate = ENABLED_COLOR
		
# updates the active unit reference and refreshes button states
func on_turn_changed(unit: Unit) -> void:
	_active_unit = unit
	_reset_turn()
	_load_equipment_from_active_unit(unit.data.equipped_items)
	_generate_equipment_buttons(_active_unit_equipment)
	_update_fight_ability()

# caches the active unit's equipment for button generation
func _load_equipment_from_active_unit(items: Array[ItemData]) -> void:
	_active_unit_equipment = items

	
# dynamically creates buttons for each equipped item in the inventory menu
func _generate_equipment_buttons(items: Array[ItemData]) -> void:
	for item in items:
		var button = Button.new()
		button.text = item.item_name
		button.custom_minimum_size.x = 200
		button.custom_minimum_size.y = 60
		inventory_menu.add_child(button)
	
# shows and hides the appropriate menus based on the current battle state
func _on_state_changed(new_state: BattleManager.BattleState) -> void:
	match new_state:
		BattleManager.BattleState.ACTION_SELECT:
			attack_menu.hide()
			inventory_menu.hide()
			action_menu.show()
		BattleManager.BattleState.MOVE_SELECT:
			action_menu.hide()
		BattleManager.BattleState.EQUIPMENT_SELECT:
			action_menu.hide()
			inventory_menu.show()
		BattleManager.BattleState.ATTACK_SELECT:
			action_menu.hide()
			attack_menu.show()
		_:
			action_menu.hide()
			inventory_menu.hide()
			attack_menu.hide()
			
func _on_fight_pressed() -> void:
	if _fight_ability == null:
		return
	BattleManager.select_ability(_fight_ability)
		
func _update_fight_ability() -> void:
	if _active_unit == null:
		return
	var job = JobRegistry.get_job(_active_unit.data.job_id)
	if job == null:
		return
	_fight_ability = AbilityRegistry.get_ability_by_name("Fight_" + job.job_name)

# disables the attack button to indicate the action has been used
func attack_consumed() -> void:
	attack_button.disabled = true
	attack_button.modulate = DISABLED_COLOR

# disables the move button to indicate movement has been used
func move_consumed() -> void:
	move_button.disabled = true
	move_button.modulate = DISABLED_COLOR

func _reset_turn() -> void:
	_move_reset()
	_attack_reset()
	_equipment_reset()

func _attack_reset() -> void:
	attack_button.disabled = false
	attack_button.modulate = ENABLED_COLOR

func _move_reset() -> void:
	move_button.disabled = false
	move_button.modulate = ENABLED_COLOR

# clears dynamically generated equipment buttons and resets the equipment list
func _equipment_reset() -> void:
	for child in inventory_menu.get_children():
		child.queue_free()
	_active_unit_equipment = []
