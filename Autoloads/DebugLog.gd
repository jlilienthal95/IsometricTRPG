extends Node

# =============================================================================
# DebugLog — centralized, per-system toggleable debug logging.
#
# The project leans heavily on raw print() scattered through BattleManager,
# ActorMarker, UnitAbilityExecutor, and others — useful during active
# development, but with no way to quiet one noisy system without deleting its
# print() calls (and forgetting to add them back later). This autoload is a
# drop-in replacement: same call-site convenience (pass an already-formatted
# string, same as you'd hand to print()), but each category can be switched
# off independently, and everything funnels through one place if you ever
# want to redirect it (e.g. to Tests/BattleLogger.gd-style file output).
#
# Usage: DebugLog.spawn("placed unit at %s" % cell)
# Toggle: DebugLog.enabled.spawn = false   — silences that category
#
# GDScript has no varargs for user-defined functions (print() is a builtin
# special case), so unlike print() this takes one pre-formatted string rather
# than a comma-separated arg list — build the string with "%s" % [...] or
# str() concatenation at the call site, same as the rest of this codebase
# already does elsewhere.
#
# This is opt-in infrastructure, not yet wired into most of the codebase.
# See AUDIT_NOTES.md for which systems still use raw print() and would
# benefit from migrating.
# =============================================================================

# one bool per debug category — add more as needed, they're free
var enabled: Dictionary = {
	"spawn": true,
	"battle_state": true,
	"ability": true,
	"ai": true,
	"effects": true,
}

func spawn(message: String) -> void:
	_log("spawn", message)

func battle_state(message: String) -> void:
	_log("battle_state", message)

func ability(message: String) -> void:
	_log("ability", message)

func ai(message: String) -> void:
	_log("ai", message)

func effects(message: String) -> void:
	_log("effects", message)

func _log(category: String, message: String) -> void:
	if not enabled.get(category, true):
		return
	print("[%s] %s" % [category, message])
