# Task: residual slice R3 — trapping moves (Bind, Wrap, Fire Spin, Clamp, Whirlpool, Sand Tomb), Rapid Spin's wrap arm

- Task ID: `P4-RESIDUAL-R3`
- Status: `IMPLEMENTED — awaiting independent review`
- Lane: full relay (new cross-turn battle state, new RNG draws on an
  already-admitted family, an escape lock that reaches the controller
  through R2's queries)
- Spec: [residual effects design proposal](../reports/phase4-residual-effects-design-proposal.md)
  (R3 parts), status `independently reviewed PASS WITH CORRECTIONS
  (applied)`, with the [design review](../reviews/2026-10-15-residual-effects-design-review.md)
  folded in: F1/F2 (the tick team check and the phase stop), decision D1
  (Rapid Spin's wrap arm in R3) and D6 (Whirlpool vs Dive, pinned with a
  test).
- Base: `ffc2f3d` on `claude/wizardly-faraday-o45q9z` (origin/main, R1 and
  R2 merged).

## Source lock (pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`)

Abbreviations: `bsc.c` `src/battle_script_commands.c`, `bs1.s`
`data/battle_scripts_1.s`, `bu.c` `src/battle_util.c`, `bm.c`
`src/battle_main.c`, `msg.c` `src/battle_message.c`, `ai.s`
`data/battle_ai_scripts.s`, `moves.h` `src/data/battle_moves.h`.

- **Records** (`moves.h`; effect 42, chance 100, SELECTED, priority 0):
  Bind 20 `:263-274` (15, Normal, acc 75, PP 20, flags 0x33); Wrap 35
  `:458-469` (15, Normal, 85, 20, 0x33); Fire Spin 83 `:1082-1093` (15,
  Fire, 70, 15, 0x32); Clamp 128 `:1667-1678` (35, Water, 75, 10, 0x33);
  Whirlpool 250 `:3253-3264` (15, Water, 70, 15, 0x32); Sand Tomb 328
  `:4267-4278` (15, Ground, 70, 15, 0x32).
- **Script** `bs1.s:829-835`: Whirlpool against an `UNDERWATER` target only
  (`jumpifnotmove MOVE_WHIRLPOOL`, `jumpifnostatus3 BS_TARGET`):
  `orword HITMARKER_IGNORE_UNDERWATER`, `setbyte sDMG_MULTIPLIER, 2`. Then
  `setmoveeffect MOVE_EFFECT_WRAP` and `BattleScript_EffectHit`
  (`bs1.s:239-270`): accuracycheck, attackstring, ppreduce, critcalc,
  damagecalc, typecalc, adjustnormaldamage, the HP update, critmessage,
  resultmessage, **seteffectwithchance**, tryfaintmon BS_TARGET.
- **`Cmd_seteffectwithchance`** `bsc.c:2774-2805`: byte 13 is not
  `CERTAIN`, so `Random() % 100 <= percentChance` is the first `&&`
  operand: drawn on a landed hit **and** on a no-effect hit (immune
  target); a miss jumped to `BattleScript_PrintMoveMissed` earlier, no
  draw. Chance 100 → `SetMoveEffect(FALSE, MOVE_EFFECT_CERTAIN)`.
- **`SetMoveEffect`** `bsc.c:2132-2146`: Shield Dust only for bytes ≤ 9,
  Safeguard only for ≤ 7 (neither covers 13); **a target at 0 HP returns
  silently** (no further draw); Substitute (not modeled).
- **Wrap case** `bsc.c:2483-2506`: already `STATUS2_WRAPPED` → nothing (no
  draw, no text, `wrappedMove`/`wrappedBy` unchanged). Otherwise
  `STATUS2_WRAPPED_TURN((Random() & 3) + 3)` (3-6), `wrappedMove`,
  `wrappedBy = gBattlerAttacker`, then `BattleScript_MoveEffectWrap`
  (`bs1.s:3888-3891`) prints `gWrappedStringIds[i]` where `i` is the
  move's index in `gTrappingMoves` (`msg.c:1263-1271`); the search loop
  stops at index `NUM_TRAPPING_MOVES - 1` (`bsc.c:2499-2505`).
- **Texts** `msg.c:143-149`, table `:1042-1050`:
  Bind "{DEF} was squeezed by\n{ATK}'s BIND!"; Wrap "{DEF} was WRAPPED
  by\n{ATK}!"; Fire Spin and Whirlpool "{DEF} was trapped\nin the vortex!";
  Clamp "{ATK} CLAMPED\n{DEF}!"; Sand Tomb "{DEF} was trapped\nby SAND
  TOMB!"; tick "{ATK} is hurt\nby {BUFF1}!" (`:148`); release "{ATK} was
  freed\nfrom {BUFF1}!" (`:149`); Rapid Spin "{ATK} got free of\n{DEF}'s
  {BUFF1}!" (`:211`). `B_BUFF1` = `wrappedMove`'s name.
- **End of turn** `ENDTURN_WRAP` `bu.c:872-903`, the 10th per-battler case
  (`bu.c:720-742`: after Curse, before Uproar and Thrash): WRAPPED and own
  `hp != 0` → decrement; still WRAPPED → `max(1, maxHP/16)` via
  `BattleScript_WrapTurnDmg` (`bs1.s:3769-3773`: text, then `DoTurnDmg`
  `:3681-3688`: HP, tryfaintmon, **checkteamslost**); reached 0 →
  `BattleScript_WrapEnds` (`:3775-3778`): text only, no damage, no team
  check. The wrapper's HP is not tested. No semi-invulnerability test.
- **Clearing**: `SwitchInClearSetData` `bm.c:2371-2377` and
  `FaintClearSetData` `bm.c:2449-2451` clear the whole `STATUS2_WRAPPED`
  field of every battler whose `wrappedBy` is the leaving slot.
  `FaintClearSetData` runs inside `tryfaintmon` (`BattleScript_FaintAttacker`
  `bs1.s:2801-2808` → `cleareffectsonfaint` → `bsc.c:2930-2938`).
- **Escape**: `IsRunningFromBattleImpossible` `bm.c:3047-3052`
  (`ESCAPE_PREVENTION | WRAPPED`), switch selection `bm.c:3198`. Already
  in R2's `runBlocked`/`switchBlocked` (`wrapTurns > 0`).
- **Rapid Spin** `Cmd_rapidspinfree` `bsc.c:8435-8469`: else-if chain —
  WRAPPED → clear, `gBattlerTarget = wrappedBy`, `BattleScript_WrapFree`
  (`bs1.s:3445-3449`); else LEECHSEED (R1); else Spikes (not modeled).
- **AI** `ai.s`: `AI_CheckBadMove` (`:52` onward) has **no** EFFECT_TRAP or
  EFFECT_RAPID_SPIN row; EFFECT_TRAP appears only in `AI_CheckViability`
  (`AI_CV_Trap`, `:685`) and the roaming script (`:3227`), both out of
  scope. The generic 0x-effectiveness −10 (`:59`) already applies. **No
  `AICheckBadMove.lua` change.**

## Verified questions

| Question | Answer (source) |
| --- | --- |
| When is the trap applied relative to damage, KO and semi-invulnerability? | After the HP update and the result (effectiveness) text, before `tryfaintmon BS_TARGET`. A KO'd target is skipped by `SetMoveEffect`'s 0-HP guard after the `% 100` draw (no `& 3`). A semi-invulnerable target makes `accuracycheck` miss with no draw at all, except Whirlpool vs `UNDERWATER`, which hits (one accuracy draw, ×2). |
| Trap on an already-wrapped target? | Ignored: the `% 100` is drawn, then no re-roll, no text, `wrappedMove`/`wrappedBy` kept (`bsc.c:2484-2487`). |
| Turn count when the wrapper switches out? | The whole `STATUS2_WRAPPED` field is cleared (`bm.c:2375-2376`); nothing carries over, and a later trap rolls a fresh 3-6. Same on the wrapper's faint (`:2450-2451`). |
| Wrap texts? | Table above; index by `gTrappingMoves`; Fire Spin and Whirlpool share the vortex text; Clamp names the user first. |

## Design (as implemented)

- `BattleEngine` constants `EFFECT_TRAP` (42), `MOVE_WHIRLPOOL` (250).
  `makeBattler` fields `wrapTurns` (0) and `wrapMove` (nil), battle-only.
  The wrapper is implicitly the opposing slot (singles).
- Landed-hit tail (after the damage, before the caller's faint check):
  `secondaryEffectRoll(rng, 100)`; then, if `defender.hp > 0` and
  `wrapTurns == 0`: `wrapTurns = (rng:next16() % 4) + 3`, `wrapMove =
  moveId`, `wrapped{side=defender, by=attacker, move}`.
- No-effect branch: `EFFECT_TRAP` joins the discarded-roll list.
- `semiInvulnerableMiss`: underwater misses unless Surf **or Whirlpool**.
  dmgMultiplier chain: `underwater and moveId == 250 → ×2` (D6).
- `resolveStatusEndTurn`, after Curse and before the rampage tick: if
  `hp > 0` and `wrapTurns > 0`, decrement; still > 0 → `wrapDamage{side,
  move, amount, hpRemaining}` (`max(1, floor(maxHP/16))`, clamped) then
  the tick team check (F1 `break`); 0 → `wrapEnded{side, move}`, clear
  `wrapMove`, no team check.
- `clearHeldBy(side)` also zeroes the opponent's `wrapTurns`/`wrapMove`;
  `recordFaint` zeroes the fainted battler's own.
- Rapid Spin: the wrap arm comes first (`if wrapTurns > 0 … elseif
  seeded …`): clear and emit `wrapFreed{side, by=otherSide, move}`.
- Controller texts: `wrapped` (per-move table, unknown moves fall back to
  the Sand Tomb text like the source loop), `wrapDamage` (text, then HP),
  `wrapEnded`, `wrapFreed`. Header event list and notes updated.
- RUN/PARTY vetoes: unchanged (R2's queries already read `wrapTurns`).

## File ownership

- **MAY CHANGE:** `src/core/BattleEngine.lua`;
  `src/core/BattleSceneController.lua` (texts only);
  `tests/battle_residual_r3_test.lua` (new),
  `tests/phase4_residual_r3_effect_rom_test.lua` (new),
  `tests/phase4_move_effect_inventory_test.lua`;
  `work/reports/phase4-move-effect-inventory.md`, this task file.
- **MUST NOT CHANGE:** `main.lua`, party/Dex code, coordination and roadmap
  files, `BattleFormulas.lua`, `TrainerAI.lua`, `AICheckBadMove.lua` (the
  source has no row to add).

## RNG change and changed assertions

- Every trap hit that lands or has no effect now draws `% 100`; a landed
  hit on a living, unwrapped target also draws `& 3`. Before R3, effect 42
  ran as a plain hit and skipped both (design Risk R4).
- **Audit of existing assertions:** an instrumented run of the whole no-ROM
  suite (a temporary probe at `resolveMoveCore`'s `useMove`, reverted with
  `git checkout`) showed **no existing test resolves an effect-42 move**;
  no test, `scripts/runtime_*.sh` replay or `work/` probe names a trapping
  move or a trapping species' battle (the ROM-mode battle tests use Route 1
  Rattata and the starters). **No existing assertion's draw count changes.**
- Changed assertions: `tests/phase4_move_effect_inventory_test.lua` only —
  row 42 `blocked_on_state` → `represented` (note: ROM fixture pending,
  `phase4_residual_r3_effect_rom_test`); row 129 note; totals
  `admitted_uncovered_positive` 32 → 26; represented 124/267/183/84 →
  125/273/189/84; blocked 73/86/32/54 → 72/80/26/54. Admitted/rejected stay
  299/55 (effect 42 was already admitted). Reason: R3 coverage.

## Acceptance

- `tests/battle_residual_r3_test.lua`: 155 checks, exact `scriptedRng` draw
  counts:
  - Admission, constants, defaults.
  - Each of the six moves: `useMove,damage,wrapped`, five draws, damage
    (3, Clamp 6), counter `(k & 3) + 3`, `wrapMove`, event fields, PP, the
    per-move text; the `& 3` mapping for 0/1/2/3/4/7/0xFFFE/0xFFFF; the
    foe's Bind/Clamp texts with names swapped; the effectiveness text
    precedes the wrapped text.
  - Immune target (Bind/Wrap vs Ghost, Sand Tomb vs Flying): four draws,
    nothing set. Miss: one draw. Accuracy boundary. KO on the trap hit: four
    draws, no `wrapped`, `faint,battleEnd`. Already wrapped: four draws, no
    text, counter and move kept.
  - Semi-invulnerable: Wrap/Clamp/Sand Tomb/Whirlpool vs air/underground/
    underwater miss with 0 draws, except Whirlpool vs underwater: hits for
    6 (×2 of 3), five draws, wrapped; it can still miss on its roll; the
    real Dive charge turn followed by Whirlpool for 6; a Fly user still
    ticks.
  - End of turn: counter 3 → two ticks of 25 then the release, exact HP and
    texts ("FOE is hurt\nby WRAP!" then HP; "FOE was freed\nfrom WRAP!");
    counter 6 → five ticks, release on turn 6; minimum 1 at maxHP 15; the
    tick names the move.
  - Order: Ingrain < Leech Seed < poison < Curse < Wrap < rampage tick with
    exact HP; the asleep variant with Nightmare; a fatal wrap tick ends the
    battle; a seed KO of the wrapper clears the wrap before the wrapped
    battler's case; per-battler order (the player's wrap tick before the
    foe's seed drain); both at 1 HP → the first battler's fatal tick decides.
  - Escape: the foe's Wrap blocks run and switch through the damage turns,
    frees after the release; the `runTurn` asserts with no state change;
    Run Away runs (no draw) but cannot switch; a wrapped foe never blocks
    the player; controller through the real engine: the wrap texts, wild RUN
    → "Can't escape!" (no turn, no RNG, `runTries` 0), PARTY pick →
    "PIKACHU can't be switched\nout!".
  - Clearing: the wrapper's mid-turn faint (with a replacement), its
    end-of-turn faint before the wrapped player's case, the wrapped
    player's own faint, the wrapper's voluntary switch (seed kept; the new
    battler's Wrap re-rolls `& 3`).
  - Rapid Spin: frees the wrap only (seed kept), three draws, "PLAYER got
    free of\nFOE's WRAP!"; the next use sheds the seed; on a KO before the
    faint; vs Ghost the wrap stays (four draws); the foe's text.
  - AI: all six trap moves score 0 against a wrapped target, Rapid Spin 0
    for a wrapped user, Wrap vs Ghost the generic −10.
- `tests/phase4_residual_r3_effect_rom_test.lua`: exact 6-member family
  records; skips without a ROM (ROM fixture pending).
- Mutation spot-checks (each applied to the working tree, then restored
  with `git checkout` plus the scratchpad copy, `cmp` clean): no landed
  `% 100` fails 30; trap missing from the no-effect list fails 3; no 0-HP
  guard fails 2; no already-wrapped guard fails 2; counter `+2` fails 28;
  `wrapMove` not stored fails 11; Whirlpool not ignoring underwater errors;
  no Whirlpool ×2 fails 3; no wrap-tick team check fails 2; tick `/8`
  fails 10; damage on the release turn fails 6; `clearHeldBy` keeping the
  wrap fails 6; `recordFaint` keeping its own wrap fails 1; no Rapid Spin
  wrap arm fails 7; Rapid Spin clearing both fails 2; Clamp text order
  fails 2; no tick text fails 4; `wrapFreed` names swapped fails 2; wrap
  before Curse fails 3.
- `bash scripts/test_all.sh` (191 files) and `lua5.1
  scripts/check_repository.lua` pass; `main.lua` unchanged.

## Deviations from the design

- None in behaviour. One observation recorded for the reviewer: the design
  (and review F1/F2) lists wrap damage among the ticks whose team check can
  decide a pending Leech Seed KO. In singles that combination is
  unreachable: the only possible wrapper is the other battler, and a seed
  KO of it runs `FaintClearSetData` at once (inside `tryfaintmon`), so the
  wrapped battler's case finds no wrap. The engine does the same
  (`recordFaint` → `clearHeldBy`), and the test pins that instead. The
  tick still runs the tick team check for its own fatal tick. Likewise the
  release's "no team check" is unobservable in singles.

## Known limits and follow-ups

- Not represented: Substitute (blocks the trap, clears the user's
  `WRAPPED`, `bsc.c:7460`), Baton Pass (drops `WRAPPED`), Shed Skin etc.,
  Serene Grace (irrelevant at chance 100), the foe's run/switch (no foe run
  or switch is modeled; the foe's counter is tracked and gates nothing).
- The `runBattle()` replay driver in `main.lua` makes no progress against a
  trapped player (design Risk R5); no current route encounter traps.
- Seeded replays that contain a trap move diverge from its first use
  (design Risk R4); none exists in the repository.
- ROM fixture pending for the six records.
