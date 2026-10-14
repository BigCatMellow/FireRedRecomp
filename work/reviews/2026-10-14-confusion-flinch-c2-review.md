# Review: Phase 4 confusion and flinch, slice C2 (P4-STATUS2-C2)

- Reviewer: independent code Reviewer (Claude), per `AGENTS.md` rule 6
- Date: 2026-10-14
- Task: [`work/tasks/phase4-confusion-flinch-c2.md`](../tasks/phase4-confusion-flinch-c2.md)
- Commit reviewed: `a774f9c` (`git show a774f9c`)
- Design: [proposal](../reports/phase4-confusion-flinch-design-proposal.md); [design review](2026-10-14-confusion-flinch-design-review.md) (corrections F3, F4, F5, F10 apply to C2); [C1 review](2026-10-14-confusion-flinch-c1-review.md)
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`
- Verdict: **PASS**. There are no Blocker or Medium findings. The implementation matches the pinned source on every point checked. Five Low findings: one test gap shown by a surviving non-equivalent mutant, one pair of vacuous assertions (their mutants are behaviour-equivalent), one undocumented inherited limit (Soundproof), and two documentation nits. None of them blocks merge.

## Scope

The commit changes `src/core/BattleEngine.lua`, `src/core/BattleSceneController.lua`, `tests/battle_confusion_flinch_test.lua`, `tests/battle_scene_controller_test.lua`, `tests/phase4_move_effect_inventory_test.lua`, the new `tests/phase4_confusion_flinch_effect_rom_test.lua`, `work/reports/phase4-move-effect-inventory.md` and the new task file. Every one is inside the task's MAY CHANGE list. `AICheckBadMove.lua`, `main.lua` and the save format are untouched, and no ROM-derived content is committed (the ROM fixture holds only source-record literals and skips without a ROM).

## Commands run (at a774f9c)

| Command | Result |
| --- | --- |
| `lua5.1 tests/battle_confusion_flinch_test.lua` | 72 passed, 0 failed |
| `lua5.1 tests/battle_status_engine_test.lua` | 202 passed, 0 failed |
| `lua5.1 tests/battle_scene_controller_test.lua` | 144 passed, 0 failed |
| `lua5.1 tests/phase4_move_effect_inventory_test.lua` | expected partition checked; SKIP for ROM admission (no `POKEPORT_ROM`) |
| `lua5.1 tests/ai_check_bad_move_test.lua` | 43 passed, 0 failed |
| `lua5.1 tests/phase4_confusion_flinch_effect_rom_test.lua` | SKIP (no ROM): ROM fixture pending |
| `bash scripts/test_all.sh` | PASS: 168 test files (no-ROM mode), rc 0 |
| `lua5.1 scripts/check_repository.lua` | PASS (295 Lua, 315 Markdown, 1035 local targets) |

## Source conformance (verified)

| Item | Source | Implementation | Result |
| --- | --- | --- | --- |
| `Cmd_seteffectwithchance`: `Random() % 100 <= percentChance` is the first `&&` operand, so the roll is drawn on every non-miss hit, including no-effect hits (blocked by `MOVE_RESULT_NO_EFFECT`). A miss jumps away first and draws nothing | `bsc.c:2774-2803` | 31/76/92/146/150 added to the no-effect roll list; effective hits roll after `applyDamage`/drain via `STATUS2_HIT_MOVES` | ✓ (mutant killed) |
| Dynamic Punch (chance 100): the roll is still drawn (`99 <= 100`). `SetMoveEffect(FALSE, CERTAIN)` changes nothing for confusion: the CONFUSION case ignores `certain`, and Shield Dust tests only `!primary`. CERTAIN matters only for an Inner Focus text on flinch, and no flinch record in 31/92/146/150 has chance 100 (all 10/20/30; checked against `battle_moves.h`) | `bsc.c:2132-2134`, `:2405-2439`, `:2795-2799` | Roll drawn, `applySecondaryStatus2` with no `certain` | ✓ (tested: 5 draws) |
| SetMoveEffect guards in order: Shield Dust (`!primary`, byte <= 9; CONFUSION 7, FLINCH 8), Safeguard (unmodeled), `hp == 0`, Substitute (unmodeled) | `bsc.c:2132-2146` | Shield Dust, then `hp <= 0`, both silent, before any turn draw | ✓ (both mutants killed) |
| CONFUSION: Own Tempo or already confused → silent; otherwise `Random() % 4 + 2` after the chance roll, then "became confused!" | `bsc.c:2405-2418`; `bs1.s:3893-3897` | `applyConfusion`: checks first, then `next16() % 4 + 2`, then `confusionApplied` | ✓ (draw-order and `%4+1` mutants killed) |
| FLINCH: Inner Focus → silent unless primary or certain (never in C2, design F10); otherwise set only if `GetBattlerTurnOrderNum(target) > gCurrentTurnActionNumber`; no text | `bsc.c:2419-2439` | Inner Focus silent; `flinchTargetPending` set only for `order[1]` of the two-move loop; never set in the switch/capture/run branches (their foe move is not touched, so the flag stays nil) | ✓ (design F3) |
| A cancelled first mover keeps its turn position; it can apply no secondary anyway. A second mover never flinches | F3 | Flag is per action index, not per "has acted" | ✓ |
| Flinch is cleared after each turn's actions and before the first turn | `battle_main.c:2917`, `:2940` | C1 clears (top of `runTurn` and `resolveEndTurn`) unchanged | ✓ |
| Snore awake (including woken this turn): attackcanceler, attackstring, ppreduce, But it failed. No draw | `bs1.s:1253-1258` | After the cancellers (C1 `wokeUp` path), `useMove`, PP −1, `moveFailed`, no draw | ✓ (both mutants killed) |
| Snore asleep: "fast asleep" after attackcanceler (C1), attackstring, ppreduce, accuracycheck (miss → `MoveMissedPause`, PP spent), then `HitFromCritCalc` with FLINCH. Same text, PP and RNG sequence as the generic hit path | `bs1.s:1259-1268` | C1 `snoreAsleep` → `fastAsleep`; then the generic hit path with the status2 roll | ✓ |
| Confuse (49): attackcanceler, attackstring, ppreduce, Own Tempo text, (Substitute), already confused text, accuracycheck → `ButItFailed` (MISSED wins in `Cmd_resultmessage`, so "attack missed"), (Safeguard), `seteffectprimary`. No RNG before accuracy | `bs1.s:902-922`; `bsc.c:1930-1941` | PP, Own Tempo, already confused, accuracy (`miss`), `applyConfusion` | ✓ (order, accuracy-first and no-PP mutants killed) |
| Teeter Dance (199), singles: the loop skips the attacker and reaches only the foe; the per-target order is the same as Confuse; a miss goes to `TeeterDanceMissed` (`resultmessage`, "attack missed"); `movevaluescleanup` per target has no singles effect | `bs1.s:2566-2618` | Shares the Confuse handler | ✓ |
| Admission: 49/118/166 need power 0 and target `MOVE_TARGET_SELECTED` (0); 199 needs target `MOVE_TARGET_FOES_AND_ALLY` (0x20) | `battle_moves.h` | `supportsMove` | ✓ (mutant killed) |
| Swagger/Flatter: (Substitute → MakeMoveMissed), accuracycheck → `PrintMoveMissed` (attackstring, ppreduce, missed), attackstring, ppreduce, `jumpifconfusedandstatmaxed` (confused AND stage == 12 → But it failed) | `bs1.s:1604-1625`, `:2147-2168`; `bsc.c:8196-8203` | Accuracy draw, PP −1, `miss`; confused-and-maxed → `moveFailed` | ✓ (see Finding 1 for one oracle gap) |
| `statbuffchange STAT_CHANGE_ALLOW_PTR` at +6: `ChangeStatBuffs` sets `B_MSG_STAT_WONT_INCREASE`, ORs `MOVE_RESULT_MISSED`, returns WORKED; the `jumpifbyte` then skips the animation and text. Nothing later in the script prints a result message, and `BattleScript_MoveEffectConfusion` does not test the result flags, so the stat step is silent and confusion is still applied. Below +6 the stage is clamped and the text uses the nominal delta ("sharply rose" for +2) | `bsc.c:6774-6815`, `:6818-6823` | `statChange` only when the stage is below +6, `stages = delta`, clamped stage | ✓ |
| Own Tempo text after the stat step; `seteffectprimary` on an already-confused target is silent (no "already confused") | `bs1.s:1619-1624`; `bsc.c:2405-2409` | Order as source; `applyConfusion` returns silently | ✓ (mutants killed) |
| First-battle tutorial: the Oak controller's stat tip fires only on `STRINGID_DEFENDERSSTATFELL`, so Swagger's and Flatter's rises never set it | `battle_controller_oak_old_man.c:1763-1772` | Swagger/Flatter emit no `tutorialTip` | ✓ (see Finding 5 for the first-battle accuracy skip) |
| Texts: "became\nconfused!" `:116`, "is\nalready confused!" `:117`, "'s OWN TEMPO\nprevents confusion!" `:273`; flinched `:123` (C1) | `src/battle_message.c` | Exact strings and line breaks | ✓ (typo mutants killed) |
| ROM fixture: 24 records (effect, power, type, accuracy, pp, chance, target, flags, priority) and the family-membership count | `src/data/battle_moves.h` | I compared all 24 rows field by field with a parser over `battle_moves.h`/`moves.h`/`battle_effects.h`: every field matches | ✓ (ROM run pending) |
| Inventory: represented 85/203/141/62 → 94/227/159/68 (+9 families, +24 moves: 18 positive, 6 zero); blocked 112/150/74/76 → 103/126/56/70; admitted 277/77 → 283/71 (+6 zero-power admissions); uncovered positive 74 → 56 records, 45 → 40 effects (31, 76, 92, 146, 150 removed) | arithmetic | Test totals and report rows agree | ✓ |
| AI: AI_CBM_Confuse for 49/118/166 (already confused −5 and end; Own Tempo −10); Snore → AI_CBM_DamageDuringSleep (−8 when not asleep); no CBM entry for Teeter Dance (score 0) | `battle_ai_scripts.s:132,158,169,193,390-395,430-432` | `EFFECT_HANDLERS` unchanged; 199 has no handler, so `handler == nil` scores 0. There is no crash path: Teeter Dance is now admitted, so the engine no longer errors on it | ✓ |

## Findings

### 1. Low: the Swagger confused-and-maxed test does not pin "accuracy and PP before the check"

Evidence: mutant M14 moves `jumpifconfusedandstatmaxed` ahead of the accuracy draw and the PP deduction, and it survives. The test "Swagger: confused and ATK +6 -> But it failed" asserts only `moveFailed` and no `statChange`. It checks neither `b.rng.draws == 1` nor `pp == 14`, and no test has a confused, maxed target that the accuracy roll misses. In source (`bs1.s:1606-1609`) that target spends PP, and on a failed accuracy roll it prints "missed", not "But it failed". The implementation is correct.

Fix: add `b.rng.draws == 1 and b.player.moves[1].pp == 9` to that check, and add a case with a confused, maxed target where the accuracy draw misses (95 at 90%), expecting `miss` and no `moveFailed`.

### 2. Low: the second-mover and hoisted-action flinch assertions are vacuous

Evidence: mutants M2 (`flinchTargetPending = true` for both movers) and M3 (flag set before the foe's move after a failed run) both survive. The tests check `b.foe.flinched == false` / `b.player.flinched == false` after `runTurn`, but `resolveEndTurn` has already cleared the flag by then, and no `flinched` event can appear because the target has already acted. Both mutants are behaviour-equivalent at the engine boundary. A flag set on a battler that has already acted is cleared at `HandleEndTurn_ContinueBattle` in source too, so in singles the turn-order rule cannot be observed. The implementation follows F3 exactly.

Fix (optional, pins the implementation): drive one action directly, for example `b.flinchTargetPending = false; b:resolveMove("player", 1, ev)` with Bite and a passing roll, and assert `b.foe.flinched == false` straight away. Do the same for the run branch by inspecting the flag inside the turn, or drop the claim from the test names.

### 3. Low: Soundproof is not listed among C2's limits (Supersonic, Snore)

Evidence: `Cmd_attackcanceler` calls `AbilityBattleEffects(ABILITYEFFECT_MOVES_BLOCK, ...)` right after the cancellers (`bsc.c:836`). Soundproof blocks the sound moves, which include MOVE_SUPERSONIC 48 and MOVE_SNORE 173 (`battle_ai_scripts.s` sound list, mirrored in `AICheckBadMove.lua` `SOUNDPROOF_MOVES`). The engine models Soundproof nowhere. This is an inherited, engine-wide gap: Growl and Sing are already represented without it, and the S3 review records it for Sing. The C2 task's "Known limits" and the inventory rows for 49 and 92 do not mention it, although Soundproof foes such as Voltorb and Mr. Mime are reachable.

Fix: add "Soundproof (Supersonic, Snore; engine-wide gap)" to the task's Known limits and to the 49/92 inventory rows.

### 4. Low: stale comments

Evidence: `resolveStatusCancellers` still says Snore's "awake-failure branch is not modeled yet" (`BattleEngine.lua`, in the CANCELLER_ASLEEP block), but C2 models it. The header capability list (the "Confusion and flinch (status2) cancellers ..." bullet) does not mention the C2 move handlers (`STATUS2_HIT_MOVES`, Confuse/Teeter Dance, Swagger/Flatter, Snore). The new `STATUS_ABILITY_NAMES[20] = "OWN TEMPO"` entry is never read, because the `confusionPrevented` text hardcodes the name.

Fix: update the two comments. Drop the unused table entry or use it in the `confusionPrevented` text.

### 5. Low (informational): the first-battle accuracy skip is not applied in the new handlers

Evidence: `Cmd_accuracycheck` skips the roll for the player's first power-0 move in the first battle (`bsc.c:1007-1016`). The Confuse and Swagger/Flatter handlers call `BattleFormulas.accuracyCheck` directly, not the `tutorialAccuracy` path. This cannot happen today, because the three starters have no move in these families at their first-battle levels. POKEDUDE battles are unmodeled.

Fix: none needed now. Note it if those handlers are ever reused for a first-battle-reachable move.

## Replay and regression note

Before C2, effects 31, 76, 92, 146 and 150 ran as plain hits through the positive-power fallback, with no secondary roll (and Snore hit even while the user was awake). Each landed or no-effect hit with these moves now draws one more `Random()`, and a confusion adds the `% 4` draw. Any seeded battle trace recorded before C2 that contains these moves will diverge after the first such hit. That divergence is the intended correction, closing the tracked plain-hit gap for these families. No committed replay contains these moves: `phase3_complete_runtime_exit_replay_test` has no battle, and the S1-S4 suite (202/0) and the confusion-free draw-count test (6 draws) are unchanged. The ROM fixture result comes from the next guarded bridge run.

## Mutation testing

Each mutant was an exact single-site edit to a saved copy of `BattleEngine.lua`/`BattleSceneController.lua`. Each was run against the confusion/flinch, status engine, scene controller, inventory and AI tests. The originals were restored after every mutant (SHA-1 verified: `0905380…` and `456d361…`).

| # | Mutant | Result | Killed by |
| --- | --- | --- | --- |
| M1 | No-effect roll skipped for status2 families | Killed | Psybeam vs Dark draws |
| M2 | Flinch also from the second mover | **Survived** (equivalent) | (Finding 2) |
| M3 | Flinch after a hoisted (failed run) action | **Survived** (equivalent) | (Finding 2) |
| M4 | Inner Focus ignored | Killed | Inner Focus blocks flinch |
| M5 | Shield Dust ignored (status2) | Killed | Shield Dust blocks secondary confusion |
| M6 | 0-HP guard dropped | Killed | KO hit cannot confuse |
| M7 | Confusion turn draw before the chance roll | Killed | Own Tempo draw count |
| M8 | Turn draw taken even when Own Tempo/already confused | Killed | Own Tempo draw count |
| M9 | Turns `% 4 + 1` | Killed | newly confused foe's count |
| M10 | Confuse: already-confused gate before Own Tempo | Killed | Own Tempo precedes already confused |
| M11 | Confuse: accuracy before the gates | Killed | no draw before the gates |
| M12 | Confuse: no PP spent | Killed | Supersonic PP |
| M13 | Swagger: a miss spends no PP | Killed | Swagger miss PP |
| M14 | Swagger: confused-and-maxed check before accuracy/PP | **Survived** | (Finding 1) |
| M15 | Swagger: confused OR maxed | Killed | confused target below +6 |
| M16 | Swagger: stat text at +6 | Killed | ATK +6 not confused |
| M17 | Swagger: Own Tempo before the stat step | Killed | Own Tempo order |
| M18 | Flatter +2 | Killed | Flatter SP.ATK +1 |
| M19 | Snore awake does not fail | Killed | awake Snore |
| M20 | Snore awake fails without PP | Killed | awake Snore PP |
| M21 | Teeter Dance admission target 0 | Killed | Teeter Dance raises "unsupported" |
| M22 | Snore removed from the status2 table | Killed | sleeping Snore flinch |
| M23 | Text "became confused!" on one line | Killed | controller `:116` |
| M24 | Text "is already\nconfused!" | Killed | controller `:117` |
| M25 | Text "prevented confusion!" | Killed | controller `:273` |

Score: 22 of 25 killed. Two survivors are behaviour-equivalent (M2, M3) and one is an oracle gap in correct code (M14).

## Recommendation

Merge. The inventory may mark 31, 49, 76, 92, 118, 146, 150, 166 and 199 `represented` with "ROM fixture pending". Findings 1-4 are small test and doc follow-ups that can ride along with the next confusion/flinch-adjacent package.

## Worker disposition (2026-10-14)

Findings 1-2 tests added (confused +6 draw/PP and miss case; direct flinch-flag checks); finding 3 Soundproof recorded; finding 4 comments and unused name removed.
