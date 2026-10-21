# Task: variable-power slice V2 — Fury Cutter

- Task ID: `P4-VARIABLE-POWER-V2`
- Status: `DONE — independently reviewed PASS WITH CORRECTIONS (applied)`
- Lane: full relay (new cross-turn battle state: a per-battler counter)
- Spec: [variable-power design proposal](../reports/phase4-variable-power-design-proposal.md)
  (§6 "Fury Cutter", "V2: Fury Cutter", verification plan V2), status
  `independently reviewed PASS WITH CORRECTIONS (applied)`, with the
  [design review](../reviews/2026-10-21-variable-power-design-review.md)
  folded in: F5 (every item action resets the counter; only capture is
  represented), F9 (the end-of-turn sleep cancel and the rampage
  `WasUnableToUseMove` cancel also reset it), D3 (V2 is its own package,
  before V3).
- Base: `53e08cd` (V1) on `claude/wizardly-faraday-o45q9z`.

## Source lock (pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`)

Abbreviations: `bsc.c` `src/battle_script_commands.c`, `bs1.s`
`data/battle_scripts_1.s`, `bm.c` `src/battle_main.c`, `bu.c`
`src/battle_util.c`, `moves.h` `src/data/battle_moves.h`.

- **Script** `BattleScript_EffectFuryCutter` (`bs1.s:1627-1639`):
  attackcanceler, attackstring, ppreduce, `accuracycheck
  BattleScript_FuryCutterHit` (hit and miss share the label),
  `furycuttercalc`, critcalc, damagecalc, typecalc, `jumpifmovehadnoeffect
  BattleScript_FuryCutterHit` (back to the calc, before
  adjustnormaldamage), adjustnormaldamage, `HitFromAtkAnimation`.
- **`Cmd_furycuttercalc`** (`bsc.c:8205-8226`): `NO_EFFECT` → counter 0,
  `BattleScript_MoveMissedPause`; otherwise `if (counter != 5) counter++`,
  `gDynamicBasePower` = record power doubled `counter - 1` times.
- **Counter** `gDisableStructs[].furyCutterCounter` (`include/battle.h:155`).
  Its only writers at the pin:
  1. `furycuttercalc` (above);
  2. `CancelMultiTurnMoves` (`bu.c:203-214`, `:213`), whatever the
     battler's lock state. Represented callers: recharge (`bu.c:1354`),
     flinch (`:1366`), full paralysis (`bs1.s:3717`), confusion self-hit
     (`bs1.s:3742`), sleep/freeze applied (`bsc.c:2173`, `:2269`), the
     attackcanceler protect step for **any** protected move
     (`bsc.c:896-906`), the end-of-turn sleep cancel (`bm.c:2941-2942`,
     needs `MULTIPLETURNS`) and the rampage `WasUnableToUseMove` cancel
     (`bu.c:958`) (F9);
  3. `ClearFuryCutterDestinyBondGrudge` (`bu.c:3041-3046`), called by
     `HandleAction_UseItem` before its item branch (`bm.c:4150-4157`, F5)
     and by the failed-run branch of `HandleAction_Run` (`bm.c:4309-4311`);
  4. the `gDisableStructs` clears at switch-in (`bm.c:2382-2384`) and faint
     (`bm.c:2457-2459`), for that battler only.
- So **using a different move does not reset the counter**, and it
  survives the target's faint and replacement.
- **Record** (`moves.h:2733-2744`): effect 119, power 10, Bug, accuracy 95,
  PP 20, chance 0, `MOVE_TARGET_SELECTED`, priority 0, flags
  `FLAG_MAKES_CONTACT | FLAG_PROTECT_AFFECTED | FLAG_MIRROR_MOVE_AFFECTED |
  FLAG_KINGS_ROCK_AFFECTED` = 0x33.
- **AI**: no `AI_CheckBadMove` row; the AI reads the record power 10
  (`battle_ai_script_commands.c:981-982`). No AI change.

## Design (as implemented)

- `BattleEngine.EFFECT_FURY_CUTTER = 119`; `makeBattler` field
  `furyCutterCounter = 0` (battle-only, never persisted).
- `resolveMoveCore`, on the ordinary accuracy-then-PP path (the engine
  spends PP after the accuracy result; the net effect matches source, where
  ppreduce comes first):
  - **not hit** (an accuracy miss, a protected target, a semi-invulnerable
    target): counter 0 at the top of the miss block, then the existing
    "missed" or protected event. 1, 0 and 0 draws.
  - **hit**: `if counter ~= 5 then counter = counter + 1 end`; a local copy
    whose power is the record power doubled `counter - 1` times; then the
    ordinary crit, damage, typecalc, random and hit. The shared record keeps
    power 10.
  - **no-effect after typecalc**: counter 0 and **no random draw** (the
    script's `jumpifmovehadnoeffect` precedes adjustnormaldamage), then the
    existing `noEffect` event. Unreachable with the real type chart (Bug has
    no 0x row; Wonder Guard is unrepresented); tested with a synthetic row.
- `cancelMultiTurnMoves` clears the counter, so every existing caller resets
  it (the list above), even when no lock is held (the end-of-turn sleep caller only runs for a locked battler).
- `recordFaint` clears it. A switch-in (voluntary or forced) installs a fresh
  battler, so its counter starts at 0; the other battler's counter is kept.
- `runTurn`: the capture action clears the player's counter before the throw
  (F5); the failed-run branch clears it before the foe's move. A successful
  run (Run Away included) ends the battle without it.
- Header slice list and the `cancelMultiTurnMoves` comment updated (a new
  caller must keep the reset).

### Limits

- Unrepresented `CancelMultiTurnMoves` callers (Truant, Disable, Taunt,
  Imprison, infatuation, Torment, Uproar, Yawn, Spite) and the other item
  actions (bag items, Poké Doll/Fluffy Tail, Poké Flute, trainer items) do
  not exist in the engine yet; each must reset the counter when it lands.
- Baton Pass (not represented) also zeroes the counter with the rest of the
  disable struct.
- The tracked plain-hit `seteffectwithchance` zero-chance gap applies to the
  hit, as for every ordinary hit.

## File ownership

- **MAY CHANGE:** `src/core/BattleEngine.lua`;
  `tests/battle_variable_power_v2_test.lua` (new);
  `tests/phase4_variable_power_v2_effect_rom_test.lua` (new);
  `tests/phase4_move_effect_inventory_test.lua` (row 119 and the counts);
  `work/reports/phase4-move-effect-inventory.md` (rows 119 and 117 notes,
  the counts); this task file.
- **MUST NOT CHANGE:** `main.lua`, party/Dex code, `BattlePartyBridge.lua`,
  the Pokémon factories, coordination and roadmap files,
  `AICheckBadMove.lua`, `BattleSceneController.lua` (no new event or text).

## RNG change and changed assertions

- **RNG:** none for a hit (accuracy, crit, random as before) or a miss. The
  changed power changes damage and KO timing, so seeded replays with
  repeated Fury Cutter diverge from the second hit. A no-effect hit would
  lose its random draw (unreachable with the real chart).
- **Changed assertions** (inventory only, the intended flip):
  `tests/phase4_move_effect_inventory_test.lua` row 119
  `blocked_on_state` → `represented`; `admitted_uncovered_positive` 23 → 22;
  represented 128/276/192 → 129/277/193; blocked 69/77/23 → 68/76/22.
  Admission stays 299/55. No other existing assertion changes; no existing
  test used move 210 or effect 119, and the added `cancelMultiTurnMoves`
  line touches only the new field.
- Inventory report: row 119 → `R`; row 117's note no longer names Fury
  Cutter; the class table, the uncovered list (22 records in 19 effects) and
  the admission note.

## Acceptance

- `tests/battle_variable_power_v2_test.lua`: 80 checks, exact `scriptedRng`
  draw counts.
  - Defaults 0. Seven consecutive hits: damage 3, 4, 6, 11, 21, 21, 21,
    counter 1-5 then 5, 3 draws each, 7 PP; the record keeps power 10; the
    foe's counter is separate; a crit at 20 power gives 8.
  - Resets on: an accuracy miss (1 draw, "missed", PP spent, next hit back to
    10); a protected target (0 draws, the protected text, PP spent); Fly and
    Dig targets (0 draws, "missed", PP spent); a no-effect hit (synthetic
    Bug → Water 0x row: 2 draws, no random, `noEffect`).
  - A Tackle between two Fury Cutters keeps the counter (20 on the second);
    a missed Tackle keeps it; a **protected Tackle resets it** (next Fury
    Cutter at 10).
  - Cancellers: flinch (0 draws), full paralysis (1 draw), confusion
    self-hit, recharge, sleep applied by Hypnosis, freeze applied; controls:
    a paralysed or confused battler that acts keeps counting (80 power, 11
    damage); a missed Hypnosis keeps it.
  - F5/run: a failed capture resets the player's counter (1 draw in the
    turn) and leaves the foe's (which keeps doubling); a failed run resets it
    (1 draw).
  - Faint resets; a voluntary switch-in starts at 0 while the foe's counter
    keeps doubling (40 power, 6); the counter survives the target's faint and
    forced replacement (next hit at 40).
  - F9: the end-of-turn sleep cancel resets a locked sleeper's counter and
    keeps an unlocked sleeper's; the rampage `targetNotAffected` cancel
    resets it through real turns (Fury Cutter, Thrash turn 1 in 5 draws,
    Thrash into a Ghost in 4 draws, counter 0 and the lock cleared).
  - The foe's own counter; the controller text of an ordinary hit.
- `tests/phase4_variable_power_v2_effect_rom_test.lua`: the record and the
  one-member family against the verified ROM; skips without a ROM (ROM
  fixture pending).
- Mutation spot-checks (each applied to the working tree from a fresh
  scratchpad backup, then restored with `cp` and confirmed with `cmp`): cap
  6 fails 4; doubling `counter` times fails 16; no miss reset fails 4; no
  `cancelMultiTurnMoves` reset fails 10; no faint reset fails 1; no capture
  reset fails 1; no failed-run reset fails 1; the no-effect hit drawing the
  random fails 1; the no-effect hit keeping the counter fails 1; writing the
  power into the shared record fails (the run aborts); default 1 fails 31;
  resetting on a different move fails 4.
- `bash scripts/test_all.sh` and `lua5.1 scripts/check_repository.lua`
  pass; `main.lua` unchanged.

## Deviations from the design

- The design lists a no-effect reset as "unreachable today". It is
  implemented with the source's draw shape (crit drawn, random not) and
  tested through a synthetic type-chart row, so a future Wonder Guard or
  chart change inherits the right behavior.

## Review (2026-10-21)

[Implementation review](../reviews/2026-10-21-variable-power-v1-v2-implementation-review.md):
PASS WITH CORRECTIONS. F4 applied: the reset wording no longer says every
caller runs whether or not the battler is locked (the end-of-turn sleep
caller runs only for a locked battler).
