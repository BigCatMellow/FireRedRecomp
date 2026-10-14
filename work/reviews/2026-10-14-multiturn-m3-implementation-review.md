# Review: Phase 4 multi-turn M3 (Rampage), implementation

- Reviewer: independent Reviewer (Claude), per `AGENTS.md` rule 6
- Date: 2026-10-14
- Under review: commit `c9bada7` "Multi-turn M3: Rampage (Thrash, Petal
  Dance, Outrage)" on `claude/wizardly-faraday-o45q9z`
- Design: "Slice M3 addendum" in
  `work/reports/phase4-multiturn-design-proposal.md`; design review
  `work/reviews/2026-10-14-multiturn-m3-design-review.md`; task
  `work/tasks/phase4-multiturn-m3.md`
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`
  (`src/battle_script_commands.c` = bsc.c, `data/battle_scripts_1.s` =
  bs1.s, `src/battle_util.c`, `src/battle_main.c`, `src/battle_message.c`)

## Verdict: **PASS WITH CORRECTIONS**

I found no behaviour defect. Every source fact that the engine relies on
matches the pin. This covers the RNG order and count, PP, the
`ENDTURN_THRASH` tick, the cancel paths, the semi-invulnerable and immune
misses, the M1/M2 lock interplay, the text, the inventory and the ROM fixture.
25 of 29 mutants are killed. Of the four that survive, three are equivalent
(redundant guards). The fourth shows a real test gap: **the position of the
end-of-turn tick relative to status damage is not tested** (F1). That gap and
two smaller untested source cases (F2) are the corrections. Both are
test-only, and no engine change is needed.

## Commands run

- `lua5.1 tests/battle_rampage_test.lua`: 44 passed, 0 failed.
- `lua5.1 tests/battle_multiturn_test.lua`: 83 passed, 0 failed (unchanged).
- `bash scripts/test_all.sh`: PASS, 173 test files (no-ROM mode).
- `lua5.1 scripts/check_repository.lua`: PASS.
- `tests/phase4_rampage_effect_rom_test.lua` and the inventory ROM checks
  skip because no ROM is available here, so the fixture was checked against
  source by hand (see "Inventory and ROM fixture").
- 29 mutants, each restored with `git checkout -- <file>`. The tree is clean
  apart from this file.

## Verified against source

### 1. RNG order and count

| Case | Source | Engine | Result |
| --- | --- | --- | --- |
| Turn 1, hit with effect: accuracy, crit, damage multiplier, seteffect `%100`, `&1` | bs1.s:585-593, 251-270; bsc.c:1093, 2789 (`Random()%100` is the first `&&` operand, CERTAIN not set by `confuseifrepeatingattackends` :6849-6855), :2728 | BattleEngine.lua:2513-2525 (roll then `next16()%2+2`) | OK, 5 draws (test) |
| Locked hit: same minus `&1` (byte 0, roll still drawn) | bsc.c:2789, 6851 | `rampageTurns == 0` guard :2521 | OK, 4 draws |
| No-effect hit, turn 1 or locked: seteffect still drawn, no lock | bsc.c:2789-2791 | whitelist :2374-2378 | OK, 4 draws |
| Miss, turn 1 or locked: accuracy only; semi-invulnerable miss draws nothing | bsc.c:958-1001, 1093-1102 | :1944-1967 | OK |
| KO on turn 1 still locks (`hp==0` guard tests `gEffectBattler` = attacker; byte 53 > Shield Dust/Safeguard limits) | bsc.c:2116-2144 | `attacker.hp > 0` :2521; defender faint handled after `resolveMoveCore` | OK (test "turn-1 KO") |
| End of last turn `%4+2` unless Own Tempo or already confused (no draw) | battle_util.c:953-973; bsc.c:2398-2418 | :2918-2931, `applyConfusion` :1428-1436 | OK |
| Canceller draws on locked turns (freeze `%5`, confusion `&1` + self-hit multiplier, paralysis `%4`) | battle_util.c:1310-1340, 1405-1450 | `resolveStatusCancellers` runs on every turn | OK (tests: paralysis, confusion, self-hit; probe: freeze/thaw) |

### 2. PP

- Turn 1 spends PP, a locked hit skips ppreduce (`jumpifstatus2
  MULTIPLETURNS`, bs1.s:589-590), and a locked miss reaches
  `PrintMoveMissed`'s ppreduce (bs1.s:276-278), which skips at 0 PP
  (bsc.c:1147). Engine :1897-1905. OK.
- The 0-PP bypass under MULTIPLETURNS (bsc.c:838-839): the post-canceller
  check exempts a live rampage (:1606-1611). The pre-canceller defensive
  check is already gated by `not lockedTurn` (:1594). A rampage cancelled
  earlier in the turn gets the normal 0-PP check, as in source. OK.
- Regression check on the split: for every non-rampage move,
  `rampageLocked` is false, so the line is the old `slot.pp = slot.pp - 1`
  with the same guards (`slot`, Endeavor, Magnitude, `noPPDeduct`). A
  battler cannot have `rampageTurns > 0` while using another move, because
  the lock forces `lockedSlot`. No regression. All 173 files pass.

### 3. End-of-turn tick

- Position: source runs per battler in turn order, with THRASH after
  INGRAIN, ABILITIES, ITEMS1, LEECH_SEED, POISON, BAD_POISON, BURN,
  NIGHTMARES, CURSE, WRAP and UPROAR (battle_util.c:721-741). Of those, the
  engine has only poison, toxic and burn, and the tick follows them inside
  the same per-side loop (:2918). The sleep cancel (battle_main.c:2938-2943)
  runs before `BattleTurnPassed`'s effects, in both source and engine
  (:2864-2871). OK. This is only probed, not tested (F1).
- `WasUnableToUseMove` (battle_util.c:216-230) is checked before the natural
  end. Of its represented flags, `targetNotAffected` is the only one that
  reaches the tick. Paralysis (bs1.s:3717), confusion self-hit (bs1.s:3742)
  and flinch (battle_util.c:1366) already cancel inside the turn, so
  `rampageTurns` is 0 and nothing ticks. The engine is equivalent.
- Natural end clears `lockedSlot` (:2925). Own Tempo is silent with no draw,
  and an already confused battler is silent with no draw (tests).
- Protect structs are cleared after the end-of-turn effects
  (`TurnValuesCleanUp(TRUE)` clears only protected/endured,
  battle_main.c:2955-2964). The reset at `runTurn` start (:2958) is
  equivalent: nothing reads the flag in between.
- Probe P2: poison KOs the rampager on its last turn. The engine draws no
  `%4` and prints no fatigue text, because `recordFaint` cleared the state
  first. This matches `FaintClearSetData`'s `status2 = 0`
  (battle_main.c:2441) running inside the poison script's `tryfaintmon`
  before the tracker reaches THRASH.

### 4. Cancel paths, faint, switch-in, continuation

- Sleep applied (bsc.c:2173) and freeze applied (:2269) go through
  `applySecondaryStatus` and `resolvePrimaryStatusMove`, both of which call
  `cancelMultiTurnMoves` (:1325, :1394). Flinch (:1262), paralysis (:1284)
  and the confusion self-hit (:1412) cancel too. `cancelMultiTurnMoves`
  clears `rampageTurns` (:1466). Each path is tested.
- Paralysis applied mid-lock and confusion applied mid-lock do not cancel,
  in source or in the engine.
- A faint clears the state (`recordFaint` :1074). A switch-in builds a fresh
  battler, as do forced replacements. A target KO keeps the lock into the
  replacement (test).
- A thaw on the rampager's own canceller after a freeze this turn: the lock
  is already cleared, `turnLocked` keeps the slot, the 0-PP check applies,
  PP is spent and there is a new `&1` roll (probe P5: 6 draws, PP 19→18,
  new lock). This matches battle_main.c:3989-4020 falling through to
  `chosenMovePositions`. It is not in the test file (F2).

### 5. Misses

- Semi-invulnerable miss: `AccuracyCalcHelper` returns before the roll and
  before `CheckWonderGuardAndLevitate` (bsc.c:958-1001), so there is no
  draw, the text is "missed", PP is spent and the lock is kept. Engine
  `not semiMiss` (:1953). Tested with a Ghost using Dig, and killed by
  mutation.
- Immune miss: `CheckWonderGuardAndLevitate` sets `targetNotAffected`
  (bsc.c:1376-1387) and the text is "It doesn't affect". Engine :1953-1965
  (pure `typeCalc`, no RNG). Cancelled at end of turn. Tested and killed by
  mutation.

### 6. M1/M2 interaction

- `isLocked` (:1478) keeps the M2 recharge term unchanged (design F4).
- Rampage, charge and recharge are mutually exclusive. A locked battler can
  select neither Hyper Beam nor a charge move. Thrash cannot start while
  charging or recharging, because the lock forces the locked slot. So the
  `if not battler.recharging` branch in `cancelMultiTurnMoves` and the
  recharge-lapse `lockedSlot` clear in `runTurn` can never touch a rampage.
- `lockedThisTurn` is computed at `runTurn` start from `isLocked`, which now
  includes the rampage. This is right for the "cancelled before acting"
  path (test: Hypnosis from a faster foe, then fast asleep). The extra
  `rampaging` term in `lockedTurn` (:1529) is redundant with `turnLocked`
  (equivalent mutant, F3).
- The M2 `noPPDeduct` flag is reset at :1612 before every move and is not
  used by the rampage. OK.

### 7. Controller text

`fatigueConfusion` produces `"<name> became\nconfused due to fatigue!"`
(BattleSceneController.lua:430-431), which matches
`sText_PkmnFatigueConfusion` (battle_message.c:177;
`{B_ATK_NAME_WITH_PREFIX}`, where the attacker is the active battler at
end of turn). `BattleScript_ThrashConfuses` (bs1.s:3730-3734) prints only
this string. The menu skip (:120-127) and the foe AI skip (:500-507) already
follow `isLocked`, and both are tested (AI call counts, foe draws).

### 8. Inventory and ROM fixture

- `tests/phase4_rampage_effect_rom_test.lua` values match
  `src/data/battle_moves.h` at the pin. Thrash is {27, 90, Normal 0, 100,
  20, 100}, Petal Dance is {27, 70, Grass 12, 100, 20, 100} and Outrage is
  {27, 90, Dragon 16, 100, 15, 100}. All have target `MOVE_TARGET_RANDOM`
  (0x04), flags CONTACT|PROTECT|MIRROR_MOVE|KINGS_ROCK = 0x33 and priority
  0. `EFFECT_RAMPAGE` has exactly 3 members. The structure matches
  `phase4_multiturn_effect_rom_test.lua`. It was not run, because no ROM is
  available.
- Inventory row 27 is now `represented`. The totals are consistent: 104→105
  families, 243→246 moves, 175→178 positive represented; 93→92, 110→107,
  40→37 blocked; 37 admitted-uncovered positive across 29 effects. The test
  literal (`tests/phase4_move_effect_inventory_test.lua:39, 229-238`), the
  report table and prose (`work/reports/phase4-move-effect-inventory.md:38-62,
  133`) and the task evidence all agree. The no-ROM partition check passes.

## Mutation results

Killed (25): lock length `+3`; no seteffect draw; re-roll on every locked
turn; no `lockedSlot` on lock; locked miss deducts at 0 PP; locked miss
spends no PP; locked hit deducts; 0-PP bypass removed; immune miss ignores
`semiMiss`; immune miss sets no flag; immune-miss branch removed; no-effect
hit sets no flag; `EFFECT_RAMPAGE` dropped from the no-effect whitelist; no
`WasUnableToUseMove` cancel at the tick; no `lockedSlot` clear at the natural
end; plain `confusionApplied` event; no decrement; natural end also taken
after an unable cancel; no per-turn flag reset; `cancelMultiTurnMoves` keeps
the rampage; faint keeps the rampage; `isLocked` without the rampage; the
sleep end-of-turn cancel without the rampage; controller text changed; a
malformed early-tick variant.

Survived (4):

| Mutant | Assessment |
| --- | --- |
| Drop `attacker.hp > 0` in the lock guard (:2521) | Equivalent today: Rampage has no recoil, and every attacker-faint path returns before :2513. The guard is still right to keep (bsc.c:2140). |
| Drop `confusionTurns == 0` at the tick (:2926) | Equivalent: `applyConfusion` repeats the guard (:1430-1431). |
| Drop `rampaging` from `lockedTurn` (:1529) | Equivalent: `turnLocked` already covers it. |
| **Move the tick before status damage**, with the block cut from :2916-2932 and pasted before :2890 | **Not equivalent. See F1.** |

## Findings

### F1 (Minor, test coverage): the tick's position after status damage is untested

The task names the tick position as a review point. The engine puts the tick
after the same side's poison, toxic and burn damage. That is correct
(battle_util.c:721-741, 953-973), and probes confirm it. With the tick moved
before the status damage, all 173 files still pass. Two cases would tell the
positions apart:

- Probe P1: a poisoned rampager's last turn. The engine order is
  `statusDamage, fatigueConfusion`. The mutant reverses it.
- Probe P2: poison KOs the rampager on its last turn, with a replacement
  available. The engine draws 4 times with no fatigue text (source:
  `FaintClearSetData` before THRASH). The mutant draws `%4` and emits
  fatigue confusion before the faint.

Correction: add both cases to `tests/battle_rampage_test.lua`, asserting the
event order and the draw count.

### F2 (Minor, test coverage): two source cases in the addendum have no test

The engine handles both correctly (probes), but no test pins them:

- Freeze then thaw: a rampager frozen this turn (the lock is cancelled when
  freeze is applied) thaws on its own `%5` canceller. It then starts a new
  rampage, with PP spent and a new `&1` roll. Probe P5 gave 6 draws, PP
  19→18 and `rampageTurns` 1 after the tick. The addendum states this
  ("Faint clears status2. A freshly frozen battler that thaws…"), and it is
  the only path through `turnLocked`, the post-canceller 0-PP check and the
  fresh-rampage branch together.
- Snap out on the last locked turn: the confusion canceller reaches 0
  ("snapped out"), the move proceeds, and the end of turn applies fatigue
  confusion, because the battler is no longer confused. Probe P4 gave 5
  draws and `confusionTurns` 4. The existing "already confused" test only
  covers a battler that stays confused.

Correction: add both cases.

### F3 (Info): redundant guards

`rampaging` in `lockedTurn` (:1528-1529) and the `confusionTurns == 0` guard
before `applyConfusion` (:2926) are redundant, which is why they survive
mutation. They are harmless and document intent. No change is required.

### F4 (Info): inherited and unmodeled behaviour, correctly listed as known limits

These are listed in the addendum and the task, and I agree with them:

- The mid-turn faint halt: a rampager that does not act still ticks.
- Wonder Guard: MISSED without `targetNotAffected`, so the rampage continues.
- Pressure, Protect (bsc.c:896-905 cancel), Disable, Taunt, Imprison, Encore,
  Truant, Attract, Yawn, Substitute, King's Rock, Persim and Lum Berries.
- Disobedience: the MULTIPLETURNS bypass at bsc.c:848 is not modeled
  anywhere in the engine.
- Doubles random-target draws (battle_main.c:4093-4111).
- `FaintClearSetData` also clears the fainted battler's `targetNotAffected`
  (battle_main.c:2470). `recordFaint` does not, but the flag is unobservable
  once `rampageTurns` is 0 and is reset at the next `runTurn`.

### F5 (Info): seeded-trace impact

As the design review's F7 says, the three moves gain the seteffect draw on
every landed or no-effect hit, plus `&1` and `%4`. No existing oracle uses
moves 37, 80 or 200. The runtime replay smoke needs a ROM and was not run.

## Required before acceptance

- F1: tests for the tick after status damage (event order, and no `%4` when
  poison KOs the rampager on its last turn).
- F2: tests for the freeze→thaw restart and for snapping out on the last
  locked turn.
