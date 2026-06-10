class_name BattleHUD
extends Control

@onready var action_menu = $ActionMenu
@onready var move_button = $ActionMenu/VBoxContainer/MoveButton
@onready var attack_button = $ActionMenu/VBoxContainer/AttackButton
@onready var equipment_button = $ActionMenu/VBoxContainer/EquipmentButton
@onready var wait_button = $ActionMenu/VBoxContainer/WaitButton

@onready var inventory_menu: PanelContainer = $InventoryMenu

@onready var attack_menu = $AttackMenu
@onready var fight_button = $AttackMenu/VBoxContainer/FightButton

const DISABLED_OPACITY = 0.4
const ENABLED_OPACITY = 1

const ENABLED_COLOR = Color(1,1,1,ENABLED_OPACITY)
const DISABLED_COLOR = Color(1,1,1,DISABLED_OPACITY)

var _active_unit_equipment: Array[ItemData] = []

func setup(battle_manager: BattleManager) -> void:
	battle_manager.state_changed.connect(_on_state_changed)
	move_button.pressed.connect(battle_manager.select_action_move)
	attack_button.pressed.connect(battle_manager.select_action_attack)
	equipment_button.pressed.connect(battle_manager.select_action_equipment)
	wait_button.pressed.connect(battle_manager.end_turn)
	
	action_menu.hide()
	fight_button.pressed.connect(battle_manager.select_ability.bind(load("res://Data/Abilities/Fight.tres")))
	inventory_menu.hide()
	attack_menu.hide()
	
func _load_equipment_from_active_unit(items: Array[ItemData]):
	_active_unit_equipment = items
	
func _generate_equipment_buttons(items: Array[ItemData]):
	for item in items:
		var button = Button.new()
		button.text = item.item_name
		button.custom_minimum_size.x = 200
		button.custom_minimum_size.y = 60
		$InventoryMenu/VBoxContainer.add_child(button)

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

func on_turn_changed(items: Array[ItemData]):
	_reset_turn()
	_load_equipment_from_active_unit(items)
	_generate_equipment_buttons(_active_unit_equipment)

func attack_consumed() -> void:
	attack_button.disabled = true
	attack_button.modulate = DISABLED_COLOR

func move_consumed() -> void:
	move_button.disabled = true
	move_button.modulate = DISABLED_COLOR
	
func _reset_turn() -> void:
	_attack_reset()
	_move_reset()
	_equipment_reset()

func _attack_reset() -> void:
	attack_button.disabled = false
	attack_button.modulate = ENABLED_COLOR
	
func _move_reset() -> void:
	move_button.disabled = false
	move_button.modulate = ENABLED_COLOR
	
func _equipment_reset() -> void:
	for child in $InventoryMenu/VBoxContainer.get_children():
		child.queue_free()
	_active_unit_equipment = []
	
