# Independent review: residual slice R2 implementation

- Commits: `4637a87` (escape prevention, Ingrain, Mean Look / Spider Web /
  Block) and `f72d3d3` (Run Away escape, decision D4), on
  `claude/wizardly-faraday-o45q9z`. Reviewed as `git diff 8f5e6d3 f72d3d3`.
- Task: [phase4-residual-r2](../tasks/phase4-residual-r2.md). Spec:
  [design proposal](../reports/phase4-residual-effects-design-proposal.md)
  (R2 parts and the F4 restructure) and
  [design review](2026-10-15-residual-effects-design-review.md).
- Source: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`.
  Abbreviations: `bm.c` = `src/battle_main.c`, `msg.c` =
  `src/battle_message.c`, `bsc.c`, `bs1.s`, `bu.c` = `src/battle_util.c`,
  `pm.c` = `src/party_menu.c`, `ai.s` = `data/battle_ai_scripts.s`.

## Verdict: **PASS**

No corrections are required. The findings below are all Low or Info. None
of them changes behaviour on a reachable path.

## What was checked

### 1. Run and switch veto sites

| Source site | Engine / controller | Result |
| --- | --- | --- |
| Trainer RUN, `bm.c:3239-3244` (`BattleScript_PrintCantRunFromTrainer` comes first) | `_runTurn` tests `runDisabledMessage` first, then `runBlocked` (`BattleSceneController.lua:652-665`). Every main.lua trainer controller sets `runDisabledMessage` (`main.lua:1401`, `:1699`). | Match. The test "trainer RUN while rooted: only the trainer text" pins the order. A mutation that moves the veto above the trainer test fails 1 check. |
| Wild RUN, `bm.c:3245-3253`; `IsRunningFromBattleImpossible` `bm.c:3002-3058` (Run Away → SUCCESS at `:3013-3016`; `ESCAPE_PREVENTION\|WRAPPED` or `ROOTED` → FORBIDDEN at `:3047-3052`) | `BattleEngine:runBlocked` (`BattleEngine.lua:1361-1365`). The controller shows `"Can't escape!"` (`msg.c:333`, `gNoEscapeStringIds[B_MSG_CANT_ESCAPE]`, `msg.c:903-905`) and returns to ACTION, with no turn, no RNG and no `runTries` change. | Match. |
| Voluntary switch, `bm.c:3196-3200` (`PARTY_ACTION_CANT_SWITCH`); `TrySwitchInPokemon` `pm.c:5916-5968` (fainted, in-battle and Egg checks, then `gText_PkmnCantSwitchOut` with the active mon's nickname, `pm.c:5960-5966`, `strings.c:256`) | The PARTY A-press in voluntary mode only (`BattleSceneController.lua:793-806`) shows `playerName .. " can't be switched\nout!"`. The after-state is PARTY and `partyMode` stays `"voluntary"`, so B still cancels. `controller.playerName` is the active mon's nickname, and main.lua keeps it current on every switch (`main.lua:1624-1625`, `:1679-1680`). | Match. The menu still opens while trapped, as in source. |
| Voluntary switch through a direct callback | `Controller.new` stores the callback wrapped (`BattleSceneController.lua:123-127`). main.lua passes the closure inline in the opts table (`main.lua:1653`) and keeps no other reference to it. | Safe. A trapped call returns nil before main's party mutation (`main.lua:1673-1689`) runs. |
| Forced replacement | Not vetoed: the PARTY check tests `partyMode == "voluntary"`, and the forced callback is stored unwrapped. `recordFaint` has already cleared the fainted battler's own flags. | Allowed. Tests cover forced PARTY after a trapped player faints. |
| Locked-move turns | The `runTurn` asserts are skipped when `isLocked(player)` (`BattleEngine.lua:4053-4058`). The same predicate, evaluated on the same state with nothing changed in between, replaces the player's action with the locked move (`:4075-4077`). The controller never offers ACTION to a locked player (`_enterAction`, `BattleSceneController.lua:185-193`). | Safe. A locked player's run or switch action is never executed, so it cannot escape. In source a locked battler never reaches action selection at all. See F1. |
| Texts | `"Can't escape!"` `msg.c:333`; `"X can't\nescape now!"` `msg.c:197` (target); `"X planted its roots!"` `msg.c:234`; `"X absorbed\nnutrients with its roots!"` `msg.c:235`; `"X fled\nusing RUN AWAY!"` `msg.c:322` with `gAbilityNames[ABILITY_RUN_AWAY] = "RUN AWAY"` (`src/data/text/abilities.h:214`); `"{STR_VAR_1} can't be switched\nout!"` `strings.c:256`. | All exact. |

### 2. main.lua

- `git diff 8f5e6d3 f72d3d3 -- main.lua` is empty.
- main.lua never calls `engine:runTurn` directly. Its only battle input is
  `world.battle.controller:processInput` (`main.lua:4465`). Its only
  `_runTurn` call is `{action="switch"}` inside the voluntary closure
  (`:1690`), and the controller wrapper and the PARTY veto both sit in
  front of that closure.
- `runBattle()` (`main.lua:3882-3901`) presses DPAD and A through
  `processInput`, so it goes through the RUN veto. Against a trapped player
  it would loop its 240 iterations and return nil, without asserting
  (see F4).
- The only other direct callers of `onVoluntarySwitchChoice` are tests
  (`tests/phase4_player_voluntary_switch_controller_test.lua:67`, a stub;
  `tests/battle_weather_w3b_test.lua:541`).

### 3. Ingrain

- Move: `bs1.s:2372-2380` and `Cmd_trysetroots` `bsc.c:8933-8944`. The
  engine branch (`BattleEngine.lua:2319-2333`) spends PP and has no
  accuracy check and no RNG. Already rooted → `moveFailed`, otherwise
  `rooted = true` and `rootsPlanted`. It works against a
  semi-invulnerable foe (USER target).
- End of turn: `ENDTURN_INGRAIN` is the first case of the per-battler enum
  (`bu.c:720-742`, case at `:760-773`). Conditions are ROOTED,
  `hp != maxHP` and `hp != 0`. The heal is `max(1, maxHP/16)`, and
  `datahpupdate` clamps it.
- The engine (`BattleEngine.lua:3931-3935`) runs Ingrain before Rain Dish,
  Leech Seed, poison/burn, Nightmare and Curse. It computes
  `min(maxHP-hp, max(1, floor(maxHP/16)))` and does not call the team
  check.
- `BattleScript_IngrainTurnHeal` (`bs1.s:3553-3560`) prints its text before
  `healthbarupdate`/`datahpupdate`. The controller adds the text and then
  the HP entry. A mutation that swaps that order fails 2 checks.
- Tests pin each of the following:
  - sandstorm (field) comes before Ingrain;
  - Ingrain filling the battler leaves Rain Dish silent;
  - exact HP through Ingrain → Rain Dish → Leech Seed → poison;
  - the deferred team check still decides after the player's heals.
- Persistence: `rooted` is cleared only in `recordFaint`. No Rapid Spin,
  wake-up or switch path touches it, and a switch is impossible while
  rooted anyway. The persist bridge writes HP, status1 and PP only.

### 4. Mean Look / Spider Web / Block

- `bs1.s:1440-1453`: `accuracycheck ..., NO_ACC_CALC`. In `bsc.c:1020-1025`
  an ON_AIR, UNDERGROUND or UNDERWATER target jumps to But it failed, with
  no draw. Then an already escape-prevented target → But it failed.
  `MOVE_EFFECT_PREVENT_ESCAPE` is at `bsc.c:2673-2677`. The engine branch
  (`BattleEngine.lua:2335-2355`) tests `defender.semiInvulnerable or
  defender.escapePrevented` after PP. It matches the R1 Ghost-Curse
  pattern, and a rooted target still succeeds.
- Holder linkage: in singles the only other battler is the opposing slot,
  so `clearHeldBy(side)` clearing the other battler's flag without
  condition is equivalent to source's `battlerPreventingEscape ==
  gActiveBattler` loop. It runs at the points where source clears:
  - in `SwitchInClearSetData` (`bm.c:2339-2343`) and the engine's
    voluntary switch branch (`BattleEngine.lua:4112-4115`);
  - in `FaintClearSetData` (`bm.c:2441-2452`) and `recordFaint`
    (`BattleEngine.lua:1330-1333`), which also zeroes the fainted
    battler's own `rooted`/`escapePrevented`.
- Forced replacement of the holder needs nothing more: the holder's faint
  has already cleared the lock, and the incoming battler is built fresh
  through `makeBattler`. The seed is not touched (tested).

### 5. Run Away (D4)

- `TryRunFromBattle` (`bm.c:4229-4280`) has a Run Away branch at
  `:4246-4251` with no `Random()` and no `++runTries` (the increment is
  only in the final else). `HandleEndTurn_RanFromBattle` (`bm.c:3798-3812`,
  case 2) leads to `BattleScript_RanAwayUsingMonAbility` (`bs1.s:3009-3012`).
- The engine (`BattleEngine.lua:4191-4202`) emits `run{success, ability}`
  and `battleEnd`, with no draw and `runTries` unchanged. The foe never
  moves. `BattleFormulas.lua` is untouched.
- Bypass: `runBlocked` returns false for ability 50 and `switchBlocked`
  has no bypass. Both match source.
- Trainer battles: `runDisabledMessage` still comes first, as in
  `bm.c:3239-3244`. That is tested.

### 6. AI

- `AI_CBM_CantEscape` (`ai.s:434-436`) checks the target's
  `ESCAPE_PREVENTION` only and scores −10. `AI_CBM_Ingrain` (`ai.s:554-556`)
  checks the user's `ROOTED` and scores −10. The dispatch is at
  `ai.s:161`, `:199`.
- The `AICheckBadMove.lua` diff adds two handlers and changes rows 106 and
  181, and nothing else.
- `TrainerAI.lua` has no 106/181 handling and is unchanged.
  `AI_CV_Trap` (`ai.s:723`) belongs to CheckViability, which is out of
  scope.

### 7. Inventory and ROM fixture

- The records match `src/data/battle_moves.h`: `:2200-2211`, `:2759-2770`,
  `:4358-4369`, `:3578-3589`. Types are Bug 6, Normal 0 and Grass 12;
  targets are 0 and USER 0x10; flags are 0x16 and 0x08.
- Admitted/rejected goes from 295/59 to 299/55. In the class tables,
  represented moves from 122/263/183/80 to 124/267/183/84 and blocked
  moves from 75/90/32/58 to 73/86/32/54. The arithmetic is consistent
  (+2 families and +4 zero-power moves).
- `tests/phase4_residual_r2_effect_rom_test.lua` asserts an exact
  4-member family. With no ROM it skips; no `.gba` file is present in this
  environment (F3).

### 8. Regressions

- `lua5.1 tests/battle_residual_r2_test.lua`: 102 passed, 0 failed.
- `bash scripts/test_all.sh`: PASS, 189 files (no-ROM mode). This includes
  the controller stub tests (`phase4_player_voluntary_switch_controller_test`,
  `phase4_player_forced_replacement_controller_test`,
  `phase4_foe_only_multimon_controller_test`) and all earlier slice tests.
- `lua5.1 scripts/check_repository.lua`: PASS.

## Mutation testing

Each mutant was applied by script, run against
`tests/battle_residual_r2_test.lua`, and reverted with `git checkout --
src/`. `git status` was clean after every run.

| Mutant | Result |
| --- | --- |
| Ingrain heal /8 | killed (error) |
| no clamp | killed (2) |
| no min 1 | killed (1) |
| heals at full HP | killed (1) |
| Ingrain moved after Rain Dish | killed (5) |
| HP before text | killed (2) |
| `runBlocked` without `rooted` | killed (8) |
| without the wrap term | killed (1) |
| without the Run Away bypass | killed (3) |
| `switchBlocked` with a Run Away bypass | killed (3) |
| without `rooted` | killed (5) |
| no `clearHeldBy` on faint | killed (3) |
| no own-flag clear on faint | killed (3) |
| no `clearHeldBy` on switch | killed (2) |
| `clearHeldBy` clears the wrong side | killed (5) |
| Mean Look without the semi-invulnerable test | killed (3) |
| without the repeat fail | killed (1) |
| no PP | killed (7) |
| sets the attacker | killed (6) |
| Ingrain without the repeat fail | killed (1) |
| run assert off | killed (5) |
| switch assert off | killed (4) |
| locked-player assert skip removed | **survives**, also under `test_all.sh` (F1) |
| Run Away bumps `runTries` | killed (3) |
| Run Away draws | killed (error) |
| no Run Away branch | killed (5) |
| wrong Run Away text | killed (3) |
| controller RUN veto off | killed (engine assert) |
| RUN veto before the trainer text | killed (1) |
| PARTY veto off | killed (2; also under `test_all.sh`) |
| PARTY veto also in forced mode | killed (1) |
| PARTY veto returns to ACTION | killed (1) |
| wrapper off | killed (2; also under `test_all.sh`) |
| wrapper without the nil guard | killed (stub error) |
| RUN veto without the nil guard | killed (stub error) |
| AI 106 also tests `rooted` | killed (1) |
| AI 181 reads the target | killed (3) |
| Ingrain admitted for any target | killed (1) |

## Findings

1. **F1 — Low (test gap, behaviour correct).** The locked-player skip of
   the `runTurn` asserts (`BattleEngine.lua:4053`) is not pinned: removing
   it survives the R2 test and `test_all.sh`. The skip is safe. The same
   `isLocked` predicate, on the same state, replaces the action with the
   locked move (`:4075-4077`), and the controller never shows ACTION to a
   locked player (`BattleSceneController.lua:185-193`). So no locked run or
   switch can execute. Removing the skip would only turn a direct
   `runTurn({action="run"})` from a trapped, locked caller into an assert.
   Optional: add one check that a trapped, locked player passing
   `{action="run"}` resolves its locked move with no assert and no flee.
2. **F2 — Info (pre-existing, not R2).** main.lua's voluntary closure
   mutates party state before `_runTurn({action="switch"})`
   (`main.lua:1673-1690`). If that closure were ever reached while the
   player is locked, the engine would silently replace the switch with the
   locked move after the party records had been swapped. This is
   unreachable, because a locked player gets no ACTION menu, so there is
   no PARTY entry. R2's wrapper checks `switchBlocked` only, and that is
   correct for R2's scope.
3. **F3 — Info.** The ROM fixture for the four records is pending: there is
   no ROM in this environment, and the ROM test skips cleanly. The source
   records were checked by hand against `battle_moves.h` (section 7).
4. **F4 — Info (documented Risk R5).** The `runBattle()` replay driver
   would make no progress against a trapped player. It exits after 240
   iterations with a nil outcome and does not crash. The replayed route
   (Route 1, the rival lab battle) has no trapping move.
5. **F5 — Info (pre-existing convention).** The new texts use
   `name(side)`, which is the bare species or nickname without the
   `Wild `/`Foe ` prefix that `B_ATK_NAME_WITH_PREFIX` /
   `B_DEF_NAME_WITH_PREFIX` would add for the foe. Every existing
   controller text does the same, so R2 is consistent with the convention.
6. **F6 — Info.** `ingrainHeal.amount` carries the clamped heal. Source's
   `gBattleMoveDamage` is the unclamped `maxHP/16`, and `datahpupdate`
   clamps it. No text or consumer reads the amount, and `hpRemaining`
   matches source exactly.
