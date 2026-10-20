# Task: protection slice P4 — Fake Out (effect 158)

- Task ID: `P4-PROTECTION-P4`
- Status: `DONE — independently reviewed PASS WITH CORRECTIONS (applied)`
- Lane: full relay (new per-battler cross-turn state, an RNG change on an
  already-admitted move, a new AI row)
- Spec: [protection design proposal](../reports/phase4-protection-design-proposal.md)
  (P4 parts, decision D6), status `independently reviewed PASS WITH
  CORRECTIONS (applied)`, with the [design review](../reviews/2026-10-15-protection-design-review.md)
  folded in. No P4-specific finding; D3 (P4 first) and D6 (2/1/0 counter,
  decrement as the last end-of-turn step, `resolveForcedSwitch` = 1) apply.
- Base: `d9e1ec2` on `claude/wizardly-faraday-o45q9z` (origin/main plus the
  proposal, its review and the folded corrections).

## Source lock (pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`)

Abbreviations: `bsc.c` `src/battle_script_commands.c`, `bs1.s`
`data/battle_scripts_1.s`, `bm.c` `src/battle_main.c`, `msg.c`
`src/battle_message.c`, `ai.s` `data/battle_ai_scripts.s`, `aisc.c`
`src/battle_ai_script_commands.c`, `moves.h` `src/data/battle_moves.h`.

- **Record** `moves.h:3279-3290`: Fake Out 252, effect 158, power 40,
  Normal, accuracy 100, PP 10, chance 0, `MOVE_TARGET_SELECTED`, **priority
  +1**, flags `PROTECT_AFFECTED | MIRROR_MOVE_AFFECTED` (0x12).
- **Script** `bs1.s:2044-2048`: `attackcanceler`, `jumpifnotfirstturn
  BattleScript_ButItFailedAtkStringPpReduce`, `setmoveeffect
  MOVE_EFFECT_FLINCH | MOVE_EFFECT_CERTAIN`, `goto BattleScript_EffectHit`.
  The fail path (`:2050-2059`): `attackstring`, `ppreduce`, pause, `orbyte
  FAILED`, `resultmessage` → "But it failed!". No RNG (it precedes
  `accuracycheck`).
- **`Cmd_jumpifnotfirstturn`** `bsc.c:6504-6512`: passes iff
  `gDisableStructs[attacker].isFirstTurn != 0`.
- **`Cmd_seteffectwithchance`** `bsc.c:2774-2805`: `CERTAIN && !NO_EFFECT`
  → `SetMoveEffect(FALSE, CERTAIN)` with **no draw**; a no-effect hit (Ghost)
  falls to the else-if, whose `Random() % 100` is evaluated first → **one
  discarded draw**.
- **`SetMoveEffect`** `bsc.c:2132-2146`: Shield Dust (byte 8 ≤ 9, not
  primary) returns silently; a target at 0 HP returns; Substitute (not
  modeled). Flinch case `:2419-2439`: Inner Focus with `certain` →
  `BattleScript_FlinchPrevention` (`bs1.s:4109-4113`):
  "{B_EFF_NAME_WITH_PREFIX}'s {B_EFF_ABILITY}\nprevents flinching!"
  (`msg.c:296`), tested **before** the turn order; otherwise the bit is set
  only when `GetBattlerTurnOrderNum(target) > gCurrentTurnActionNumber`.
- **`isFirstTurn`** (`include/battle.h:164`): `= 2` at battle start,
  switch-in and faint (`bm.c:2228`, `:2396`, `:2481`); `--` if nonzero in
  every `TurnValuesCleanUp(FALSE)` (`bm.c:3640-3641`): once in
  `TryDoEventsBeforeFirstTurn` (`:2909`) and once at the end of every turn,
  after `HandleFaintedMonActions` (`:2964-2970`).
- **AI** `AI_CBM_FakeOut` (`ai.s:187`, `:510-513`): `is_first_turn_for
  AI_USER; if_equal 0, Score_Minus10`. `Cmd_is_first_turn_for`
  (`aisc.c:1778-1790`) returns the raw value. Fake Out's power is 40, so the
  step 1-2 typecalc −10 against a Ghost comes first.

## Design (as implemented)

- `BattleEngine.EFFECT_FAKE_OUT = 158`. `makeBattler` field `isFirstTurn =
  2` (battle-only, never persisted).
- `BattleEngine.new` sets both leads to 1. `runTurn`'s switch branch sets
  the incoming battler to 2. `resolveForcedSwitch` sets the replacement to 1
  (the engine runs its end of turn before the replacement arrives).
  `recordFaint` sets 2. The **last statement of `resolveEndTurn`**
  decrements both battlers' nonzero counters (D6).
- `resolveMoveCore`, right after `useMove`: effect 158 with `isFirstTurn ==
  0` → spend PP (guarded), `moveFailed`, return. No RNG.
- Landed-hit tail: `applySecondaryStatus2(defender, "flinch", events,
  certain = true)`. `applySecondaryStatus2` gains the `certain` parameter:
  Shield Dust and 0 HP stay silent; Inner Focus emits `flinchPrevented{side,
  ability = 39}` only when `certain`; otherwise the existing
  `flinchTargetPending` rule. No draw.
- No-effect branch: effect 158 joins the discarded-roll list.
- Priority +1 is already read from the record by `getWhoStrikesFirst`.
- `AICheckBadMove.lua`: **only** the Fake Out row and handler. `fakeOut`
  returns −10 when `user.isFirstTurn == 0`, else 0; the `[158]` dispatch row
  is added; the `UNPORTED_EFFECTS[158]` entry and the Fake Out sentence of
  the header's "REAL GAPS" paragraph are removed. The Memento/Explosion/
  Roar/Baton Pass/Attract text and entries are untouched (another agent
  owns the Memento code).
- Controller: `flinchPrevented` → "<target>'s INNER FOCUS\nprevents
  flinching!". Header event list updated.

## File ownership

- **MAY CHANGE:** `src/core/BattleEngine.lua`;
  `src/core/BattleSceneController.lua` (texts only);
  `src/core/AICheckBadMove.lua` (the Fake Out row and handler only);
  `tests/battle_protection_p4_test.lua` (new),
  `tests/phase4_protection_p4_effect_rom_test.lua` (new),
  `tests/phase4_move_effect_inventory_test.lua`;
  `work/reports/phase4-move-effect-inventory.md`, this task file.
- **MUST NOT CHANGE:** `main.lua`, party/Dex code, coordination and roadmap
  files, the Memento code in `AICheckBadMove.lua`.

## RNG change and changed assertions

- A Fake Out against a Ghost now takes the discarded `% 100` (one more
  draw). A Fake Out after the user's first turn now fails with no draws
  (before P4 it was a plain hit: accuracy, crit and random). A landed first
  Fake Out draws the same three as before.
- **Audit of existing assertions:** no existing test, `scripts/runtime_*.sh`
  replay or `work/` probe resolves move 252 (grep for `252`/`FAKE_OUT` over
  `tests/` and `scripts/` finds only the inventory row). `isFirstTurn` is a
  new field that no existing code reads, and the end-of-turn decrement draws
  nothing. **No existing assertion's draw count changes.**
- Changed assertions: `tests/phase4_move_effect_inventory_test.lua` only —
  row 158 `blocked_on_state` → `represented` (ROM fixture pending,
  `phase4_protection_p4_effect_rom_test`); `admitted_uncovered_positive`
  26 → 25; represented 125/273/189/84 → 126/274/190/84; blocked
  72/80/26/54 → 71/79/25/54. Admitted/rejected stay 299/55. Reason: P4
  coverage.

## Acceptance

- `tests/battle_protection_p4_test.lua`: 54 checks, exact `scriptedRng`
  draw counts:
  - Admission, the constant, `makeBattler` 2, leads 1.
  - Turn 1: `useMove,damage,flinched`, 3 draws, 6 damage, PP 10 → 9, the
    foe's PP kept, both counters 0 after the end of turn, the texts. Turn 2
    and 3: `useMove,moveFailed`, 0 draws for Fake Out, PP spent, "But it
    failed!".
  - Priority: a much faster foe still moves second (no speed-tie draw).
  - Flinch only for a target that has not acted: Fake Out vs a faster Fake
    Out (the player flinches, its PP kept); Fake Out moving second after a
    faster Quick Attack (no flinch, 6 draws).
  - Shield Dust silent (6 draws); Inner Focus `flinchPrevented` (ability
    39, 6 draws, the text), also when Fake Out moves second; a non-certain
    flinch against Inner Focus stays silent.
  - Ghost: `noEffect`, 4 draws, PP spent. KO: no flinch, no Inner Focus
    text, 3 draws.
  - Voluntary switch-in on turn N (a reused table at 0 is reset to 2): 1
    after N, Fake Out works on N+1, fails on N+2. Forced replacement after
    turn N (player and foe sides): starts at 1, works on N+1, fails on N+2.
    `recordFaint` sets 2.
  - AI: 0 on the first turn (no error), −10 after it, −10 against a Ghost
    from the type check, raw 2 → 0.
- `tests/phase4_protection_p4_effect_rom_test.lua`: the exact 1-member
  family record; skips without a ROM (ROM fixture pending).
- Mutation spot-checks (each applied to the working tree, then restored from
  a scratchpad copy, `cmp` clean): no discarded Ghost draw fails 1; leads not
  set to 1 fails 8; forced replacement not 1 fails 2; `certain` not passed
  fails (error); no end-of-turn decrement fails 12; switch-in not reset to
  2 fails 2; `recordFaint` not 2 fails 2; the fail path spending no PP
  fails 1; no flinch tail fails (error); Inner Focus tested after the turn
  order fails 1.
- `bash scripts/test_all.sh` and `lua5.1 scripts/check_repository.lua`
  pass; `main.lua` unchanged.

## Deviations from the design

- None in behaviour. The switch branch sets the incoming battler to 2
  explicitly (the design said "keeps 2"), so a caller that passes a reused
  battler table still gets `SwitchInClearSetData`'s value.

## Known limits and follow-ups

- Protect is not represented: a protected target's "protected itself!" on
  both Fake Out paths arrives with P1.
- Not represented: Substitute (SetMoveEffect's guard), Speed Boost's `!= 2`
  test, the `AI_CV_FakeOut` CheckViability row.
- Seeded replays containing a Fake Out against a Ghost, or a Fake Out after
  the user's first turn, diverge from that use (design Risk R3); none exists
  in the repository.
- ROM fixture pending for move 252.

## Review (2026-10-20)

[Implementation review](../reviews/2026-10-20-protection-p4-p5-implementation-review.md):
PASS WITH CORRECTIONS. F2 applied: a direct check pins the turn-order flinch
gate (the post-turn field check could not fail). F3/F5/F6 informational.
