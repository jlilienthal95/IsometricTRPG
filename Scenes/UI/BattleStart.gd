class_name BattleStart
extends Control

@onready var battle_start_label: Label = $BattleStartLabel
@onready var animation_player: AnimationPlayer = $AnimationPlayer


#func _on_battle_won() -> void:
	#battle_start_label.text = "BATTLE WON!"
	#animation_player.play("transition_in")
	#await animation_player.animation_finished
	#
#func _on_battle_lost() -> void:
	#battle_start_label.text = "BATTLE LOST."
	#animation_player.play("transition_in")
	#await animation_player.animation_finished
