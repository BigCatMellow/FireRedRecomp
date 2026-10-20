# Task: protection slice P1 — the protected-target check

- Task ID: `P4-PROTECTION-P1`
- Status: `DONE — independently reviewed PASS WITH CORRECTIONS (applied)`
- Lane: full relay (a gate that touches every admitted move family, new
  per-turn battle state, a new controller text)
- Spec: [protection design proposal](../reports/phase4-protection-design-proposal.md)
  (§2, §4 shapes A-E, §5, "P1: the protected-target gate", verification
  plan P1), status `independently reviewed PASS WITH CORRECTIONS (applied)`,
  with the [design review](../reviews/2026-10-15-protection-design-review.md)
  folded in: F1 (paralysis gate order), F2 (Jump Kick into a protected
  Ghost), F4 (the move-passed-attackcanceler flag before the charge block),
  F5 (Triple Kick's draw under the known gap), D2 (P1 ships as
  infrastructure: nothing sets the flag until P2), D5 (Nightmare, Ghost
  Curse and Psych Up pass through).
- Base: `f45aefb` on `claude/wizardly-faraday-o45q9z` (origin/main, P4 and P5
  merged).

## Source lock (pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`)

Abbreviations: `bsc.c` `src/battle_script_commands.c`, `bs1.s`
`data/battle_scripts_1.s`, `bm.c` `src/battle_main.c`, `msg.c`
`src/battle_message.c`, `bu.c` `src/battle_util.c`, `moves.h`
`src/data/battle_moves.h`.

- **Predicate** `DEFENDER_IS_PROTECTED` (`bsc.c:42`):
  `gProtectStructs[gBattlerTarget].protected && (flags &
  FLAG_PROTECT_AFFECTED)`, bit 1 (`include/constants/pokemon.h:239`). A
  `MOVE_TARGET_USER` move's target is the user
  (`src/battle_controller_player.c:460-466`, `battle_controller_opponent.c:1370`,
  `:1393`), never protected while it acts.
- **`Cmd_attackcanceler`** `bsc.c:896-905`: after the cancellers and the
  no-PP check, `DEFENDER_IS_PROTECTED && (Curse clause) && (!IsTwoTurnsMove
  || MULTIPLETURNS)` → `CancelMultiTurnMoves(attacker)` (`bu.c:203-214`),
  `MOVE_RESULT_MISSED`, `MISS_TYPE = B_MSG_PROTECTED`, and the script
  continues. `HITMARKER_OBEYS` is set just before (`bsc.c:828-864`).
- **`Cmd_accuracycheck`** `bsc.c:1003-1105`: `ACC_CURR_MOVE` runs
  `JumpIfMoveAffectedByProtect` before `AccuracyCalcHelper` (no `Random()`,
  no `CheckWonderGuardAndLevitate`); `NO_ACC_CALC(_CHECK_LOCK_ON)` tests
  Lock-On, then the semi-invulnerable jump, then protect (`:1020-1027`).
- **`Cmd_resultmessage`** `bsc.c:1937`: the miss string prints when `MISSED
  && (!DOESNT_AFFECT_FOE || MISS_TYPE > B_MSG_AVOIDED_ATK)`; `B_MSG_PROTECTED`
  is 1, so "It doesn't affect" wins whenever a typecalc flagged immunity.
  `gMissStringIds[B_MSG_PROTECTED]` (`msg.c:897`) is
  "{B_DEF_NAME_WITH_PREFIX}\nprotected itself!" (`msg.c:66`).
- **Lifetime**: cleared by `TurnValuesCleanUp(TRUE)` at the start of
  `BattleTurnPassed` (`bm.c:2957`, `:3630-3634`) and by `FaintClearSetData`
  (`bm.c:2461`).
- **Flag census** (`moves.h`, every record): the only non-`USER` moves
  without `FLAG_PROTECT_AFFECTED` among admitted families are Curse (`flags =
  0`) and Psych Up (`SNATCH` only); the `USER` moves that carry it are Haze,
  Hail, Milk Drink (and the unadmitted Bide, Wish, Imprison, Grudge).
- Per-family scripts, each re-read at the pin while implementing (see the
  table below for the lines).

## Design (as implemented)

- `makeBattler` field `protected = false` (battle-only, never persisted).
  `runTurn` clears it for both battlers beside `tookMoveDamage`;
  `recordFaint` clears it.
- `BattleEngine:protectBlocks(defender, move)`: protected, flag bit 1, and
  not a `MOVE_TARGET_USER` move.
- `resolveMove` resets `self.protectedMove` and `self.moveObeyed` per
  action.
- `resolveMoveCore`:
  - **F4:** `self.moveObeyed = true` after the cancellers and the locked
    0-PP check, **before** the charge block (nothing reads it until P2).
  - **Trap 2:** `rampageLocked` is captured after the charge block and
    **before** the protect step (it used to be computed at the shared PP
    site, after where the cancel now runs).
  - **The attackcanceler step**, after the charge block's second-turn arm
    (**trap 1**: turn 1 returns inside the block and is never blocked; turn 2
    has already cleared the lock and set `noPPDeduct`), before the Focus
    Punch branch: `if protectBlocks then protectedMove = true;
    cancelMultiTurnMoves(attacker) end`. No RNG.
  - `failedOrProtected(attackerSide, defenderSide)` returns `protected`
    when `protectedMove`, else `moveFailed` (a `ButItFailed` reached with
    `MISSED` already set).
- Event `protected{side = <attacker>, target = <defender>}`; controller text
  "<target>\nprotected itself!". Header event list updated.

| Family (effect) | Source | Protected behaviour |
| --- | --- | --- |
| Shape A: every `EffectHit` variant (0, 2, 4, 5, 6, 31, 36, 43, 68-73, 76, 103, 125, 138-140, 146, 149, 150, 152, 169, 171, 182, 200, 202-204, 207, 209), 17, 78, 99, 101, 190, 129, 186, 42, 48/198 and Struggle, 3, 80, 29/44/77, 40, 41/130, 87, 88, the stat-down family, 27 turn 1, 158 turn 1, 170 not hit | `bs1.s:246-285`, `:605-611`, `:536-560`, `:808-835`, `:1199-1210` | shared accuracy step, **before** the semi-invulnerable test and the roll: "used", protected, PP −1, no draws, no damage/secondary/recoil/drain/wrap/recharge lock, no multi-hit count draw; Thunder in rain, Swift and Vital Throw included |
| 104 Triple Kick | `bs1.s:1380-1430` | protected (0 hits), PP −1, 0 draws. **F5:** source still draws `TripleKickEnd`'s `seteffectwithchance` `Random() % 100`; the engine omits it under the tracked trailing-roll gap (inventory row 104) |
| 118 Swagger / 166 Flatter | `bs1.s:1604-1608`, `:2147-2151` | no roll; PP −1; protected |
| 1 sleep, 66 poison, 33 Toxic, 167 Will-O-Wisp | `bs1.s:287-300`, `:984-1003`, `:687-700`, `:2170-2185` | printstring gates (already, Insomnia/Vital Spirit, Immunity, Water Veil) and `NotAffected` (type) keep their text; "any status" and the final accuracycheck → protected, no draw |
| 67 Thunder Wave / Stun Spore / Glare (**F1**) | `bs1.s:1005-1022` | Limber, then the typecalc immunity ("doesn't affect"), then protected **even when already paralyzed** (the already-paralyzed and any-status gates are skipped) |
| 49 confuse, 199 Teeter Dance | `bs1.s:902-917`, `:2566-2618` | Own Tempo / already confused keep their text; otherwise protected, no draw |
| 205 Tickle | `bs1.s:2644-2677` | both at −6 keeps "won't go lower"; otherwise protected |
| 38 OHKO, 91 Pain Split | `bs1.s:761-775`, `:1235-1245` | protected (not "But it failed!"), no `tryKO` draw, no HP change |
| 106 Mean Look | `bs1.s:1440-1453` | protected before the already-prevented gate; no escape lock |
| 84 Leech Seed | `bs1.s:1153-1166`; `bsc.c:6436-6456` | no roll; `leechSeed{result = "evaded"}` (also for a Grass target) |
| 107 Nightmare (D5) | `bs1.s:1455-1469`; `bsc.c:2678-2681` | the fail paths give protected; **an asleep target is still put in a nightmare** |
| 168 Memento | `bs1.s:2199-2201`, `:2234-2244` | `mementoHP`, protected, the user faints; no stat drop, never fails at −6/−6 |
| 7 Explosion | `bs1.s:376-417` | crit and damage draws taken (2), no accuracy draw; protected, or "doesn't affect" against an immune target; the user faints |
| 147 Earthquake / 126 Magnitude | `bs1.s:1679-1690`, `:1830-1875` | Magnitude's strength roll first; the miss path's typecalc: Flying → "doesn't affect", else protected |
| 45 Jump Kick / Hi Jump Kick (**F2**) | `bs1.s:853-870` | protected, then the crash (the protect path skips the immunity scan), one random draw; normal crash damage, **0 HP against a Ghost** (the existing leaf already models the crash's own typecalc, so it is reused) |
| 189 Endeavor | `bs1.s:2474-2485` | protected in both HP orders, no draw |
| 92 Snore | `bs1.s:1253-1268` | awake → protected; asleep → "fast asleep", then protected, no flinch draw |
| 158 Fake Out after the first turn | `bs1.s:2044-2059` | protected instead of "But it failed!" |
| 170 Focus Punch hit this turn | `bs1.s:2255-2261` | lost focus (unchanged; it precedes any protected text) |
| Pass-through: 109 Curse (both paths, flags 0), 143 Psych Up (flags `SNATCH`), 25 Haze and 164 Hail (`USER`), every `USER` family, turn 1 of 39/75/145/151/155, Nightmare on a sleeping target | `moves.h`; `bsc.c:896-899` | identical events, draws and state with or without the flag |
| Charge turn 2 (39/75/145/151/155) | `bs1.s:784-792`, `:1997-2008` | "used", protected, **no PP**, the lock and the semi-invulnerable bit cleared, unlocked next turn; Solar Beam in sun spends its one PP before and is blocked the same turn |
| 27 rampage, locked turn | `bs1.s:585-593`; `bu.c:203-214` | protected; the rampage ends with **no fatigue confusion**; PrintMoveMissed's guarded `ppreduce` (1 PP, 0 stays 0) |

Residual end-of-turn effects never read the flag, so poison, Leech Seed,
wrap and Curse damage still tick on a protected battler.

## File ownership

- **MAY CHANGE:** `src/core/BattleEngine.lua`;
  `src/core/BattleSceneController.lua` (the `protected` text only);
  `tests/battle_protection_p1_test.lua` (new);
  `work/reports/phase4-move-effect-inventory.md` (notes only); this task
  file.
- **MUST NOT CHANGE:** `main.lua`, party/Dex code, coordination and roadmap
  files, `AICheckBadMove.lua` (no source row needs it).

## RNG change and changed assertions

- **None.** The flag is never set outside tests, so no live battle,
  existing test or replay can reach a changed branch. The new per-turn
  reset, the `moveObeyed` write and the moved `rampageLocked` capture draw
  nothing. The full no-ROM suite's per-file output is byte-identical to the
  pre-change run except for the added test file.
- **Changed assertions:** none. `tests/phase4_move_effect_inventory_test.lua`
  is untouched (P1 admits nothing; admitted/rejected stay 299/55).
- Inventory notes for rows 158 and 170 now say P1 gives the protected text.

## Acceptance

- `tests/battle_protection_p1_test.lua`: 652 checks, exact `scriptedRng`
  draw counts. Move records are transcribed from `moves.h` at the pin with
  line numbers.
  - Defaults, the predicate (flag bit, `USER` target, unprotected), the
    `runTurn` reset (a stale flag blocks nothing: Tackle hits, 3 draws) and
    the `recordFaint` reset.
  - A 105-row table, every admitted family against a protected target
    through `resolveMove`: the event signature, the draw count, the PP
    change, no damage/recoil/drain/HP change, no status or stage change, and
    a per-row effect check (no wrap, no recharge lock, no rampage lock, seed
    kept after Rapid Spin, screens kept after Brick Break, paralysis kept
    after Smelling Salt, no confusion, no escape lock, Pain Split HP
    unchanged). Includes the F1 rows (Thunder Wave, Stun Spore and Glare
    against an already-paralyzed target give `protected`; Limber and a
    Ground/Ghost type keep their texts) and the gate-text rows for every
    shape-B family.
  - Struggle (move 165): protected, no PP.
  - Shape D: Nightmare lands on a sleeping target; Memento faints the user
    with no drops, also at −6/−6; Self-Destruct takes 2 draws and faints the
    user, "doesn't affect" against a Ghost; Jump Kick crash 5 and Hi Jump
    Kick crash 6 (one draw each); **Jump Kick into a protected Ghost: the
    protected text, the crash text, one draw, no HP loss (F2)**, with the
    controller texts.
  - Shape E: 21 pass-through moves give identical events, draws and state
    with and without the flag; Ghost Curse curses (the user pays 200 of 400
    HP), Psych Up copies +3.
  - Multi-turn: turn 1 of all eight two-turn moves charges against a
    protected target; turn 2 is "used, protected", 0 draws, no PP, lock and
    semi-invulnerable bit cleared, unlocked. Solar Beam in sun: 1 PP,
    blocked, unlocked. Locked Thrash: an unprotected control ends in fatigue
    confusion; the protected last locked turn ends the rampage with no
    confusion, 1 PP, unlocked; a locked 0-PP Thrash stays at 0 PP (trap 2).
    A recharging battler against a protecting foe is unaffected.
  - Residuals: poison, Leech Seed, wrap and Curse damage still tick on a
    protected battler.
  - Focus Punch hit this turn into Protect: lost focus wins. F4: a charging
    turn 1 and a protected move set `moveObeyed`; a full paralysis does not.
  - Controller texts: "PLAYER used TACKLE!|FOE\nprotected itself!", the
    foe's move naming the player, Leech Seed "evaded the attack!", Thunder
    Wave into a protected Ground type "It doesn't affect FOE...".
- Mutation spot-checks (each applied to a scratch copy written over the
  working tree, then restored from a fresh scratchpad backup, `cmp` clean):
  the protect step before the charge block fails 17; `rampageLocked` after
  the cancel fails 1; no `cancelMultiTurnMoves` in the step fails 3; the F1
  gate after "already paralyzed" fails 3; Jump Kick taking the immunity scan
  fails 2; the Ghost crash losing HP fails 2; the predicate ignoring the
  `USER` target fails 1 or the flag fails 1; Leech Seed rolling fails 6;
  Nightmare blocked on a sleeping target fails 3; no Memento branch fails 2;
  Explosion rolling accuracy fails 2; no typecalc in the Earthquake miss
  path fails 2; no `runTurn` reset fails 1; no `recordFaint` reset fails 1;
  `moveObeyed` after the charge block fails 1; Mean Look without the check
  fails 3; Triple Kick excluded fails 3; status `failed()` not protected
  fails 11; the status accuracy roll kept fails 12; confuse rolling fails 6;
  Swagger rolling fails 8; Fake Out `moveFailed` fails 1; the controller
  text fails 3. One equivalent mutation survives: testing the
  semi-invulnerable miss before protect in the shared step is unobservable,
  because the protected branch of the miss path runs first either way (and
  a protected battler is never mid-Fly).
- `bash scripts/test_all.sh` and `lua5.1 scripts/check_repository.lua`
  pass; `main.lua` unchanged.

## Deviations from the design

- **Mean Look:** the design puts the check after the semi-invulnerable test.
  The engine tests protect first. In source the semi-invulnerable jump goes
  to `ButItFailed`, whose `resultmessage` prints the protected text anyway
  (attackcanceler already set `MISSED`), so both orders give the same text;
  the state is also unreachable (a protected battler is never mid-Fly).
- **Struggle** is tested through the auto-Struggle path (every slot at 0
  PP), not a slot holding move 165.
- The table also covers Teeter Dance and the Earthquake/Magnitude and
  Explosion loops, whose `movevaluescleanup` clears attackcanceler's
  `MISSED` before the loop's `accuracycheck`; that accuracycheck re-tests
  protect itself, so the outcome is the one the design lists.

## Source behaviour that differed from the proposal's table

- None in outcome. Two source details the table does not spell out, both
  with the same visible result: the loop scripts above re-derive the mark at
  their own `accuracycheck`, and `NO_ACC_CALC`'s semi-invulnerable jump
  still prints the protected text.

## Known limits and follow-ups

- Nothing sets `protected` until P2 (Protect/Detect, its counter and its
  draw).
- Not represented: Substitute (the gates that would print the protected text
  through `ButItFailed`), Magic Coat, Snatch and Lightning Rod precedence,
  Lock-On, Levitate's `B_MSG_GROUND_MISS`, Rollout/Fury Cutter/Uproar/Bide
  state in `CancelMultiTurnMoves`, doubles targeting.
- Triple Kick's trailing `seteffectwithchance` draw stays absent under the
  tracked gap (inventory row 104, F5).
- `moveObeyed` is written but unread until P2.

## Review (2026-10-20)

[Implementation review](../reviews/2026-10-20-protection-p1-implementation-review.md):
PASS WITH CORRECTIONS. F1 applied: a test pins that a blocked action's
protected mark does not leak into the next action (deleting the per-action
reset now fails it). F2 applied: Tackle and a locked Thrash into a protected
Ghost give the protected text, not "doesn't affect". F3 applied: inventory
rows 27/106/109/152/168/189 no longer call Protect absent. F4 (duplicated
Jump Kick predicate) and F5 informational.
`tests/battle_protection_p1_test.lua`: 656 passed.
