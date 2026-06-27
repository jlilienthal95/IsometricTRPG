class_name BattleHUD
extends Control

signal menu_requested(menu)
signal hide_requested

@onready var action_menu = $ActionMenu
@onready var move_button = $ActionMenu/VBoxContainer/MoveButton
@onready var abilities_button = $ActionMenu/VBoxContainer/AbilitiesButton
@onready var equipment_button = $ActionMenu/VBoxContainer/EquipmentButton
@onready var wait_button = $ActionMenu/VBoxContainer/WaitButton

@onready var equipment_menu = $EquipmentMenu
@onready var equipment_vbox: VBoxContainer = $EquipmentMenu/EquipmentScroll/VBoxContainer

@onready var abilities_menu = $AbilitiesMenu
@onready var fight_button = $AbilitiesMenu/VBoxContainer/FightButton
@onready var job_action_button = $AbilitiesMenu/VBoxContainer/JobActionButton
@onready var items_button: Button = $AbilitiesMenu/VBoxContainer/ItemsButton

@onready var job_ability_menu = $JobAbilityMenu
@onready var job_ability_vbox: VBoxContainer = $JobAbilityMenu/JobAbilityScroll/VBoxContainer

var _active_unit: Unit = null
var _fight_ability: AbilityData = null

var job_ability_button =  preload("res://Scenes/UI/JobActionButton.tscn")

func setup(battle_manager: BattleManager) -> void:
	move_button.pressed.connect(battle_manager.select_action_move)
	abilities_button.pressed.connect(battle_manager.select_action_abilities)
	equipment_button.pressed.connect(battle_manager.select_action_equipment)
	wait_button.pressed.connect(battle_manager.end_turn)
	fight_button.pressed.connect(_on_fight_pressed)
	job_action_button.pressed.connect(battle_manager.select_job_ability)
	_hide_all()

func refresh() -> void:
	if _active_unit == null:
		return
	move_button.disabled = _active_unit.data.has_moved
	abilities_button.disabled = _active_unit.data.has_acted
	_equipment_reset()
	_abilities_reset()
	_generate_equipment_buttons(_active_unit.data.equipped_items)
	_generate_job_ability_buttons(_active_unit.data.abilities)

func on_turn_changed(unit: Unit) -> void:
	_active_unit = unit
	_reset_turn()
	_generate_equipment_buttons(_active_unit.data.equipped_items)
	_generate_job_ability_buttons(_active_unit.data.abilities)
	_update_fight_ability()

func _generate_equipment_buttons(items: Array[ItemData]) -> void:
	for item in items:
		var button = Button.new()
		button.text = item.item_name
		button.custom_minimum_size.x = Constants.ACTION_BUTTON_X
		button.custom_minimum_size.y = Constants.ACTION_BUTTON_Y
		equipment_vbox.add_child(button)

func _generate_job_ability_buttons(abilities: Array[AbilityData]) -> void:
	for ability in abilities:
		var button = job_ability_button.instantiate()
		var mp_cost = ability.mp_cost
		button.get_node("./ActionLabel").text = ability.ability_name.replace("_", " ")
		if mp_cost > 0:
			button.get_node("./MpLabel").text = str(ability.mp_cost)
		button.custom_minimum_size.x = Constants.ACTION_BUTTON_X
		button.custom_minimum_size.y = Constants.ACTION_BUTTON_Y
		if _active_unit.data.current_mp >= ability.mp_cost:
			button.pressed.connect(BattleManager.select_ability.bind(ability))
		else:
			button.disabled = true
		job_ability_vbox.add_child(button)

func show_menu(menu) -> void:
	_hide_all()
	if menu != null:
		menu.show()

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

func _reset_turn() -> void:
	_move_reset()
	_abilities_reset()
	_equipment_reset()
	_job_ability_reset()

func _abilities_reset() -> void:
	abilities_button.disabled = false
	abilities_button.modulate = Color.WHITE

func _move_reset() -> void:
	move_button.disabled = false
	move_button.modulate = Color.WHITE

func _equipment_reset() -> void:
	for child in equipment_vbox.get_children():
		child.queue_free()

func _job_ability_reset() -> void:
	for child in job_ability_vbox.get_children():
		child.queue_free()

func _hide_all() -> void:
	action_menu.hide()
	equipment_menu.hide()
	abilities_menu.hide()
	job_ability_menu.hide()
