class_name BattleUI
extends Control

enum UIElement { ALL, HUD, CHARACTER_INFO }

var _fade_tween: Tween = null

@onready var battle_hud: BattleHUD = $BattleHUD
@onready var character_info: CharacterInfo = $CharacterInfo
@onready var cinematic_bars: CinematicBars = $CinematicBars

# The UI subscribes ITSELF to the state machine and turn signals — BattleManager
# never calls into the UI. New UI elements can react to battle state without
# any change to battle logic.
func setup() -> void:
	modulate.a = 1.0
	battle_hud.setup(BattleManager)
	BattleManager.state_changed.connect(_on_state_changed)
	BattleManager.active_unit_changed.connect(on_turn_changed)
	BattleManager.turn_ended.connect(_on_turn_ended)
	BattleManager.battle_ended.connect(_on_battle_end)

func _on_state_changed(state: BattleManager.BattleState) -> void:
	match state:
		BattleManager.BattleState.ACTION_SELECT:
			await fade_out()
			battle_hud.show_menu(battle_hud.action_menu)
			character_info._update_display()
			await fade_in()
		BattleManager.BattleState.MOVE_SELECT:
			fade_out(Constants.FADE_TIMER, UIElement.HUD)
			await character_info.fade_out(Constants.FADE_TIMER)
			battle_hud.show_menu(null)
		BattleManager.BattleState.EQUIPMENT_SELECT:
			await fade_out(Constants.FADE_TIMER, UIElement.HUD)
			battle_hud.show_menu(battle_hud.equipment_menu)
			await fade_in()
		BattleManager.BattleState.ABILITIES_SELECT:
			await fade_out(Constants.FADE_TIMER, UIElement.HUD)
			battle_hud.show_menu(battle_hud.abilities_menu)
			await fade_in()
		BattleManager.BattleState.JOB_ABILITIES_SELECT:
			await fade_out(Constants.FADE_TIMER, UIElement.HUD)
			battle_hud.show_menu(battle_hud.job_ability_menu)
			await fade_in()
		BattleManager.BattleState.TARGET_SELECT:
			await fade_out(Constants.FADE_TIMER, UIElement.HUD)
		BattleManager.BattleState.RESOLVING:
			await fade_out()
			battle_hud.show_menu(null)
		_:
			await fade_out()
			battle_hud.show_menu(null)

func on_battle_start() -> void:
	var battle_start_scene: PackedScene = preload("res://Scenes/UI/BattleStart.tscn")
	var battle_start: BattleStart = battle_start_scene.instantiate()
	add_child(battle_start)
	battle_start.animation_player.play("transition_in")
	await battle_start.animation_player.animation_finished
	battle_start.queue_free()
	
func _on_battle_end(isWin: bool) -> void:
	var battle_start_scene: PackedScene = preload("res://Scenes/UI/BattleStart.tscn")
	var battle_start: BattleStart = battle_start_scene.instantiate()
	add_child(battle_start)
	if isWin:
		battle_start.battle_start_label.text = "BATTLE WON!"
	else:
		battle_start.battle_start_label.text = "BATTLE LOST."
	battle_start.animation_player.play("transition_in")
	await battle_start.animation_player.animation_finished
	battle_start.queue_free()

func on_turn_changed(unit: Unit) -> void:
	battle_hud.on_turn_changed(unit)

func _on_turn_ended() -> void:
	fade_out()

func refresh_hud() -> void:
	battle_hud.refresh()

func fade_out(duration: float = Constants.FADE_TIMER, target: UIElement = UIElement.ALL) -> void:
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)
	if target == UIElement.ALL or target == UIElement.HUD:
		_fade_tween.tween_property(battle_hud, "modulate:a", 0.0, duration)
	if target == UIElement.ALL or target == UIElement.CHARACTER_INFO:
		_fade_tween.tween_property(character_info, "modulate:a", 0.0, duration)
	await _fade_tween.finished

func fade_in(duration: float = Constants.FADE_TIMER, target: UIElement = UIElement.ALL) -> void:
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)
	if target == UIElement.ALL or target == UIElement.HUD:
		_fade_tween.tween_property(battle_hud, "modulate:a", 1.0, duration)
	if target == UIElement.ALL or target == UIElement.CHARACTER_INFO:
		_fade_tween.tween_property(character_info, "modulate:a", 1.0, duration)
	await _fade_tween.finished

func fade_bars_in() -> void:
	await cinematic_bars.fade_in()

func fade_bars_out() -> void:
	await cinematic_bars.fade_out()
