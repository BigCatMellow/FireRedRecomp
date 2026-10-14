# Review: P4-MULTITURN-M1 implementation (charge and recharge)

- Record role: `REVIEW`
- Reviewer: independent implementation Reviewer (no authorship of the design or the code)
- Date: 2026-10-14
- Task: `work/tasks/phase4-multiturn-m1.md`
- Commits reviewed: `6c23139`, `b9e7a6f` (`git diff 5dab7a4..b9e7a6f -- src tests`)
- Design and its review: `work/reports/phase4-multiturn-design-proposal.md`,
  `work/reviews/2026-10-14-multiturn-design-review.md` (F1-F12)
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`
  (`src/battle_main.c`, `src/battle_util.c`, `src/battle_script_commands.c`,
  `data/battle_scripts_1.s`, `src/battle_message.c`, `src/data/battle_moves.h`)
- `main.lua` read only (controller callers at `:1328`, `:1397`, `:1553-1690`).

## Verdict

**NEEDS_FIX**

The engine and controller follow the corrected design, and most design-review
corrections are met: F1 timer equivalence, F2 chain stop, F4 Struggle/0-PP
bypass on a live lock, F5 override in every `runTurn` branch, F6 controller
entry points, and the F8 turn-1/turn-2 details. The remaining problems are
small:

- one reachable source divergence (finding 1);
- one controller guard that F6 required and the code leaves out (finding 2);
- missing tests for three source-specified behaviors, which mutation testing
  confirms (finding 3).

None needs a redesign.

## Commands run (all at `b9e7a6f`, clean tree)

| Command | Result |
| --- | --- |
| `lua5.1 tests/battle_multiturn_test.lua` | 36 passed, 0 failed |
| `lua5.1 tests/battle_confusion_flinch_test.lua` | 75 / 0 |
| `lua5.1 tests/battle_status_engine_test.lua` | 202 / 0 |
| `lua5.1 tests/battle_scene_controller_test.lua` | 144 / 0 |
| `lua5.1 tests/phase4_*controller*_test.lua` (3 files) | 8/0, 7/0, 9/0 |
| `bash scripts/test_all.sh` | PASS: 170 test files (no-ROM mode), rc 0 |
| `lua5.1 scripts/check_repository.lua` | PASS (297 Lua, 319 Markdown, 1052 targets) |

## Verified correct

- **F1 timer.** In `runTurn` the override runs first, then the decrement
  (`rechargeTimer - 1`, which clears RECHARGE at 0). `isLocked` returns
  `charging or (recharging and timer > 1)`. Source decrements in
  `TurnValuesCleanUp(FALSE)` at end of turn (`battle_main.c:2970`,
  `:3641-3646`). Walk-through:
  - Hyper Beam turn: 2 in both models.
  - Between turns: engine 2 / source 1. Both are locked.
  - Recharge turn: 1 in both, and the canceller clears it.
  - If the canceller is not reached: at the next selection the engine has
    1 (unlocked by the `> 1` rule, then 0 at the next `runTurn` start), and
    source has 0.
  Every state observable at selection, cancellers or forced-switch time
  matches. `runTurn` is the only per-turn entry: the forced switch goes
  through `resolveForcedSwitch`, which is not a turn.
- **F2.** The recharge canceller sits after sleep and freeze and before flinch.
  It clears the bit and the timer, calls `cancelMultiTurnMoves`, emits
  `mustRecharge`, and returns `true`. On that turn there is no confusion
  decrement and no paralysis or confusion RNG. A recharger that wakes or
  thaws gets that message first, then "must recharge!". A recharger that
  stays asleep or frozen keeps RECHARGE, which lapses by the timer.
- **Lock state.** `cancelMultiTurnMoves` clears `charging` only. It keeps
  `lockedSlot` while `recharging`, so a recharger that is frozen or put to
  sleep still has its slot. No reachable state has `isLocked` true with
  `lockedSlot == nil`: every path that clears `recharging` (canceller, lapse)
  also clears or re-checks the slot, and `charging` always sets it. Faint
  clears all four fields (`recordFaint`). A switched-in or forced-switched
  battler is built fresh by `makeBattler`, so its timer starts at 0.
  `BattlePartyBridge` persists only HP, status and PP.
- **Charge turn 1.** The cancellers run first, and a cancelled turn 1 gets no
  PP, no lock and no text. If it is not cancelled: PP −1, then the lock, then
  `chargeTurn` (no `useMove`, no RNG). Skull Bash then raises DEF +1, silently
  at +6. The texts match `battle_message.c:135-138`, and "must\nrecharge!"
  matches `:185`.
- **Charge turn 2.** The cancellers run with the lock still set. Then the lock
  is cleared, `noPPDeduct` is set, and the ordinary hit runs from
  accuracycheck with `useMove`. Sky Attack gets crit stage +1 and the 30%
  flinch through `STATUS2_HIT_MOVES[75]` (`bs1.s:784-792`, `bsc.c` critcalc),
  on turn 2 only.
- **Recharge.** It is set after damage and before `runTurn`'s faint check, so
  a KO still costs the next turn. A miss returns earlier, so there is no
  recharge and no roll. A no-effect hit draws one roll through the
  no-effect branch and does not recharge (`bsc.c:2774-2800`).
- **F4.** While a lock is live, the Struggle substitution and the 0-PP guard
  are skipped, and turn 2 fires with every slot at 0 PP.
- **F5.** A locked foe's action is replaced in every branch: move, switch,
  capture and failed run were probed. A locked player's run, capture or
  switch becomes the locked move, and turn order uses the locked slot.
- **Cancel points.** All are present: flinch, full paralysis, confusion
  self-hit, sleep (primary and secondary) and freeze application, and a
  sleeping charger at end of turn (in `resolveEndTurn`, before the timers).
  If the lock is cancelled earlier in the same turn and the battler still
  acts (a thaw), turn 1 runs again with the slot captured at turn start,
  which is the F9 edge (probed; but see finding 1 for the 0-PP sub-case).
- **F6 controller.**
  - `_enterAction` is reached from the `advanceMessage` end and from the
    empty-list fall-through in `_setMessages`, which covers the
    `onMessagesComplete` follow-up and the switch callbacks.
  - Probe: Hyper Beam KOs the foe, the foe replacement is sent out, then
    "A must recharge!" auto-runs, and the AI is consulted for the unlocked
    foe.
  - A locked foe never calls `chooseFoeMove`.
  - Fake engines without `isLocked` or `isOver` are tolerated (nil checks;
    probed).
  - No infinite auto-run is possible. Every locked turn emits a visible
    message ("must recharge!", "used", "fast asleep", "frozen solid",
    "flinched", "fully paralyzed", "confused"), and the lock clears after the
    battler's action. Recursion is therefore bounded at one nested turn.
- **Unaffected paths.** Explosion, Memento, Endeavor, Magnitude and the
  confuse paths come after the charge block and never see charge effects;
  `noPPDeduct` is reset after the cancellers on every action. There is no
  Metronome, Sleep Talk (unsupported, power 0), Pressure or Yawn, so there
  are no other lock sources. The first-battle tutorial only meets rival
  moves. `main.lua` callers are unchanged, and the drive loops still press A
  in MESSAGES.
- The ROM fixture records and inventory partition match `battle_moves.h`
  (8 members; flags and targets checked).

## Findings

### 1. Same-turn lock cancel with 0 PP diverges from source — severity LOW-MEDIUM

Evidence:
- `Cmd_attackcanceler` (`bsc.c:833-842`) runs `AtkCanceller_UnableToUseMove`
  **before** the 0-PP check. A battler whose lock was cancelled earlier in the
  same turn still uses `moves[gCurrMovePos]`: no selection ran, so
  `noValidMoves` is unset (`battle_main.c:3982-3988`).
- The engine runs its `slot.pp <= 0 → noPP` guard and the Struggle
  substitution **before** `resolveStatusCancellers`, and bypasses them only
  while `charging or recharging` is still set at action time.
- Reachable case: turn 1 of a charge move spends its last PP (Sky Attack has
  5). On turn 2 a faster foe puts the charger to sleep (Hypnosis) or freezes
  it (a 10% secondary). Probe (`resolveMoveCore`, Razor Wind at PP 1 plus
  Tackle):
  - engine events: `useMove@foe, statusApplied@player, noPP@player`, with
    the sleep counter **not** decremented (status 4);
  - source: "fast asleep" and the counter decremented (3);
  - freeze: source draws `Random() % 5` and, on a thaw, prints "no PP left";
    the engine skips the roll.
  - With every slot at 0, the engine substitutes Struggle. Struggle hits
    after a thaw, while source prints "no PP left".
- The comment at `BattleEngine.lua:1524` ("real-game-unreachable") is no
  longer true.

Fix: in `runTurn`, record the sides whose action was fixed by a lock at turn
start (for example `self.lockedAction[side] = true` next to the override).
For such an action in `resolveMoveCore`:
- skip the Struggle substitution;
- move the `noPP` check to after `resolveStatusCancellers`, emitted only when
  the lock is no longer live.

Add a test: last PP on turn 1, faster Hypnosis on turn 2, expect
`fastAsleep` and the sleep counter −1.

### 2. `_enterAction` omits the forced-switch guard required by F6 — severity LOW

Evidence: F6 says to auto-run only if "the battle is not over, nothing is
awaiting a forced switch, and" the player is locked. `_enterAction` checks
`isOver` and `isLocked` only. Probe: a controller without `onMessagesComplete`,
where Hyper Beam KOs a foe that has a replacement. Draining the messages enters
ACTION with `awaitingForcedSwitch == "foe"`. `_enterAction` then calls
`_runTurn`, and the engine asserts "a forced switch is pending". Production
`main.lua` always resolves the foe switch in its hook, and with no orchestrator
`hasReplacement("foe")` is false, so the game cannot reach this. It is a
contract deviation and a crash only at a test or fake seam.

Fix: add `and not engine.awaitingForcedSwitch` to the `_enterAction`
condition.

### 3. Source-specified behaviors without tests — severity LOW-MEDIUM

Evidence (mutation survivors, see table):
- **M03.** Moving the recharge canceller after flinch survives. No test has a
  recharger flinched by a faster foe, where source prints "must recharge!"
  and not "flinched!" (`battle_util.c` canceller order).
- **M24.** Removing `cancelMultiTurnMoves` on freeze application survives. The
  only freeze test sets `status = FREEZE` directly, which source cannot reach
  for a charger (design review F3). Nothing checks that an Ice Beam freeze
  ends the lock (so a menu is offered next turn).
- **M17.** Removing the engine's foe override survives, because the
  controller already passes `lockedSlot` and `resolveMoveCore` re-reads it.
  The engine contract (F5: turn order uses the locked slot) has no test with
  a wrong foe slot (for example Quick Attack passed for a locked foe).
- Also untested (probed correct): a locked foe in the capture and failed-run
  branches, and F6(d), the follow-up auto-run of a locked player after a foe
  replacement.
- **M25** (primary sleep cancel removed) is observationally equivalent in M1.
  A slept battler is still asleep at end of turn, so the end-turn
  sleeping-charger cancel (`battle_main.c:2941-2942`) clears the lock before
  the next selection. No test is required for it.

Fix: add tests for M03, M24 and M17, the capture/run foe lock, and the F6(d)
follow-up path.

### 4. Charge/recharge texts omit the foe prefix — severity INFO

`name(side)` returns the bare foe name, so the foe reads "B is glowing!".
Source `B_ATK_NAME_WITH_PREFIX` would read "Foe B" or "Wild B". This
pre-existing controller convention applies to every message and is out of
scope for this task.

## Mutation table

Each mutant was applied to a pristine copy, then run against the multi-turn,
confusion/flinch, status-engine, scene-controller and three phase-4 controller
suites. The files were restored after every mutant. SHA-1 values were checked
after the run (`BattleEngine.lua` 0e54bc09…, `BattleSceneController.lua`
1b60b818…).

| # | Mutant | Result | Killing check |
| --- | --- | --- | --- |
| M01 | recharge canceller after confusion | KILLED | recharge turn: no confusion tick or draw |
| M02 | recharge canceller before sleep | KILLED | asleep recharger; woke up then must recharge |
| M03 | recharge canceller after flinch | **SURVIVED** | — (finding 3) |
| M04 | recharge canceller does not stop the chain | KILLED | recharge turn: no run, no PP |
| M05 | timer decrement removed | KILLED | timer-1 recharge no longer locks |
| M06 | `isLocked` ignores the timer | KILLED | timer-1 recharge no longer locks |
| M07 | turn 1 emits `useMove` | KILLED | Razor Wind turn 1 |
| M08 | turn 1 spends no PP | KILLED | Razor Wind turn 1/2 PP |
| M09 | turn 2 spends PP | KILLED | Razor Wind turn 2 no PP |
| M10 | Sky Attack crit stage removed | KILLED | crit stage 1 |
| M11 | Sky Attack flinch removed | KILLED | turn 2 flinch |
| M12 | recharge on miss | KILLED | missed Hyper Beam |
| M13 | recharge on no-effect | KILLED | Hyper Beam vs Ghost |
| M14 | no roll on no-effect | KILLED | Hyper Beam vs Ghost draw count |
| M15 | Struggle bypass removed | KILLED | locked turn 2 at 0 PP |
| M16 | 0-PP guard bypass removed | KILLED | locked turn 2 at 0 PP |
| M17 | `runTurn` override removed for foe | **SURVIVED** | — (finding 3) |
| M18 | `runTurn` override removed for player | KILLED | recharge turn ignores run |
| M19 | controller does not auto-run | KILLED | locked player gets no menu |
| M20 | controller calls AI for locked foe | KILLED | no extra AI call |
| M21 | flinch cancel point removed | KILLED | flinch on turn 2 |
| M22 | paralysis cancel point removed | KILLED | full paralysis on turn 2 |
| M23 | confusion self-hit cancel point removed | KILLED | confusion self-hit |
| M24 | sleep/freeze application cancel removed (secondary) | **SURVIVED** | — (finding 3) |
| M25 | primary sleep cancel removed | SURVIVED (equivalent in M1) | — (finding 3, end-turn cancel masks it) |
| M26 | end-turn sleeping-charger cancel removed | KILLED | sleeping charger loses lock |
| M27 | faint does not clear the lock | KILLED | faint clears the charge lock |
| M28 | Skull Bash DEF at +6 not silent | KILLED | Skull Bash at +6 silent |
| M29 | recharge timer set to 1 | KILLED | recharging player locked |
| M30 | turn 2 does not clear `charging` | KILLED | lock ends after turn 2 |
| M31 | Skull Bash DEF raise removed | KILLED | Skull Bash +1 |
| M32 | recharge canceller does not clear `recharging` | KILLED | recharge ends after canceller |

Score: 28 killed of 32. Of the 4 survivors, 1 is equivalent and 3 are real
test gaps.

## Required for PASS

1. Finding 1: run the cancellers before the 0-PP/Struggle handling for an
   action fixed by a turn-start lock, plus a test.
2. Finding 2: add the forced-switch guard to `_enterAction`.
3. Finding 3: add tests killing M03, M24 and M17, plus the capture/run foe-lock
   tests and the F6(d) follow-up test.

## Worker disposition (2026-10-14)

F1 fixed: actions locked at turn start keep the locked slot and check PP after the cancellers (a cancelled lock no longer reports no PP early or substitutes Struggle); the stale comment updated; a crash the new test exposed (lockedSlot cleared by the cancel) fixed. F2 guard added. F3 tests added (recharge before flinch, freeze cancel, locked foe order, failed-capture branch, follow-up auto-run, forced-switch guard).
