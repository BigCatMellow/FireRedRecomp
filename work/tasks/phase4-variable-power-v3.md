# Task: variable-power slice V3 — Rollout / Ice Ball and Defense Curl

- Task ID: `P4-VARIABLE-POWER-V3`
- Status: `DONE — independently reviewed PASS WITH CORRECTIONS (applied)`
- Lane: full relay (new cross-turn battle state: a fourth lock family and a
  battle-only status2 bit)
- Spec: [variable-power design proposal](../reports/phase4-variable-power-design-proposal.md)
  (§7 "Rollout / Ice Ball", §8 "Defense Curl", "V3: Rollout / Ice Ball (117)
  and Defense Curl (156)", verification plan V3), status
  `independently reviewed PASS WITH CORRECTIONS (applied)`, with the
  [design review](../reviews/2026-10-21-variable-power-design-review.md)
  folded in: F2 (Rollout vs Rampage PP: equal on a protected locked turn,
  different on an unprotected locked miss), F3 (one `rolloutLocked`
  capture after the protect step and before the hit branch; the fifth hit
  frees `lockedSlot`), F10 (Defense Curl at +6 prints "won't go higher!"),
  D3 (V3 is its own package, after V2's `cancelMultiTurnMoves` edit).
- Base: `49d0f45` (origin/main, after V1 `53e08cd`, V2 `0663e1d` and the
  V1/V2 review fold `1ff5ff3`).

## Source lock (pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`)

Abbreviations: `bsc.c` `src/battle_script_commands.c`, `bs1.s`
`data/battle_scripts_1.s`, `bm.c` `src/battle_main.c`, `bu.c`
`src/battle_util.c`, `moves.h` `src/data/battle_moves.h`, `cb.h`
`include/constants/battle.h`.

- **Script** `BattleScript_EffectRollout` (`bs1.s:1592-1602`):
  attackcanceler, attackstring, `jumpifstatus2 BS_ATTACKER,
  STATUS2_MULTIPLETURNS, BattleScript_RolloutCheckAccuracy` (skips
  ppreduce), ppreduce, `accuracycheck BattleScript_RolloutHit` (hit and miss
  share the label), typecalc2, `rolloutdamagecalculation`, then
  `BattleScript_HitFromCritCalc`.
- **`Cmd_rolloutdamagecalculation`** (`bsc.c:8161-8193`): `NO_EFFECT` (a
  miss, a protected or semi-invulnerable target, a typecalc2 immunity) →
  `CancelMultiTurnMoves(attacker)`, `BattleScript_MoveMissedPause`
  (`:8163-8167`). Otherwise the first hit (MULTIPLETURNS clear) sets
  `rolloutTimer = 5`, MULTIPLETURNS and `gLockedMoves` (`:8172-8178`);
  `--rolloutTimer`, and at 0 MULTIPLETURNS clears (`:8179-8182`); power =
  record power doubled `4 - timer` times (`:8184-8187`), doubled again under
  `STATUS2_DEFENSE_CURL` (`:8189-8190`).
- **Lock**: MULTIPLETURNS skips action selection (`bm.c:3125-3130`) and the
  0-PP check (`bsc.c:838-839`). Rollout is not in `IsTwoTurnsMove`
  (`bsc.c:7821-7832`), so the protect step (`bsc.c:896-906`) cancels a
  locked Rollout before `jumpifstatus2`; ppreduce then spends one PP while
  above 0 (`bsc.c:1147`).
- **Timer** `gDisableStructs[].rolloutTimer` (`include/battle.h:156`).
  Writers: `rolloutdamagecalculation`; `CancelMultiTurnMoves`
  (`bu.c:203-214`, `:212`) at every represented caller (recharge
  `bu.c:1354`, flinch `:1366`, full paralysis `bs1.s:3717`, confusion
  self-hit `bs1.s:3742`, sleep/freeze applied `bsc.c:2173`, `:2269`, the
  protect step, the end-of-turn sleep cancel `bm.c:2941-2942`); the
  disable-struct clears at switch-in (`bm.c:2382-2384`) and faint
  (`:2457-2459`).
- **Defense Curl** `BattleScript_EffectDefenseCurl` (`bs1.s:2010-2021`):
  attackcanceler, attackstring, ppreduce, `setdefensecurlbit`
  (`bsc.c:8472-8476`), `setstatchanger STAT_DEF, 1`, statbuffchange
  (StatUpDoAnim / StatUpPrintString). `STATUS2_DEFENSE_CURL` (`cb.h:130`) has
  no other reader than Rollout; status2 is cleared at faint (`bm.c:2441`)
  and switch-in (`:2367`).
- **Records**: Rollout `moves.h:2668-2679` (117, 30, Rock, 90, PP 20, chance
  0, selected, priority 0, flags 0x33); Ice Ball `:3916-3927` (the same,
  Ice); Defense Curl `:1446-1457` (156, 0, Normal, 0, PP 40, chance 0,
  `MOVE_TARGET_USER`, priority 0, `FLAG_SNATCH_AFFECTED` = 0x08).
- **AI**: Rollout/Ice Ball have no `AI_CheckBadMove` row; Defense Curl's
  `AI_CBM_DefenseUp` is already ported (`AICheckBadMove.lua:645`). No AI
  change.

## Design (as implemented)

- `BattleEngine.EFFECT_ROLLOUT = 117`, `EFFECT_DEFENSE_CURL = 156`;
  `makeBattler` fields `rolloutTimer = 0` and `defenseCurl = false`
  (battle-only, never persisted). For this family `rolloutTimer > 0` is
  MULTIPLETURNS.
- Lock plumbing: `rolloutTimer > 0` added to `isLocked`, to `lockedTurn`
  (`rollingOut`), to the post-canceller 0-PP bypass and to the end-of-turn
  sleep cancel. The controller's M1 auto-run reads `isLocked` and needs no
  change.
- `cancelMultiTurnMoves` clears `rolloutTimer` (and `lockedSlot` with its
  existing `not recharging` guard), so every existing caller cancels the
  lock.
- PP (F2/F3): `rolloutLocked = rolloutTimer > 0` is captured once, right
  after the protect step's `cancelMultiTurnMoves` and before the hit branch.
  The PP block spends one PP (guarded at 0) unless `rolloutLocked`.
- Not hit (an accuracy miss, a protected target, a semi-invulnerable
  target): `cancelMultiTurnMoves`, then the existing `miss` or `protected`
  event. A first-turn miss sets no lock.
- Hit: a pure typecalc2 query first; a no-effect result cancels and emits
  `noEffect` before any crit or random draw (unreachable with the real
  chart; tested with a synthetic row). Otherwise the first hit sets
  `rolloutTimer = 5` and `lockedSlot`; then `rolloutTimer - 1`, and at 0
  `lockedSlot = nil` (`not recharging` guard). A local copy's power is 30
  doubled `4 - timer` times, times 2 under `defenseCurl`; then the ordinary
  crit, damage, typecalc, random and hit. The shared record keeps power 30.
- Defense Curl: admitted in `supportsMove` (power 0, `MOVE_TARGET_USER`);
  `resolveMoveCore` gives it the effect-11 stat entry (DEF +1, self-target,
  no accuracycheck) and sets `defenseCurl = true` after PP, before the
  at-limit branch, so the bit is set at +6 too. `recordFaint` clears
  `rolloutTimer` and `defenseCurl`; a switch-in installs a fresh battler.
- Header slice list, the `cancelMultiTurnMoves` and `isLocked` comments
  updated.

### Limits

- Unrepresented `CancelMultiTurnMoves` callers (Truant, Disable, Taunt,
  Imprison, infatuation, Torment, Uproar, Yawn, Spite) do not exist yet;
  each must cancel the lock when it lands. `rolloutTimerStartValue` is not
  modeled (no reader in the represented engine).
- Snatch (Defense Curl is `FLAG_SNATCH_AFFECTED`) and Baton Pass are not
  represented.
- The tracked plain-hit `seteffectwithchance` zero-chance gap applies to
  every Rollout hit, as for every ordinary hit.

## File ownership

- **MAY CHANGE:** `src/core/BattleEngine.lua`;
  `tests/battle_variable_power_v3_test.lua` (new);
  `tests/phase4_variable_power_v3_effect_rom_test.lua` (new);
  `tests/phase4_move_effect_inventory_test.lua` (rows 117 and 156 and the
  counts); `work/reports/phase4-move-effect-inventory.md` (rows 117 and 156,
  the counts); this task file.
- **MUST NOT CHANGE:** `main.lua`, party/Dex code, `BattlePartyBridge.lua`,
  the Pokémon factories, coordination and roadmap files,
  `AICheckBadMove.lua`, `BattleSceneController.lua` (no new event or text).

## RNG change and changed assertions

- **RNG:** no new draws. A hit draws accuracy, crit and random; a miss 1; a
  protected or semi-invulnerable miss 0; a (synthetic) no-effect hit 1.
  Defense Curl draws nothing. A locked foe skips the AI choice for turns
  2-5 (as for M1), and the changed power changes damage and KO timing, so
  seeded replays with Rollout, Ice Ball or Defense Curl diverge.
- **Behavior change:** Defense Curl was rejected before; it is now admitted.
  Camper Liam's Geodude and Sandshrew (CHECK_BAD_MOVE) previously raised
  'unsupported move effect 156' when the AI chose it and now follow source
  (AI scoring and draws unchanged). Brock (aiFlags 7) is unchanged:
  `EarlyRivalAI.choose` still rejects effect 156 (and Onix's Bind remains
  blocked).
- **Changed assertions** (inventory only, the intended flip):
  rows 117 and 156 `blocked_on_state` → `represented` (156 admission false
  → true); admitted/rejected 299/55 → 300/54; `admitted_uncovered_positive`
  22 → 20; represented 129/277/193/84 → 131/280/195/85; blocked 68/76/22/54
  → 66/73/20/53. No other existing assertion changes.
- Inventory report: rows 117 and 156 → `R`; the class table, the uncovered
  list (20 records in 18 effects) and the admission note.

## Acceptance

- `tests/battle_variable_power_v3_test.lua`: 144 checks, exact `scriptedRng`
  draw counts.
  - Defaults and admission (Rollout, Ice Ball, Defense Curl; Defense Curl
    needs `MOVE_TARGET_USER`).
  - Five hits through `runTurn` for Rollout and Ice Ball: damage 5, 9, 16,
    30, 59 (power 30-480), timer 4..0, 3 draws a turn, PP 19 throughout,
    the lock overrides the chosen Tackle on turns 2-5 and is released after
    hit 5 (the next turn uses Tackle; a new sequence restarts at 30 and
    spends PP); the record keeps power 30.
  - Defense Curl: DEF +1, the bit, 0 draws, PP 39; curled hits 9, 16, 30,
    59, 117 (power 60-960); at +6 "won't go higher!" with the bit set (and
    the next hit at 60); the foe's bit does not double the player's Rollout.
  - Cancel paths on a locked turn: accuracy miss (1 draw, no PP, restarts at
    30); first-turn miss (PP, no lock); protected locked turn (0 draws, one
    PP, the protected text); protected locked at 0 PP (PP stays 0);
    protected first turn; Fly and Dig targets (0 draws, no PP, cancelled); a
    locked 0-PP slot still hits; a synthetic no-effect hit (1 draw).
  - Cancellers: flinch, full paralysis, confusion self-hit, recharge, sleep
    applied by Hypnosis, freeze applied; controls: a paralysed battler that
    acts keeps rolling, a missed Hypnosis keeps the lock, an existing freeze
    keeps it, an existing sleep keeps it through the canceller and the
    end-of-turn sleep cancel ends it; flinch clears the Fury Cutter counter
    and the lock together.
  - P1 interplay through `runTurn`; the lock survives the target's faint and
    forced replacement (hit 3 at 120); faint clears the timer and the bit; a
    switch-in starts clear while the foe keeps its curled lock.
  - Controller: a locked player gets no menu (five turns run, the unlocked
    foe's AI asked each turn); a locked foe runs no AI.
- `tests/phase4_variable_power_v3_effect_rom_test.lua`: the three records
  and the two families against the verified ROM; skips without a ROM (ROM
  fixture pending).
- Mutation spot-checks (each applied to the working tree from a scratchpad
  backup, then restored with `cp` and confirmed with `cmp`):
  `rolloutLocked` captured before the protect step fails 2; no miss cancel
  fails 4; doubling `5 - timer` times fails 26; no Defense Curl doubling
  fails 7; `isLocked` without the timer fails 15; no 0-PP bypass fails 2;
  no end-of-turn sleep cancel fails 1; no faint clear fails 1; no
  `cancelMultiTurnMoves` clear fails (the run aborts); no hit-5 release
  fails 2; no no-effect cancel fails 2; the bit not set at +6 fails 2;
  locked hits spending PP fails 16; no 0-PP guard fails 1.
- `bash scripts/test_all.sh` and `lua5.1 scripts/check_repository.lua`
  pass; `main.lua` unchanged.

## Deviations from the design

- The design calls the typecalc2 no-effect "unreachable in this engine". It
  is implemented with the source's draw shape (accuracy only: typecalc2 and
  the cancel precede `HitFromCritCalc`) and tested through a synthetic
  type-chart row, as V2 did for Fury Cutter.
- `tests/phase4_variable_power_v3_effect_rom_test.lua` was not named in the
  design; it mirrors V1/V2's ROM fixture.

## Review corrections applied (2026-10-28)

[Implementation review](../reviews/2026-10-28-variable-power-v3-implementation-review.md):
PASS WITH CORRECTIONS.

- F1: the curled five-hit loop runs for Rollout and Ice Ball (Ice Ball
  against a Normal foe), 9/16/30/59/117 each.
- F2: the behavior-change note now names Liam's Geodude and Sandshrew, and
  says Brock is unchanged.
- F3: the controller test asserts the menu returns (`ACTION`) after hit 5.
- F4: a lock cancelled earlier in the same turn (freeze, then thaw)
  restarts at 30 and spends PP; at 0 PP it reports no PP.
- F5 (design wording) belongs to the design proposal and is not applied
  here.
