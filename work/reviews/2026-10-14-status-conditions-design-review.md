# Review: Phase 4 primary status conditions, design proposal and discovery

- Reviewer: independent Reviewer (Claude), read-only on source
- Date: 2026-10-14
- Artifacts: `work/reports/phase4-status-conditions-design-proposal.md` and its basis
  `work/reports/phase4-status-conditions-discovery.md`
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`. Files read:
  `include/constants/battle.h`, `include/constants/battle_string_ids.h`,
  `src/battle_util.c`, `src/battle_main.c`, `src/battle_script_commands.c` (bsc),
  `data/battle_scripts_1.s` (bs1), `src/battle_message.c` (bm),
  `src/pokemon.c`, `src/field_poison.c`, `src/field_control_avatar.c` (fca),
  `src/battle_controller_player.c`, `src/battle_controller_opponent.c`.
  Fetched at the pin; local copies in `/tmp/claude-0/status/` match these line numbers.
- Project code read: `src/core/BattleEngine.lua`, `BattleFormulas.lua`,
  `BattlePartyBridge.lua`, `CaptureRules.lua`, `main.lua` (battle persistence call sites).
- Verdict: **PASS WITH CORRECTIONS**. The core mechanics claims are source-correct.
  Neither document has a blocker. Two Major gaps must be corrected before S1 is
  contracted: the toxic-counter `UNKNOWN` is now resolved and changes how S1 must
  persist status, and status-clear-on-faint is missing.

## Verified as claimed

| Claim | Source | Result |
|---|---|---|
| status1 layout: sleep bits 0-2, PSN 3, BRN 4, FRZ 5, PAR 6, TOX 7, counter 8-11 | `battle.h:90-101` | correct |
| Canceller order Sleep → Frozen → … → Confused → Paralysed → … → Thaw | `battle_util.c:1233-1250` enum | correct (see F5/F6 for precision) |
| Sleep: decrement first (Early Bird 2), still asleep → fails unless Snore/Sleep Talk; reaching 0 → "woke up" and **the move proceeds** | `battle_util.c:1266-1308`; `bs1.s:3663-3668` `BattleScript_MoveUsedWokeUp` ends in `return` after `BattleScriptPushCursor()` (`:1301`) | correct: a counter of 1 wakes and acts the same turn |
| Sleep duration `(Random() & 3) + 2` | bsc `:2356` (SetMoveEffect); also Yawn `battle_util.c:1041` | correct |
| Freeze `Random() % 5`, zero → thaw and act (20%) | `battle_util.c:1313-1331` | correct |
| Paralysis `Random() % 4 == 0` → fully paralyzed | `battle_util.c:1439-1449` | correct |
| Paralysis speed `/4` in GetWhoStrikesFirst | `battle_main.c:3449-3450`, `:3474-3475` | correct |
| Run odds use unmodified speed | `battle_main.c:4263` uses `gBattleMons[].speed`; project `BattleEngine.lua:2154-2158` passes raw `.speed` | correct |
| Burn halving after `/50`, before Reflect, no crit gate, Guts exempt | `pokemon.c:2537-2550` | correct |
| Defrost by Fire at MOVEEND_DEFROST | bsc `:4103-4116` | correct |
| End of turn order Poison → Bad poison → Burn, per battler in turn order; formulas | `battle_util.c:723-743`, `:805-841` | correct (see F7 for the toxic minimum) |
| Field before battler end-turn | `battle_main.c:2958-2964` | correct |
| Capture ×2 sleep/freeze, ×15/10 others, after the HP term | bsc `:9549-9556` | correct |
| Field poison: step counter mod 5 outside secret bases, −1 HP per poisoned mon, 0 HP faints, status cleared, all-fainted whiteout; no 1-HP survival | `fca.c:710-733`; `field_poison.c:32-39,53-82,92-119` | correct |
| Bridge round-trips `status` | `BattlePartyBridge.lua:149,171,188`; `SaveFileCodec.lua:405,420` stores the u32 | correct, no save-format change |
| "Status-free battles keep today's sequences" | all new draws are gated on a status bit | correct (refined in F8) |

## Findings

### F1 — Major — Toxic-counter `UNKNOWN` resolved: the counter is battle-local and never reaches the party copy

Evidence:
- `battle_util.c:817-830` (`ENDTURN_BAD_POISON`): `gBattleMons[...].status1 += STATUS1_TOXIC_TURN(1)` updates only the battle copy. It emits no `REQUEST_STATUS_BATTLE`. The damage script `bs1.s:3676-3687` only does `datahpupdate`.
- bsc `:2351-2364`: when Toxic is applied, `status1` was 0 (guard `:2332`), so the emitted value written to the party copy is `STATUS1_TOXIC_POISON` with counter 0.
- Switch-in reloads from the party: bsc `:4461` `EmitGetMonData(REQUEST_ALL_BATTLE)` leads to `battle_controller_player.c:1549` / `battle_controller_opponent.c:484`, `battleMon.status1 = GetMonData(..., MON_DATA_STATUS)`, and bsc `:4480-4481` copies it into `gBattleMons`.
- None of the other `REQUEST_STATUS_BATTLE` emitters (bsc `:2700,2937,4113,6184,6205,6498,8086,8735,9205`; `battle_util.c:917,1042,1536,1852,2163,2838,2989`) can write the status of a still-toxic battler with a nonzero counter. Each either requires another status, sets 0, or clears the poison bits.
- No code clears `STATUS1_TOXIC_COUNTER` explicitly on switch-out or at battle end. The reset happens only because the battle copy is never written back.

Consequence for the project: `main.lua:1564,1618,1674,1694` call `persistPartyBattler` every turn and on switch. `BattlePartyBridge.lua:188` copies `battler.status` wholesale. A naive S1 would therefore persist the incremented counter, and that counter would survive switch and battle end. That diverges from the source.

Correction (proposal, "Discovery UNKNOWNs resolved here", replace the Toxic bullet):
> - **Toxic counter on switch/after battle** (resolved): the counter is battle-local. `ENDTURN_BAD_POISON` (`battle_util.c:817-830`) increments only `gBattleMons[].status1` and emits nothing. The party copy keeps the value emitted when Toxic was applied, which is the TOX bit with counter 0 (`battle_script_commands.c:2351-2364`). Every switch-in reloads `status1` from the party (`battle_script_commands.c:4461,4480`; `battle_controller_player.c:1549`). So the counter restarts at 0 on each switch-in. After battle the Pokémon stays badly poisoned (bit 7) with counter 0. No explicit clear exists. The reset follows from the counter never being written back.

Correction (proposal §1 State, add a bullet):
> - `persistPartyBattler` must write `status` with the toxic counter bits cleared (`status & ~0x0F00`). That matches the source party copy. A switched-in battler built from the record then starts at counter 0. The in-battle counter lives only on the battler.

Correction (proposal Risks): delete "Toxic persistence stays blocked on its source lock". In the S1 row, replace "toxic-counter source lock" with "toxic counter battle-local (masked on persist)".

Correction (discovery, Outside battle table, Toxic row): replace `UNKNOWN — counter reset behavior not source-locked here` with `Counter is battle-local and never written to the party copy; it restarts at 0 on each switch-in and after battle (see proposal; battle_util.c:817-830, battle_script_commands.c:2363,4461).`

### F2 — Major — Status cleared on faint is missing

Evidence: bsc `:2930-2938` `Cmd_cleareffectsonfaint`: `gBattleMons[gActiveBattler].status1 = 0;` then `EmitSetMonData(REQUEST_STATUS_BATTLE, ...)`. That writes 0 to the party copy. Field faint does the same: `field_poison.c:32-39` sets `STATUS1_NONE`.

Consequence: the project persists `battler.status` every turn, including the forced-switch drain at `main.lua:1564` with the battler at 0 HP. Without the clear, a fainted Pokémon keeps its status in the save. That breaks parity with revive, the party screen, and field poison, where `field_poison.c:45,102` would treat a fainted poisoned Pokémon as still poisoned.

Correction (proposal §1 State, add):
> - On faint (`checkFaint` → `recordFaint`), clear `battler.status` to 0 as `Cmd_cleareffectsonfaint` does (`battle_script_commands.c:2930-2938`). The persisted record then carries status 0. This applies to faints from move damage, recoil and end-of-turn damage alike.

Correction (proposal Verification plan, add): "a faint while statused persists `status = 0`".

### F3 — Minor — End-of-turn sequencing rules S1 needs that are not stated

Evidence:
- `battle_main.c:2958-2964`: field and battler end-turn effects run only `if (gBattleOutcome == 0)`.
- `battle_util.c:1051-1057`: the loop returns after each executed effect. `BattleTurnPassed` is re-entered and re-tests `gBattleOutcome`.
- `bs1.s:3685-3686`: each status tick does `tryfaintmon` then `checkteamslost`. `checkteamslost` (bsc `:3385-3412`) sets the outcome once a whole party is at 0 HP.
- So once one battler's end-turn damage decides the battle, the remaining battlers' end-turn effects are skipped. If a faint only leaves a replacement pending (outcome still 0), the remaining battlers still tick, and the replacement comes later in `HandleFaintedMonActions` (`battle_main.c:2965`).
- `battle_util.c:723-743`: Ingrain, end-turn abilities, `ITEMS1` (Leftovers) and Leech Seed all precede Poison for the same battler. `ITEMS2` comes last.

Correction (proposal §5, append):
> Rules: (a) run the phase at every site where `decaySideTimers` runs, under the same `not isOver()` gate. Today those sites are `BattleEngine.lua:2101,2146,2176,2220,2226,2236`. (b) Battler order is the turn's action order. Hoisted switch, item and run actions come first, otherwise the `getWhoStrikesFirst` result. **[Superseded 2026-10-15 by weather slice W0 (`work/tasks/phase4-weather-w0.md`), per `2026-10-14-weather-design-review.md` D1: source recomputes the order at `ENDTURN_ORDER` (`battle_util.c:484-501`) with `GetWhoStrikesFirst(player, foe, FALSE)`: chosen-move priority (a non-move action is `MOVE_NONE`), current speed, and one `Random() & 1` on a tie.]** (c) Skip battlers at 0 HP. (d) After each faint call `checkFaint`. If that decides the battle, stop the phase. If it only queues a forced switch, continue with the remaining battlers, and the replacement is resolved after the phase. (e) Two forced switches can come out of one phase. (f) Future per-battler effects (Ingrain, Leftovers/`ITEMS1`, Leech Seed) precede Poison for the same battler, and `ITEMS2` follows Burn (`battle_util.c:723-743`).

### F4 — Minor — `battle_message.c` numbers are file line numbers, not string ids, and three texts are wrong or missing

Evidence: the cited numbers 83, 88, 92, 94, 98, 100, 101, 104, 106, 162, 163, 90, 96, 85, 91, 97 are **line numbers** in `src/battle_message.c` (for example `bm.c:83` is `sText_PkmnFellAsleep`). The STRINGID values are different (`battle_string_ids.h`: `STRINGID_PKMNFELLASLEEP 35`; id 83 is `STRINGID_PKMNSLEPTHEALTHY`).
- Canceller thaw prints `gGotDefrostedStringIds[B_MSG_DEFROSTED]` = `STRINGID_PKMNWASDEFROSTED2` (`bm.c:1106-1109`, `bs1.s:3701-3705`). That is `bm.c:102`, with the ATK name, not `bm.c:101`.
- `bm.c:101` `STRINGID_PKMNWASDEFROSTED` (DEF name) is the Fire-move defrost (`bs1.s:3707-3711`).
- Thaw-hit uses `STRINGID_PKMNWASDEFROSTEDBY` (`bm.c:103`).
- `bm.c:106` is "is paralyzed!\nIt can't move!" (`STRINGID_PKMNISPARALYZED`, `bs1.s:3714`), not a generic "can't move".
- "already paralyzed" (`bm.c:107`, `STRINGID_PKMNISALREADYPARALYZED` 58) is missing.

Correction (proposal §6, replace the list):
> New events with source texts (`src/battle_message.c` line : STRINGID): fell asleep (`:83` `PKMNFELLASLEEP`), was poisoned (`:88` `PKMNWASPOISONED`), badly poisoned (`:92` `PKMNBADLYPOISONED`), was burned (`:94` `PKMNWASBURNED`), was frozen solid (`:98` `PKMNWASFROZEN`), is paralyzed / may be unable to move (`:104` `PKMNWASPARALYZED`), is fast asleep (`:162` `PKMNFASTASLEEP`), woke up (`:163` `PKMNWOKEUP`), is frozen solid (`:100` `PKMNISFROZEN`), attacker defrosted by the canceller thaw (`:102` `PKMNWASDEFROSTED2`), target defrosted by a Fire move (`:101` `PKMNWASDEFROSTED`), defrosted by a thaw-hit move (`:103` `PKMNWASDEFROSTEDBY`, S4), fully paralyzed "is paralyzed! It can't move!" (`:106` `PKMNISPARALYZED`), hurt by poison (`:90` `PKMNHURTBYPOISON`), hurt by its burn (`:96` `PKMNHURTBYBURN`), and the "already" texts (`:85` `PKMNALREADYASLEEP`, `:91` `PKMNALREADYPOISONED`, `:97` `PKMNALREADYHASBURN`, `:107` `PKMNISALREADYPARALYZED`).

### F5 — Minor — Line-citation drift

Evidence: `CANCELLER_THAW` is `battle_util.c:1513-1525`, not `:1510-1522` (`:1510-1512` is the tail of `CANCELLER_BIDE`). The canceller enum is `:1233-1250`, with `CANCELLER_FLAGS` at `:1235`, not `:1236-1250`.

Correction (proposal §2 and discovery "Effects during a turn"): replace `:1510-1522` with `:1513-1525` and `:1236-1250` with `:1233-1250`.

### F6 — Minor — Canceller order and freeze-draw precision

Evidence: `battle_util.c:1233-1250`. Between `CANCELLER_FROZEN` and `CANCELLER_PARALYSED` come Truant, Recharge, Flinch, Disabled, Taunted, Imprisoned and Confused. After it come Ghost, In love, Bide and Thaw. For a frozen battler using an `EFFECT_THAW_HIT` move, `Random() % 5` is still drawn (`:1313`). On a nonzero result the code falls through (`:1321-1324`) and thaws at `CANCELLER_THAW`. Sleep, freeze and full paralysis all exit via `BattleScript_MoveEnd` (`bs1.s:3661,3699,3718`) before `attackstring`/`ppreduce`, so none of them prints "used" or costs PP.

Correction (proposal §2, replace the sentence after the list):
> These draws come before accuracy/crit/damage. When added, Truant, Recharge, Flinch, Disabled, Taunt, Imprison and Confusion sit between Freeze and Paralysis, and Ghost, Love, Bide and Thaw come after. A frozen battler using a thaw-hit move still consumes the `Random() % 5` draw. None of the three failures prints "used" or deducts PP.

### F7 — Minor — Toxic minimum-1 is applied before the multiplier

Evidence: `battle_util.c:819-824`: `damage = maxHP / 16; if (damage == 0) damage = 1;` then the counter increment, then `damage *= counter`.

Correction (proposal §5): replace "toxic `maxHP/16 × n` (n incremented first, cap 15) … each minimum 1" with "toxic `max(1, maxHP/16) × n` (n incremented first, capped at 15); poison and burn `max(1, maxHP/8)`". Apply the same wording in the discovery "End of turn" section.

### F8 — Minor — Paralysis speed position and RNG-risk wording

Evidence: `battle_main.c:3428-3452`. The order is stat stage, then badge `×110/100` (player, `FLAG_BADGE03_GET`), then Macho Brace `/2`, then paralysis `/4`, then Quick Claw. The tie draw `Random() & 1` (`:3510,3523`) is drawn only when the two final speeds are equal. Paralysis can therefore create or remove a tie and add or remove that draw. `BattleFormulas.effectiveSpeed` (`BattleFormulas.lua:499`) is used only by `getWhoStrikesFirst`, so either location works. Run must keep using raw `.speed`.

Correction (proposal Risks, replace the first bullet):
> - RNG ordering: new draws occur only when a status bit is set. These are the freeze `% 5` and paralysis `% 4` draws on each move attempt, the sleep-duration `& 3` on application, and the speed-tie `& 1`, which paralysis can add or remove. A battle in which no status is ever present keeps today's sequences. A party record loaded with a nonzero `status` (for example from an imported save) will change behavior once S1 lands. Today that field is ignored.

Correction (proposal §3, Paralysis bullet, append): "applied after stat stage, badge boost and Macho Brace, and before Quick Claw (`battle_main.c:3428-3452`)".

### F9 — Info — CaptureRules hook location

Evidence: the multiplier seam is `CaptureRules.calculateCatchValue`'s `modifiers` (`CaptureRules.lua:128-142`, documented at `:22-33`). The live path `CaptureRules.tryPokeBall` (`:210-217`) hard-codes `statusNumerator = 1, statusDenominator = 1`. `BattleEngine.lua:2120` calls `tryPokeBall`. Source applies the two tests separately (bsc `:9553-9556`). They are mutually exclusive under the one-status rule.

Correction (proposal §7 Capture, append): "S4 must change the call at `BattleEngine.lua:2120` (or `tryPokeBall`) to pass 2/1 for sleep or freeze and 15/10 for PSN/BRN/PAR/TOX. Today the seam is unreachable from the engine."

### F10 — Info — Sleep counter persistence and edge cases

Evidence: when the sleep canceller sets `effect = 2` (still asleep or woke), it emits `status1` (`battle_util.c:1533-1538`). The remaining sleep counter is therefore written to the party copy, survives switching and battle end, and is never reset on switch. With Snore or Sleep Talk the decrement happens without an emit (`effect` stays 0, `:1291-1296`). Rest sets `STATUS1_SLEEP_TURN(3)` (bsc `:6497`).

Correction (proposal §1 State, add): "Sleep turns persist as-is across switch and battle end (unlike the toxic counter)."

### F11 — Info — Defrost and field-poison details for later slices

Evidence: MOVEEND_DEFROST (bsc `:4104-4109`) requires target frozen, target HP ≠ 0, attacker ≠ target, `specialDmg` dealt, no `MOVE_RESULT_NO_EFFECT`, and `moveType == TYPE_FIRE`. `FaintFromFieldPoison` (`field_poison.c:36`) also applies `FRIENDSHIP_EVENT_FAINT_OUTSIDE_BATTLE`. A poisoned Pokémon already at 0 HP counts as fainted (`:105`).

Correction (proposal §3 Defrost): "…thaws it after damage if the target is still above 0 HP (`battle_script_commands.c:4104-4109`)". (§7 Field poison, append): "the faint also applies the outside-battle faint friendship event (`field_poison.c:36`)."

## Summary of required changes before S1 contracting

F1 and F2 are required. F3 to F8 are textual corrections to apply in the same edit. F9 to F11 are informational and can go into the S4/S5 task contracts.

## Disposition

Worker applied F1-F11 corrections to the proposal and the discovery report on
2026-10-14 (the toxic-counter and field-poison `UNKNOWN`s are now resolved in
both). F9-F11 also recorded in the proposal for the S4/S5 contracts.
