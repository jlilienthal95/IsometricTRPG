class_name BattleInfo
extends ColorRect

enum MarqueeState { IDLE, WAITING, SCROLLING, RESETTING }

var _marquee_state: MarqueeState = MarqueeState.IDLE
var _marquee_position: float = 0.0
var _marquee_timer: float = 0.0
var _marquee_delay: float = 1.2
var _marquee_speed: float = 30.0  # pixels per second
var _marquee_overflow: float = 0.0

@onready var info_scroll: ScrollContainer = $InfoScroll
@onready var info_label: Label = $InfoScroll/InfoCenter/InfoLabel

func _process(delta: float) -> void:
	if _marquee_state == MarqueeState.IDLE:
		return
	
	match _marquee_state:
		MarqueeState.WAITING:
			_marquee_timer -= delta
			if _marquee_timer <= 0.0:
				print("marque scrolling...")
				_marquee_state = MarqueeState.SCROLLING
		
		MarqueeState.SCROLLING:
			_marquee_position += _marquee_speed * delta
			info_scroll.scroll_horizontal = int(_marquee_position)
			if _marquee_position >= _marquee_overflow:
				_marquee_position = _marquee_overflow
				info_scroll.scroll_horizontal = int(_marquee_overflow)
				_marquee_state = MarqueeState.RESETTING
				_marquee_timer = _marquee_delay
		
		MarqueeState.RESETTING:
			_marquee_timer -= delta
			if _marquee_timer <= 0.0:
				reset_marquee()
				_marquee_timer = _marquee_delay
				_marquee_state = MarqueeState.WAITING

func display(text: String) -> void:
	if text.is_empty():
		hide()
		return
	info_label.text = text
	show()
	start_marquee()

func hide_info() -> void:
	stop_marquee()
	hide()

func start_marquee() -> void:
	print("starting marquee")
	var content_width = info_scroll.get_child(0).size.x
	var visible_width = info_scroll.size.x
	_marquee_overflow = content_width - visible_width
	if _marquee_overflow <= 0:
		print("no overflow to scroll")
		_marquee_state = MarqueeState.IDLE
		return
	reset_marquee()
	_marquee_timer = _marquee_delay
	_marquee_state = MarqueeState.WAITING

func stop_marquee() -> void:
	_marquee_state = MarqueeState.IDLE
	reset_marquee()
	
func reset_marquee() -> void:
	print("resetting marquee...")
	info_scroll.scroll_horizontal = 0
	_marquee_position = 0.0
