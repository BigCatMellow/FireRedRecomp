# Task: protection slice P5 — Focus Punch (effect 170)

- Task ID: `P4-PROTECTION-P5`
- Status: `DONE — independently reviewed PASS WITH CORRECTIONS (applied)`
- Lane: full relay (a pre-turn event, per-turn and battle-long battle
  state, new controller texts, an RNG change on an already-admitted move)
- Spec: [protection design proposal](../reports/phase4-protection-design-proposal.md)
  (P5 parts, decision D4), status `independently reviewed PASS WITH
  CORRECTIONS (applied)`, with the [design review](../reviews/2026-10-15-protection-design-review.md)
  folded in: F8 (the run latch is player-only), D4 (model the latch).
- Base: P4 (`8c74736`) on `claude/wizardly-faraday-o45q9z`.

## Source lock (pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`)

Abbreviations: `bsc.c` `src/battle_script_commands.c`, `bs1.s`
`data/battle_scripts_1.s`, `bm.c` `src/battle_main.c`, `msg.c`
`src/battle_message.c`, `moves.h` `src/data/battle_moves.h`.

- **Record** `moves.h:3435-3446`: Focus Punch 264, effect 170, power 150,
  Fighting, accuracy 100, PP 20, chance 0, `MOVE_TARGET_SELECTED`,
  **priority −3**, flags `MAKES_CONTACT | PROTECT_AFFECTED` (0x03).
- **Pre-turn hook** `CheckFocusPunch_ClearVarsBeforeTurnStarts`
  (`bm.c:3669-3702`), entered after both actions are chosen and
  `SetActionsAndBattlersTurnOrder` has run (`bm.c:3578-3579`,
  `:3619-3620`), before the first action:
  - skipped entirely while `HITMARKER_RUN` is set (`:3671`);
  - per battler **in battler-id order** (player, then foe):
    `gChosenMoveByBattler == MOVE_FOCUS_PUNCH`, not `STATUS1_SLEEP`, no
    Truant counter, not `noValidMoves` → `BattleScript_FocusPunchSetUp`
    (`bs1.s:3649-3655`): "{B_ATK_NAME_WITH_PREFIX} is tightening\nits
    focus!" (`msg.c:224`). No RNG;
  - the chosen move is reset to `MOVE_NONE` each turn (`bm.c:2907`) and
    written only at selection (`:3288`); a locked or recharging battler
    skips selection (`:3125-3130`).
- **`HITMARKER_RUN`** (`include/constants/battle.h:168`): set when a
  `B_ACTION_RUN` reaches `STATE_WAIT_ACTION_CASE_CHOSEN` (`bm.c:3326-3328`),
  cleared only by `gHitMarker = 0` at battle start (`:2257`). The trainer
  and trapped vetoes return earlier (`:3239-3253`). The AI's flee also sets
  it in source (`src/battle_controller_opponent.c:1355-1367`; review F8);
  the engine has no AI flee.
- **Move script** `bs1.s:2255-2261`: `attackcanceler`, `jumpifnodamage
  BattleScript_HitFromAccCheck` (`bsc.c:8757-8763`: continues when
  `physicalDmg || specialDmg` is nonzero), `ppreduce`, "{B_ATK_NAME_WITH_PREFIX}
  lost its\nfocus and couldn't move!" (`msg.c:254`). **No `attackstring`**,
  no RNG. Otherwise the ordinary hit from `accuracycheck`.
- **Damage record** `Cmd_datahpupdate` (`bsc.c:1822-1854`): `gHpDealt` into
  `physicalDmg`/`specialDmg` for HP loss without `HITMARKER_PASSIVE_DAMAGE`;
  Pain Split excluded (`gCurrentMove != MOVE_PAIN_SPLIT`, and it is Normal
  so neither arm fires); a 0-HP hit records 0. The damage record is cleared
  by `TurnValuesCleanUp(FALSE)` (`bm.c:3637-3639`); `FaintClearSetData`
  (`:2461-2479`) clears only named protect flags, so the engine's extra clear
  on faint is not a source clear (unobservable; review F1).

## Design (as implemented)

- `BattleEngine.EFFECT_FOCUS_PUNCH = 170`, `MOVE_FOCUS_PUNCH = 264`.
  `makeBattler` field `tookMoveDamage = false`; engine field
  `runAttempted = false`. Both battle-only, never persisted.
- `runTurn`: `tookMoveDamage` is reset for both battlers beside
  `targetNotAffected`. After the locked-action substitution, `runAttempted =
  true` when the player's action is `run`, then
  `resolveFocusPunchSetup(playerAction, foeAction, events)` emits
  `focusPunchSetup{side}` right after `turnStart`, before every branch
  (switch, capture, run, moves), so it is the first event of the turn after
  both actions are known. It does nothing while `runAttempted`; otherwise,
  player then foe: a `move` action whose slot holds move 264, a side not
  locked at turn start, not asleep, and not every slot at 0 PP.
- `applyDamage`: when `defenderSide ~= attackerSide` and the clamped damage
  is > 0, `defender.tookMoveDamage = true`. Pain Split, crash, recoil, the
  confusion self-hit and end-of-turn damage do not use `applyDamage`.
- `resolveMoveCore`, after the cancellers, the locked 0-PP check and the
  charge block, before `useMove`: effect 170 with `tookMoveDamage` → spend
  PP (guarded), `focusLost{side}`, return. No `useMove`, no RNG.
- `recordFaint` clears `tookMoveDamage`.
- Priority −3 is already read from the record by `getWhoStrikesFirst`.
- Controller: `focusPunchSetup` → "X is tightening\nits focus!",
  `focusLost` → "X lost its\nfocus and couldn't move!". Header event list
  updated. No `main.lua` change: the controller shows the turn's events in
  order, so the setup text precedes every action text.
- AI: `AI_CBM_HighRiskForDamage` for effect 170 is already ported; no
  `AICheckBadMove.lua` change.

## File ownership

- **MAY CHANGE:** `src/core/BattleEngine.lua`;
  `src/core/BattleSceneController.lua` (texts only);
  `tests/battle_protection_p5_test.lua` (new),
  `tests/phase4_protection_p5_effect_rom_test.lua` (new),
  `tests/phase4_move_effect_inventory_test.lua`;
  `work/reports/phase4-move-effect-inventory.md`, this task file.
- **MUST NOT CHANGE:** `main.lua`, party/Dex code, coordination and roadmap
  files, `AICheckBadMove.lua`.

## RNG change and changed assertions

- A Focus Punch user that took move damage earlier in the turn now loses
  focus and draws nothing (before P5 it was a plain hit: accuracy, crit and
  random). The hook draws nothing. A hit Focus Punch is unchanged.
- **Audit of existing assertions:** no existing test, `scripts/runtime_*.sh`
  replay or `work/` probe resolves move 264 (grep for `264`/`FOCUS_PUNCH`
  over `tests/` and `scripts/` finds only the inventory row and an
  unrelated stat value). The new per-turn reset and the `applyDamage` write
  touch no existing event or draw. **No existing assertion's draw count
  changes.**
- Changed assertions: `tests/phase4_move_effect_inventory_test.lua` only —
  row 170 `blocked_on_state` → `represented` (ROM fixture pending,
  `phase4_protection_p5_effect_rom_test`); `admitted_uncovered_positive`
  25 → 24; represented 126/274/190/84 → 127/275/191/84; blocked
  71/79/25/54 → 70/78/24/54. Admitted/rejected stay 299/55. Reason: P5
  coverage.

## Acceptance

- `tests/battle_protection_p5_test.lua`: 39 checks, exact `scriptedRng`
  draw counts:
  - Admission, constants, defaults.
  - Lost focus: `turnStart,focusPunchSetup,useMove(foe),damage,focusLost`,
    3 draws, PP 20 → 19, no damage to the foe, the texts with no "used"
    line; the next turn the record is reset and Focus Punch hits for 20.
  - Focus kept: no hit (Splash), a miss (4 draws), a no-effect hit against
    a Ghost (6 draws), Pain Split (HP 400 → 250, 3 draws), a 0-damage False
    Swipe against a 1-HP user (6 draws).
  - Both use Focus Punch: the texts in battler-id order (player first) with
    either speed order; the faster hits, the slower loses focus (PP spent).
  - No text: asleep (fastAsleep), waking this turn (no text, `wokeUp`, then
    `focusLost`), recharging, a locked Thrash with Focus Punch in another
    slot, Struggle.
  - Text despite freeze (`frozenSolid`), paralysis and confusion.
  - Switch turn: the foe's text precedes the player's switch, and its Focus
    Punch hits the incoming battler.
  - Run latch: no text on the failed-run turn (4 draws), none for either
    side on the next two turns, Focus Punch still resolves.
  - The record: 0 damage records nothing, same-side application records
    nothing, `recordFaint` clears it.
  - Controller `_runTurn` through the real engine: "PIKACHU is
    tightening\nits focus!|EKANS used TACKLE!|PIKACHU lost its\nfocus and
    couldn't move!".
- `tests/phase4_protection_p5_effect_rom_test.lua`: the exact 1-member
  family record; skips without a ROM (ROM fixture pending).
- Mutation spot-checks (each applied to the working tree, then restored from
  a scratchpad copy, `cmp` clean): no run latch fails 3; the hook ignoring
  the latch fails 3; sleep not checked fails 2; lock not checked fails 1;
  Struggle not checked fails 1; foe-first order fails 2; the record not reset
  per turn fails 2; 0 damage recording fails 2; a "used" line on lost focus
  fails 7; lost focus spending no PP fails 2; no lost-focus branch fails 11;
  `recordFaint` keeping the record fails 1.
- `bash scripts/test_all.sh` and `lua5.1 scripts/check_repository.lua`
  pass; `main.lua` unchanged.

## Deviations from the design

- None in behaviour. The hook is a named method (`resolveFocusPunchSetup`)
  called from `runTurn`; it runs before `getWhoStrikesFirst`'s speed-tie
  draw, which source takes before the hook. The hook draws nothing, so the
  order is unobservable (the design's own note).

## Known limits and follow-ups

- Protect is not represented: P1 adds the protected text on the hit path
  (lost focus takes precedence, already true).
- Not represented: Truant (hook), Substitute (the record goes to the
  substitute), the AI flee setting `HITMARKER_RUN` (roamers, Safari;
  review F8), `AI_CV_FocusPunch`.
- Multi-hit records only the last hit's `gHpDealt` in source; the engine's
  flag is true for any nonzero hit. Every multi-hit hit deals at least 1
  until Endure (P3), so this is unobservable today; P3 should revisit it.
- Seeded replays containing a Focus Punch user hit earlier in the turn
  diverge from that use (design Risk R3); none exists in the repository.
- ROM fixture pending for move 264.

## Review (2026-10-20)

[Implementation review](../reviews/2026-10-20-protection-p4-p5-implementation-review.md):
PASS WITH CORRECTIONS. F1 applied (comments no longer claim FaintClearSetData
clears the damage record). F4: the multi-hit last-hit deviation can only be
exposed by Focus Band (not modeled), not by P3 Endure.
