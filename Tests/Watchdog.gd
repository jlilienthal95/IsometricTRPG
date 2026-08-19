class_name Watchdog
extends Node

# Runs a coroutine against a REAL-TIME timeout, independent of Engine.time_scale.
# Time.get_ticks_msec() is wall-clock and unaffected by time scaling, so a 15s
# timeout means 15 real seconds no matter how fast the game itself is running —
# exactly what's needed to catch a hang whether tests run at 1x or 10x.
#
# Mechanism: GDScript coroutines can't be cancelled once directly awaited, so
# the target coroutine is launched WITHOUT awaiting it here (fire-and-forget —
# calling an async func without `await` still runs it, just doesn't block the
# caller). This function polls a completion flag once per frame against the
# wall-clock deadline. On timeout it returns immediately with timed_out=true;
# the orphaned background coroutine is abandoned. That's an acceptable
# tradeoff for a test tool whose job is to DETECT and REPORT a hang, not to
# guarantee full cleanup of a process that is already broken.

const DEFAULT_TIMEOUT_SEC: float = 15.0

var _done: bool = false
var _result = null

func run(coroutine: Callable, timeout_sec: float = DEFAULT_TIMEOUT_SEC) -> Dictionary:
	_done = false
	_result = null
	var start_ms := Time.get_ticks_msec()
	_run_bg(coroutine)
	while not _done:
		var elapsed_sec := (Time.get_ticks_msec() - start_ms) / 1000.0
		if elapsed_sec > timeout_sec:
			return {"timed_out": true, "result": null, "elapsed_sec": elapsed_sec}
		await get_tree().process_frame
	return {
		"timed_out": false,
		"result": _result,
		"elapsed_sec": (Time.get_ticks_msec() - start_ms) / 1000.0,
	}

func _run_bg(coroutine: Callable) -> void:
	var r = await coroutine.call()
	_result = r
	_done = true
