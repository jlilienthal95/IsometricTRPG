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
@onready var job_ability_button = $AbilitiesMenu/VBoxContainer/JobActionButton
@onready var items_button: Button = $AbilitiesMenu/VBoxContainer/ItemsButton

@onready var job_ability_menu = $JobAbilityMenu
@onready var job_ability_vbox: VBoxContainer = $JobAbilityMenu/JobAbilityScroll/VBoxContainer

var _active_unit: Unit = null
var _fight_ability: AbilityData = null

func setup(battle_manager: BattleManager) -> void:
	battle_manager.state_changed.connect(_on_state_changed)
	move_button.pressed.connect(battle_manager.select_action_move)
	abilities_button.pressed.connect(battle_manager.select_action_abilities)
	equipment_button.pressed.connect(battle_manager.select_action_equipment)
	wait_button.pressed.connect(battle_manager.end_turn)
	fight_button.pressed.connect(_on_fight_pressed)
	job_ability_button.pressed.connect(battle_manager.select_job_ability)
	_hide_all()

func refresh() -> void:
	if _active_unit == null:
		return
	move_button.disabled = _active_unit.data.has_moved
	move_button.modulate = Color(1, 1, 1, 0.4) if _active_unit.data.has_moved else Color.WHITE
	abilities_button.disabled = _active_unit.data.has_acted
	abilities_button.modulate = Color(1, 1, 1, 0.4) if _active_unit.data.has_acted else Color.WHITE

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
		button.custom_minimum_size.x = 335
		button.custom_minimum_size.y = 60
		equipment_vbox.add_child(button)

func _generate_job_ability_buttons(abilities: Array[AbilityData]) -> void:
	for ability in abilities:
		var button = Button.new()
		button.text = ability.ability_name.replace("_", " ")
		button.custom_minimum_size.x = 335
		button.custom_minimum_size.y = 33
		button.pressed.connect(BattleManager.select_ability.bind(ability))
		job_ability_vbox.add_child(button)

func _on_state_changed(new_state: BattleManager.BattleState) -> void:
	print("HUD state changed: ", new_state)
	match new_state:
		BattleManager.BattleState.ACTION_SELECT:
			print("emitting menu_requested with action_menu")
			menu_requested.emit(action_menu)
		BattleManager.BattleState.MOVE_SELECT:
			hide_requested.emit()
		BattleManager.BattleState.EQUIPMENT_SELECT:
			menu_requested.emit(equipment_menu)
		BattleManager.BattleState.ABILITIES_SELECT:
			menu_requested.emit(abilities_menu)
		BattleManager.BattleState.JOB_ABILITIES_SELECT:
			menu_requested.emit(job_ability_menu)
		BattleManager.BattleState.RESOLVING:
			hide_requested.emit()
			
		_:
			menu_requested.emit(null)

func show_menu(menu) -> void:
	print("show_menu called with: ", menu)
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
