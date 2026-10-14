# Review: status leftovers slice L2 implementation (Rest, Focus Energy)

- Reviewer: independent implementation reviewer (Claude)
- Date: 2026-10-14
- Commit: `c0752ad` on `claude/wizardly-faraday-o45q9z` ("Status leftovers L2: Rest, Focus Energy, Focus Energy crit stage and AI term")
- Design: [proposal](../reports/phase4-status-leftovers-design-proposal.md) (L2 parts), [design review](2026-10-14-status-leftovers-design-review.md), [task](../tasks/phase4-status-leftovers-l2.md)
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`
  - Local copies: `src/battle_script_commands.c` (`bsc.c`), `data/battle_scripts_1.s` (`bs1.s`), `src/battle_util.c`, `src/battle_main.c`, `src/pokemon.c`, `src/battle_message.c` (`bm.c`).
  - Fetched at the pin: `data/battle_ai_scripts.s`, `src/data/battle_moves.h`, `include/constants/battle.h`.
- Verdict: **PASS**. There are no Blocker, High or Medium findings. Behaviour, RNG, PP, gate order, texts, lifecycle, AI and inventory all match source. The findings are Low/Info: two unreachable-path test gaps and some stale comments outside the slice's touch list. None needs a code change before the slice is accepted.

## What was verified (no finding)

### Rest (37)

- **Script shape.** `BattleScript_EffectRest` (`bs1.s:735-747`) is attackcanceler, attackstring, ppreduce, then the gates. There is no accuracycheck and no Random() anywhere in the script, `Cmd_jumpifcantmakeasleep` (`bsc.c:6546-6566`) or `Cmd_trysetrest` (`bsc.c:6480-6502`). The engine spends one PP before any gate (`BattleEngine.lua:1870`) and draws nothing; the tests count draws on every path.
- **Gate order.** Already asleep (`bs1.s:739`, "is already asleep!" `bm.c:86`), then jumpifcantmakeasleep (Uproar, then Insomnia/Vital Spirit on `gBattlerTarget`, which `GetMoveTarget` sets to the user for `MOVE_TARGET_USER`, `battle_util.c:3123`), then trysetrest's full-HP check (`BattleScript_AlreadyAtFullHp`, `bs1.s:2038-2042`). The engine follows this order (`BattleEngine.lua:1872-1890`). An Insomnia user fails with "stayed awake" even at full HP, and a full-HP user keeps its status; both are tested. Uproar is unreachable (no uproar state).
- **Status overwrite and toxic counter.** Source writes `status1 = STATUS1_SLEEP_TURN(3)` (`bsc.c:6497`), which clears every other bit and the counter (bits 8-11). The engine writes `withSleepTurns(0, 3)` = 3 (`:1896`); tested for toxic with counter 5 and 15.
- **Text choice.** `status1 & (u8)~STATUS1_SLEEP` is `& 0xF8`, bits 3-7 (PSN/BRN/FRZ/PAR/TOX), and excludes the counter. The engine ORs the five `StatusConditions` predicates (`:1893-1895`). A counter-only word gives "went to sleep!", as in source (tested). Texts `gRestUsedStringIds` (`bm.c:973-977`) -> `:133` "went\nto sleep!" / `:134` "slept and\nbecame healthy!"; the controller strings match byte for byte.
- **Heal and order.** trysetrest sets `gBattleMoveDamage = -maxHP` (`bsc.c:6484`); after the Rest text, updatestatusicon, then `BattleScript_PresentHealTarget` (`bs1.s:2028-2036`) does datahpupdate (clamped to max) and "regained\nhealth!" (`bm.c:124`). The engine emits `restSlept` then `restoreHP` to max with the same field shape as the existing heal events (`:2192-2195`); the controller orders the texts the same way (tested).
- **Sleep duration.** CANCELLER_ASLEEP (`battle_util.c:1266-1300`) decrements before testing, so sleep 3 gives two fast-asleep turns and the user wakes and acts on the third. Tested through `runTurn` with exact draws and PP (no PP on the asleep turns).
- **Interactions.**
  - Confusion: the confusion canceller runs first; Rest does not touch status2 (tested, `confusionTurns` 3 -> 2).
  - Freeze: a frozen user only reaches Rest after a thaw, which clears the bit, so it prints "went to sleep!"; the bit test itself is checked with the cancellers bypassed.
  - Paralysis: the `% 4` canceller draw precedes Rest (tested).
  - End-of-turn: status1 is now sleep only, so no poison/burn/toxic tick on the Rest turn (tested for poison).
  - Locks: Rest is not a charge or rampage move, and a locked battler never selects it. `resolveEndTurn`'s sleep-cancels-lock step (`:3034-3040`) cannot apply to a Rest user. The Rest branch is after the charge branch, so `noPPDeduct` handling is unaffected.
  - Party: `persistPartyBattler` writes the sleep-3 word (counter masked), matching trysetrest's `EmitSetMonData(REQUEST_STATUS_BATTLE)`.

### Focus Energy (47)

- `BattleScript_EffectFocusEnergy` (`bs1.s:884-894`): ppreduce, `jumpifstatus2 STATUS2_FOCUS_ENERGY -> BattleScript_ButItFailed`, then `Cmd_setfocusenergy` (`bsc.c:7383-7396`), "is getting\npumped!" (`gBattleText_GetPumped`, `bm.c:153`, via `gFocusEnergyUsedStringIds` `:1058-1062`). No RNG. The engine (`:1908-1921`) and controller match; the second use prints "But it failed!" (`bm.c:336`) and still spends PP (tested).
- **Crit arithmetic.** `Cmd_critcalc` (`bsc.c:1184-1194`) is `2 * FE + [43] + [75] + [200] + [209] + items`, clamped to index 4 of `{16, 8, 4, 3, 2}` (`bsc.c:588`). `critStageFor` (`:2976-2979`) returns `2 * FE + CRIT_STAGE_EFFECTS[effect]`, and `critRoll` clamps at 4 (`BattleFormulas.lua:535`). Without items the maximum is 3 (`% 3`). All four critcalc sites call the helper (`BattleEngine.lua:1742` Explosion, `:2409` ordinary hit, `:2863` multi-hit, `:2935` Triple Kick); each site was mutated in turn and each mutation fails the tests. The confusion self-hit has no critcalc in source and none here.
- **Lifecycle.** `FaintClearSetData` zeroes status2 (`battle_main.c:2433-2441`); `recordFaint` clears `focusEnergy` (`:1116`). Switch-ins are fresh `makeBattler` results (`BattlePartyBridge.battlerFromParty`), so both forced and voluntary switch-ins start clear (tested). `persistPartyBattler` writes only HP, PP and status1, so the flag is never persisted.

### AI_CBM_FocusEnergy

- `if_effect EFFECT_FOCUS_ENERGY, AI_CBM_FocusEnergy` (`battle_ai_scripts.s:131`) sits between Mist and Confuse in the dispatch chain, and `AI_CBM_FocusEnergy` (`:386-388`) is `if_status2 AI_USER, STATUS2_FOCUS_ENERGY, Score_Minus10`. The port's dispatch is a table keyed by effect, and every effect occurs once in the chain, so the order cannot change a result; row 47 sits between rows 46 and 49 as in source. Focus Energy has power 0, so the type/absorb gate is skipped as in source, and it is not on the Soundproof list.
- The handler reads `user` (AI_USER), not the target (tested, and a target mutation fails).
- Rest has no CheckBadMove entry in source; row 37 is absent from both `EFFECT_HANDLERS` and `UNPORTED_EFFECTS`, so it scores 0 (tested).
- The commit's diff to `src/core/AICheckBadMove.lua` is the new `focusEnergy` function and row 47 only (9+/1-). The Memento entry (`UNPORTED_EFFECTS[168]`) and the module header are unchanged.

### Admission, inventory and ROM fixture

- `supportsMove` admits effect 37 for move 156 only and effect 47, both requiring power 0 and `MOVE_TARGET_USER` (`:1212-1218`).
- Records at the pin: Focus Energy `battle_moves.h:1511-1522` (47, 0, Normal, 0, 30, 0, USER, SNATCH), Rest `:2031-2042` (37, 0, Psychic = 14, 0, 10, 0, USER, SNATCH). Each effect has exactly one member in `battle_moves.h`. The fixture's tuples, `0x10` and `0x08` are right.
- Inventory: rows 37 and 47 move from `blocked_on_state` (zero-power, rejected) to `represented` (admitted). Totals 285/69, represented 110/251/181/70, blocked 87/102/34/68 are consistent with a two-family, two-move, zero-power transfer; the report table matches the test.

### Regressions

- `lua5.1 tests/battle_status_leftovers_l2_test.lua`: 93 passed, 0 failed.
- `bash scripts/test_all.sh`: PASS, 177 test files (no-ROM mode). L1 (`battle_status_leftovers_test.lua`) passes; its only change is one check label.
- Files touched are inside the task's MAY CHANGE list; `main.lua`, the bridges and the party/Dex code are untouched.

## Mutation testing

Each mutation was applied to the working tree, both test commands were run, and the file was restored with `git checkout -- <file>`. The tree is clean afterwards.

| # | Mutation | L2 test | test_all |
| --- | --- | --- | --- |
| m01 | Rest: full-HP check before Insomnia/Vital Spirit | 2 fail | fail |
| m02 | Rest: Insomnia check before already-asleep | **0 fail** | pass (F1) |
| m03 | Rest: drop Vital Spirit | 3 fail | fail |
| m04 | `statused` without toxic | 2 fail | fail |
| m05 | `statused` without burn | 1 fail | fail |
| m06 | `statused` counts the toxic counter | 1 fail | fail |
| m07 | keep the old status bits under sleep 3 | 8 fail | fail |
| m08 | sleep 2 instead of 3 | 16 fail | fail |
| m09 | Rest spends no PP | 8 fail | fail |
| m10 | Rest heals half | 9 fail | fail |
| m11 | heal event before the Rest text | 4 fail | fail |
| m12 | admit effect 37 for any move id | 1 fail | fail |
| m13 | Focus Energy spends no PP | 2 fail | fail |
| m14 | Focus Energy never fails | 2 fail | fail |
| m15 / m16 | FE term `1 *` / `3 *` | 11 / 10 fail | fail |
| m17 | `recordFaint` keeps `focusEnergy` | 2 fail | fail |
| m18 | `makeBattler` default `nil` instead of `false` | 3 fail | fail |
| m19 / m20 | an extra Random() in Rest / Focus Energy | 16 / 4 fail | fail |
| m21 (x4) | bypass `critStageFor` at each of the four sites | 1-6 fail each | fail (L1 too) |
| m22 / m23 / m24 | AI −8 / reads target / row 47 back to no penalty | 2 / 3 / 2 fail | fail |
| m25 / m26 | Rest statused text / pumped text altered | 1 / 1 fail | fail |
| m27 | remove `critRoll`'s clamp at 4 | **0 fail** | pass (F2) |

## Findings

### F1 — Low: the asleep-before-Insomnia gate order is untested

Source checks `jumpifstatus STATUS1_SLEEP` (`bs1.s:739`) before `jumpifcantmakeasleep` (`:740`), and the engine does the same (`BattleEngine.lua:1872-1884`). Swapping the two gates (m02) passes every test, because the only already-asleep case uses a user with no ability. Both paths are unreachable in the engine (the sleep canceller stops a sleeping user, and an Insomnia/Vital Spirit battler cannot be put to sleep), so this does not affect behaviour.

**Optional correction.** Add one bypassed-canceller case with a sleeping Insomnia user that expects `statusAlready`, not `stayedAwake`.

### F2 — Info: the crit clamp at index 4 is unreachable and untested

`Cmd_critcalc` clamps at `ARRAY_COUNT(sCriticalHitChance) - 1` (`bsc.c:1193-1194`). Without Scope Lens, Lucky Punch or Stick the engine's maximum stage is 3 (Focus Energy + a +1 move), so removing `critRoll`'s clamp (m27, `BattleFormulas.lua:535`) changes nothing any test can see. The clamp is correct. It becomes reachable only with a held-item slice, which should test it then.

### F3 — Low: stale "Focus Energy is out of scope" comments in BattleFormulas.lua

`BattleFormulas.lua:76-79` (header item 5) and `:529-532` (`critRoll` comment) still say the crit-stage sources "(Focus Energy, high-crit moves, Scope Lens/Lucky Punch/Stick) are out of this slice's scope". After L1 and L2, Focus Energy and the high-crit effects are represented through `BattleEngine:critStageFor`; only the held items remain. These comments were not on the F5 touch list of the design review, so this is not a process miss.

**Optional correction.** Reword both to name `critStageFor` as the stage source and keep only the held items as absent.

### F4 — Info: other stale or incomplete comments (already recorded or harmless)

- `AICheckBadMove.lua:83-86` still says status2 is never set "beyond confusion and flinch". The task file records this as a known stale comment because the module header is outside this slice's AI scope. Leave it to the owner of that header.
- The `BattleEngine.lua` header family note on status2 (`:262-265`) names confusion and flinch only. Focus Energy is documented in `makeBattler`, the event list (`:77-79`) and the "not ported" note (`:295-297`), so nothing is misleading; a one-line mention would make the header complete.

### F5 — Info: `supportsMove` restricts Rest to move 156 but not Focus Energy to 116

Effect 37 requires `moveId == MOVE_REST`; effect 47 accepts any id (`BattleEngine.lua:1212-1218`). Both families have exactly one member at the pin, and the ROM fixture asserts that, so this asymmetry has no effect. It is noted only for consistency.

### F6 — Info: presentation detail

Rest's success path has no attackanimation before its text; the animation belongs to `BattleScript_PresentHealTarget` (`bs1.s:2029`). The controller has no animation model, so nothing changes. Also, the already-asleep text uses the `:85` string (B_DEF_NAME) instead of `:86` (B_ATK_NAME); for a self-targeted move both name the user, so the output is identical.

## Recommendation

Accept L2 as implemented. F1 and F3 are optional follow-ups; F2, F4, F5 and F6 need no action. The ROM fixture still needs to run with a verified ROM.
