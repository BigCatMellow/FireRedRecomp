# Review: Phase 4 multi-turn M3 addendum (Rampage), design

- Reviewer: independent Reviewer (Claude), per `AGENTS.md` rule 6
- Date: 2026-10-14
- Under review: the "Slice M3 addendum: Rampage" section of
  `work/reports/phase4-multiturn-design-proposal.md:198-347` and the task
  `work/tasks/phase4-multiturn-m3.md` (commit `2dbb76b`)
- Base engine: `src/core/BattleEngine.lua` at `2dbb76b` (M1 + M2 merged)
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`
- Verdict: **PASS WITH CORRECTIONS**. There are no Blocker or Major findings.
  Every source claim I checked is correct, including the disputed one: a
  missed locked turn does spend PP. The design fits the existing engine. Three
  Minor findings need to go into the spec before implementation: a
  semi-invulnerable exception the no-effect miss path misses, an incomplete
  RNG table, and engine sites that the design implies but does not name. The
  Info items record verified facts and one future-feature note.

## Verified as stated

| Claim | Source | Result |
| --- | --- | --- |
| Move data: Thrash Normal 90, Petal Dance Grass 70, Outrage Dragon 90; acc 100, chance 100, `MOVE_TARGET_RANDOM` | `src/data/battle_moves.h:484-495, 1043-1054, 2603-2614` | OK |
| Script: attackcanceler, accuracycheck → `PrintMoveMissed`, attackstring, `jumpifstatus2 MULTIPLETURNS` over ppreduce, `confuseifrepeatingattackends`, `goto HitFromCritCalc` | `data/battle_scripts_1.s:585-593` | OK |
| `HitFromCritCalc`: critcalc, damagecalc, typecalc, adjustnormaldamage, …, resultmessage, **seteffectwithchance**, tryfaintmon | `:251-270` | OK |
| `PrintMoveMissed`: attackstring, **ppreduce**, resultmessage | `:276-285` | OK |
| `confuseifrepeatingattackends` sets `MOVE_EFFECT_THRASH \| AFFECTS_USER` (not CERTAIN) only when LOCK_CONFUSE is clear | `src/battle_script_commands.c:6849-6855` | OK |
| `seteffectwithchance`: the CERTAIN branch is not taken, so `Random() % 100 <= chance` is evaluated first on every hit, including a no-effect hit and a locked turn with byte 0 | `:2774-2803` (`:2789`) | OK |
| THRASH byte 53 (`include/constants/battle.h:274`); AFFECTS_USER is stripped first (`bsc.c:2116-2121`), so the Shield Dust (`<= 9`) and Safeguard (`<= 7`) guards do not apply, the `hp == 0` guard tests the live attacker, and the Substitute guard is skipped | `bsc.c:2131-2144` | OK. A turn-1 KO sets the lock. |
| `MOVE_EFFECT_THRASH`: MULTIPLETURNS, `gLockedMoves`, `LOCK_CONFUSE_TURN((Random() & 1) + 2)`; bits 10-11, MULTIPLETURNS bit 12 | `bsc.c:2719-2730`; `battle.h:113-115` | OK |
| Locked battler skips selection; `gLockedMoves` is used | `src/battle_main.c:3125-3130, 3989-3992` | OK |
| 0-PP check bypassed under MULTIPLETURNS | `bsc.c:838-839` | OK |
| **A locked-turn miss spends PP.** `PrintMoveMissed` runs ppreduce. `HITMARKER_NO_PPDEDUCT` is set only for Struggle (`battle_main.c:3986`) and Soundproof under MULTIPLETURNS (`battle_util.c:1884-1885`). It is cleared between actions (`battle_main.c:4446-4449, 4456-4459`) and by ppreduce itself (`bsc.c:1166`). At 0 PP the deduction is skipped (`:1147`). | as cited | **Confirmed.** This differs from the two-turn second turn, which sets NO_PPDEDUCT (`data/battle_scripts_1.s:789`). |
| `ENDTURN_THRASH` comes after poison, burn, wrap and uproar, per battler in turn order | `src/battle_util.c:721-741, 744-751` | OK |
| Decrement first; `WasUnableToUseMove` → `CancelMultiTurnMoves`; else at 0 with MULTIPLETURNS: clear it, and if not confused, `SetMoveEffect(TRUE, CONFUSION \| AFFECTS_USER)`; execute `ThrashConfuses` only if confusion was set | `battle_util.c:953-973` | OK. With Own Tempo, `effect++` runs with no script, so nothing prints. |
| `WasUnableToUseMove` includes `targetNotAffected` | `battle_util.c:216-230` | OK |
| Confusion: Own Tempo or already confused → silent, no draw; otherwise `Random() % 4 + 2` | `bsc.c:2398-2418` | OK |
| `BattleScriptExecute` overwrites `gBattlescriptCurrInstr`, so the pushed "became confused!" script never runs | `battle_util.c:2428-2434`; `bs1.s:3730-3734` | OK |
| Text "{ATK} became\nconfused due to fatigue!" | `src/battle_message.c:177, 628` | OK |
| Protect structs are cleared by `TurnValuesCleanUp(FALSE)` only after the end-of-turn effects (`TRUE` clears only protected/endured) | `battle_main.c:2952-2963, 3623-3648` | OK |
| Cancel points: sleep applied `bsc.c:2173`, freeze applied `:2269`, flinch `battle_util.c:1366`, full paralysis `bs1.s:3717`, confusion self-hit `bs1.s:3742`, sleeping battler at end of turn `battle_main.c:2941-2942`, Protect `bsc.c:900` | as cited | OK |
| No-effect hit: typecalc sets `targetNotAffected` | `bsc.c:1340` | OK |
| Missed roll: `CheckWonderGuardAndLevitate` sets `targetNotAffected` (`:1380, 1387`); resultmessage prints "It doesn't affect" when MISSED, DOESNT_AFFECT_FOE and `MISS_TYPE == MISSED` | `bsc.c:1102, 1937` | OK, but see F1 for the semi-invulnerable exception |
| Wonder Guard sets MISSED without DOESNT_AFFECT_FOE for a non-immune type | `bsc.c:1330-1339, 1408-1416` | OK (known limit) |
| Faint clears status2 (`FaintClearSetData`) | `battle_main.c:2433-2441` | OK |
| A thawed battler whose lock was cancelled falls through to `chosenMovePositions` (still the rampage slot from its last selection), so the move starts again with PP and a new roll | `battle_main.c:3980-4020` | OK |
| Random-target draw only in doubles | `battle_main.c:4093-4111` | OK |
| Turn count: roll 2 → 2 attacking turns, roll 3 → 3 | follows from the turn-1 tick | OK |
| AI: effect 27 is in neither the `AI_CheckBadMove` chain nor `sDiscouragedPowerfulMoveEffects`; only the x0 prefix (−10) applies | `data/battle_ai_scripts.s:52-90`; `src/battle_ai_script_commands.c:245-259` | OK |
| RNG draw order: accuracy (`bsc.c:1093`), crit (`:1199`), damage multiplier (`:1581`, also on a no-effect hit), seteffect `% 100` (`:2789`), `& 1` (`:2728`), end of turn `% 4` (`:2413`) | as cited | OK (for the gaps, see F1 and F2) |

### Fit with the engine (`src/core/BattleEngine.lua`)

| Site | Design | Check |
| --- | --- | --- |
| `makeBattler` (`:944-948`) / switch-in | `rampageTurns = 0`, flag false | OK. Every switch-in builds a fresh battler (`BattlePartyBridge.lua:138, 158`). |
| `recordFaint` (`:1063`) | clear | OK |
| `cancelMultiTurnMoves` (`:1451-1455`) | clear | OK. Every modeled cancel point already routes through it: `:1245, 1252, 1274, 1315, 1384, 1402`. |
| `isLocked` (`:1462-1465`) | add `rampageTurns > 0` | OK. The controller's menu skip and foe-AI skip follow it (`BattleSceneController.lua:122-124, 501-502`). See F4. |
| `runTurn` lock override and `lockedThisTurn` (`:2879-2888`) | unchanged | OK. `turnLocked` (`:1513-1520`) already covers a lock cancelled earlier this turn. |
| Post-canceller 0-PP check (`:1590-1594`) | exempt a live rampage | OK |
| Sleep cancel in `resolveEndTurn` (`:2807`) | also `rampageTurns` | OK. Source and engine both run it before the battler end-of-turn effects. |
| `resolveStatusEndTurn` (`:2822-2856`) | tick per side after status damage | OK. See the Info note on position. |
| `applyConfusion` (`:1417-1426`) | reuse, emitting `fatigueConfusion` | OK. It has no Shield Dust gate, which matches primary `SetMoveEffect`. It needs an event-type parameter or a wrapper. |
| `AICheckBadMove.lua` | no change | OK |

## Findings

### F1 (Minor): the no-effect miss must exclude a semi-invulnerable target

The design (proposal `:306-308`) says that on a miss against an immune target
Rampage prints `noEffect` and sets `targetNotAffected`. Source does this only
when the ordinary accuracy roll fails. `AccuracyCalcHelper` returns on an
ON_AIR, UNDERGROUND or UNDERWATER target before the roll and before
`CheckWonderGuardAndLevitate` (`bsc.c:958-1001`, called from `Cmd_accuracycheck` at `:1042-1043` before the roll at `:1093-1102`). That miss
draws **no** accuracy RNG, prints "missed" (DOESNT_AFFECT_FOE is not set) and
leaves `targetNotAffected` clear. **The lock therefore continues and ticks**,
and on the last turn the battler still becomes confused.

As written, a Thrash into a Ghost that is underground (Sableye or Shedinja with
Dig, which a player can own) would print "It doesn't affect" and cancel the
lock at end of turn. That is wrong text and wrong lock state. The engine
already has the right pattern for Jump Kick: `immunity.noEffect and not semiMiss`
(`BattleEngine.lua:1907`, with `semiMiss` at `:1860`).

Fix: gate the Rampage no-effect miss text and flag on `not semiMiss`. Change
the RNG table row "1 or locked, miss | accuracy only" to "accuracy only (no
draw against a semi-invulnerable target)". Add an acceptance case: a locked
Thrash into a Ghost using Dig prints "missed", spends PP and keeps the lock.

### F2 (Minor): the RNG table leaves out the canceller draws on locked turns

The table (proposal `:331-337`) puts `[cancellers]` only on the turn-1 row. A
locked turn runs the same cancellers (`AtkCanceller_UnableToUseMove`). These
include confusion `Random() & 1` (`battle_util.c:1413`) and, on a self-hit, the
`adjustnormaldamage2` multiplier. They also include paralysis `Random() % 4`
(`:1440`). A battler frozen earlier in the same turn draws `Random() % 5` on
its locked action (the `lockedThisTurn` path). The prose covers these, but the
table is the oracle the tests are written from.

Fix: prefix every row with `[cancellers]`, and list which draws that means:
freeze `%5`, confusion `&1` plus the self-hit multiplier, paralysis `%4`.

### F3 (Minor): engine sites the design implies but does not name

The design is implementable, but four existing sites change and the addendum
does not cite them:

1. **ppreduce** (`BattleEngine.lua:1876`). Hit and miss share this step, and it
   does not check for 0 PP. Rampage needs it split: a hit skips the
   decrement when `rampageTurns > 0`, and a miss decrements only when
   `pp > 0`. A locked miss at 0 PP is reachable: turn 1 can spend the last
   PP, and the bypass at `bsc.c:838-839` lets the lock continue. The M2
   `self.noPPDeduct` flag cannot be reused as is, because it suppresses the
   miss deduction too, which is correct for two-turn moves (`bs1.s:789`) but
   wrong here.
2. **The no-effect roll whitelist** (`:2326-2333`). `EFFECT_RAMPAGE` must be
   added, or the no-effect hit loses its seteffect draw.
3. **The generic miss branch** (`:1926`) needs the Rampage `typeCalc` query
   (with the F1 gate) before its plain `miss`.
4. **The natural lock end** in the end-of-turn tick must also set
   `lockedSlot = nil`, as `cancelMultiTurnMoves` does (`:1454`). A stale slot is
   harmless today, because `resolveMoveCore` reads it only while `lockedTurn`
   is set (`:1517-1520`). Clearing it keeps the invariant M1 and M2 rely on.

Fix: list these in the addendum's Design section and in the task's MAY CHANGE
bullets.

### F4 (Info): `isLocked` shorthand

The design writes `isLocked = charging or rampageTurns > 0 or recharge`. The
current recharge term is `recharging and rechargeTimer > 1` (`:1464`), and it
must stay that way. Recharge and rampage cannot both be set: a locked battler
cannot select Hyper Beam, and the recharge canceller clears its own state
(`:1241-1246`).

### F5 (Info): the end-of-turn tick position is correct

In source, `HandleEndTurn_ContinueBattle` clears flinch and cancels a sleeping
battler's lock (`battle_main.c:2938-2943`). `BattleTurnPassed` then runs the
field effects and then each battler's effects in turn order, with THRASH after
that battler's poison, toxic and burn (`battle_util.c:721-741`). The engine
runs flinch clear, sleep cancel, `decaySideTimers`, then `resolveStatusEndTurn`
per side in action order (`BattleEngine.lua:2802-2811`). The tick belongs
inside the per-side loop, after that side's status damage. Gate it on
`rampageTurns > 0`, not on HP: a status-damage faint has already cleared the
state through `recordFaint`. Keep the loop's existing `isOver()` early return.
That matches source, where a battle-ending faint skips the remaining
battlers. Source has no HP test in `ENDTURN_THRASH`, and none is needed.

The design's `runTurn`-start reset of `targetNotAffected` is equivalent to
source's end-of-turn clear. Nothing reads the flag between those two points,
and every switch-in builds a fresh battler. The hoisted switch, capture and run
branches all reach `resolveEndTurn`, so a locked foe that hits a newly
switched-in Ghost cancels correctly.

### F6 (Info): shift-mode switch after a foe faint (not modeled)

`Cmd_jumpifcantswitch` checks only WRAPPED and ESCAPE_PREVENTION
(`bsc.c:4536-4545`). Source therefore lets a rampaging player Pokémon switch out
at the shift-style "Will you change Pokémon?" prompt after the foe faints
(`bs1.s:2843-2852`). The engine does not have that prompt, so this is not
reachable now. If it is added, the switch-in clear already gives source
behaviour.

### F7 (Info): seeded-trace impact

Today the three moves run as plain hits with no seteffect roll (the tracked
plain-hit gap). M3 adds one draw to every landed or no-effect hit, plus `& 1`
on turn 1 and `% 4` at fatigue. That is an intended correction. `grep` finds no
use of moves 37, 80 or 200 in `tests/` or `src/`, so no existing oracle
changes.

## Scope

The task's MAY CHANGE list covers every site above. Leaving `AICheckBadMove.lua`
unchanged is correct. Nothing in the design touches `main.lua`, the save format
or the party bridge, because status2 is never persisted.

## Required before implementation

- F1: the `not semiMiss` gate, the table row and an acceptance case.
- F2: canceller draws in every RNG table row.
- F3: name the four engine sites in the addendum and the task.
