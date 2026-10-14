# Review: multi-hit tail implementation (commit 22e74a0)

- Reviewer: independent implementation reviewer (Claude)
- Date: 2026-10-14
- Commit: `22e74a0` "Multi-hit tail: source order for 29/44, effectiveness text once", on branch `claude/wizardly-faraday-o45q9z`
- Spec: [proposal follow-up](../reports/phase4-status-leftovers-design-proposal.md) ("Follow-up: multi-hit KO tail for 29/44"); [task](../tasks/phase4-multihit-tail.md)
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`. Local copies: `bs1.s` (`data/battle_scripts_1.s`), `bsc.c` (`src/battle_script_commands.c`), `bmv.h` (`src/data/battle_moves.h`).
- Verdict: **PASS WITH CORRECTIONS**. There are no Blocker, High or Medium findings. On every path, the RNG order and draw count, the KO ordering and the effectiveness text match source for 29, 44 and 77. Triple Kick and the other families are unchanged. 13 of 14 mutations were caught. The one survivor guards a real crash path that the tests do not exercise (F1, Low). The other correction is a stale phrase in the inventory (F2, Low). F3 and F4 are informational.

## What was verified (no finding)

### Draw order and count against source

- **Hit count (29).** `Cmd_setmultihitcounter` with arg 0 (`bsc.c:6857-6870`) draws `Random() & 3`, then a second draw only when the first result is > 1. `rollMultiHitCount` is called after the accuracy check and PP, as in `bs1.s:606-610`. 44 and 77 pass a literal 2, so they draw nothing for the count (`:842`, `:1077`).
- **Per hit.** `critcalc` draws first (`bsc.c:1197-1199`). Then `damagecalc` and `typecalc` run with no RNG, then `jumpifmovehadnoeffect` (`bs1.s:624`), then `adjustnormaldamage`, which draws the random roll (`:625`). The engine has the same order (`BattleEngine.lua:2885-2911`): a no-effect hit stops before the random roll.
- **Trailing `% 100`.**
  - In `Cmd_seteffectwithchance` (`bsc.c:2774-2805`), the first branch needs `MOVE_EFFECT_CERTAIN`. 29 and 44 run `setbyte sMULTIHIT_EFFECT, 0` (`bs1.s:612`, `:845`), and `copybyte cEFFECT_CHOOSER` copies that 0 on every hit. So the first branch is false. The `else if` then evaluates `Random() % 100 <= percentChance` as its first `&&` operand (`:2789`), so the draw always happens. The next operand, effect byte != 0 (`:2790`), then short-circuits, so nothing is applied.
  - All 14 effect-29/44 records in `battle_moves.h` have `secondaryEffectChance = 0`. I counted them in the local copy.
  - The landed path reaches the roll at `BattleScript_MultiHitEnd` (`:651-652`). So does the no-effect path: `:624` goes to `MultiHitNoMoreHits`, then `resultmessage`, then `jumpifmovehadnoeffect MultiHitEnd` (`:642-647`).
  - The engine draws the roll on both paths (`:2905`, `:2946-2948`).
- **Miss.** The accuracy check jumps to `BattleScript_PrintMoveMissed` (`bs1.s:276-285`), which has no `seteffectwithchance`. The engine returns from `resolveMove` before it calls `resolveMultiHit`. `tests/battle_engine_test.lua:1069-1075` still asserts exactly 1 draw for a missed Double Slap.
- **Ghost (no effect).** Double Kick draws accuracy, crit and `% 100`: 3 draws. Fury Attack draws accuracy, 1 or 2 count draws, crit and `% 100`: 4 or 5 draws. No damage event and no count are emitted. Both match source.

### KO ordering

- **Source order.** A KO leaves the loop in one of two ways: through `jumpifhasnohp BS_TARGET` (`:615`), or through `decrementmultihit` reaching 0 and then `goto` (`:640-641`). After that, source runs `resultmessage` (`:645`), "Hit N time(s)!" (`:649`, where N comes from `addbyte sMULTIHIT_STRING + 4` per landed hit), `seteffectwithchance` (`:652`) and `tryfaintmon BS_TARGET` (`:653`).
- **Engine order.** The engine emits `multiHit`, then draws the roll, then returns. The faint comes from the caller:
  - `runTurn`'s move loop calls `checkFaint(otherSide)` (`BattleEngine.lua:3351`). That emits `faint` and then either `battleEnd` (outcome `playerWon`/`playerLost`) or `forcedSwitchNeeded`.
  - On a forced switch, `resolveEndTurn` still runs, because `isOver()` is false. On a true battle end it is skipped.
  - That is the same end-of-turn handling the old in-loop `checkFaint` path took (`:3339-3349`).
- **Switch, capture and failed-run turns.** These branches call `checkFaint(SIDE_PLAYER)` after the foe's `resolveMove` (`:3220`, `:3264`, `:3296`). A probe with the foe's Double Kick KOing the switched-in player gives `multiHit, faint, battleEnd` (`playerLost`). With a replacement it gives `multiHit, faint, forcedSwitchNeeded`. See F4.
- **Oak tutorial and first battle.** No multi-hit move is reachable there. The `firstBattle` crit suppression and the damage `tutorialTip` sit in code this commit leaves unchanged (`:2888`, `applyDamage`).

### Effectiveness flags

- `MoveValuesCleanUp` (`bsc.c:3469-3478`) zeroes `gMoveResultFlags` on every hit (`movevaluescleanup`, `bs1.s:619`). So the single `resultmessage` reports the last landed hit's `typecalc` flags. The engine records `lastFlags = flags` per landed hit and puts them on `multiHit`. The matchup cannot change mid-sequence, so the result is identical either way.
- The loop body has `critmessage` (`:633`) but no `resultmessage`, so the per-hit damage events correctly carry `false`/`false`. A crit does not set a result flag, so a crit hit still reports SE or NVE alone.
- **Consumers.** Searching `src/`, `main.lua`, `tools/`, `scripts/` and `mods/`, the only readers of `superEffective` and `notVeryEffective` are the two controller branches (`BattleSceneController.lua:235-236` for `damage`, `:345-346` for `multiHit`). There is no sound, animation, replay, trace or AI consumer. `AICheckBadMove` computes its own effectiveness. No ROM-gated test asserts multi-hit events; the 29/44/77 ROM fixtures check move records only.
- **No double printing.** Triple Kick's `multiHit` carries no flags, and its kicks still carry their own, so nothing prints twice. Controller order is now: the HP entry per hit, the effectiveness line once, "Hit N time(s)!", then "X fainted!" and the forced-switch prompt.

### Intentionally changed assertions (each justified)

- **Draw counts.** Double Kick 5→6, Double Slap 8→9, Fury Attack 13→14 and 7→8, and the type-immune 29 3→4. Each adds exactly the MultiHitEnd `% 100` (`bs1.s:651-652`; `bsc.c:2789`).
- **Mid-sequence KO block** (`battle_engine_test.lua:1007-1041`).
  - `multiHit hits=1` from `resolveMove` follows from `:615` → `:644-649`.
  - There is no in-loop faint, because `tryfaintmon` comes after MultiHitEnd (`:653`).
  - The 5 draws are accuracy, count, crit, random and `% 100`.
  - The faint and `battleEnd` now come from the caller's `checkFaint`.
  - The removed assertion "no trailing multiHit" was asserting the divergence itself.
- **Status-leftovers test** (`battle_status_leftovers_test.lua:485-499`). L1's "older shape" assertion is replaced by the source tail with 4 draws. The new Twineedle-vs-Grass controller check matches `bs1.s:645-649`.

### Regressions

- **Twineedle.** Still 6 draws, with the count before the poison roll. Only the flag placement moved.
- **Triple Kick.** It keeps its own loop (`resolveTripleKick`), which is unchanged: 9 draws, per-kick flags, and on a KO the count comes before the faint.
- **Ordinary hits and the status-hit families.** These never reach `resolveMultiHit`, and `applyDamage` is unchanged.
- **Test runs.** `lua5.1 tests/battle_multihit_tail_test.lua` gives 81/0. `bash scripts/test_all.sh` passes 178 files (no-ROM mode).

### Inventory and docs

- **Inventory rows 29, 44 and 77.** They are accurate (KO tail, `% 100` on landed and no-effect paths, text once) and keep their links and member lists. `phase4_move_effect_inventory_test` passes.
- **Proposal.** The Risks bullet, the follow-up status and the Known limits are consistent with the code.
- **Task file.** Its change, event and test lists match the diff.

### Mutation testing

Each mutation was applied with `sed`, then both `tests/battle_multihit_tail_test.lua` and `scripts/test_all.sh` were run, then the file was restored with `git checkout`. The tree was left clean.

| # | Mutation | New test (fail) | `test_all` |
|---|---|---|---|
| M1 | key the tail on `statusKind` again (`:2870`) | 34 | fail |
| M2 | drop the no-effect `% 100` (`:2905`) | 3 | fail |
| M3 | drop `and entry.statusKind` (`:2948`) | **0** | **pass** (F1) |
| M4 | keep per-hit flags on damage events (`:2922`) | 6 | fail |
| M5 | `multiHit.superEffective` always false (`:2940`) | 5 | fail |
| M6 | `multiHit.notVeryEffective` always false (`:2941`) | 2 | fail |
| M7 | in-loop `checkFaint` for every entry (`:2930`) | 26 | fail |
| M8 | `sourceTail = false` on 29 | 20 | fail |
| M9 | `sourceTail = false` on 44 | 14 | fail |
| M10 | drop `sourceTail` on 77 | 2 | fail |
| M11 | controller: drop the SE line on `multiHit` | 3 | fail |
| M12 | controller: drop the NVE line on `multiHit` | 1 | fail |
| M13 | controller: print the count before SE | 2 | fail |
| M14 | drop the landed-path trailing roll (`:2947`) | 14 | fail |

## Findings

### F1 (Low, test gap): the `entry.statusKind` guard on the trailing roll is load-bearing but untested

`BattleEngine.lua:2946-2948` applies a status only when `secondaryEffectRoll(...)` passes **and** the entry has a `statusKind`. Removing the second condition (M3) passes every test. Here is why:

- With chance 0, the roll passes on `next16() % 100 == 0`, so 1% of the time in real play.
- `applySecondaryStatus(defenderSide, nil, ...)` then reaches `STATUS_BLOCKING_ABILITY[nil]` (`:1366`).
- Every test battler has `ability == nil` (`makeBattler` does not set one), so `target.ability == blocking` is `nil == nil` and the function returns early, silently.
- Real battlers built by `BattlePartyBridge` always have a numeric ability (`BattlePartyBridge.lua:149`, `... or 0`). For them, the mutant reaches `StatusConditions.canApply`, whose `assert(StatusConditions.KINDS[kind])` (`StatusConditions.lua:97`) raises "unknown status kind nil".
- I reproduced this. With the foe given `ability = 66` and the 6th draw 0, Double Kick runs cleanly at HEAD and raises under M3.

The shipped code is correct. Correction: add a 29 or 44 case whose foe has a numeric ability (for example `engine.foe.ability = 0`), with `PASSING_ROLL` as the trailing draw, and assert no error and no status event.

### F2 (Low, doc): inventory row 104 calls per-kick effectiveness text the "multi-hit convention"

`work/reports/phase4-move-effect-inventory.md:210` (Triple Kick) still says "effectiveness text per kick (multi-hit convention; source prints once at end)". After this commit, the multi-hit convention is to print once. Triple Kick is now the only family that prints per hit. Correction: change it to something like "effectiveness text per kick (its own loop; 29/44/77 now print once; source prints once at end)".

### F3 (Info, citations): label lines cited as command lines

Several new comments and the task file cite `bs1.s:651` for `seteffectwithchance` and `:644` for `resultmessage`. Those are the label lines (`BattleScript_MultiHitEnd::`, `BattleScript_MultiHitPrintStrings::`). The commands are at `:652` and `:645`. Examples: `BattleEngine.lua` comments, `battle_engine_test.lua:937`, and the task's "Source behaviour verified". The meaning is unambiguous. Fix this only if you are touching the lines anyway.

### F4 (Info, unlisted behaviour change, positive): duplicate faint on hoisted-action turns removed

With the old shape, a foe multi-hit KO on a switch, capture or failed-run turn emitted the faint inside the loop. The branch's own `checkFaint(SIDE_PLAYER)` (`:3220`, `:3264`, `:3296`) then ran again. Those branches guard only `isOver()`, not `awaitingForcedSwitch`. With a replacement available, the parent commit emitted `faint, forcedSwitchNeeded, faint`; I ran the same probe on `22e74a0~1`. HEAD emits a single `faint, forcedSwitchNeeded`, which matches source.

This is a strict improvement, but the task's "Event changes" section does not mention it. Consider recording it, and adding a regression assertion: foe Double Kick KOs the switched-in player, `hasReplacement` is true, and exactly one `faint` is emitted. The underlying branch guard is still weaker than the move loop's. Any other path that faints the defender inside `resolveMove` would still produce the duplicate. That is outside this commit's scope.

## Not findings (checked)

- The non-source branch in `resolveMultiHit` is retained, and no entry uses it. The task documents this. It is harmless.
- These pre-existing gaps are unchanged and already documented: the attacker-faint check `jumpifhasnohp BS_ATTACKER` (dead code because Rough Skin is not represented); Endure and Focus Band (`:639`); per-hit MOVEEND reactions (Static and the other contact abilities draw `Random()` in source); Serene Grace; Synchronize.
- Header comment line `BattleEngine.lua:384` is longer than the rest of its block. This is cosmetic only.
