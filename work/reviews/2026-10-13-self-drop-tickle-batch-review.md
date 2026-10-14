Verdict: **PASS** (with findings; two Low in-batch findings to fix in this PR or at merge reconciliation, plus two pre-existing defects that this batch's own source reasoning exposes and that need a follow-up task)

# Self-drop hits and Tickle batch (fast lane): independent review

- Branch `claude/wizardly-faraday-o45q9z`, head `754c5b84181d9e81abbb0088fcae2c33a4df26ca`, base/merge-base `origin/main` `6504d48f18045388f333d4fd4c86ddb30bb53c08`.
- Task: [P4-FL2-SELF-DROP-TICKLE](../tasks/phase4-self-drop-tickle-batch.md). Lane: AGENTS.md "Battle-effect fast lane" (AGENTS.md:84-114).
- Families: 182 Superpower (276), 204 Overheat (315) / Psycho Boost (354), 205 Tickle (321). Ordinary singles only.
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`.
- Reviewer: independent reviewer subagent. It did not construct the change and modified, committed and pushed nothing in the checkout; mutations ran on a scratch copy.

## Scope

- 8 files: the 7 MAY CHANGE paths plus the task file (lane rule 1 allows it).
  `src/core/BattleEngine.lua` (+66/-2), `src/core/BattleSceneController.lua` (+3), `tests/battle_engine_test.lua` (+128),
  `tests/battle_scene_controller_test.lua` (+37), `tests/phase4_move_effect_inventory_test.lua` (7/7),
  `tests/phase4_self_drop_tickle_effect_rom_test.lua` (new, 37), `work/reports/phase4-move-effect-inventory.md` (rows 182/204/205 only),
  `work/tasks/phase4-self-drop-tickle-batch.md` (new).
- No ROM bytes, extracted tables or binaries. The fixture holds source-derived literals from `battle_moves.h`, the same pattern as the accepted dual-stat fixture.
- `git diff --check origin/main...HEAD` is clean.

## Source conformance

| Source (c75f352) | Implementation | Result |
| --- | --- | --- |
| `bs1.s:2383-2385`, `2640-2642`: `setmoveeffect ATK_DEF_DOWN` / `SP_ATK_TWO_DOWN` `\| AFFECTS_USER \| CERTAIN`, then `goto BattleScript_EffectHit` | Ordinary hit pipeline; `SELF_DROP_HIT_MOVES` `BattleEngine.lua:578-581` | Match |
| `bs1.s:239-266` EffectHit: `datahpupdate` → `resultmessage` → `seteffectwithchance` → `tryfaintmon BS_TARGET` | Drop at `:1516-1531`, after `applyDamage` (`:1458`) and after the recoil/drain block. The defender faint is emitted later by `runTurn`. The test at `battle_engine_test.lua:1953-1957` asserts `damage,statChange…,faint` | Match |
| `bsc.c:2783-2788` CERTAIN and not `MOVE_RESULT_NO_EFFECT` → `SetMoveEffect`, **no Random()** | No draw on a landed hit (3 draws total). Tests at `:1925-1931` assert draws==3 plus an RNG sentinel | Match |
| `bsc.c:2789-2791`: on NO_EFFECT the else-if evaluates `Random() % 100` first → one draw, nothing applied | `:1442-1445` adds `SELF_DROP_HIT_MOVES` to the no-effect roll. Test `:1945-1948` asserts draws==4, sentinel, no drop | Match |
| Miss → `BattleScript_PrintMoveMissed`, no seteffectwithchance | Shared miss return `:1180`. Test `:1949-1952` asserts 1 draw, PP spent, no drop | Match |
| `bsc.c:2110-2141` SetMoveEffect: AFFECTS_USER → effect battler = attacker; skipped if that battler has 0 HP. Shield Dust (`<= 9`) and Safeguard (`<= 7`) guards do not apply to these effect bytes. Substitute is bypassed by `affectsUser` | Attacker is always alive at `:1516` (no recoil on 182/204; the recoil faint returns earlier). No ability/Substitute model exists (task exclusion) | Match |
| `bsc.c:2707-2709`, `2765-2767` → `BattleScript_AtkDefDown` / `BattleScript_SAtkDown2` | Table entries ATK -1, DEF -1 / SPATK -2 | Match |
| `bs1.s:3568-3585`: ATK then DEF, each `statbuffchange AFFECTS_USER\|CERTAIN\|ALLOW_PTR`; `jumpifbyte cMULTISTRING_CHOOSER == 2` skips the message | Ordered `ipairs`. A stat at MIN emits nothing (`:1521`). Tests `:1932-1943` | Match |
| `bsc.c:6774-6795` ChangeStatBuffs: `statValue == -2` → "harshly"; MIN → `B_MSG_STAT_WONT_DECREASE`; result clamped at MIN | `math.max(MIN, current + delta)` with event `stages = -2` (harshly text) and `stage` clamped. Test `:1935-1938` (stage 1 → 0, stages -2) | Match |
| `bs1.s:2644-2677` Tickle: `ppreduce` → `jumpifstat ATK > MIN` → anim, else `DEF == MIN` → `CantLowerMultipleStats` → `accuracycheck BattleScript_ButItFailed` → ATK -1, DEF -1, each silently skipped at MIN | Gate `:1125-1130` (both at MIN only, before accuracy, no RNG). PP spent by the shared ppreduce `:1159`; `statsWontFall` `:1227-1230`; loop `:1232-1241` | Match |
| `BattleScript_ButItFailed` `bs1.s:2054-2059` → `resultmessage` with MISSED already set → `gMissStringIds` (`bsc.c:1937-1940`), i.e. "missed", not "But it failed" | Shared `miss` event. Test `:2000-2003` | Match |
| Tickle has no `typecalc` and `Cmd_accuracycheck` (`bsc.c:1003-1095`) does no type check, so a Ghost target is not immune | No typeCalc on the Tickle path. The test defender (type 7) is immune to Normal in the local chart and still drops (`:1966-1990`); mutant M12 is caught | Match |
| `bm.c:309,310,312`: AttackersStatFell / DefendersStatFell "{X}'s {BUFF1}\n{BUFF2}", `sText_StatsWontDecrease2` "{DEF}'s stats won't\ngo any lower!" (DEF name) | `BattleSceneController.lua:262-264` uses the defender side. Controller tests check the ATTACK→DEFENSE order, the both-minimum text and "PLAYER's SP. ATK\nharshly fell!" | Match |
| `bmv.h:3591,4098,4176,4605`; constants `battle_move_effects.h:186,208,209`, `moves.h:280,319,325,358` | Fixture and engine records: see Assertions | Match |
| `CantLowerMultipleStats` `orbyte MOVE_RESULT_FAILED`; a stat already at MIN with ALLOW_PTR sets `MOVE_RESULT_MISSED` (`bsc.c:6817-6818`, since WONT_DECREASE == WONT_INCREASE == 2) | Not represented; nothing in the engine reads it (Mirror Move, Kings Rock, moveend consumers are absent) | Excluded, acceptable |
| Oak first battle: `Cmd_accuracycheck` `bsc.c:1007-1018` skips accuracy for a player power-0 move until flag 2. Flag 2 is set on the first player `STRINGID_DEFENDERSSTATFELL` (`battle_controller_oak_old_man.c:1766-1772`) | The engine's `tutorialAccuracy` (`:1141-1144`) now also bypasses Tickle, but the Tickle path never sets `tutorialPlayerStatDone` and emits no `tutorialTip` | **Mismatch**: Finding 2 (unreachable in retail; the contract excludes it) |

### Other code paths (item 1)

- Multi-hit (`resolveMultiHit`), Explosion (effect 7), the effect-45 crash path (only 26/136 and only on a miss), fixed/current-HP/Endeavor/Psywave/OHKO and the Struggle typecalc skip are keyed on other effect ids or move ids. 182/204 can reach none of them.
- A crit takes the ordinary `critRoll` path, and the drop runs after it unchanged. False Swipe's clamp is keyed on its own effect.
- The new no-effect draw is gated on `SELF_DROP_HIT_MOVES` only. No other move's RNG changes.
- Moves 276/315/354 were already admitted, through the positive-power fallback, as plain hits. Their behavior changes from plain hit to hit + drop. Their landed-hit RNG count is unchanged (3); the immune case gains one draw. Both follow the source.

## Regression check (`resolveMove`)

- `isTickle` and `tickleGateFails` are false for every effect except 205, so `needsAccuracyCheck` is unchanged for all other moves.
- The Tickle branch sits inside `move.power == 0` after Restore HP and Pain Split and before `dualStatUp`. It returns, so the STAT_STAGE path is unaffected.
- `supportsMove` adds a branch only effect 205 reaches. It used to be rejected, and the controller menu gate (`BattleSceneController.lua:355`) now admits it.
  `AICheckBadMove.lua:181,183,590,598` already score these effects and are unchanged.
- The `selfDrop` block runs before the `hitVariant` block, and no effect is in both tables.
- Full no-ROM suite: no other test changed.

## Assertions and mutations

- The oracles are literal stat names, deltas and expected stages from the battle scripts (`battle_engine_test.lua:1887-1894`, `:1927-1929`). They are not read back from `SELF_DROP_HIT_MOVES`. RNG counts are literal (3 / 4 / 1 / 0) and each has an RNG sentinel.
- 50 new engine checks: 3 moves × 2 sides × 6 = 36 for the self-drop moves, and 2 sides × 6 + 2 = 14 for Tickle. 388 + 50 = 438 matches. The controller adds 3 (89 → 92).
- Mutation run on a scratch copy (`/tmp/claude-0/review2/repo`, script `tools/mut.py`). **All 19 mutants were caught**:

| # | Mutant | Caught by |
| --- | --- | --- |
| M1 | no extra draw on an immune hit | 6 engine |
| M2 | drop also applied on an immune hit | 6 engine |
| M3 | Superpower DEF before ATK | 2 engine |
| M4 | no clamp on -2 | 4 engine |
| M5 | stat at -6 still emits an event | 8 engine |
| M6 | Tickle gate does not skip accuracy (gate after accuracycheck) | 2 engine |
| M7 | Tickle DEF before ATK | 2 engine + 1 controller |
| M8 | Tickle gate fails when either stat is at -6 | 2 engine + 1 controller |
| M9 | admission ignores target | 1 engine |
| M10 | no PP spent on gate fail | 2 engine |
| M11 | drop applied to the defender | 18 engine |
| M12 | Tickle applies type immunity | 4 engine |
| M13 | Overheat -1 instead of -2 | 8 engine + 1 controller |
| M14 | landed self-drop spends a roll | 12 engine |
| M15 | Tickle miss still lowers stats | 2 engine |
| M16 | drop moved before damage | 18 engine |
| M17 | admission ignores power | 1 engine |
| M18 | Tickle gate checks ATK only | 2 engine |
| M19 | Tickle -2 | 6 engine |

- ROM fixture vs `bmv.h`. Flags: CONTACT 1, PROTECT 2, MAGIC_COAT 4, MIRROR 16, KINGS_ROCK 32.

| Move | effect | power | type | accuracy | pp | secondaryEffectChance | flags | Result |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Superpower 276 | 182 | 120 | FIGHTING 1 | 100 | 5 | 0 | 1+2+16 = 0x13 | Match |
| Overheat 315 | 204 | 140 | FIRE 10 | 90 | 5 | 100 | 1+2+16+32 = 0x33 | Match |
| Psycho Boost 354 | 204 | 140 | PSYCHIC 14 | 90 | 5 | 100 | 2+16+32 = 0x32 | Match |
| Tickle 321 | 205 | 0 | NORMAL 0 | 100 | 20 | 0 | 2+4+16+32 = 0x36 | Match |

  All four have target 0 and priority 0. The membership scan of 0..353 expects exactly 4 members, which is correct for this pin.
- Inventory arithmetic (`tests/phase4_move_effect_inventory_test.lua:194,216,217,228-236`):
  - Rows: 182 (1 positive) and 204 (2 positive) move C→R with admission already true. 205 (1 zero) moves C→R with admission false→true.
  - represented: 57→60 families, 146→150 moves, positive 107→110, zero 39→40. Correct.
  - candidate: 13→10 families, 16→12 moves, positive 7→4, zero 9→8. Correct.
  - admitted 254→255, rejected 100→99. Correct.
  - admitted_uncovered_positive 108→105 (the 3 positive moves are now covered). Correct.
  - The test recomputes these from the table and passes.

## Test results (local, no ROM)

- `env -u POKEPORT_ROM -u POKEPORT_RUNTIME_REPLAY bash scripts/test_all.sh`: PASS, 157 test files. The new fixture is picked up by the `tests/*_test.lua` glob and skips cleanly.
- `lua5.1 scripts/check_repository.lua`: PASS (283 tracked Lua, 285 tracked Markdown, 946 local targets).
- Individual results:
  - `battle_engine_test` 438/0
  - `battle_scene_controller_test` 92/0
  - `phase4_move_effect_inventory_test` partition PASS (ROM part skipped)
  - `phase4_self_drop_tickle_effect_rom_test` SKIP
- **ROM fixture pending** until the next guarded bridge run.

## Findings

1. **Low (doc consistency, in batch).** `work/reports/phase4-move-effect-inventory.md:55-56` still lists effects 182 and 204 among the "111 admitted, semantically uncovered positive-power records". This PR makes both rows `R` (`:287`, `:309`), so the report now contradicts itself.
   The summary table at `:37-41` was already stale before this PR (50/137, 248/106 against the test's 57/146 before and 60/150 now), and this PR leaves it so.
   Fix: drop 182 and 204 from the `:56` list, change "111"/"61 effects" to the test's current values (105 records; recount the effects) or say the test is authoritative, and update the `:37-41` table to 60/150/110/40, 10/12/4/8, 255/99.
2. **Low (first-battle interplay; contract-excluded, unreachable in retail).** `BattleEngine.lua:1141-1144` makes `tutorialAccuracy` true for a player Tickle in a `firstBattle`, so accuracy is skipped (this matches `bsc.c:1011-1014`).
   The Tickle branch `:1226-1243` never sets `tutorialPlayerStatDone` and never emits `tutorialTip kind="stat"`. In the source, the first player `STRINGID_DEFENDERSSTATFELL` sets FIRST_BATTLE_MSG_FLAG_STAT_CHG and shows Oak's tip (`battle_controller_oak_old_man.c:1766-1772`).
   Probe result: three consecutive firstBattle Tickles all skip accuracy (0 draws), and no tip appears. In the source, the 2nd and later uses would roll accuracy.
   Fix: after the first Tickle `statChange`, mirror `:1285-1289` (`if self.firstBattle and attackerSide == SIDE_PLAYER and not self.tutorialPlayerStatDone then` set the flag and emit the tip), and add a test. Or reject Tickle when `firstBattle` is set.
3. **Medium (pre-existing, outside this batch; exposed by this batch's reasoning).** The recoil family's immune hit draws 3 times in the engine, but the source draws 4.
   `bs1.s:897,2563` set RECOIL_25/33 with `CERTAIN`. On `MOVE_RESULT_NO_EFFECT` the CERTAIN branch at `bsc.c:2783` fails and the else-if at `:2789` evaluates `Random()`, exactly as this PR argues for Superpower.
   The existing test `battle_engine_test.lua:697-698` asserts the opposite (3 draws, "no extra roll"). The engine now holds two contradictory oracles for the same source construct.
   Fix (follow-up task): add `RECOIL_MOVES` to the no-effect roll at `BattleEngine.lua:1442-1445`, and change the test to 4 draws with a sentinel.
4. **High impact, pre-existing, outside this batch (follow-up task).** A plain `EFFECT_HIT` hit consumes 4 Random() in the source but 3 in the engine.
   `BattleScript_EffectHit` (`bs1.s:263`) runs `seteffectwithchance` unconditionally. With MOVE_EFFECT_BYTE 0, the else-if at `bsc.c:2789` still calls `Random()` before testing the effect byte.
   The engine counts acc + crit + damage = 3 (for example `battle_engine_test.lua:264,271,292,303`). The same applies to every Hit-script move that has no extra handling.
   This PR does not cause or change this. It is still the largest RNG-parity gap visible from this review.
   Fix: a separate task to spend the `seteffectwithchance` draw on every landed or immune Hit-script move whose effect byte is not CERTAIN, then update the draw-count oracles.
5. **Info (test strength).** The `-2 clamp` check (`:1938`) does not assert the event kinds or the draw count. The controller test does not cover Superpower's attacker-side "ATTACK fell!" → "DEFENSE fell!" order. Only the player-side Tickle runs against a type-immune defender. All relevant mutants were caught anyway.
6. **Info (cosmetic).** `phase4_self_drop_tickle_effect_rom_test.lua:37` prints a fixed "5 passed", the same as the precedent fixture.

## Result

PASS. Families 182/204/205 may be reconciled as `represented` (ordinary singles), marked "ROM fixture pending". The task's exclusions stay: Mist, Protect, Substitute, abilities (Clear Body/White Smoke/Hyper Cutter/Serene Grace/Shield Dust/Flash Fire), Magic Coat, Kings Rock, move-result flags, doubles and animation.
Fix findings 1-2 in this PR or at merge reconciliation. Open a follow-up task for findings 3-4.

Signed: independent reviewer subagent; did not construct the change.
