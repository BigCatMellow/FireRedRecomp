# Review: protection slice P1 implementation (commit `fbf54f5`)

- Reviewed: commit `fbf54f5` on `claude/wizardly-faraday-o45q9z` (base `f45aefb`):
  `src/core/BattleEngine.lua`, `src/core/BattleSceneController.lua`,
  `tests/battle_protection_p1_test.lua`, `work/tasks/phase4-protection-p1.md`,
  `work/reports/phase4-move-effect-inventory.md`.
- Against: `work/reports/phase4-protection-design-proposal.md` (P1 sections, the
  per-family table), `work/reviews/2026-10-15-protection-design-review.md`
  (F1, F2, F4, F5, D2, D5) and the task file.
- Date: 2026-10-20.
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`. The
  local `/tmp/claude-0` copies of `bsc.c`, `bs1.s`, `bmv.h` (battle_moves.h),
  `bm.c` (battle_message.c) and `bmain.c` (battle_main.c) are byte-identical to
  the pinned files (`cmp`). `include/constants/pokemon.h`, `src/battle_util.c`,
  `src/battle_controller_player.c`, `src/battle_controller_opponent.c` and
  `src/battle_message.c` were fetched fresh from raw.githubusercontent.com at
  the pin.
- Abbreviations: `bsc.c` = `src/battle_script_commands.c`, `bs1.s` =
  `data/battle_scripts_1.s`, `bmain.c` = `src/battle_main.c`, `msg.c` =
  `src/battle_message.c`, `bu.c` = `src/battle_util.c`, `moves.h` =
  `src/data/battle_moves.h`.
- Nothing was committed. Every mutation was applied over the working tree
  from a scratchpad backup and restored. `git status` and `git diff` are clean
  apart from this file.

## Verdict: **PASS WITH CORRECTIONS**

The engine change is faithful to source. I found no behavioural defect:

- the predicate;
- the attackcanceler placement and both ordering traps;
- every family I traced (more than 20, across shapes A-E and all the special
  cases);
- the lifetimes;
- the controller text.

The no-regression claim holds byte for byte. The corrections are two test
gaps on load-bearing lines and one documentation inconsistency (F1-F3). No
engine code needs to change.

## Findings

### F1 (MEDIUM, test gap): the per-action `protectedMove` reset in `resolveMove` is unpinned

`BattleEngine:resolveMove` resets `self.protectedMove = false` before each
action (`src/core/BattleEngine.lua:1620`). It is the only thing that stops one
blocked action's MISS_TYPE from leaking into the next action. Source clears
`MISS_TYPE` per action in `HandleAction_UseMove` (`bmain.c:3979`).
`runTurn` does not touch `protectedMove`, so without this line the mark also
carries into the next turn.

- Mutation: delete line 1620. The result is 652/652 passed and
  `scripts/test_all.sh` still passes.
- Probe (scratchpad, using the test's own `battle`/`protectDuring` helpers): the
  player Tackles into a protected foe, then the unprotected foe Tackles the
  player in the same turn.
  - With the line: `useMove:player, protected:player, useMove:foe,
    critical:foe, damage:foe`, 3 draws.
  - Without it: `useMove:foe, protected:foe`, 0 draws, and the player takes no
    damage.

P2 reaches this state in every live Protect turn. Add a test where a blocked
action is followed by an unprotected action (same turn, and the first action
of the next turn) that hits with its normal draws.

### F2 (LOW, test gap): the converse of the "It doesn't affect" priority is untested

Source: the shape-A scripts (`BattleScript_EffectHit`, `bs1.s:246-285`) and
the rampage script (`bs1.s:585-593`) run `accuracycheck` before any
`typecalc`. `JumpIfMoveAffectedByProtect` returns before
`CheckWonderGuardAndLevitate` (`bsc.c:1040-1041`, `:1102`). So a protected
**immune** target, such as Tackle or Thrash into a Ghost, prints "protected
itself!", not "It doesn't affect". A rampage also does not set
`targetNotAffected`.

The engine does this correctly (`BattleEngine.lua:2793-2812`). The tests pin
only the cases where "doesn't affect" wins:

- Thunder Wave into Ground;
- Glare into Ghost;
- Earthquake and Magnitude into Flying;
- Self-Destruct into Ghost.

Mutation: give the protected miss branch a typecalc for `EFFECT_HIT` and
`EFFECT_RAMPAGE` as well (`if HITS_UNDERGROUND[...] or effect == 0 or effect ==
RAMPAGE`). The result is 0 failures, and the suite passes.

Add two rows:

- Tackle into a protected Ghost gives `protected` with 0 draws.
- A locked Thrash into a protected Ghost gives `protected`,
  `targetNotAffected` stays false, the rampage ends and there is no fatigue
  confusion.

### F3 (LOW, docs): inventory notes still say Protect is absent on rows P1 now covers

The commit updated rows 158 (Fake Out) and 170 (Focus Punch). These rows of
`work/reports/phase4-move-effect-inventory.md` still say Protect is "absent" or
"not modeled", although P1 now implements their protected paths:

| Line | Row |
| --- | --- |
| 133 | 27 Rampage |
| 212 | 106 Mean Look |
| 215 | 109 Curse (pass-through) |
| 258 | 152 Thunder |
| 274 | 168 Memento ("Protect/Substitute/Mist/abilities not modeled"; P1 implements `BattleScript_MementoTargetProtect`) |
| 295 | 189 Endeavor |

Update them in the same style as rows 158 and 170 ("P1 gives the protected
text …; the flag is set only by tests until P2"). Leaving them is harmless to
behaviour, but the inventory is the admission ledger.

### F4 (INFO): the Jump Kick test is a magic-number duplicate

`BattleEngine.lua:2812` adds a second copy of the existing test `move.effect ==
45 and (moveId == 26 or moveId == 136)` (the first is at `:2833`). Behaviour
is correct: effect 45 is only Jump Kick and Hi Jump Kick (`moves.h:341`,
`:1771`). A named local or constant would keep the two sites in step. This is
optional.

### F5 (INFO): the one surviving shared-step mutation is equivalent, as the task file says

Testing the semi-invulnerable miss before protect (`local semiMiss =
scriptHasAccuracyCheck` without `not protectedMiss`) survives. That is
expected:

- The `protectedMiss` branch of the miss path runs first, and returns, for
  every non-Jump-Kick family.
- In source the `NO_ACC_CALC` semi-invulnerable jump also ends at a
  `resultmessage` that prints the protected text (`bsc.c:1020-1027`).
- A battler that has just used Protect cannot be mid-Fly.

## Verification detail

### 1. The predicate

`DEFENDER_IS_PROTECTED` is `gProtectStructs[gBattlerTarget].protected &&
(gBattleMoves[gCurrentMove].flags & FLAG_PROTECT_AFFECTED)` (`bsc.c:42`).
`FLAG_PROTECT_AFFECTED` is `(1 << 1)` (`include/constants/pokemon.h:239`). The
engine's `math.floor(flags / 2) % 2` is that bit. `flags` reaches the engine
verbatim from the ROM record (`import/BattleMove.lua:46`, byte 0x08).

**The `MOVE_TARGET_USER` exclusion.** The player controller points the cursor
at itself for a USER move (`battle_controller_player.c:460`). The opponent
controller does the same (`battle_controller_opponent.c:1370-1371`, `:1393`).
`HandleAction_UseMove` then reads `gBattleStruct->moveTarget`
(`bmain.c:4116`), and locked moves keep their stored target (`bmain.c:3989`).
So a USER move's target is the user, which is never protected while it
acts. The engine's `MOVE_TARGET_USER = 0x10` bit test matches.

**Census over every record in `moves.h`.**

- The non-USER moves without the protect bit are Counter, Metronome, Mirror
  Move, Transform, Sketch, Curse, Spikes, Sleep Talk, Mirror Coat, Psych Up,
  Future Sight, Nature Power, Role Play, Assist, Magic Coat, Snatch, Doom
  Desire and `MOVE_NONE`. Of these, only Curse and Psych Up are admitted.
- The USER moves that carry the bit are Haze, Bide, Milk Drink, Hail, Wish,
  Imprison and Grudge. Haze, Hail and Milk Drink are admitted, and all three
  pass through.

This matches the task's census.

**Records checked.**

- Curse (`moves.h:2265-2276`): `.flags = 0`.
- Psych Up (`:3175-3186`): `FLAG_SNATCH_AFFECTED` only.

So the Curse clause in `Cmd_attackcanceler` (`bsc.c:897`) is dead, and Ghost
Curse lays its curse through Protect. Its `NO_ACC_CALC_CHECK_LOCK_ON` re-test
uses the same macro.

**Test transcriptions.** I compared every `rec(...)` in the test file
against `moves.h`: power, accuracy, PP, chance, target, priority and flags.
There were 0 mismatches across all transcribed records.

### 2. Placement and the two ordering traps

**`IsTwoTurnsMove`** (`bsc.c:7822-7832`) is true for Skull Bash, Razor Wind,
Sky Attack, Solar Beam, the semi-invulnerable moves and Bide.

- Turn 1, `BattleScriptFirstChargingTurn` (`bs1.s:794-806`): its
  attackcanceler runs without MULTIPLETURNS, so the move is not blocked. In
  the engine, turn 1 returns inside the charge block before the step.
- Turn 2, `BattleScript_TwoTurnMovesSecondTurn` and
  `BattleScript_SecondTurnSemiInvulnerable` (`bs1.s:784-792`, `:1993-1999`):
  attackcanceler is blocked while MULTIPLETURNS is set. Then
  `clearstatusfromeffect` and `orword HITMARKER_NO_PPDEDUCT` run. So the
  blocked move spends no PP, the lock is cleared, and
  `CancelMultiTurnMoves` clears `STATUS3_SEMI_INVULNERABLE`
  (`bu.c:203-214`). The engine's second-turn arm does exactly this before
  the step, and the shared PP site honours `noPPDeduct`.

**Solar Beam in sun.** `BattleScript_SolarBeamOnFirstTurn` (`bs1.s:1909-1914`)
sets MULTIPLETURNS and spends one PP, then jumps to the second-turn
attackcanceler, where the move is blocked. In the engine, `charging` is set
before the cancellers, so the move takes the second-turn arm and is gated with
1 PP spent. This matches.

**Mutations on placement.**

- Moving the step before the charge block fails 18 checks.
- Making a protected charge turn 2 spend PP fails 9.
- Computing `rampageLocked` after the cancel fails 1. This is the locked 0-PP
  Thrash: source `PrintMoveMissed`'s `ppreduce` is guarded at 0 PP.
- Dropping `cancelMultiTurnMoves` fails 3.

**Rampage** (`bs1.s:585-593`). A blocked Thrash takes `PrintMoveMissed`,
which runs `ppreduce`: 1 PP, and 0 stays 0. `CancelMultiTurnMoves` clears
`LOCK_CONFUSE`. The engine's `ENDTURN_THRASH` analogue
(`BattleEngine.lua:4429-4441`) then sees `rampageTurns == 0`, so there is no
fatigue confusion. This matches.

**Hyper Beam** (`bs1.s:1107-1111`). `setmoveeffect MOVE_EFFECT_RECHARGE` comes
after `accuracycheck`. A blocked Hyper Beam therefore sets no recharge in
source, and the engine sets none either.

**Wrap** (`bs1.s:829-836`). `MOVE_EFFECT_WRAP` is only applied by the hit
path, so a blocked Wrap sets no wrap.

**A recharging battler** is stopped by `CANCELLER_RECHARGE` before
attackcanceler, so it is unaffected.

**`moveObeyed` (review F4).** It is set after the cancellers and the locked
0-PP check, before the charge block (`BattleEngine.lua:2162`). Source sets
`HITMARKER_OBEYS` at `bsc.c:864`, after the no-PP check and disobedience.
Moving it after the charge block fails 3 checks.

### 3. Per-family outcomes (traced against the scripts)

| Family | Source | Engine result (confirmed) |
| --- | --- | --- |
| Shape A (Tackle, multi-hit, Wrap, Hyper Beam, Brick Break, Rapid Spin, Thunder in rain, Swift, Vital Throw) | `Cmd_accuracycheck` runs `JumpIfMoveAffectedByProtect` first, before `AccuracyCalcHelper` and `Random()` (`bsc.c:1040-1043`) → `PrintMoveMissed` (`bs1.s:276-285`) | "used", protected, PP −1, 0 draws, no tail |
| Status 1/66/33/167 | `bs1.s:287-300`, `:984-1003`, `:687-700`, `:2170-2185` | printstring and `NotAffected` gates keep their text (`NotAffected` sets `DOESNT_AFFECT`, which wins at `bsc.c:1937`); `ButItFailed` and the final accuracycheck give protected with no draw |
| 67 Thunder Wave/Stun Spore/Glare (F1) | `typecalc; jumpifmovehadnoeffect` before the already/any gates (`bs1.s:1010-1013`) | Limber, then "doesn't affect" (Ground; Glare into Ghost), then protected even when already paralyzed. Removing the gate fails 3; putting protect before typecalc fails 3; skipping Limber fails 4 |
| 49 Confuse, 199 Teeter Dance | `bs1.s:902-917`, `:2566-2618` | Own Tempo and already-confused texts stay; protected, no draw |
| 118/166 Swagger/Flatter | accuracycheck → `PrintMoveMissed` before `attackstring` (`bs1.s:1604-1608`) | PP −1, protected, no roll |
| 205 Tickle | `jumpifstat` gates before accuracycheck (`bs1.s:2644-2651`) | both at −6 keeps "won't go lower" (mutation fails 1) |
| 38 OHKO, 91 Pain Split | `NO_ACC_CALC_CHECK_LOCK_ON` → `JumpIfMoveAffectedByProtect(0)` → `ButItFailed` (`bsc.c:1020-1027`; `bs1.s:761-775`, `:1235-1245`) | protected, not moveFailed |
| 106 Mean Look | `NO_ACC_CALC` → `ButItFailed` (`bs1.s:1440-1453`) | protected, no escape lock (order deviation is equivalent, as the task says) |
| 84 Leech Seed | `setseeded` tests `MOVE_RESULT_NO_EFFECT` before the Grass test (`bsc.c:6436-6447`) | "evaded" even for a Grass target; no roll |
| 107 Nightmare (D5) | no accuracycheck; `SetMoveEffect` has no `MISSED` guard (`bsc.c:2110-2147`, `:2678-2681`) | lands on a sleeping target; fail paths give protected |
| 168 Memento | `jumpifbyte cMISS_TYPE == B_MSG_PROTECTED` → `MementoTargetProtect` (`bs1.s:2199-2201`, `:2234-2244`); `trymemento` cannot fail while protected (`bsc.c:8683-8685`) | `mementoHP`, protected, user faints, no drops, also at −6/−6 |
| 7 Explosion | `setatkhptozero`, then the loop: crit, damage, typecalc, adjust, accuracycheck (`bs1.s:376-417`) | 2 draws, no accuracy draw; "doesn't affect" for a Ghost, else protected; the user faints in both cases (mutation fails 1) |
| 147/126 Earthquake/Magnitude | `HitAllWithUndergroundBonusMissed` runs `typecalc` (`bs1.s:1867-1875`) | Magnitude roll first; Flying gets "doesn't affect", otherwise protected |
| 45 Jump Kick (F2) | `MoveMissedDoDamage` (`bs1.s:852-870`): the crash's typecalc sets `DOESNT_AFFECT`; `bicbyte` clears only `MISSED`; HP update is gated on `!NO_EFFECT` | protected, crash text, 1 draw, 0 HP lost against a Ghost |
| 189 Endeavor | `setdamagetohealthdifference ButItFailed`, then accuracycheck (`bs1.s:2474-2485`) | protected on both HP orders, no draw |
| 92 Snore | awake → `ButItFailed`; asleep → "fast asleep" then accuracycheck (`bs1.s:1253-1268`) | both give protected; no flinch draw |
| 158 Fake Out, 170 Focus Punch | `bs1.s:2044-2059`, `:2255-2261` | Fake Out: protected; Focus Punch already hit: lost focus wins |
| 104 Triple Kick | first in-loop accuracycheck → `TripleKickNoMoreHits` (`bs1.s:1380-1393`) | 0 hits, protected; the trailing draw is omitted under the tracked gap (F5 of the design review) |
| Pass-through | Curse (flags 0), Psych Up (SNATCH), Haze/Hail/Milk Drink (USER) | identical events, draws and state |

**`resultmessage` priority** (`bsc.c:1937`). The miss string prints only when
`MISSED && (!DOESNT_AFFECT_FOE || MISS_TYPE > B_MSG_AVOIDED_ATK)`.
`B_MSG_PROTECTED` is 1 and `B_MSG_AVOIDED_ATK` is 2
(`include/constants/battle_string_ids.h:415-417`). Otherwise the default arm
puts `DOESNT_AFFECT` ahead of `FAILED` (`bsc.c:1973-1976`). So every engine
site that keeps `noEffect` ahead of `protected` is correct. The opposite case
(no typecalc before the accuracycheck) is correct in the engine but untested
(F2).

### 4. Residual ticks

Only `protectBlocks` reads `battler.protected` (grep over `src/` and
`main.lua`). End-of-turn code never reads it, and in source `DoBattlerEndTurnEffects`
does not consult `gProtectStructs[].protected`. Poison, Leech Seed, wrap and
Curse therefore still tick on a protected battler, and the tests confirm it.

### 5. No-regression, lifetimes

**The suite at the base and at this commit.** I ran `bash
scripts/test_all.sh` at `f45aefb` (temporary worktree, since removed) and at
`fbf54f5`. The per-file output is byte-identical except for the added P1
file: 197 files at the base, 198 now, and the P1 test reports 652 passed.

**Behaviour with the flag unset.** I read every branch the commit touches.
Each new branch is gated on `self.protectedMove` or `protectedMiss`, and both
are false when the flag is unset.

**The moved `rampageLocked` capture.** It is equivalent because nothing
writes `rampageTurns` between the new and the old capture sites. The only
writes are at `:1414`, `:1929`, `:3528` and `:4430`.

**Lifetimes.**

- `TurnValuesCleanUp(TRUE)` at the start of `BattleTurnPassed` clears
  `protected` (`bmain.c:2957`, `:3630-3634`). The engine's reset at the start
  of `runTurn` is equivalent, because nothing reads the flag in between.
- `FaintClearSetData` (`bmain.c:2461`, called from `Cmd_tryfaintmon`,
  `bsc.c:2940`) matches the `recordFaint` reset.
- The two mutations that remove these resets fail 1 check each.

`lua5.1 scripts/check_repository.lua` passes.

### 6. Controller text

`sText_PkmnProtectedItself` is `"{B_DEF_NAME_WITH_PREFIX}\nprotected
itself!"` (`msg.c:66`), reached through `gMissStringIds[B_MSG_PROTECTED]`
(`msg.c:897`). The controller adds `name(event.target) .. "\nprotected
itself!"` (`BattleSceneController.lua:307-311`). That uses the same naming
helper as the existing "It doesn't affect" text (`:332`).

Two mutations fail 3 checks each: naming the attacker instead of the target,
and dropping the branch.

## Mutation summary

Each mutation was applied to the working tree from a scratchpad backup and
restored afterwards. The working tree was confirmed identical to the backup
(`cmp`) and `git status` was clean.

| Mutation | `battle_protection_p1_test.lua` |
| --- | --- |
| predicate ignores USER target / ignores flag / tests contact bit 0 | fails 1 / 1 / 164 |
| no `cancelMultiTurnMoves` in the step | fails 3 |
| step before the charge block | fails 18 (suite fails) |
| `rampageLocked` after the cancel | fails 1 (suite fails) |
| protected charge turn 2 spends PP | fails 9 |
| `moveObeyed` after the charge block | fails 3 |
| F1 gate removed / protect before typecalc immunity / protect before Limber | fails 3 / 3 / 4 |
| status final check removed / status `failed()` always moveFailed | fails 12 / 11 |
| Memento branch removed / Memento user survives | fails 2 / 2 |
| Explosion rolls accuracy / protected beats noEffect / user survives | fails 2 / 1 / 1 |
| Jump Kick no crash / takes immunity scan | test errors (crash event missing) / fails 2 |
| Earthquake no typecalc on the protected miss | fails 2 |
| Triple Kick excluded | fails 3 |
| Leech Seed rolls / Nightmare blocked when asleep / Mean Look check removed | fails 6 / 3 / 3 |
| Confuse/Teeter check removed / Swagger rolls | fails 6 / 8 |
| Endeavor / Snore awake / Fake Out give moveFailed | fails 1 / 1 / 1 |
| Tickle gate ignored / Focus Punch: protect before lost focus | fails 1 / 1 |
| `runTurn` reset removed / `recordFaint` reset removed | fails 1 (suite fails) / 1 |
| controller names the attacker / controller branch dropped | fails 3 / 3 |
| **`resolveMove` `protectedMove` reset removed** | **survives (F1; suite passes)** |
| **EffectHit/rampage take typecalc on the protected miss** | **survives (F2; suite passes)** |
| semi-invulnerable test before protect | survives (equivalent, F5) |
