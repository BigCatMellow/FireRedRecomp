# Review: protection slices P4 (Fake Out), P5 (Focus Punch) and the F2 Jump Kick fix

- Reviewed: `8c74736` (P4), `ecb20d3` (P5) and `8019703` (F2 crash fix) on `claude/wizardly-faraday-o45q9z`, read as `git diff 264038d 8019703`. The doc fold `d9e1ec2` was skimmed.
- Specs: `work/reports/phase4-protection-design-proposal.md`, `work/reviews/2026-10-15-protection-design-review.md`, `work/tasks/phase4-protection-p4.md`, `work/tasks/phase4-protection-p5.md`, `work/tasks/phase4-multiturn-m2.md` (F2 follow-up section).
- Date: 2026-10-20
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`.
  - Local copies in `/tmp/claude-0`: `bsc.c`, `bs1.s`, `bmain.c`, `bm.c` (which is battle_message.c), `r3src/battle_util.c`, `src2/*.h`.
  - Fetched at the pin: `data/battle_ai_scripts.s`, `src/battle_ai_script_commands.c`, `src/data/battle_moves.h`.
- Abbreviations: `bsc.c` = `src/battle_script_commands.c`, `bs1.s` = `data/battle_scripts_1.s`, `bmain.c` = `src/battle_main.c`, `msg.c` = `src/battle_message.c`, `bu.c` = `src/battle_util.c`.
- Nothing in the repository was edited except this file. Each mutation was applied, tested and restored from a scratchpad backup, and `git diff` was clean after every one.

## Verdict: **PASS WITH CORRECTIONS**

All three commits behave as the source does at the pin, on every path I traced. I found no behaviour bug. All 195 test files pass in `bash scripts/test_all.sh`, and `lua5.1 scripts/check_repository.lua` passes. Of 49 mutations, 46 are killed by the suite. The 3 survivors (A3, A10, A14) are equivalent mutants (identical observable behaviour; see below).

There are two LOW corrections. Neither changes behaviour, and neither blocks merging:

- F1: a wrong source claim about `FaintClearSetData` in a comment, the P5 task file and a test label.
- F2: a vacuous assertion in the P4 test.

The rest are INFO notes.

## Findings

### F1 (LOW, citation): `FaintClearSetData` does not clear `physicalDmg`/`specialDmg`

`recordFaint` says "...and gProtectStructs (src/battle_main.c:2461; protection slice P5)" and clears `tookMoveDamage`. The `makeBattler` comment, the P5 task file ("`gProtectStructs` is cleared by ... `FaintClearSetData` (`:2461`)") and the P5 test label "recordFaint clears the record (FaintClearSetData)" make the same claim.

At the pin, `FaintClearSetData` (`bmain.c:2455-2481`) zeroes `gDisableStructs`. It then clears only named `gProtectStructs` fields: `protected`, `endured`, `noValidMoves`, `helpingHand`, ... `notFirstStrike` (`:2461-2479`). It never touches `physicalDmg` or `specialDmg`. Only `TurnValuesCleanUp(FALSE)` zeroes the whole struct (`:3637-3639`).

This cannot be observed:

- The fainted battler never acts again.
- Its replacement arrives in `HandleFaintedMonActions`, before the same `BattleTurnPassed`'s `TurnValuesCleanUp(FALSE)` (`:2964-2970`).
- The engine resets the record at every `runTurn` start, before any read.

Keeping the clear is harmless hygiene. **Correction:** reword the `recordFaint` comment, the `makeBattler` comment's "and on faint (FaintClearSetData, :2461)", the task file's damage-record bullet and the test label. They should say that source does not clear the record on faint, and that the engine clears it for hygiene only. Alternatively, drop the clear and the test. Mutation B18 ("recordFaint keeps the record") is killed only by that unit check.

### F2 (LOW, test strength): "moving second: no flinch" asserts a field that is always false by then

`tests/battle_protection_p4_test.lua` ("moving second: the hit lands, no flinch, no text") checks `not e.foe.flinched` after `runTurn`. `resolveEndTurn` clears `flinched` for both battlers first thing, so that part of the check is vacuous.

Mutation A10 survives. A10 makes `applySecondaryStatus2` set the flinch when `certain` regardless of `flinchTargetPending`. That makes it an equivalent mutant end-to-end: the bit is set only after the target has acted, and `resolveEndTurn` clears it before any read. So the "only a target that has not acted" rule is protected only by the pre-existing C2 logic, not by a P4 assertion.

**Correction:** add a direct unit check next to the existing non-certain Inner Focus check:

```lua
engine.flinchTargetPending = false
engine:applySecondaryStatus2("foe", engine.foe, "flinch", out, true)
-- expect: not engine.foe.flinched and #out == 0
```

A scratchpad probe confirms this check kills A10. Also reword the event-level label, or keep its event-sequence check, which is the meaningful part.

### F3 (INFO): the D6 "decrement last" placement cannot be observed yet

Mutation A3 moves the `isFirstTurn` decrement to the start of `resolveEndTurn` and removes the final one. It survives the whole suite.

The placement only matters for a battler that faints during the end-of-turn effects. That battler is then either replaced, and `resolveForcedSwitch` writes 1, or the battle ends.

The implementation matches source (`bmain.c:2950-2970`: end-of-turn effects, then `HandleFaintedMonActions`, then `TurnValuesCleanUp(FALSE)`) and D6. No test can pin the order until something reads `isFirstTurn` after an end-of-turn switch-in. The comment "a battler that fainted here holds 2 from recordFaint" is slightly loose: that battler table is then decremented to 1. It is discarded, so this does not matter.

### F4 (INFO): the multi-hit "last hit" deviation stays unobservable after P3

The P5 task says P3 (Endure) should revisit this. A later hit with `gHpDealt` = 0 on the Focus Punch user needs the user to survive at 1 HP, through Endure or Focus Band. In singles, the Focus Punch user chose Focus Punch that turn, so it cannot have used Endure. Focus Band is not modeled. The follow-up note can name Focus Band instead of P3.

### F5 (INFO): `noValidMoves` is modeled as "every slot at 0 PP" only

`AreAllMovesUnusable` (`bu.c:405-425`) also counts Disable, Torment, Taunt, Imprison, Encore and Choice Band (`CheckMoveLimitations`, `:360-401`). This matches the engine's existing Struggle precondition, which models none of them, so there is nothing to change now.

### F6 (INFO): notes on the F2 crash fix

- The crash's `typecalc` also sets `gProtectStructs[attacker].targetNotAffected` (`bsc.c:1339-1340`). Only the rampage end-of-turn cancel reads it, so a Jump Kick cannot observe it.
- `STATUS2_FORESIGHT` would bypass the Ghost row in that `typecalc` (`bsc.c:1301-1306`). Foresight is not modeled. Record it as a dependency if Foresight/Odor Sleuth arrive.

## Verified as stated

### Fake Out (P4)

**`isFirstTurn` lifecycle**

| Event | Source | Engine |
| --- | --- | --- |
| Battle start | `= 2` (`bmain.c:2228`); the earlier `TurnValuesCleanUp(FALSE)` (`:2217`) precedes it; `TryDoEventsBeforeFirstTurn` decrements to 1 (`:2909`) | leads = 1 in `BattleEngine.new` |
| Voluntary switch-in | `SwitchInClearSetData` sets 2 (`:2396`); the end of that turn gives 1 | explicit 2, then the decrement |
| Faint | `FaintClearSetData` sets 2 (`:2481`) | `recordFaint` = 2 |
| Forced replacement | arrives in `HandleFaintedMonActions` before `TurnValuesCleanUp(FALSE)` (`:2964-2970`), so 2 becomes 1 | `resolveForcedSwitch` = 1 |
| End of turn | decrement if nonzero (`:3640-3641`) | last statement of `resolveEndTurn` |

`resolveEndTurn` runs on every non-ending turn path: the move, switch, capture and failed-run branches, and the forced-switch-pending exits.

**Fail path.** `Cmd_jumpifnotfirstturn` (`bsc.c:6504-6512`) passes iff the value is nonzero. On failure, `BattleScript_ButItFailedAtkStringPpReduce` (`bs1.s:2050-2059`) runs `attackstring`, `ppreduce` and "But it failed!". It comes before `accuracycheck`, so there is no RNG. The engine emits `useMove`, then `moveFailed`, spends PP guarded on `pp > 0`, and draws nothing.

**Certain flinch** (`Cmd_seteffectwithchance`, `bsc.c:2774-2805`):

- CERTAIN without NO_EFFECT draws nothing.
- `SetMoveEffect` checks Shield Dust (byte 8 ≤ 9, `:2132-2134`) and then the 0-HP guard (`:2140-2143`), both silent.
- In the flinch case (`:2419-2439`), Inner Focus with CERTAIN goes to `BattleScript_FlinchPrevention` (`bs1.s:4109-4113`). This test comes before the turn-order test, so the text prints even when Fake Out moves second.
- Text: `msg.c:296` "{B_EFF_NAME_WITH_PREFIX}'s {B_EFF_ABILITY}\nprevents flinching!". The controller renders "FOE's INNER FOCUS\nprevents flinching!".
- On a KO, both the flinch and the Inner Focus text are silent.

**Ghost target.** The `% 100` operand in the else-if arm is evaluated first, so one discarded draw follows the accuracy, crit and random draws. That makes 4 draws, and PP is spent.

**AI row.** The dispatch row is at `ai.s:187`. `AI_CBM_FakeOut` (`ai.s:510-513`) is `is_first_turn_for AI_USER; if_equal 0, Score_Minus10`. `Cmd_is_first_turn_for` (`aisc.c:1778-1790`) returns the raw value. The handler reads `user` (`engine.foe`), which is correct: mutating it to read `target` is killed. The typecalc −10 against a Ghost comes first.

**`AICheckBadMove.lua` diff scope.** It touches exactly four things:

- the Fake Out sentence of the "REAL GAPS" header (the rest of the paragraph, including Memento/Explosion/Roar/Baton Pass/Attract, is unchanged and reads correctly);
- the `fakeOut` handler;
- the `[158]` dispatch row;
- the removal of `UNPORTED_EFFECTS[158]`.

**Record and constants.** The record (`battle_moves.h:3279-3290`) has priority +1 and flags 0x12 (`pokemon.h:239`, `:242`). The constants are correct: Shield Dust 19, Inner Focus 39 and `EFFECT_FAKE_OUT` 158.

### Focus Punch (P5)

**Setup-text hook.** `CheckFocusPunch_ClearVarsBeforeTurnStarts` is at `bmain.c:3669-3702`:

- It is skipped while `HITMARKER_RUN` is set.
- It walks battlers in id order.
- Its conditions are: chosen move `MOVE_FOCUS_PUNCH`, not asleep, no Truant counter, and not `noValidMoves`.

The engine's `resolveFocusPunchSetup` matches. It goes player then foe and checks the move-264 slot, `lockedThisTurn` (a locked or recharging battler skips selection, so its chosen move stays `MOVE_NONE`: `:3125-3130`, `:2993`, `:3288`), sleep, and all-slots-0 PP. Freeze, paralysis and confusion do not suppress the text. A battler that wakes this turn is still asleep at the hook, so it gets no text. The hook comes before every action branch, so the text precedes a switch, a ball or a run. The text is `msg.c:224`.

**Run latch.** `HITMARKER_RUN` is set only at `bmain.c:3327` and `:3341` (Safari) and cleared only by `gHitMarker = 0` (`:2257`); a grep of the pinned battle sources finds no other writer.

- In the engine, the latch is set after the locked-action substitution, because a locked player cannot choose run.
- It is set before the hook, so the run turn itself is silenced.
- It is player-only (review F8).
- The trainer and trapped vetoes return before `runTurn`. The controller handles this through `runDisabledMessage` and `runBlocked` in `BattleSceneController:_runTurn`.
- A successful run ends the battle, so in practice only a failed run leaves the latch visible.

**Damage record.**

- `Cmd_jumpifnodamage` (`bsc.c:8757-8763`) reads `physicalDmg || specialDmg`.
- `Cmd_datahpupdate` (`:1822-1854`) writes `gHpDealt`. It skips `HITMARKER_PASSIVE_DAMAGE` and Pain Split, and a 0-HP hit records 0. `healthbarupdate`/`datahpupdate` are skipped on NO_EFFECT.
- The engine sets `tookMoveDamage` only in `applyDamage` for an opposing-side, nonzero amount.
- I audited every engine HP write. Pain Split, crash, recoil, Curse, Belly Drum, the confusion self-hit, Explosion's self-KO and the end-of-turn damage all bypass `applyDamage`. Every `applyDamage` caller is move damage: single hit, fixed damage, Super Fang, Endeavor, OHKO, multi-hit, Triple Kick and Explosion.
- The record is reset per turn at `runTurn` start, which is equivalent to `TurnValuesCleanUp(FALSE)`.

**Lost focus** (`bs1.s:2255-2261`): `attackcanceler` first (the engine's cancellers and locked-0-PP check come first, which mutation B17 confirms), then `ppreduce` and "lost its\nfocus and couldn't move!" (`msg.c:254`). There is no `attackstring` and no RNG. A protected target would still lose focus first, since attackcanceler's protect arm only sets MISSED and continues.

**Deviation 1** (hook before the speed-tie draw): the hook draws nothing and its events precede every action, so the change cannot be observed.

**Deviation 2** (multi-hit, last hit only): confirmed per F4.

**Record and constants.** The record (`battle_moves.h:3435-3446`) has priority −3 and flags 0x03. The constants are correct: `EFFECT_FOCUS_PUNCH` 170, `MOVE_FOCUS_PUNCH` 264 and `HITMARKER_RUN` `1 << 15`.

### F2 crash fix (`8019703`)

I re-traced `BattleScript_MoveMissedDoDamage` (`bs1.s:852-870`) against an underground Ghost:

1. `AccuracyCalcHelper` sets only MISSED for the semi-invulnerable miss, with no RNG and no `CheckWonderGuardAndLevitate`.
2. `attackstring`, `ppreduce` and `resultmessage` print "missed".
3. The `DOESNT_AFFECT_FOE` test is false, so "kept going and crashed!" prints.
4. `damagecalc` runs.
5. `typecalc` calls `ModulateDmgByType(0)`, which sets `DOESNT_AFFECT_FOE` and makes the damage 0 (`bsc.c:1240-1252`, `:1301-1321`).
6. `adjustnormaldamage` calls `ApplyRandomDmgMultiplier`. Its `Random()` comes before the zero test, so there is one draw (`:1558-1569`).
7. `DMG_RECOIL_FROM_MISS` turns 0 into 1 (`:6465-6470`).
8. `bicbyte` clears only MISSED. `MOVE_RESULT_NO_EFFECT` = `MISSED | DOESNT_AFFECT_FOE | FAILED` (`battle.h:203`).
9. `healthbarupdate` (`:1713`) and `datahpupdate` (`:1758`) are both gated on `!NO_EFFECT`, so both are skipped. 0 HP is lost.

The engine sets `loss = 0` only for `immunity.noEffect`. It keeps the `miss` and `crash` events and the one random draw. Against a non-immune Normal digger, the crash is still the normal 12. Mutations C1-C4 (no zeroing, zeroing always, no draw, no crash event) are all killed by `battle_multiturn_test`. The controller still prints the crash text and an unchanged HP entry.

### Regressions, inventory and fixtures

- **Earlier slices.** No regressions. All of the following pass at `8019703`: `battle_multiturn_test` (multi-turn and rampage), `battle_confusion_flinch_test`, the residual R1-R3 and trapping tests, the weather tests, and every other file in `scripts/test_all.sh` (195 PASS, no-ROM mode). `isFirstTurn`, `tookMoveDamage` and `runAttempted` have no readers outside `BattleEngine.lua` except the AI `fakeOut` handler.
- **Unchanged files.** `main.lua` is unchanged.
- **Moves 252 and 264.** No other test or `scripts/runtime_*.sh` replay uses them; a grep finds only unrelated numbers.
- **Inventory.** Rows 158 and 170 go from `B` to `R`.
  - Represented: 125/273/189/84 becomes 127/275/191/84.
  - Blocked: 72/80/26/54 becomes 70/78/24/54.
  - `admitted_uncovered_positive`: 26 becomes 24, and the effect list drops 158 and 170 (23 effects become 21).
  - Admitted/rejected stays 299/55.
  - The test and `phase4-move-effect-inventory.md` agree.
- **ROM fixtures.** `phase4_protection_p4_effect_rom_test` and `phase4_protection_p5_effect_rom_test` assert the exact 1-member family and the full record. Priority is parsed as `s8`, as in the existing Vital Throw fixture. Both skip cleanly without `POKEPORT_ROM`. Both remain ROM fixture pending, as stated.

## Mutation testing

Each mutation was run through `lua5.1 tests/battle_protection_p4_test.lua`, `lua5.1 tests/battle_protection_p5_test.lua`, `lua5.1 tests/battle_multiturn_test.lua` and `bash scripts/test_all.sh`. Each was restored from a scratchpad backup, and `git diff` was clean after every one.

### Killed: P4 (Fake Out)

| Mutation | Result |
| --- | --- |
| Leads not set to 1 | 8 fails |
| No end-of-turn decrement | 12 fails |
| Switch-in not reset to 2 | 2 fails |
| Forced replacement set to 2 | 2 fails |
| `recordFaint` does not set 2 | 2 fails |
| Fail path spends no PP | 1 fail |
| Fail path draws RNG | 6 fails |
| Fail test uses `<= 1` | 2 fails |
| Flinch tail draws | 10 fails |
| Inner Focus never prints | 1 fail |
| Inner Focus prints for a non-certain flinch | 1 fail |
| Shield Dust ignored for CERTAIN | 2 fails |
| KO guard skipped | 1 fail |
| No discarded Ghost draw | 1 fail |
| `certain` not passed | 1 fail |
| Fail check before `useMove` | 6 fails |
| AI always 0 | 1 fail |
| AI penalises `<= 1` | 1 fail |
| AI reads the target | 1 fail |
| AI row removed | 1 fail |
| Inner Focus text changed | 1 fail |

### Killed: P5 (Focus Punch)

| Mutation | Result |
| --- | --- |
| Latch never set | 3 fails |
| Hook ignores the latch | 3 fails |
| Latch cleared every turn | 2 fails |
| Latch set after the hook | 1 fail |
| Sleep not checked | 2 fails |
| Lock not checked | 1 fail |
| Struggle not checked | 1 fail |
| Foe first | 2 fails |
| Freeze suppresses the text | 1 fail |
| Hook only on move turns | 1 fail |
| Record not reset per turn | 2 fails |
| 0 damage records | 2 fails |
| Record outside the side guard | 1 fail |
| "used" line on lost focus | 7 fails |
| Lost focus spends no PP | 2 fails |
| No lost-focus branch | 11 fails |
| Lost focus before the cancellers | 2 fails |
| `recordFaint` keeps the record | 1 fail |
| Lost focus draws RNG | 2 fails |
| Setup text changed | 2 fails |

### Killed: F2 crash fix

C1-C4 each fail 1 check in `battle_multiturn_test`.

The counts match the spot-checks claimed in both task files where they overlap.

### Survivors (all equivalent)

| Mutation | Why it survives |
| --- | --- |
| A3 (decrement placement) | see F3 |
| A10 (CERTAIN ignores turn order) | see F2; a direct unit check kills it |
| A14 (Shield Dust after the Inner Focus test) | one ability per battler: Shield Dust and Inner Focus cannot coexist. A second variant (A14b, the Shield Dust return moved below the Inner Focus block) passes every P4 check for the same reason; another suite file catches it, so it counts as killed |
