Verdict: **NEEDS_FIX** (runtime behavior matches the source for every path checked; two Medium test-evidence gaps let in-family source behavior regress undetected, plus Low/informational oracle and documentation findings)

# Batch 4 hit effects (fast lane): independent review

- Branch `claude/wizardly-faraday-o45q9z`, head `18e076ee133a715c5bae2ceec4065201f14f2441`, base `origin/main` (merge-base `7d9c007`).
- Task: [P4-FL4-HIT-EFFECTS](../tasks/phase4-batch4-hit-effects.md). Lane: AGENTS.md "Battle-effect fast lane".
- Families: 140 All Stats Up Hit (246 Ancient Power, 318 Silver Wind), 186 Brick Break (280). Ordinary singles only.
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`.
- Reviewer: independent reviewer subagent. It did not construct the change. Nothing was modified, committed or pushed in the checkout; mutations ran on a scratch copy at `/tmp/claude-0/review4/repo` (harness `/tmp/claude-0/review4/mut/run.py`, `run2.py`, probe `probe.lua`).

## Scope

- 8 files, all MAY CHANGE paths or the task file: `src/core/BattleEngine.lua` (+49/-1), `src/core/BattleSceneController.lua` (+2), `tests/battle_engine_test.lua` (+81), `tests/battle_scene_controller_test.lua` (+34), `tests/phase4_batch4_hit_effect_rom_test.lua` (new, 36), `tests/phase4_move_effect_inventory_test.lua` (5/5), `work/reports/phase4-move-effect-inventory.md` (summary, uncovered list, rows 140/186), `work/tasks/phase4-batch4-hit-effects.md` (new).
- No pre-existing test line removed or changed except the two inventory rows and totals.
- No ROM bytes, extracted tables or binaries; fixture holds literals from `battle_moves.h`.
- `git diff --check origin/main...HEAD` clean.

## Source conformance

| Source (c75f352) | Implementation | Result |
| --- | --- | --- |
| `bs1.s:1768-1770` EffectAllStatsUpHit: `setmoveeffect MOVE_EFFECT_ALL_STATS_UP \| AFFECTS_USER`, goto EffectHit (so seteffectwithchance at `bs1.s` EffectHit tail, after resultmessage, before `tryfaintmon BS_TARGET`) | `BattleEngine.lua:1628-1650`, after `applyDamage` and recoil/drain, before `resolveMove` returns to `runTurn`'s faint check | Match |
| `bsc.c:2774-2805` Cmd_seteffectwithchance: not CERTAIN, so `Random() % 100 <= percentChance` is evaluated first, then effect byte, then `!(NO_EFFECT)` | `BattleFormulas.secondaryEffectRoll` (`BattleFormulas.lua:469-471`, `<=`); landed: `:1629`; no-effect roll spent and discarded `:1536-1540` | Match (Serene Grace excluded) |
| `bsc.c:2110-2142` SetMoveEffect: AFFECTS_USER sets `gEffectBattler = gBattlerAttacker`; hp==0 guard is on the effect battler (attacker), Substitute guard skipped for AFFECTS_USER; Safeguard guard only `<= 7` | No defender-hp gate, so a KO still boosts (probe confirms: `useMove damage statChange x5`, foe hp 0) | Match (untested, F3) |
| `bsc.c:2682-2685` ALL_STATS_UP → push, `BattleScript_AllStatsUp` | Inline 5-stat block | Match |
| `bs1.s:3405-3410` gate: ATK/DEF/SPEED/SPATK `< MAX` → go; `SPDEF == MAX` → return; else go. Equivalent to "skip iff all five at +6" | `anyBelow` over all five (`:1633-1636`) | Match (partial gate untested, F2) |
| `bs1.s:3411-3438` per stat ATK, DEF, SPEED, SPATK, SPDEF: `statbuffchange AFFECTS_USER\|ALLOW_PTR` then `printfromtable gStatUpStringIds`, no skip | Order table `:1631`; each stat emits rose or prevented (`:1637-1648`) | Match |
| `bsc.c:6796-6815` ChangeStatBuffs increase: at MAX → `B_MSG_STAT_WONT_INCREASE`, clamp, with ALLOW_PTR sets `MOVE_RESULT_MISSED` and returns WORKED (message printed) | `prevented=true, stages=1` → controller "won't go higher!" (`BattleSceneController.lua:246-248`) | Match (MISSED side effect not modeled, F5) |
| `bm.c:110` `sText_StatsWontIncrease` "{B_ATK_NAME_WITH_PREFIX}'s {B_BUFF1}\nwon't go higher!"; `bm.c:1010-1013` gStatUpStringIds | Controller uses attacker side name | Match |
| `bs1.s:2413-2418` Brick Break: attackcanceler → accuracycheck (miss → PrintMoveMissed) → attackstring → ppreduce → **removelightscreenreflect** → critcalc → damagecalc | Block at `BattleEngine.lua:1477-1484`, after the shared accuracy/PP and miss return, before critcalc `:1490` and `calculateBaseDamage(... self.sideStatus[defenderSide])` `:1498` | Match |
| `bsc.c:9440-9460` Cmd_removelightscreenreflect: opposing side of attacker; if either **timer** nonzero, clear both flags and both timers, animTurn = 1 | Defender side; if either **flag** set, clear both flags and timers, emit `wallShattered` | Match under the flag⇔timer invariant kept by `resolveScreenMove`/`decaySideTimers` (F7) |
| `bs1.s:2423-2429` + `bsc.c:1662-1696` Cmd_attackanimation: wall removed → `bicbyte MISSED\|DOESNT_AFFECT`, animation runs (either mode increments animTurn), animTurn ≥ 2 → `STRINGID_THEWALLSHATTERED` before hit/healthbar; target SELECTED so the `animTargetsHit` early return does not apply | `wallShattered` precedes `critical`/`damage`/`noEffect`, also on an immune target | Match |
| `bsc.c:4346-4437` typecalc2 re-sets DOESNT_AFFECT on immunity; damage is already 0 (`bsc.c:1240-1250` ModulateDmgByType); critmessage gated on NO_EFFECT (`bsc.c:1870-1880`) | Immune target: `useMove, wallShattered, noEffect`, no HP change | Match |
| `pokemon.c:2509-2559, 2648` physical: `attack*power*(2*lvl/5+2)/def/50`, Reflect `/2` only when not crit, min 1, `+2` | Lv20, 40/40, power 75: 15 → +2 = 17; with Reflect 7 → 9. Test asserts 17 | Match (oracle verified) |
| `bm.c:256` "The wall shattered!" | `BattleSceneController.lua:262-263` | Match |
| EffectHit/BrickBreak tail `seteffectwithchance` spends `Random()` even with effect byte 0 (`bs1.s:2441`, `bsc.c:2789`) | Brick Break spends 3 draws, not 4 | Known pre-existing gap (batch 2 follow-up), but asserted as a contract (F1) |
| `bmv.h:3201-3212, 3643-3654, 4137-4148`; `moves.h:250,284,322`; `battle_move_effects.h:144,190`; `pokemon.h:96-114, 238-243` | Fixture `phase4_batch4_hit_effect_rom_test.lua:17-21`: AP {140, 60, ROCK 5, 100, 5, 10, CONTACT\|PROTECT\|MIRROR = 0x13}; Silver Wind {140, 60, BUG 6, 100, 5, 10, PROTECT\|MIRROR\|KINGS_ROCK = 0x32}; Brick Break {186, 75, FIGHTING 1, 100, 15, 0, CONTACT\|PROTECT\|MIRROR\|KINGS_ROCK = 0x33}; target 0, priority 0. `grep` of bmv.h finds exactly 3 members of 140/186 | Match |

## Regression check

- New code is keyed only on `move.effect == 140` (no-effect roll `:1538`, post-damage block `:1628`) and `== 186` (`:1477`). Effect 186 is in none of the earlier early-return tables (multi-hit, fixed, current-HP, Endeavor, Psywave, OHKO), so it reaches the inserted block. No other effect's RNG count or event order can change.
- `supportsMove` unchanged: both families already admitted by `power > 0`.
- `decaySideTimers` (`:1728-1746`) only decrements while the flag is set; after removal both flags are false and timers 0, so no stray `screenExpired`. AI (`AICheckBadMove.lua:334-341`) reads flags only and stays consistent.
- No pre-existing test changed. Main: engine 485, controller 96. Head: 513, 98.

## Assertions and mutations

Count arithmetic: per side 4 Brick Break + 2 ids x 5 All Stats Up = 14; x2 sides = 28; 485 + 28 = 513. Controller 96 + 2 = 98. ROM fixture prints "4 passed" (membership + 3 records).

Inventory: independent recomputation from the test table gives 55 admitted-uncovered positive effects / 102 records, exactly the report's list at `phase4-move-effect-inventory.md:55-56`; classes represented 67/159, candidate 3/3 (1 positive, 2 zero) match the table at `:37-38` and `expectedClasses`. Text "One is a candidate record and 101 need ..." = 102. Consistent.

| Mutation (scratch copy) | Result |
| --- | --- |
| Removal moved after damage | Caught (engine x4) |
| Wrong side (attacker) | Caught (engine x6, controller) |
| Timers not cleared | Caught (engine x2) |
| Only Reflect cleared | Caught |
| No shatter on immune target | Caught (engine x2) |
| No `wallShattered` event | Caught |
| Roll `<` instead of `<=` | Caught (engine x4) |
| Maxed stat silent | Caught (engine x4, controller) |
| All-maxed gate removed (always runs) | Caught (engine x4) |
| No roll on immune | Caught (engine x4) |
| Wrong stat order (SPEED last) | Caught |
| +2 instead of +1 | Caught |
| Raise defender instead of attacker | Caught |
| Controller text changed | Caught (controller) |
| **Gate checks ATK only** | **Survived** (F2) |
| **Gate omits SP.DEF clause (4-stat gate)** | **Survived** (F2) |
| **Skip boost when defender fainted** | **Survived** (F3) |

## Test results

- `env -u POKEPORT_ROM -u POKEPORT_RUNTIME_REPLAY bash scripts/test_all.sh`: PASS, 159 test files (no-ROM).
- `lua5.1 scripts/check_repository.lua`: PASS (285 Lua, 289 Markdown, 963 local targets).
- `tests/battle_engine_test.lua` 513/0; `tests/battle_scene_controller_test.lua` 98/0; `tests/phase4_batch4_hit_effect_rom_test.lua` SKIP (no ROM); `tests/phase4_move_effect_inventory_test.lua` partition PASS, ROM part SKIP.

## Findings

- **F2 Medium: the All Stats Up gate is only asserted at its two extremes.** `tests/battle_engine_test.lua:2185-2191` tests "speed at +6, rest below" and "all five at +6". A gate that checks only ATK, or omits the `SPDEF == MAX` clause the source lock cites (`bs1.s:3410`), passes all 513 tests. A family marked `represented` should pin its gate. Fix: add a case with ATK/DEF/SPEED/SPATK at 12 and SPDEF at 6: expect four `prevented` entries in order, then `spDefense` rising to 7 (current code produces this; verified by probe), and 4 draws.
- **F3 Medium: KO-then-boost is unasserted.** Source applies the boost before `tryfaintmon BS_TARGET`, and SetMoveEffect's hp guard (`bsc.c:2139-2142`) checks the attacker because of AFFECTS_USER. So Ancient Power that KOs still raises all five, and the stat messages come before the faint. The engine does this (probe), but a mutation that skips the boost when `defender.hp == 0` survives. Fix: add an engine test where the defender has 1 HP: expect `useMove, damage, statChange x5`, and through `runTurn`, the faint after the stat changes.
- **F1 Low: the Brick Break RNG oracle and acceptance criterion are not source-derived.** `work/tasks/phase4-batch4-hit-effects.md:53` says "RNG = accuracy, crit, damage only", and `tests/battle_engine_test.lua:2158,2166` assert `draws==3`. Source spends a fourth `Random()` in Brick Break's `seteffectwithchance` (`bs1.s:2441`, `bsc.c:2789`), even with effect byte 0 and on an immune target. This matches the engine's documented plain-hit gap (`phase4-self-drop-tickle-batch.md:74-76`), and fixing it here alone would be wrong, but the lane requires source-derived oracles and the acceptance text states a source-false contract. Fix: reword acceptance 1 to "3 draws, matching the engine's tracked plain-hit seteffectwithchance gap (source spends 4)", and add the same note as a comment beside both asserts so closing the gap updates them on purpose.
- **F4 Low: stale "not ported" text.** `src/core/BattleEngine.lua:423-425` still says Brick Break's screen removal is "Not ported". `src/core/BattleFormulas.lua:115-117` says it is out of scope (that file is outside MAY CHANGE; correct it in a follow-up or add it to MAY CHANGE). Inventory rows 35 and 65 (`phase4-move-effect-inventory.md:140,170`) say "no Brick Break effect". Fix: update the BattleEngine header now and the rows to "Brick Break removal: see 186".
- **F5 Informational: unmodeled MISSED side effect.** With ALLOW_PTR, a maxed stat sets `MOVE_RESULT_MISSED` (`bsc.c:6810-6811`). That flag later suppresses MOVEEND_RAGE (`bsc.c:4091`) and MOVEEND_MIRROR_MOVE recording (`bsc.c:4291`). The engine models neither, so there is no behavior gap today. Record it in row 140's limits so later Rage/Mirror Move/last-landed work does not miss it.
- **F6 Informational: the controller test checks presence only.** `tests/battle_scene_controller_test.lua:472` does not check that "The wall shattered!" comes before the damage/effectiveness text. Engine order is asserted at `battle_engine_test.lua:2156`. Optional: assert the message index precedes the HP or critical text.
- **F7 Informational: flag vs timer condition.** Source keys removal on timers (`bsc.c:9444`) and the engine keys it on flags. These are equivalent while `resolveScreenMove`/`decaySideTimers` keep flag⇔timer>0. A one-line comment at `BattleEngine.lua:1479` would record this.
- **F8 Informational: stale coordination text.** `work/coordination/PROJECT_GOAL.md:94` and `work/coordination/HANDOFF.md:254,268` still say Brick Break drafts stay "outside active dispatch". The 2026-10-13 fast lane supersedes this, but the coordination text is now stale (outside this task's MAY CHANGE; route to the orchestrator).

No defect was found in runtime behavior. F2 and F3 must be fixed before PASS. F1 and F4 are cheap and should go in the same fix.

— independent reviewer subagent; did not construct the change

## Re-check (commit 3eb5051 on top of 18e076e)

Verdict: **PASS**

- I reviewed only the delta `git diff 18e076e 3eb5051 -- src tests work/reports work/tasks`. Runtime code is unchanged. The only edits in `BattleEngine.lua` and `BattleFormulas.lua` are comments. The task file now lists `BattleFormulas.lua` (comment only) under MAY CHANGE. `git diff --check` is clean.
- F2: the new test `all stats up gate checks SP.DEF clause` sets ATK/DEF/SPEED/SP.ATK to +6 and SP.DEF to 0. It expects four prevented entries in source order, then SP.DEF rising to 7, with 4 draws (`bs1.s:3405-3410`). Fixed.
- F3: the new test `all stats up applies on KO before faint` runs through `runTurn`. It expects `turnStart, useMove, damage, statChange x5, faint, battleEnd` and ATK at 7 (`bsc.c:2139-2142`, the HP guard on the attacker under AFFECTS_USER). Fixed.
- F1: the acceptance text (task file, acceptance 1) and the comments next to both `draws==3` asserts now name the tracked gap, where the source spends 4 draws. Fixed.
- F4: `BattleEngine.lua:423-426`, `BattleFormulas.lua:115-117` and inventory rows 35 and 65 updated. Fixed. F5: row 140 now records the MISSED flag limit. F6: the controller test asserts use < wall shattered < foe's action. F7: comment at `BattleEngine.lua:1478-1479`.
- F8: left for the orchestrator. It is outside this task's MAY CHANGE.
- I re-ran the three surviving mutants on a fresh `git archive 3eb5051` copy (`/tmp/claude-0/review4/repo2`). All three are now caught:

  | Mutant | Result |
  | --- | --- |
  | Gate checks ATK only | 517/4 (the SP.DEF clause test fails, x4) |
  | Gate omits the SP.DEF clause | 517/4 (the SP.DEF clause test fails, x4) |
  | Boost skipped on defender KO | 517/4 (the KO test fails, x4) |

- Tests: `test_all.sh` passes (159 files, no ROM). `check_repository.lua` passes (285 Lua, 290 Markdown, 965 targets). Engine 521/0 (513 + 2 checks x 2 ids x 2 sides). Controller 98/0. The ROM fixture and the inventory ROM part skip cleanly.
- Note: the copy committed at `work/reviews/2026-10-13-batch4-hit-effects-review.md` predates this section. Sync it from this file before merge.

— independent reviewer subagent; did not construct the change
