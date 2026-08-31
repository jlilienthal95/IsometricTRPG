# Audit notes — full pass, [see conversation for context]

This file is a summary of everything changed in this pass, plus open items
and suggestions. Delete it once you've read it — it's not meant to become a
permanent fixture of the repo.

## 1. File reorg — done
Units, Objects, and Effects now group everything about one instance into one
folder (data + scene + frames), matching how Barrel already worked:
- `Scenes/Battle/Units/Unit.gd`, `Unit.tscn` (generic base)
  - `Knight/`, `Pirate/`, `Archer/` — each holds `<Job>.tres` + `<Job>.tscn`
    (inherited scene) + `<Job>Frames.tres`
  - `Marta/`, `Theo/`, `Auburn/` — each holds `<Unit>.tres`
- `Scenes/Battle/Objects/BattleObject.gd`, `Object.tscn` (generic base)
  - `Barrel/` — `Barrel.tres` + `Barrel.tscn` + `BarrelFrames.tres`
- `Scenes/Battle/Effects/TileEffectVisual.gd` (shared script, see below)
  - `Burning/`, `Electrified/` — each holds its `.gd`-free `.tscn` + `.tres`
- `Scenes/Battle/ActorMarker.gd` + `ActorMarker.tscn` now sit together (the
  `.tscn` was previously miscategorized under `Objects/` despite being usable
  for units too — and turned out to be unreferenced anywhere; kept rather
  than deleted since I can't confirm intent, but flagging it as dead)
- Deleted `Data/Objects/Barrel.tres` — a stray orphaned duplicate of the real
  one, unreferenced anywhere in the project (confirmed via grep before deleting)
- `Data/Abilities/` (Flame/Freeze/Spark .tres+.tscn pairs) was **not**
  reorganized — deferred, see Open Items below

Verified with a scripted check afterward: every `path="res://..."` in every
`.tscn`/`.tres` in the project resolves to a real file. The only "missing"
references are ones that were already missing before I touched anything —
this export doesn't include `Assets/` or `addons/` (expected for a
"compressed" archive with binaries stripped).

## 2. Units → scene inheritance — done
- `JobData.scene`: the job's inherited `Unit.tscn` scene (Knight/Pirate/Archer.tscn)
- `UnitData.scene_override`: optional per-unit override scene, checked first
- `UnitData.get_scene()`: override → job scene → bare `Unit.tscn`, in that order
- Removed entirely: the runtime `_apply_job_sprite()` step, and the
  `sprite_frames`/`sprite_offset`/`shadow_scale`/`flip_offset` data fields on
  `JobData` that fed it. All of that is now just authored directly on each
  job's `.tscn` node properties, like Barrel already did for objects.
- `battle_scene._spawn_unit()` now actually calls `unit_data.get_scene()`
  instead of a hardcoded `preload("Unit.tscn")`.

**This is also the actual fix for the Marta bug** — see item 3.

## 3. Marta-only-idles bug — root cause found, fixed by item 2
Root cause: `Unit.setup()` called `play_idle()` *before* `_apply_job_sprite()`
swapped in the job's real `SpriteFrames`. Godot resets an `AnimatedSprite2D`'s
playback when you assign it a *different* `SpriteFrames` resource than the one
already on it — but it's a no-op if the new resource happens to already be the
one assigned. `Unit.tscn`'s placeholder default just happened to already be
Knight's frames (that's literally where they were copied from), so Marta
(Knight) was unaffected while Theo (Pirate) and Auburn (Archer) had their
just-started idle animation silently killed by the swap.

The scene-inheritance refactor removes the runtime swap entirely, so this bug
class can't recur — there's no longer a moment where the "wrong" SpriteFrames
is briefly assigned. I also independently reordered `setup()` as a
belt-and-suspenders fix in case you want the old runtime-swap approach back
for some reason (you shouldn't need it, but it's there in the diff history).

## 4. Tests — one real bug fixed, one new suite added, one assertion tightened
- **Crash bug**: `BattleAssertion.gd` and `TestSuite.make_unit_data()` both
  referenced `data.unit_name`, which doesn't exist on `UnitData` (the field is
  `name`). Any test that called `assert_unit_integrity()` or
  `assert_object_integrity()` (both `EffectSystemTests`... no — both used from
  `BattleTestRunner.gd`, confirmed live) would have hard-errored, not silently
  passed. Fixed.
- **New suite**: `Tests/AbilityTimingTests.gd`, testing the frame→seconds
  timing math directly (this is the exact "30 frames at 30fps, impact frame
  15 → 0.5s" example from the brief). This math previously only existed
  inline inside `UnitAbilityExecutor._execute_sequence()`, an async function
  that also touches a live caster/sprite/camera — not something you can unit
  test in isolation. I extracted it into `Core/Battle/AbilityTiming.gd` (pure,
  static, no scene tree needed) and pointed the executor at it. Registered in
  `TestRunner.SUITES`.
- **Tightened one weak assertion**: `EffectSystemTests._test_object_effects()`
  checked `current_hp < hp_before` for a burning tick (i.e. "some damage
  happened"). Traced the actual formula (`BurningHandler` damage_multiplier
  0.5 × `Constants.BASE_DAMAGE_UNIT` × `EffectDamageResolver`'s ±20% variance)
  and replaced it with an exact `[4, 5]` range check.
- Everything else in `Tests/` (`StatResolutionTests`, `MovementExecutionTests`,
  `GridObjectTests`, `PathfinderTests`, `TurnQueueTests`) was already checking
  exact expected values step-by-step, not just end states — I read through all
  of them looking for the "passes because the assertion is flawed" pattern and
  didn't find more instances of it. If you had specific failing-to-catch-bugs
  tests in mind beyond these, point me at which ones and I'll dig further.

## 5 & 7. BattleActor consolidation — done
`BattleActor.gd` was ~90% `pass` stubs; all the real logic was duplicated (or
near-duplicated) between `Unit.gd` and `BattleObject.gd`. Moved up to the base
class, with small hook methods for the genuine differences:
- HP mutation (`apply_damage`/`apply_heal`) — now one implementation, with
  `_play_hit_feedback()` / `_on_damaged()` / `_on_defeated()` /
  `_get_damage_anim_player()` hooks for what a Unit vs. a BattleObject does
  locally when hit
- Effect storage (`has_effect`/`get_effect`/`apply_effect`/`remove_effect`) —
  identical in both, now lives once; `BattleObject` overrides only
  `apply_effect`/`remove_effect` to add its grid registration step, via `super`
- `play_damage_count` — one implementation, driven by whichever
  AnimationPlayer the subclass points at
- `update_z_index` — one implementation, using a `_grid_ref` both subclasses
  now set during their own `setup()`
- Found and fixed a real bug this surfaced: `BattleObject.apply_effect` used
  to register with the grid even when `data.is_dead` was true (the dead-check
  guard existed on `Unit`'s version but not `BattleObject`'s)

Also found and fixed the same "template stub, duplicated logic" pattern in
`Core/Battle/AbilityVisuals/`: `AbilityVisual._calc_duration()` is a shared
formula that `ArrowVisual.travel()` had literally copy-pasted instead of
calling. Now calls it. Also consolidated a duplicated magic constant
(`14 * 4 + 3`, `Constants.MAX_ELEVATION * 4 + 3`, appearing 3 separate places)
into `Constants.UNOCCLODED_ACTOR_Z_INDEX` / `Constants.Z_INDEX_LAYER_STRIDE`.

## 6. Objects showing CharacterInfo — done, was a one-line bug
`CharacterInfo` already fully supported rendering `ObjectData` (name + HP, no
MP/level — see `_render()`). The gap was purely upstream: the hover handler in
`battle_scene._on_cell_hovered()` called `_battle_grid.get_unit_at()`, which
only ever returns units. `get_actor_at()` (checks both units and objects,
units taking priority) already existed and was unused. Swapped it in.

## 8. Binary player/enemy assumption — two real instances found and fixed
- `ActorMarker.actor_type` was a **second**, independent `Type` export,
  separate from the `type` field already authored on the marker's
  `actor_data`. No marker in `battle_scene.tscn` ever set it, so it silently
  defaulted to `PLAYER` for everything (including Theo, authored as `type=1`
  ENEMY). Removed; spawn logic now reads `actor_data.type` directly.
- `UnitData.is_player_controlled: bool` was **another** independent boolean,
  duplicating `type`. Already caught actively drifting in
  `Tests/BattleScenarioGenerator.gd`, which set both `type` and
  `is_player_controlled` separately (an easy place for them to disagree).
  Removed; the 3 real call sites (`AIBrain`, `BattleHUD`, `InputHandler`) plus
  2 test call sites now check `data.type == BattleActorData.Type.PLAYER`
  directly against the enum.

I grepped the whole project for `is_player_controlled` / binary player checks
afterward — nothing else turned up. `TurnQueue` only tracking
player/enemy arrays (excluding neutrals) is intentional design, not a bug —
neutral units aren't supposed to take turns.

## 9. General bugs found and fixed (not already covered above)
- `Data/Objects/Barrel.tres` — dead orphaned duplicate, deleted (see item 1)
- `Electrified.tscn` was silently running `Burning.gd`'s script (byte-for-byte
  identical file, itself dead code — `Electrified.gd` was never referenced
  anywhere). Consolidated into one shared `Scenes/Battle/Effects/TileEffectVisual.gd`.
- `JobData.flip_offset` was authored data (non-zero on Knight and Pirate) that
  was **never read anywhere in the codebase**. It looks like it was meant to
  reposition a sprite when facing-flipped (asymmetric art), but
  `set_facing`/`set_facing_toward` never applied it. Removed along with the
  other now-scene-authored visual fields — **but the underlying design gap is
  still open**: if Pirate/Knight's flipped sprite actually needs a position
  correction, that logic doesn't exist anywhere now either. I didn't
  reintroduce a guess at it since I can't verify visually without the actual
  art assets or a running editor. Flagging this as something to check
  in-editor with the real sprites.
- `BattleActor.gd`'s `#func play_damage_count` — a large commented-out dead
  duplicate at the bottom of the old file — removed as part of the rewrite.
- Cleaned up heavy `print()` spam specifically in `battle_scene._spawn_actors()`
  (rewrote using `push_warning`/`push_error` for actual problems instead of
  logging every step unconditionally) since I was already rewriting that
  function for the item 8 fix. I did **not** do a project-wide print() sweep —
  see Suggestions below.

## 10. Comments — done thoroughly on everything touched above; not exhaustive project-wide
Every file rewritten or edited in this pass has section-labeled comments and
inline explanations for non-obvious steps (BattleActor, Unit, BattleObject,
UnitData, JobData, battle_scene spawn logic, AbilityVisual + subclasses,
EffectHandler, AbilityTiming, the new test suite). I did **not** do a
project-wide pass over every one of the ~150 `.gd` files that weren't touched
for another reason (e.g. most of `Resources/Effects/Handlers/*.gd`, the AI
`Considerations/*.gd`, `Core/Grid/BattleGrid.gd` beyond the one-line fix). If
you want that as an explicit next pass, say the word — it's a big, boring,
mechanical task that's very doable, just not something I want to rush through
in the same pass as the structural changes above.

## 11. Utility / tooling suggestions
- **Centralized debug logging.** The project leans hard on raw `print()` —
  scattered across `BattleManager`, `ActorMarker`, `UnitAbilityExecutor`, etc.
  — with no way to turn a category off without deleting the line. A small
  autoload (`DebugLog.gd`) with per-system toggles
  (`DebugLog.spawn("...")`, `DebugLog.enabled.spawn = false`) would let you
  keep this level of visibility during active development without it
  drowning out the console during normal play. `Tests/BattleLogger.gd`
  already does something adjacent for test runs specifically — worth looking
  at whether that pattern generalizes.
- **Pure-function extraction for testability**, demonstrated by
  `AbilityTiming.gd` this pass: any time a formula lives inline inside a big
  async/stateful function, it's untestable in isolation. Worth doing the same
  extraction for `EffectDamageResolver`-adjacent math if more of it
  accumulates, and for the AI `Consideration` scoring formulas if they ever
  get complex enough to need dedicated tests.
- **The marker-based placement pattern is worth reusing.** You already said
  this is the kind of tool you want more of — two concrete candidates I
  noticed while reading: (1) `BattleScenario`/`BattleTestRunner`'s random
  scenario generation could plausibly use hand-placed markers for
  hybrid "randomize around these fixed points" scenarios instead of pure
  randomization; (2) patrol/AI waypoints for future non-battle or ambient
  units, if that's ever a direction the game goes.

## Open Items — status update (third pass)

The remaining items from the second pass are now done:

- **Full print() → DebugLog migration — done.** Went through every runtime
  `.gd` file with a `print()` call (excluding `Tools/*` build scripts,
  `Tests/*` which prints intentionally, and explicitly-named debug utilities
  — `battle_scene._debug_print_grid()`, `ActionCandidate.debug_print()`,
  `Scenes/Battle/debug.gd`, and `ActorMarker.gd`'s `@tool`-only editor
  preview logging, all deliberately left as plain `print()` since they're
  either opt-in tools or editor-only, not runtime noise). Converted:
  `CinematicDirector.gd` (the worst offender — 11 sequential trace prints
  narrating one function step-by-step, collapsed to 2 `DebugLog.effects`
  calls), `ActionEnumerator.gd`, `ActionResolver.gd`, `TileVisualManager.gd`,
  `TurnQueue.gd`, `EffectExecutor.gd`, `EffectHandler.gd`, `battle_scene.gd`
  (remaining spots beyond the spawn-loop already done in an earlier pass).
  Also removed a handful of dead commented-out `#print(...)` lines found
  along the way (`BattleManager`, `BattleStart`, `ActionEnumerator`,
  `Pathfinder`, `TurnQueue`, `MouseDetectRect`).
- **Two more real bugs found during the sweep:**
  - `BattleUI.refresh_character_info()` was dead code (never called anywhere)
    that called `character_info.setup(actor)` — a method that doesn't exist
    on `CharacterInfo` (it has `refresh()`/`set_hovered_actor()`, no
    `setup()`). Would have crashed instantly if anything had ever called it.
    Removed.
  - `Core/AI/Considerations/ResourceEfficiency.gd` had no `is_relevant()`
    override, so — unlike its sibling stub `EffectSynergy.gd`, which
    correctly opts out — it silently ran on every single scoring pass,
    inheriting the base class's `get_consideration_name() -> ""` and writing
    a spurious `""` key into every action candidate's score dictionary for
    zero actual effect. Every `AIProfile` (Marta/Theo/Auburn included)
    authors a `"resource_efficiency"` weight that this bug made permanently
    dead. Fixed to match `EffectSynergy`'s honest "not implemented, opted
    out via `is_relevant()`" pattern, with `get_consideration_name()`
    corrected to `"resource_efficiency"` so it's ready to receive real
    scoring logic whenever that gets designed.
- **Comment sweep — extended to the remaining under-commented files.**
  `Core/AI/AIBrain.gd` was done in the prior pass. This pass added:
  one-line behavioral headers to the 3 effect handlers that had real logic
  but zero comments (`BlazingHandler`, `ElectrifiedHandler`, `FrozenHandler`
  — each now explains how it differs from `BurningHandler`, its closest
  sibling, since that comparison is more useful than restating what each
  config field does); doc comments on `KillPotential.gd` and
  `TargetWeakness.gd` (previously uncommented despite non-trivial scoring
  logic); and the `ResourceEfficiency`/`EffectSynergy` fix above, which
  needed real explanation, not just a header.

  Deliberately **not** touched: the ~38 near-identical stub handlers in
  `Resources/Effects/Handlers/` (Poison, Sleep, Silence, etc.) — these
  already carry an appropriate "stub, registered for coverage, not yet
  implemented" comment and are otherwise just 4 empty override functions
  each; adding more prose per file would be padding, not information.

At this point every item from the original 12-point brief has had at least
one full pass, and every explicitly-deferred follow-up from earlier rounds
has been completed. What's left is genuinely open-ended (a hypothetical
line-by-line comment pass on the ~150 files never otherwise touched) rather
than a known gap.

## Open Items — status update (second pass)

Everything below was marked "deferred" in the first pass and has now been done:

- **`Data/Abilities` reorg — done.** `Flame`, `Freeze`, `Spark` each now have
  their own folder (`.tres` + `.tscn` together), matching Barrel/Units.
  `Arrow.tscn` (shared, no 1:1 ability) and the scene-less `Fight_*.tres`/
  `Last_Ditch_Effort.tres` were left at `Data/Abilities/` root as planned.
- **DebugLog utility — added and demonstrated.** New autoload
  `Autoloads/DebugLog.gd`, registered in `project.godot`. Per-category
  toggles (`spawn`, `battle_state`, `ability`, `ai`, `effects`). Migrated the
  two noisiest offenders as a working example: `BattleManager.gd` and
  `UnitAbilityExecutor.gd` (the latter had ~20 unconditional `print()` calls
  tracing a single async function step-by-step — collapsed into fewer,
  higher-signal `DebugLog.ability(...)` calls, since the function's own
  numbered-step comments already carry most of that narrative). Editor-tool
  prints in `ActorMarker.gd` were deliberately left as plain `print()` —
  they're `@tool`-script/editor-only, low volume, and not part of the runtime
  noise problem this utility targets.
- **AIBrain.gd comment pass — done.** This was the one "major template" file
  with a noticeably lower comment density than its neighbors (5 comments over
  197 lines). Added section headers and, more importantly, actually explained
  the intelligence→bucket→random-top-3 action selection scheme, which wasn't
  documented anywhere and isn't obvious from the code alone. Also removed a
  pile of dead commented-out `#print(...)`/`#action.debug_print()` lines that
  had accumulated across `_choose_action`.

**Still not done, still explicitly deferred:** a full project-wide comment
sweep of every untouched `.gd` file (most of `Resources/Effects/Handlers/*`,
the AI `Considerations/*`, most of `Core/Grid/BattleGrid.gd` beyond its
existing — already decent — comments), and a full project-wide `print()` →
`DebugLog` migration beyond the two files above. Both are large, mechanical,
low-risk tasks — say the word if you want them done exhaustively rather than
by example.
- **`flip_offset` gap (see item 9)**: needs an in-editor look with real art to
  decide if flipped-sprite repositioning is actually needed, and if so, where
  it belongs now that positioning is scene-authored rather than data-driven.
- **`Data/Abilities` reorg deferred.** `Flame.tres`+`Flame.tscn`,
  `Freeze.tres`+`Freeze.tscn`, `Spark.tres`+`Spark.tscn` are paired the same
  way Barrel's data+scene were, and would benefit from the same per-instance
  folder treatment. `Arrow.tscn` is a shared generic projectile visual (no
  1:1 ability), and `Fight_*.tres`/`Last_Ditch_Effort.tres` are data-only with
  no scene — I'd leave those where they are. Want me to do this pass too?
- **Project-wide comment sweep and print() cleanup** — both mentioned above as
  explicit, scoped follow-ups I didn't want to rush into the same pass as the
  structural refactor.
- **`ActorMarker.tscn` (the barrel-icon-in-editor scene under `Scenes/Battle/`)
  appears completely unused** — nothing instances it; markers in
  `battle_scene.tscn` are plain `Node2D`s with `ActorMarker.gd` attached
  directly. Worth a decision: finish wiring it up as the actual marker visual,
  or delete it.
- **Godot verification caveat**: I don't have a Godot editor available in this
  environment, so none of the `.tscn`/`.tres` surgery in this pass has been
  opened and confirmed inside the actual editor — only checked mechanically
  (every `path=` reference resolves to a real file, syntax matches the
  existing inherited-scene pattern from Barrel). Please do a full open-and-
  run pass before trusting this in a real session, especially the three new
  job scenes (Knight/Pirate/Archer.tscn) and the Unit/Object base scene moves.
