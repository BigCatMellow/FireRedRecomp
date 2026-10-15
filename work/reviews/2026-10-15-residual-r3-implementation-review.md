# Review: residual slice R3 implementation (commit `1dd2ec4`)

- Reviewed: commit `1dd2ec4` on `claude/wizardly-faraday-o45q9z`, "Residual R3: trapping moves, wrap end of turn, Rapid Spin wrap arm"
- Task: [phase4-residual-r3](../tasks/phase4-residual-r3.md)
- Design: [residual effects design proposal](../reports/phase4-residual-effects-design-proposal.md) (R3 section, `:778-801`; verification plan `:925-937`) and its [design review](2026-10-15-residual-effects-design-review.md)
- Source: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`. Abbreviations: `bsc.c` = `src/battle_script_commands.c`, `bs1.s` = `data/battle_scripts_1.s`, `bu.c` = `src/battle_util.c`, `bm.c` = `src/battle_main.c`, `msg.c` = `src/battle_message.c`, `ai.s` = `data/battle_ai_scripts.s`, `moves.h` = `src/data/battle_moves.h`
- Date: 2026-10-15

## Verdict: **PASS**

The behaviour matches the source on every point I checked. Mutation testing found no gap that is reachable in this engine. The findings below are three low-severity documentation and citation notes and three informational notes. None of them blocks the merge.

## What I verified

### 1. Trap application (`BattleEngine.lua:3230-3248`, no-effect list `:3053-3065`)

- **Order.** `BattleScript_EffectTrap` (`bs1.s:829-835`) jumps to `BattleScript_EffectHit`. In that script the HP update, `critmessage` and `resultmessage` all run before `seteffectwithchance`, and `tryfaintmon BS_TARGET` runs after it (`bs1.s:262-270`). The engine follows the same order: the trap block sits in the landed-hit tail after the damage and effectiveness events, and before the caller's faint check. A test pins "It's super effective!" before the vortex text, and the KO test checks the event order `damage,faint,battleEnd`.
- **The `% 100` draw.** `Cmd_seteffectwithchance` (`bsc.c:2774-2805`): byte 13 has no `CERTAIN` bit, so `Random() % 100` is the first operand of the `&&` chain. It is drawn on a landed hit and on a no-effect hit. A miss jumps to `PrintMoveMissed` earlier, so nothing is drawn. The engine draws it in both places: `EFFECT_TRAP` was added to the discarded-roll list in the no-effect branch.
- **KO'd target.** `SetMoveEffect`'s 0-HP guard (`bsc.c:2140-2143`) runs before the switch on the effect byte, so the `% 100` is drawn and `& 3` is not. The engine checks `defender.hp > 0` after the roll. The test sees four draws.
- **Already-wrapped target.** The `MOVE_EFFECT_WRAP` case (`bsc.c:2483-2487`) only advances the script pointer: no draw, no text, and `wrappedMove`/`wrappedBy` stay as they were. The engine checks `wrapTurns == 0`. The test sees four draws and confirms the original counter and `WRAP` are kept when Fire Spin hits.
- **Immune target.** Bind/Wrap against a Ghost and Sand Tomb against a Flying type each take four draws and set nothing.
- **Semi-invulnerable target.** Every trap move misses an air, underground or underwater target with no draw, except Whirlpool against an underwater target. For that case `bs1.s:830-833` sets `HITMARKER_IGNORE_UNDERWATER`, which `AccuracyCalcHelper` reads at `bsc.c:984` and clears at `:991`, and `sDMG_MULTIPLIER 2`. The engine follows this through `semiInvulnerableMiss` (`:1841`) and the ×2 arm (`:3003-3006`), which mirrors Surf. The accuracy roll is still drawn, and the test checks that Whirlpool can still miss on it.
- **Turn count.** `STATUS2_WRAPPED_TURN((Random() & 3) + 3)` gives 3-6. The engine's `next16() % 4 + 3` is equivalent for non-negative 16-bit values. The test covers draws 0, 1, 2, 3, 4, 7, 0xFFFE and 0xFFFF.
- **Decrement and release.** `ENDTURN_WRAP` (`bu.c:872-903`) decrements first. If the counter is still nonzero, the battler takes a damage tick; if it has reached 0, the release text prints. The engine does the same, so a counter of N gives N−1 damage ticks and then the release turn. Tests: counter 3 gives two ticks of 25 and a release on turn 3; counter 6 gives five ticks and a release on turn 6.
- **Per-move texts.** These match `gWrappedStringIds` (`msg.c:1042-1050`) indexed by `gTrappingMoves` (`:1263-1271`), with the strings at `:143-147`. Clamp names the attacker first (`{B_ATK} CLAMPED\n{B_DEF}!`). Fire Spin and Whirlpool share the vortex text. Unlisted moves fall back to Sand Tomb because the lookup loop stops at `NUM_TRAPPING_MOVES - 1` (`bsc.c:2499-2505`). DEF is the wrapped battler and ATK the user. The foe-side Bind and Clamp texts are tested with the names swapped.

### 2. End of turn (`BattleEngine.lua:4071-4088`)

- **Position.** The wrap block runs after Curse and before the rampage tick. Uproar sits between them in the source (`bu.c:904`), but it is not modeled, so the order is right. As in the source, the battler's own `hp != 0` is tested and the wrapper's HP is not.
- **Damage tick.** Damage is `max(1, floor(maxHP/16))`, capped at current HP. The event is emitted text first, then HP (`BattleScript_WrapTurnDmg`, `bs1.s:3769-3773`), and then `tickTeamCheck`, which models `DoTurnDmg`'s `tryfaintmon` and `checkteamslost` (`bs1.s:3681-3688`). A fatal tick ends the battle. When both battlers are at 1 HP, the first one's fatal tick decides the battle.
- **Release.** "was freed from MOVE!" (`msg.c:149`, `bs1.s:3775-3778`), with no damage and no team check.
- **Tick texts.** "X is hurt\nby MOVE!" (`msg.c:148`); `B_ATK` is the ticking battler and `B_BUFF1` is `wrappedMove`.
- **The implementer's claim** (a wrap tick can never decide a pending Leech Seed KO in singles): **confirmed**. The Leech Seed drain calls `tryfaintmon BS_ATTACKER` and then `tryfaintmon BS_TARGET` at once (`bs1.s:3242-3243`). That reaches `BattleScript_FaintAttacker`/`FaintTarget`, then `cleareffectsonfaint` (`bs1.s:2805`, `:2814`), then `FaintClearSetData` (`bsc.c:2940`). That function zeroes the fainted battler's own `status2` (`bm.c:2441`) and the `WRAPPED` bits of every battler whose `wrappedBy` is the fainted slot (`bm.c:2450-2451`). In singles there are two cases:
  - The pending KO is the battler that is ticking. Its own wrap is cleared and its HP is 0.
  - The pending KO is the other battler. That battler is the only possible wrapper, so the wrap is cleared.

  Either way, no wrap tick or release can follow a pending KO. The engine does the same: `resolveStatusEndTurn` calls `recordFaint` for both sides right after the drain (`:4020-4024`), and `recordFaint` clears the battler's own wrap and then calls `clearHeldBy` (`:1356-1359`). The test "seed KO of the wrapper clears the wrap before the player's case" pins this. For the same reason, the release's lack of a team check cannot be observed (mutation M15 below).

### 3. Escape prevention and clearing

- `runBlocked` and `switchBlocked` include `wrapTurns > 0` (`:1389-1401`), matching `bm.c:3047` and `:3198`. Run Away bypasses the run block but not the switch block. The `runTurn` asserts and the controller vetoes ("Can't escape!" and "can't be switched\nout!") are exercised through the real engine with no turn and no draw.
- `clearHeldBy` zeroes the opponent's `wrapTurns`/`wrapMove` (`bm.c:2375-2376` on switch, `:2450-2451` on faint). The whole field is cleared, so no turns carry over. It is called from `recordFaint` and from the voluntary-switch branch (`:4199`). Tests cover:
  - the wrapper fainting mid-turn with a replacement;
  - the wrapper fainting at end of turn before the wrapped battler's case;
  - the wrapped battler's own faint;
  - the wrapper's voluntary switch, where the seed survives and a fresh Wrap re-rolls `& 3`.
- Every path that sets HP to 0 (Explosion, Memento, recoil, end-of-turn ticks) goes through `recordFaint` via `checkFaint` or an explicit faint sequence, so the wrapper cannot be at 0 HP with an uncleared wrap.

### 4. Rapid Spin (`:3250-3268`)

- **Order.** `Cmd_rapidspinfree` (`bsc.c:8435-8469`) is an else-if chain: the wrap first, then the seed, then Spikes (not modeled). One cleanup per use. The engine matches.
- **Text.** "X got free of\nY's MOVE!" (`msg.c:211`). ATK is the user and DEF is `wrappedBy`, which `gBattlerTarget` is set to at `bsc.c:8441`. In singles that is the opposing slot.
- **Draws and timing.** A landed hit draws nothing extra (CERTAIN). The free happens before `tryfaintmon BS_TARGET`, so on a KO the event order is `wrapFreed,faint`. Against a Ghost there is no effect: four draws and the wrap is kept. The seed is shed on the next use.

### 5. Texts

All of them were checked against `msg.c:143-149` and `:211`; see items 1, 2 and 4. `possessive` is a file-level local defined at `BattleSceneController.lua:39`, before `WRAPPED_TEXT`, so the closure resolves it correctly. `self.moveName` is the existing `gMoveNames` hook.

### 6. AI

`AI_CheckBadMove` (`ai.s:52` onward) has no `EFFECT_TRAP` or `EFFECT_RAPID_SPIN` row. `EFFECT_TRAP` appears only in `AI_CheckViability` (`ai.s:685`). The generic 0× rule (`ai.s:59`) gives −10 for Wrap against a Ghost, and that is tested. No `AICheckBadMove.lua` change is needed, and the commit has none. `main.lua`, `AICheckBadMove.lua`, `BattleFormulas.lua` and `TrainerAI.lua` are unchanged.

### 7. Inventory and ROM fixture

- **Inventory.** Six positive-power moves move from blocked to represented: represented goes from 124/267/183 to 125/273/189, blocked from 73/86/32 to 72/80/26, uncovered positive from 32 to 26, and the uncovered effects list drops effect 42 (24 to 23 effects). Admitted/rejected stay at 299/55 because effect 42 was already admitted. The report table matches the test.
- **ROM fixture** (`tests/phase4_residual_r3_effect_rom_test.lua`). All six records match `moves.h:263-274`, `:458-469`, `:1082-1093`, `:1667-1678`, `:3253-3264` and `:4267-4278`: effect, power, type, accuracy, PP, chance 100, target SELECTED, priority 0, and flags 0x33 for the contact moves (Bind, Wrap, Clamp) and 0x32 for the others. The test also asserts the family has exactly six members. It skips cleanly without a ROM.

### 8. RNG audit (spot check)

I confirmed that nothing in the pre-commit tree resolves an effect-42 move:
- No test, `scripts/runtime_*.sh` replay or `work/` probe names a trapping move id or an `EFFECT_TRAP` record.
- Only four ROM-mode tests start a trainer battle: `phase4_foe_only_multimon`, `phase4_two_sided_replacement_state`, `phase4_player_voluntary_switch` and `phase4_player_forced_replacement`. All four use Ben (trainer 89), whose Ekans would know Wrap. None of them resolves a turn with Ekans active: they force faints or resolve one turn against the lead Rattata.
- `phase4_fixed_damage_effect_rom_test` (trainer 204) resolves a Sonic Boom family move.

The claim holds.

### 9. Regressions

- `lua5.1 tests/battle_residual_r3_test.lua`: 155 passed, 0 failed.
- `bash scripts/test_all.sh`: PASS, 191 files in no-ROM mode. The R1 and R2 suites are included.
- `lua5.1 scripts/check_repository.lua`: PASS.

## Mutation testing

Each mutation was applied by exact-string replacement and the file restored afterwards. `git status` and `git diff` are clean, and `cmp` against the scratchpad backups matches. The R3 suite result is shown for every mutation; the starred rows were also run through the full `test_all.sh`, which failed for each of them.

| # | Mutation | R3 suite |
| --- | --- | --- |
| M1* | no landed `% 100` | 30 fail |
| M2* | trap removed from the no-effect roll list | 3 fail |
| M3 | no 0-HP guard | 2 fail |
| M4 | no already-wrapped guard | 2 fail |
| M5 | counter `+2` | 28 fail |
| M6 | counter `% 3` | 10 fail |
| M7 | `wrapMove` not stored | 11 fail |
| M8 | Whirlpool does not ignore underwater | error / fail |
| M9 | no Whirlpool ×2 | 3 fail |
| M10 | Whirlpool also hits air | 1 fail |
| M11 | one fewer damage tick (`> 1`) | 6 fail |
| M12 | tick `/8` | 10 fail |
| M13 | no minimum 1 | 1 fail |
| M14 | no tick team check | 2 fail |
| M15 | release runs the team check | **survives** (unobservable, see item 2 and F5) |
| M16 | release keeps `wrapMove` | 1 fail |
| M17* | `clearHeldBy` keeps the wrap | 6 fail |
| M18 | `recordFaint` keeps its own wrap | 1 fail |
| M19 | Rapid Spin clears wrap and seed | 2 fail |
| M20* | Rapid Spin has no wrap arm | 7 fail |
| M21 | `runBlocked` ignores the wrap | fail (assert) |
| M22* | `switchBlocked` ignores the wrap | 7 fail (plus 1 in R2) |
| M23 | `wrapped.by` wrong | 12 fail |
| M24 | tick ignores `hp > 0` | **survives** (unobservable, see F5) |
| C1 | Clamp name order swapped | 2 fail |
| C2 | Bind possessive dropped | 2 fail |
| C3 | fallback text Bind instead of Sand Tomb | **survives** (unreachable, see F4) |
| C4 | `wrapFreed` names swapped | 2 fail |
| C5 | tick text without its HP entry | 2 fail |
| C6 | Fire Spin given the Sand Tomb text | 2 fail |

Where the task file lists the same mutation, its counts match mine.

## Findings

1. **Low, documentation. A stale comment in the voluntary-switch branch** (`BattleEngine.lua:4196-4198`). It still reads "the foe loses the escape prevention the outgoing player held". Since R3, `clearHeldBy` also clears the foe's wrap there. Suggest "the escape prevention and the wrap". There is no behaviour impact.

2. **Low, documentation. A scope-list wording** (`BattleEngine.lua:315-316`). The edited phrase "multi-turn/charging moves (the trapping moves are residual R3 and the Mean Look/Ingrain escape lock residual R2)" sits in a list of unsupported features. A reader could take it to mean the trapping moves are still unsupported. The R3 bullet at `:346-350` is correct. Suggest "(the trapping moves came with residual R3, ...)" or dropping the parenthetical. There is no behaviour impact.

3. **Low, citation. The AI roaming reference** (test header `tests/battle_residual_r3_test.lua:34-36` and the task file's Source lock "AI" bullet). Both say EFFECT_TRAP appears in "the roaming script (`:3227`)". `ai.s:3227` is actually `if_status2 AI_USER, STATUS2_WRAPPED, AI_Roaming_End`, a status test in `AI_Roaming`, not an EFFECT_TRAP row. `ai.s:685` (`AI_CV_Trap`) is the only EFFECT_TRAP reference. The conclusion (no AICheckBadMove change) is unaffected. Suggest rewording to "`AI_Roaming` tests `STATUS2_WRAPPED` (`:3227`), out of scope".

4. **Informational. The Sand Tomb fallback is untested and unreachable** (`BattleSceneController.lua:637`, mutation C3). Every effect-42 move has its own entry in the table, so the `or WRAPPED_TEXT[328]` branch never runs. It does faithfully mirror the source's loop bound (`bsc.c:2499-2505`). No action needed.

5. **Informational. Two guards with no observable effect** (mutations M15 and M24).
   - The release's "no team check" (M15) cannot be observed in singles, by the argument in item 2.
   - The tick's `battler.hp > 0` test (M24) is redundant because `recordFaint` always zeroes a fainted battler's `wrapTurns`.

   Both are kept as faithful mirrors of the source, and the task file's Deviations section records the first. No action needed.

6. **Informational, not new in R3. Absorbing and immunity abilities are not modeled.** Levitate is not modeled anywhere in the engine (the header says "Abilities only where named"). In the source, Sand Tomb against a Levitate holder is a miss/no-effect result: it draws the `% 100` and does not wrap (`Cmd_typecalc` sets `MISSED | DOESNT_AFFECT_FOE`). The engine would instead hit and wrap. The same gap affects every Ground move, and the same kind of gap applies to Water Absorb or Flash Fire against Whirlpool, Clamp or Fire Spin. It belongs to the existing ability backlog, not to R3.

## Corrections required

None. Findings 1-3 are optional cleanups that can go into the next slice's housekeeping.
