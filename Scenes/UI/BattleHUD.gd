class_name BattleHUD
extends Control

@onready var action_menu = $ActionMenu
@onready var move_button = $ActionMenu/VBoxContainer/MoveButton
@onready var attack_button = $ActionMenu/VBoxContainer/AttackButton
@onready var wait_button = $ActionMenu/VBoxContainer/WaitButton

func setup(battle_manager: BattleManager) -> void:
	battle_manager.state_changed.connect(_on_state_changed)
	move_button.pressed.connect(battle_manager.select_action_move)
	attack_button.pressed.connect(battle_manager.select_action_attack)
	wait_button.pressed.connect(battle_manager.end_turn)
	action_menu.hide()

func _on_state_changed(new_state: BattleManager.BattleState) -> void:
	match new_state:
		BattleManager.BattleState.ACTION_SELECT:
			action_menu.show()
		_:
			action_menu.hide()
