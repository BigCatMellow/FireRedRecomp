# Task: primary status conditions, slice S2 (status on hit)

- Task ID: `P4-STATUS-S2`
- Status: `IMPLEMENTED — awaiting independent review`; ROM fixture pending
- Lane: full relay (applies saved status in ordinary play). Owner delegation
  2026-10-14; battle files only, away from in-flight Codex work.
- Builds on: [S1](phase4-status-s1-groundwork.md); design
  [proposal](../reports/phase4-status-conditions-design-proposal.md) §4.
- Families: 2 Poison Hit (4), 4 Burn Hit (5), 5 Freeze Hit (4), 6 Paralyze
  Hit (8), 202 Poison Fang (1), 209 Poison Tail (1): 23 moves.

## Source lock (pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`)

- Scripts `data/battle_scripts_1.s:321-374` (setmoveeffect + Hit), `:2632`
  (Poison Fang, MOVE_EFFECT_TOXIC), table `:233` (Poison Tail uses the Poison
  Hit script). Applied texts `:3848-3881`.
- `src/battle_script_commands.c:2774-2804` `Cmd_seteffectwithchance`: the
  `Random() % 100 <= chance` roll is drawn whenever the byte is not CERTAIN
  (also on a no-effect hit); chance ≥ 100 calls SetMoveEffect with CERTAIN.
- `:2110-2370` `SetMoveEffect`: Shield Dust blocks secondary status
  (`:2132-2134`, no certain exemption); 0 HP (`:2140`); Immunity / Water Veil
  / Limber print their prevention text only when primary or certain, else
  break; type immunities and existing status break silently; Magma Armor
  breaks after type/status. Sun, Safeguard and Substitute are not represented.
- `:1184-1188` `Cmd_critcalc`: Poison Tail +1 stage.
- Texts `src/battle_message.c:83,88,92,94,98,104,270,272,280`; ability names
  `src/data/text/abilities.h`.
- Records `src/data/battle_moves.h` (23 members, in the ROM fixture).

## MAY CHANGE

- `src/core/BattleEngine.lua`: `STATUS_HIT_MOVES`, ability constants,
  `applySecondaryStatus`, Poison Tail crit stage, no-effect roll, events.
- `src/core/BattleSceneController.lua`: applied/prevented texts.
- `src/core/WildPokemonFactory.lua`: capture masks the toxic counter.
- Tests: `tests/battle_status_engine_test.lua`, controller, wild factory,
  updated `tests/battle_engine_test.lua` scripted draws (Ember now takes its
  real burn roll), inventory partition, new
  `tests/phase4_status_hit_effect_rom_test.lua`.
- `work/reports/phase4-move-effect-inventory.md`: six rows to R, totals.

No main.lua, save format or admission change.

## Acceptance

1. Roll boundaries (chance, chance+1), one draw on hit, no-effect and KO.
2. Each kind applies with its text; Fire/Ice/Poison/Steel immunities;
   Electric paralyzable; existing status unchanged.
3. Abilities: Shield Dust (also vs certain), silent Immunity/Water Veil/
   Limber when not certain, Limber text with Zap Cannon, Magma Armor silent.
4. Poison Fang badly poisons; Poison Tail crit stage 1.
5. Frozen target hit by Ember: no burn, then defrost; newly statused target
   ticks at end of turn.
6. Capture masks the toxic counter. Full no-ROM suite and checker pass.

## Known effects on existing behavior

- Ember and the other 22 moves now draw their seteffectwithchance roll
  (previously the positive-power fallback skipped it, the tracked plain-hit
  RNG gap). Seeded ROM replays using these moves need the guarded ROM run.

## Follow-ups

- AICheckBadMove status assumptions (S1 review F4) now that the player can
  be statused by the foe.
- Poison Fang vs a healthy Poison/Steel target sets
  `MOVE_RESULT_DOESNT_AFFECT_FOE` after damage in source; no visible effect
  modeled.

## Evidence (Worker, 2026-10-14)

Status engine 109/0; controller 127/0; wild factory 29/0; battle engine
568/0; full suite and repository checker in the PR.
