# Review: weather slice W0 implementation (`bcc3db7`)

- Commit: `bcc3db7` "Weather W0: recompute end-of-turn order at ENDTURN_ORDER"
  on `claude/wizardly-faraday-o45q9z` (base `43d2d52`)
- Task: `work/tasks/phase4-weather-w0.md`
- Spec: `work/reports/phase4-weather-design-proposal.md` ("End-of-turn order
  (W0, implemented)"), `work/reviews/2026-10-14-weather-design-review.md`
  (F1, F3, F8, D1)
- Source: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`
  (`src/battle_util.c`, `src/battle_main.c`, `src/battle_script_commands.c`)
- Date: 2026-10-15

## Verdict: PASS WITH CORRECTIONS

The engine change is correct against source. I found no behavioural defect.
The order is recomputed once, in the right place, from the right inputs, and
it drives every per-battler phase. Both changed assertions are real source
ties. The corrections are two Minor items: two tests still call
`resolveEndTurn` with the old signature, and two documents still state the
superseded ruling without a note. The rest are Info.

`bash scripts/test_all.sh` (179 files) and `lua5.1 scripts/check_repository.lua`
pass at `bcc3db7`. `tests/battle_end_turn_order_test.lua` has 42 passed, 0 failed.

## Source verification

1. **What is sorted.** `ENDTURN_ORDER` (`battle_util.c:484-501`) resets
   `gBattlerByTurnOrder[i] = i` and calls `GetWhoStrikesFirst(order[i],
   order[j], FALSE)` for each pair, swapping on any nonzero result. In singles
   this is one call with (0 = player, 1 = foe). `endTurnOrder` makes one
   `getWhoStrikesFirst(self.player, self.foe, ...)` call and puts the foe
   first on `~= 0` (`BattleEngine.lua:3078-3088`). Correct.
2. **Chosen-move priority.** `battle_main.c:3478-3503`: a battler with
   `B_ACTION_USE_MOVE` contributes `moves[chosenMovePositions]` (or
   `MOVE_STRUGGLE` when `noValidMoves`). Any other action contributes
   `MOVE_NONE`. `gChosenActionByBattler` is reset only after the end of turn
   (`:2990-2994`). A locked or recharging battler is forced to
   `B_ACTION_USE_MOVE` with its stale slot (`:3125-3130`).
   - In the engine, switch, capture and run pass `nil` for the player. `nil`
     reads as priority 0 in `BattleFormulas.getWhoStrikesFirst`
     (`BattleFormulas.lua:604-605`).
   - The foe passes `chosenMoveRecord(FOE, foeAction)`. `foeAction` has
     already been replaced with `lockedSlot` when the foe is locked
     (`BattleEngine.lua:3222-3227`), so Thrash, a charging move or a
     recharge slot contributes its own record. That matches the stale slot.
   - A locked player cannot reach a hoisted site, because `runTurn` turns its
     action into a move first.
   - Struggle uses the chosen slot's record, not priority 0. This is
     documented as a Known limit shared with turn start, and it is accurate.
   - Records captured at turn start equal source's end-of-turn reads, because
     no supported effect rewrites a move slot mid-turn (no Mimic, Transform
     or Sketch).
3. **Speed at that moment.** `effectiveSpeed` applies the current stage, then
   paralysis `/4` (`BattleFormulas.lua:584-590`). Source applies stage, then
   badge and Macho Brace, then paralysis, then Quick Claw
   (`battle_main.c:3428-3476`). Badge, Macho Brace and Quick Claw are not
   modeled; this is documented. The value is read inside `resolveEndTurn`,
   so a mid-turn String Shot or Thunder Wave counts. Tests cover both.
4. **The tie draw.** Source draws `speed1 == speed2 && Random() & 1` only
   on an exact speed tie at equal priority, in both the nonzero-priority
   branch (`:3510`) and the zero-priority branch (`:3523`). The `&&`
   short-circuits, so a non-tie draws nothing. The engine matches this, and
   the equal-Quick-Attack test covers the nonzero branch.
5. **Other draws in GetWhoStrikesFirst.** There are none. Quick Claw compares
   `gRandomTurnNumber` (`:3451`, `:3476`) and draws nothing.
6. **The 0-HP claim.** The commit says source has already sent in the
   replacement by `ENDTURN_ORDER`. Verified: `Cmd_end`/`Cmd_end2` set
   `B_ACTION_TRY_FINISH` (`battle_script_commands.c:3798-3809`), and
   `HandleAction_TryFinish` runs `HandleFaintedMonActions`
   (`battle_main.c:4433-4439`, `battle_util.c:1144-1222`), which runs
   `BattleScript_HandleFaintedMon` (`openpartyscreen`/switch-in,
   `battle_scripts_1.s:2824-2849`) after each action. The Known limit, filed
   under R2, is stated correctly.

## Placement

`resolveEndTurn` (`BattleEngine.lua:3108-3122`) runs in this order:
1. flinch clear;
2. sleeping multi-turn cancel (`HandleEndTurn_ContinueBattle`,
   `battle_main.c:2930-2950`);
3. `endTurnOrder`;
4. `decaySideTimers`;
5. `resolveStatusEndTurn(events, sides)`.

This matches source. `ENDTURN_ORDER` is the first field case, and every
field case runs before any battler case (`battle_main.c:2958-2964`). Every
per-battler phase iterates `sides`: status damage, toxic counter, the
ENDTURN_THRASH tick and the fatigue confusion with its draw
(`:3136-3184`). No other end-of-turn phase exists yet: no Leech Seed,
Leftovers end-of-turn heal, Ingrain or Wish.

## Call sites

All six production sites pass the specified records
(`BattleEngine.lua:3275`, `:3321`, `:3352`, `:3399`, `:3405`, `:3415`). This
matches the task table. No other production caller exists. `HOISTED_ORDER`
and `sidesOf` are gone (grep of `src/`, `main.lua` and `tests/`). The 0-HP
skip is correct. Both early-exit sites are reached only with a 0-HP battler
(`awaitingForcedSwitch`, or `checkFaint` returning true, which requires
`hp == 0`, `:3030-3036`), so they never draw (see F4).

## Changed assertions

I instrumented `endTurnOrder` and `getWhoStrikesFirst` and ran every
`tests/*_test.lua`. Ties at `ENDTURN_ORDER` occur only in
`battle_end_turn_order_test.lua` (8), `battle_engine_test.lua` (1) and
`battle_status_engine_test.lua` (1). The task's claim of "exactly two"
end-of-turn tie draws in the existing suite is confirmed.

- `battle_status_engine_test.lua:193-205`: the paralyzed player (40/4 = 10)
  ties the foe (10) at both points. The 4th draw is justified.
- `battle_engine_test.lua:1083-1102`: the switched-in Charmander-stat
  battler ties the foe, and `MOVE_NONE` against Tackle is priority 0 on both
  sides. The 4th draw is justified.
- `battle_status_engine_test.lua:551-555` changes only a comment. The
  assertion still holds because the incoming battler (20) is faster than
  the foe (10).

Other seeded traces:
- `work/local-runner/probes/*` record no draw counts.
- The ROM tests could not run (no ROM in the container). I read their
  assertions:
  - `phase3_exit_path_rom_test.lua:130,165`: a successful capture, and a
    1-HP KO that ends the battle. Neither reaches the end of turn.
  - The effect ROM tests assert one-move draw counts.
  - `phase4_player_voluntary_switch_rom_test.lua` asserts HP persistence,
    not draws.
- The LÖVE runtime replays (`main.lua:3593-4182`, seed 0) assert outcomes
  only. The rival leg loses by Growl every turn. `route1_wild_win` and
  `natural_capture` could shift their RNG stream after a tied end of turn.
  This is the intended source behaviour, but it is unverified here (F5).

## Regressions

All of these suites pass, including the existing lock, Thrash end-of-turn,
sleep-cancel and fatigue-confusion checks:
- `battle_multiturn_test` (M1/M2/M3 charge, recharge and semi-invulnerable
  locks)
- `battle_rampage_test`
- `battle_confusion_flinch_test`
- `battle_status_engine_test`
- `battle_status_leftovers*_test`
- `early_rival_battle_test` (the first battle)
- `oak_speech_*` and `phase3_title_oak_entry_test` (the Oak tutorial)

There are no Leech-like residuals to regress.

## Mutation testing

Each mutant was applied to `src/core/BattleEngine.lua`, then
`lua5.1 tests/battle_end_turn_order_test.lua` and
`bash scripts/test_all.sh` were run, then the file was restored with
`git checkout -- src/core/BattleEngine.lua`. The working tree is clean apart
from this file.

| # | Mutant | New test | Suite | Result |
| --- | --- | --- | --- | --- |
| M1 | `endTurnOrder` always player first (old hoisted behaviour) | 20 fail | fail | killed |
| M2 | 0-HP guard removed | 2 fail | fail | killed |
| M3 | guard tests only `player.hp` | 1 fail | fail | killed |
| M4 | swap only on result 1 (tie never swaps) | 4 fail | fail | killed |
| M5 | priority ignored (`nil, nil` into GetWhoStrikesFirst) | 6 fail | fail | killed |
| M6 | switch site passes `nil` for foe | 2 fail | fail | killed |
| M7 | capture site passes `nil` for foe | 2 fail | fail | killed |
| M8 | run site passes `nil` for foe | 1 fail | fail | killed |
| M9 | normal exit passes moves swapped | 1 fail | fail | killed |
| M10 | normal exit passes `nil, nil` | 1 fail | fail | killed |
| M11 | both early exits pass `nil, nil` | 0 | pass | survived (equivalent, F4) |
| M12 | order computed after the status phase (fixed player-first) | 12 fail | fail | killed |
| M13 | order computed before flinch clear / sleep cancel (single call) | 0 | pass | survived (equivalent, F4) |
| M14 | result mapping inverted | 16 fail | fail | killed |
| M15 | 0-HP guard returns foe first | 0 | pass | survived (equivalent, F4) |
| M16 | hoisted player record = foe's record | 2 fail | fail | killed |
| M17 | hoisted foe record from slot 1, not the chosen slot | 2 fail | fail | killed |
| M18 | end-of-turn speed ignores stages and paralysis | 3 fail | fail | killed |

Against the base engine (`43d2d52`'s `BattleEngine.lua` swapped in), the new
test fails 20 of 42 checks. The task says 18 (F3).

## Findings

### F1. Minor. Two tests still call `resolveEndTurn` with the old `sides` signature

- `tests/battle_confusion_flinch_test.lua:117`:
  `b:resolveEndTurn(events, { "player", "foe" })`
- `tests/battle_rampage_test.lua:344`:
  `b:resolveEndTurn({}, { "player", "foe" })`

After W0, the list `{ "player", "foe" }` is taken as `playerMove`. Its
`.priority` is nil, which reads as 0, and `foeMove` is nil. Lua accepts the
call silently, and both checks still pass by coincidence. The flinch and
sleep-cancel effects they test happen before the order is computed. The
call sites are now misleading, and they would break if `endTurnOrder` ever
read another field of the record.

Correction: change both calls to `resolveEndTurn(events, nil, nil)` (or pass
the move records), and add both files to the task's MAY CHANGE list. The
task's "no other assertion changed" stays true, because only the call
arguments change.

### F2. Minor. The superseded ruling is still unannotated in two places

The commit annotates correction (b) in
`work/reviews/2026-10-14-status-conditions-design-review.md:86` and M28 in
`work/reviews/2026-10-14-status-s1-review.md:245`. Both annotations are
accurate:
- M28's replacement mutant is killed (M1, M6-M8 and M16 above).
- The note on (b) correctly cites the D1 summary of `GetWhoStrikesFirst`.

The same superseded rule appears unannotated in two other places:
- `work/reports/phase4-status-conditions-design-proposal.md:107-108`: "(b)
  Battler order is the turn's action order: hoisted switch, item and run
  actions first …"
- `work/reviews/2026-10-14-status-s1-review.md:72-73`: "Battler order is the
  action order. Hoisted switch, item and run actions put the player first,
  which matches `SetActionsAndBattlersTurnOrder:3559-3592`."

Correction: add the same "[Superseded 2026-10-15 by weather W0 …]" note to
both.

### F3. Info. The old-engine failure count is 20, not 18

The task's acceptance section (`work/tasks/phase4-weather-w0.md`,
"Old-engine check") says 18 of the new checks fail against `43d2d52`. With
the base `BattleEngine.lua` swapped in, I get 22 passed and 20 failed. The
per-mutant counts the task gives match mine:
- removing the 0-HP guard fails 2;
- passing `nil` for the foe at the switch, capture and run sites fails 2,
  2 and 1.

Correct the number.

### F4. Info. Three mutants survive; all are equivalent, and one parameter pair is dead

- **M11.** Both early-exit sites (`:3399`, `:3405`) are reached only with a
  0-HP battler, so `endTurnOrder` returns at the guard and never reads
  `playerMove`/`foeMove` there. Passing the records is harmless and keeps
  the sites ready for a future R2 change. A one-line comment would stop a
  later reader from assuming they are tested.
- **M13.** The flinch clear and the sleep cancel change neither speed,
  priority nor HP, so computing the order before them cannot be observed.
  The same holds for placement relative to `decaySideTimers`, which makes no
  draws. The placement follows source, but no test can pin it until a phase
  between them affects the inputs.
- **M15.** When either battler is at 0 HP, the order direction cannot be
  observed, because every per-battler phase skips a 0-HP battler (as
  documented).

No action is needed beyond the optional comment.

### F5. Info. ROM-backed tests and runtime replays were not run

There is no verified ROM in this container, so every `*_rom_test.lua` ROM
section and `scripts/runtime_replay_smoke.sh` skipped. From reading them,
none asserts a draw count across a tied end of turn. The rival replay is
robust: the player uses Growl and loses. `route1_wild_win` and
`natural_capture` (seed 0) could see a shifted RNG stream after a tied end
of turn, which is now the source-correct behaviour. Run
`POKEPORT_ROM=… POKEPORT_RUNTIME_REPLAY=1 bash scripts/test_all.sh` on the
local runner before the next phase gate.

### F6. Info. The per-turn `gRandomTurnNumber` draw is still not modeled (pre-existing)

`BattleTurnPassed` draws `gRandomTurnNumber = Random()` after the end of turn
(`battle_main.c:2999`, and `:2926` at battle start). The engine does not
model it, so the "exact" draw counts are exact relative to the modeled
stream. This is already documented (`phase4-weather-design-proposal.md:441`,
`:998`) and is out of scope for W0.

## Required before closing W0

1. F1: update the two stale `resolveEndTurn` test calls, and amend MAY
   CHANGE.
2. F2: annotate the two remaining statements of the superseded ruling.
3. F3: correct "18" to "20" in the task file.
