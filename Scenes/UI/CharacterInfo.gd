class_name CharacterInfo
extends Control

const PLAYER_BG = preload("res://Assets/UI/Windows/Character_Info_Window.png")
const ENEMY_BG = preload("res://Assets/UI/Windows/Character_Info_Window_Enemy.png")
const NEUTRAL_BG = preload("res://Assets/UI/Windows/Character_Info_Window_Neutral.png")

@onready var background: NinePatchRect = $Background
@onready var portrait_rect: TextureRect = $PortraitRect
@onready var name_label: Label = $Name
@onready var hp_bar: ProgressBarScene = $HpBar
@onready var hp_count: Label = $HpCount
@onready var hp_max_count: Label = $HpMaxCount
@onready var mp_accent: Label = $MpAccent
@onready var mp_bar: ProgressBarScene = $MpBar
@onready var mp_count: Label = $MpCount
@onready var mp_max_count: Label = $MpMaxCount
@onready var mp_divider: Label = $MpDivider
@onready var lvl_count: Label = $LvlCount
@onready var lvl_accent: Label = $LvlAccent
@onready var info_button: HoverButton = $InfoButton

var _fade_tween: Tween = null

# --- state ---
# _active_actor: whoever's turn it is (baseline display)
# _hovered_actor: whoever's under the cursor (temporary override)
# _update_display() is the ONLY place that resolves state -> render;
# _render() never writes state, state changes never render directly.
var _active_actor: BattleActor = null
var _hovered_actor: BattleActor = null

func _ready() -> void:
	BattleManager.active_unit_changed.connect(_on_active_unit_changed)
	BattleEvents.hp_changed.connect(_on_hp_changed)
	
	info_button.focused.connect(_on_info_focused)
	info_button.unfocused.connect(_on_info_unfocused)
	info_button.pressed.connect(_on_info_pressed)

# =============================================================================
# STATE — every mutation funnels into _update_display
# =============================================================================

func _on_active_unit_changed(actor: BattleActor) -> void:
	_active_actor = actor
	_update_display()

func set_hovered_actor(actor: BattleActor) -> void:
	_hovered_actor = actor
	_update_display()

func clear_hovered_actor() -> void:
	_hovered_actor = null
	_update_display()

# reactive: refresh only if the changed actor is the one currently displayed
func _on_hp_changed(actor, _amount: int, _new_hp: int) -> void:
	if actor == _displayed_actor():
		_update_display()

func refresh() -> void:
	_update_display()

# The info icon is an AnimatedTexture that ships paused (pause = true); it only
# animates while the button is focused. HoverButton.focused emits the button as
# an argument — the handler MUST accept it, or Godot drops the call at emit time
# ("expected 0 arguments, called with 1") and this never fires.
func _on_info_focused(_button: HoverButton) -> void:
	_set_info_icon_playing(true)

func _on_info_unfocused() -> void:
	_set_info_icon_playing(false)
	
func _on_info_pressed() -> void:
	print("info pressed")

# `pause` lives on the AnimatedTexture, not the button — icon is typed Texture2D
# so cast before touching it. Rewinds to frame 0 when stopping so each hover
# restarts the animation cleanly.
func _set_info_icon_playing(playing: bool) -> void:
	var anim := info_button.icon as AnimatedTexture
	if anim == null:
		return
	anim.pause = not playing
	if not playing:
		anim.current_frame = 0

# =============================================================================
# DISPLAY
# =============================================================================

# hover overrides active; no actor at all hides the window
func _displayed_actor() -> BattleActor:
	return _hovered_actor if _hovered_actor != null else _active_actor

func _update_display() -> void:
	if BattleManager.current_state == BattleManager.BattleState.RESOLVING:
		hide_window()
		return
	if BattleManager.current_state == BattleManager.BattleState.MOVE_SELECT and _hovered_actor == null:
		hide_window()
		return
	var to_show = _displayed_actor()
	if to_show != null:
		_render(to_show)
	else:
		hide_window()

# =============================================================================
# RENDER — pure display, never writes state
# =============================================================================

func _render(actor: BattleActor) -> void:
	_set_background(actor.data.type)
	hp_bar.setup(actor.data.current_hp, actor.data.max_hp)
	hp_count.text = str(actor.data.current_hp)
	hp_max_count.text = str(actor.data.max_hp)

	if actor.data is UnitData:
		var unit_data := actor.data as UnitData
		_show_unit_details()
		mp_bar.show()
		mp_bar.setup(unit_data.current_mp, unit_data.max_mp)
		mp_count.text = str(unit_data.current_mp)
		mp_max_count.text = str(unit_data.max_mp)
		name_label.text = unit_data.name
		lvl_count.text = str(unit_data.current_lvl)
		portrait_rect.texture = unit_data.job.portrait if unit_data.job != null else null
	else:
		_hide_unit_details()
		name_label.text = actor.data.object_name if actor.data is BattleObjectData else ""
		portrait_rect.texture = actor.data.portrait
	show()
	await fade_in()

func _set_background(type: BattleActorData.Type) -> void:
	match type:
		BattleActorData.Type.PLAYER:
			background.texture = PLAYER_BG
		BattleActorData.Type.ENEMY:
			background.texture = ENEMY_BG
		BattleActorData.Type.NEUTRAL:
			background.texture = NEUTRAL_BG

# =============================================================================
# VISIBILITY
# =============================================================================

func _clear_info() -> void:
	name_label.text = ""
	hp_count.text = ""
	hp_max_count.text = ""
	mp_count.text = ""
	mp_max_count.text = ""
	lvl_count.text = ""
	
func _hide_unit_details() -> void:
	mp_bar.hide()
	mp_count.text = ""
	mp_max_count.text = ""
	mp_accent.text = ""
	mp_divider.text = ""
	lvl_count.text = ""
	lvl_accent.text = ""
	info_button.hide()

func _show_unit_details() -> void:
	mp_accent.text = "MP"
	mp_divider.text = "/"
	lvl_accent.text = "LV"
	info_button.show()

func hide_window() -> void:
	await fade_out()
	_clear_info()
	hide()

func fade_out(duration: float = Constants.FADE_TIMER) -> void:
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, duration)
	await _fade_tween.finished

func fade_in(duration: float = Constants.FADE_TIMER) -> void:
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 1.0, duration)
	await _fade_tween.finished
