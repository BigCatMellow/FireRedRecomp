# Task: residual slice R2 — escape prevention, Ingrain, Mean Look / Spider Web / Block, Run Away

- Task ID: `P4-RESIDUAL-R2`
- Status: `DONE — independently reviewed PASS`
- Lane: full relay (new cross-turn battle state, an action veto that reaches
  the controller)
- Spec: [residual effects design proposal](../reports/phase4-residual-effects-design-proposal.md)
  (R2 parts), status `independently reviewed PASS WITH CORRECTIONS
  (applied)`, with the [design review](../reviews/2026-10-15-residual-effects-design-review.md)
  folded in: F4 (no `main.lua`; controller veto plus the callback wrapper),
  F5 (nil-guarded controller calls on stub engines), F6 (controller MAY
  CHANGE, `main.lua` MUST NOT CHANGE), F8.1 (Run Away text), F8.3
  (CANT_SWITCH checks), decisions D1 (Ingrain in R2), D3 (amended by F4)
  and D4 (Run Away escape as its own commit).
- Base: `8f5e6d3` on `claude/wizardly-faraday-o45q9z` (origin/main, R1
  merged).

## Source lock (pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`)

Abbreviations: `bsc.c` `src/battle_script_commands.c`, `bs1.s`
`data/battle_scripts_1.s`, `bu.c` `src/battle_util.c`, `bm.c`
`src/battle_main.c`, `msg.c` `src/battle_message.c`, `pm.c`
`src/party_menu.c`, `ai.s` `data/battle_ai_scripts.s`, `moves.h`
`src/data/battle_moves.h`.

- **Records** (`moves.h`): Spider Web 169 `:2200-2211` (effect 106, power
  0, Bug, acc 100, PP 10, SELECTED, flags 0x16); Mean Look 212
  `:2759-2770` (106, 0, Normal, 100, 5, SELECTED, 0x16); Block 335
  `:4358-4369` (106, 0, Normal, 100, 5, SELECTED, 0x16); Ingrain 275
  `:3578-3589` (181, 0, Grass, 100, 20, USER, 0x08 Snatch). Run Away =
  ability 50.
- **Mean Look** `bs1.s:1440-1453`: attackcanceler, attackstring, ppreduce,
  `accuracycheck BattleScript_ButItFailed, NO_ACC_CALC` (no draw; an
  ON_AIR/UNDERGROUND/UNDERWATER target fails, `bsc.c:1020-1025`), already
  `STATUS2_ESCAPE_PREVENTION` → But it failed, (Substitute), then
  `MOVE_EFFECT_PREVENT_ESCAPE` (`bsc.c:2673-2677`: sets the bit and
  `battlerPreventingEscape = gBattlerAttacker`), "X can't\nescape now!"
  (`msg.c:197`).
- **Ingrain** `bs1.s:2372-2380`: attackcanceler, attackstring, ppreduce,
  `Cmd_trysetroots` (`bsc.c:8933-8944`: already ROOTED → But it failed,
  else set), "X planted its roots!" (`msg.c:234`). No accuracy, no RNG.
- **Ingrain end of turn** `bu.c:760-773`: the first per-battler case
  (`bu.c:720-742`); ROOTED, `hp != maxHP`, `hp != 0` → heal
  `max(1, maxHP/16)`; `BattleScript_IngrainTurnHeal` (`bs1.s:3553-3560`)
  prints "X absorbed\nnutrients with its roots!" (`msg.c:235`) before
  `datahpupdate` (clamps). No team check.
- **Run veto** `bm.c:3239-3253`: a trainer battle →
  `BattleScript_PrintCantRunFromTrainer` first; otherwise
  `IsRunningFromBattleImpossible() != SUCCESS` →
  `BattleScript_PrintCantEscapeFromBattle` (`bs1.s:3038-3040`), a selection
  script: "Can't escape!" (`msg.c:333`, `gNoEscapeStringIds[0]`), back to
  `STATE_BEFORE_ACTION_CHOSEN`. No turn, no RNG, no `runTries`.
  `IsRunningFromBattleImpossible` (`bm.c:3002-3058`): Smoke Ball, link or
  **Run Away** → SUCCESS (`:3013-3016`); Shadow Tag / Arena Trap / Magnet
  Pull (not modeled); `ESCAPE_PREVENTION | WRAPPED` or `ROOTED` → FORBIDDEN
  (`:3047-3052`).
- **Switch veto** `bm.c:3196-3200`: `WRAPPED | ESCAPE_PREVENTION` or
  `ROOTED` → the party menu opens with `PARTY_ACTION_CANT_SWITCH`.
  `TrySwitchInPokemon` (`pm.c:5916-5968`), after the fainted / in-battle /
  Egg checks, prints `gText_PkmnCantSwitchOut` "{STR_VAR_1} can't be
  switched\nout!" (`src/strings.c:256`) with the **active** mon's nickname
  (`pm.c:5960-5966`) and stays in the menu. No Run Away bypass.
- **Clearing**: `SwitchInClearSetData` (`bm.c:2339-2343`: every battler
  whose `battlerPreventingEscape` is the switching slot loses the bit;
  `:2365-2368` zeroes the incoming slot's own status2/status3);
  `FaintClearSetData` (`bm.c:2441-2452`: own bits zeroed, others lose the
  escape prevention held by the fainted slot). A seed is never cleared by
  the receiver's switch or faint (R1).
- **Run Away escape** (D4) `TryRunFromBattle` `bm.c:4229-4280`: the Run Away
  branch (`:4246-4251`) sets `fleeType = FLEE_ABILITY` and escapes, with no
  `Random()` and no `++runTries` (that increment is only in the final else,
  `:4272`). `HandleEndTurn_RanFromBattle` (`bm.c:3798-3812`) picks
  `BattleScript_RanAwayUsingMonAbility` (`bs1.s:3009-3012`):
  `sText_PkmnFledUsing` "{B_ATK_NAME_WITH_PREFIX} fled\nusing
  {B_ATK_ABILITY}!" (`msg.c:322`).
- **AI** `ai.s`: `AI_CBM_CantEscape` `:434-436` (target
  `STATUS2_ESCAPE_PREVENTION` → −10; no WRAPPED/ROOTED test);
  `AI_CBM_Ingrain` `:554-556` (user `STATUS3_ROOTED` → −10).

## Design (as implemented)

- `BattleEngine` constants `EFFECT_MEAN_LOOK` (106), `EFFECT_INGRAIN` (181),
  `ABILITY_RUN_AWAY` (50). `makeBattler` fields `rooted`, `escapePrevented`
  (battle-only; the persist bridge writes HP/status1/PP only). The preventer
  is implicitly the opposing slot (singles).
- `BattleEngine:clearHeldBy(side)`: the opposing battler loses
  `escapePrevented` (R3 adds the wrap fields). Called from `recordFaint`
  (which also zeroes the fainted battler's own `rooted`/`escapePrevented`)
  and from `runTurn`'s voluntary switch branch. `resolveForcedSwitch` adds
  nothing (the faint already cleared it). The seed is not touched.
- `BattleEngine:runBlocked(side)` (Run Away → false; else `escapePrevented`
  or `rooted` or `wrapTurns > 0`) and `BattleEngine:switchBlocked(side)`
  (the same three, no Run Away bypass). `wrapTurns` is R3's field, read as
  `(b.wrapTurns or 0)`.
- `runTurn` asserts `not runBlocked("player")` for a run action and
  `not switchBlocked("player")` for a switch action, before any state
  changes, unless the player is locked (its action is replaced by the
  locked move).
- `supportsMove` admits 106 (power 0, SELECTED) and 181 (power 0, USER).
- Early branches beside Leech Seed/Nightmare/Curse (after the cancellers):
  - Ingrain: PP; `moveFailed` when already rooted; else `rooted = true`
    and `rootsPlanted{side}`.
  - Mean Look / Spider Web / Block: PP; `moveFailed` when the target is
    semi-invulnerable (any state) or already escape-prevented; else
    `escapePrevented = true` and `escapePrevented{side, target}`. No draw.
- `resolveStatusEndTurn` per battler: **Ingrain** (`ingrainHeal{side,
  amount, hpRemaining}`), Rain Dish, Leech Seed, poison/toxic/burn,
  Nightmare, Curse, the rampage tick. Ingrain never runs the tick team
  check.
- Controller (`BattleSceneController.lua`, MAY CHANGE per F6):
  1. RUN: after the `runDisabledMessage` test, `self.engine.runBlocked and
     self.engine:runBlocked("player")` → messages `{ "Can't escape!" }`,
     back to ACTION, no `runTurn`.
  2. PARTY A-press, voluntary mode only, before the callback:
     `self.engine.switchBlocked and self.engine:switchBlocked("player")` →
     `"<playerName> can't be switched\nout!"` with after-state PARTY
     (`partyMode` stays `"voluntary"`, so B still cancels). The forced mode
     is never checked.
  3. `Controller.new` stores `onVoluntarySwitchChoice` wrapped: a blocked
     player returns nil without calling the owner's closure. The forced
     callback is stored as given.
  4. Texts: `rootsPlanted` "X planted its roots!"; `ingrainHeal` "X
     absorbed\nnutrients with its roots!" then HP; `escapePrevented` "X
     can't\nescape now!" (target name).
- `AICheckBadMove`: new handlers `cantEscape` (target `escapePrevented`
  −10) and `ingrain` (user `rooted` −10); dispatch rows 106 and 181 now
  point at them. Nothing else in the file changed.
- Run Away escape (separate commit, D4): in `runTurn`'s run branch, a
  player with ability 50 escapes before `BattleFormulas.tryRunFromBattle`
  is consulted: `run{side, success=true, ability=true}` then
  `battleEnd{outcome="ran"}`, no draw, `runTries` unchanged, the foe never
  moves. The controller prints "X fled\nusing RUN AWAY!" for that event
  (`gAbilityNames[ABILITY_RUN_AWAY]`, `src/data/text/abilities.h:214`).
  `BattleFormulas.lua` is not touched.

## File ownership

- **MAY CHANGE:** `src/core/BattleEngine.lua`;
  `src/core/BattleSceneController.lua` (controller MAY CHANGE: the RUN and
  PARTY vetoes, the callback wrapper, texts);
  `src/core/AICheckBadMove.lua` (only the Mean Look and Ingrain rows and
  handlers); `tests/battle_residual_r2_test.lua` (new),
  `tests/phase4_residual_r2_effect_rom_test.lua` (new),
  `tests/phase4_move_effect_inventory_test.lua`;
  `work/reports/phase4-move-effect-inventory.md`, this task file.
- **MUST NOT CHANGE:** `main.lua` (main.lua MUST NOT CHANGE), party/Dex
  code, coordination and roadmap files, `BattleFormulas.lua`,
  `TrainerAI.lua`, any other `AICheckBadMove.lua` row or handler.

## Changed assertions

- `tests/phase4_move_effect_inventory_test.lua`: rows 106 and 181 →
  `represented`, admitted; totals admitted 295 → 299, rejected 59 → 55;
  represented 122/263/183/80 → 124/267/183/84; blocked 75/90/32/58 →
  73/86/32/54. Reason: the R2 admissions and coverage.
- No other existing assertion changed. The existing controller stub tests
  (`tests/phase4_player_voluntary_switch_controller_test.lua`,
  `tests/battle_scene_controller_test.lua` and the other controller tests)
  pass unchanged (F5).

## Acceptance

- `tests/battle_residual_r2_test.lua`: 102 checks (94 in the core commit,
  8 added with Run Away), exact `scriptedRng` draw counts:
  - Admission and defaults.
  - Queries: rooted / escape prevention / a wrap counter each block run
    and switch; Run Away bypasses only the run; per side.
  - `runTurn` asserts on a blocked run and a blocked switch with no state
    change (turn, draws, `runTries`); a blocked player may still use a
    move; a rooted Run Away holder's switch still asserts.
  - Ingrain: rooted, 0 draws, PP; text; repeat fail; works vs a
    semi-invulnerable foe. End of turn: 25 of 400 with text before HP;
    full HP nothing; clamp at maxHP; minimum 1; the foe heals.
  - Order: Ingrain < Rain Dish < Leech Seed < poison with exact HP;
    Ingrain filling the battler leaves Rain Dish silent; sandstorm (field)
    before Ingrain; Ingrain and Rain Dish do not trigger the deferred team
    check (a seed KO of the foe is decided after the player's heals).
  - Mean Look / Spider Web / Block: escape prevented, 0 draws, PP, text;
    repeat fail; semi-invulnerable (air/underground/underwater) fail with 0
    draws; a rooted target still succeeds; the foe's Mean Look traps the
    player through a turn.
  - Clearing: the preventer's end-of-turn faint (with a replacement) frees
    the player and clears the fainted battler's own flags; the trapped
    player's faint clears its own flags and the foe's lock, and the forced
    replacement resolves; the player's voluntary switch frees the foe and
    keeps the seed; a trapped foe never blocks the player.
  - AI rows: Mean Look 0 / −10 (all three moves), no ROOTED test, reads
    the target; Ingrain 0 / −10, reads the user; the live engine battlers.
  - Run Away (D4 commit): a slower holder escapes with 0 draws and
    `runTries` 0, `turnStart,run,battleEnd`, "PLAYER fled\nusing RUN
    AWAY!"; the same battler without Run Away draws once and fails; a
    rooted or escape-prevented holder bypasses the controller veto and
    flees with no draw; a trainer battle still shows the trainer text; a
    rooted holder still can't be switched out.
  - Controller through the real engine: wild RUN while rooted or
    escape-prevented → "Can't escape!", no turn, no RNG, `runTries` 0, one
    message, back to ACTION; an untrapped RUN reaches the engine; a trainer
    RUN while rooted shows only the trainer text; the voluntary PARTY pick
    while trapped → "TANGELA can't be switched\nout!", no callback, no
    turn, stays in voluntary PARTY, B cancels; the stored callback is
    wrapped (direct call returns nil, untrapped direct call goes through);
    the forced callback is unwrapped and never vetoed (even with a forced
    `switchBlocked`); a trapped player's faint reaches forced PARTY and the
    replacement goes through; stub engines without the queries keep
    working (F5).
- `tests/phase4_residual_r2_effect_rom_test.lua`: exact 4-member records;
  skips without a ROM (ROM fixture pending).
- Mutation spot-checks (each restored from a scratchpad backup, `cmp`
  clean): no Ingrain heal fails 6 (and errors); `clearHeldBy` no-op fails
  5; no switch-branch clear fails 2; no Mean Look semi-invulnerable test
  fails 3; no Run Away bypass in `runBlocked` fails 1; no own-flag clear
  on faint fails 3; no `runTurn` asserts fails 6; no controller RUN veto
  errors (the engine assert surfaces, Risk R5); no PARTY A-press veto fails
  1 (the wrapper still blocks); no wrapper fails 2; AI row 106 reverted
  fails 2; AI row 181 reverted fails 2; no Run Away escape branch fails 5;
  no Run Away text fails 3.
- `bash scripts/test_all.sh` (189 files) and `lua5.1
  scripts/check_repository.lua` pass; `main.lua` is unchanged
  (`git diff 8f5e6d3 -- main.lua` is empty).

## Deviations from the design

- The `runTurn` asserts sit at the top of `runTurn` (before the turn
  counter and other state change) rather than at the top of each branch,
  and are skipped for a locked player, whose chosen action is replaced by
  the locked move. Same contract, no partial mutation.
- Mean Look's fail test reads `defender.semiInvulnerable` directly (any of
  the three states), which is what `NO_ACC_CALC` does
  (`bsc.c:1020-1025`); the design's `semiInvulnerableMiss` gives the same
  answer for effect 106.

## Known limits and follow-ups

- Not represented: Substitute, Magic Coat, Snatch, Protect, Baton Pass
  carry-over, Shadow Tag / Arena Trap / Magnet Pull (the single place to
  add them is `runBlocked`/`switchBlocked`), Smoke Ball, Teleport (must
  reuse `runBlocked` when admitted, review F8.2), the Roar/Whirlwind
  anchor text.
- Wild battles have no voluntary switch selector in this project
  ("POKEMON switching is not available yet." comes first); the switch veto
  is therefore reachable only in trainer battles, as the voluntary switch
  itself.
- The `runBattle()` replay driver in `main.lua` would make no progress
  against a trapped player (Risk R5); no current route encounter traps.
- Optional hand-off note for the `main.lua` owner (proposal, "`main.lua`:
  no change"): a belt-and-braces `switchBlocked` guard at the top of
  `onVoluntarySwitchChoice` is possible but not needed.
- ROM fixture pending for the four records.

## Review (2026-10-15)

[Implementation review](../reviews/2026-10-15-residual-r2-implementation-review.md):
PASS. main.lua unchanged and its real flow cannot bypass the vetoes (all input
goes through the controller; the voluntary callback is held only by the
controller). 37/38 mutants caught; the survivor (the locked-player assert skip)
is correct but untested (F1, optional). F2-F6 informational.
