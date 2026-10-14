# Task: ability stat and accuracy terms

- Task ID: `P4-ABILITY-TERMS`
- Status: `IMPLEMENTED — awaiting independent review`
- Lane: full relay (shared damage/accuracy formulas). Owner delegation
  2026-10-14; formulas/engine only.
- Origin: [S3 review F1](../reviews/2026-10-14-status-s3-review.md)
  (Compound Eyes/Hustle accuracy). Guts and Marvel Scale became reachable
  with status slice S2, so their raw-stat terms are included; Huge Power,
  Pure Power, Thick Fat and Hustle's attack term share the same source block.

## Source lock (pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`)

- `src/pokemon.c:2437-2491` `CalculateBaseDamage`, before stat stages and
  in this order: Huge Power/Pure Power `attack *= 2`; (badges, hold items
  not represented); Thick Fat `spAttack /= 2` for Fire/Ice; Hustle
  `attack = 150 * attack / 100`; (Plus/Minus doubles-only); Guts
  `attack = 150 * attack / 100` when `status1`; Marvel Scale
  `defense = 150 * defense / 100` when `status1`.
- `src/battle_script_commands.c:1069-1074` `Cmd_accuracycheck`: after the
  stage ratio, Compound Eyes `calc * 130 / 100`; (Sand Veil needs weather);
  Hustle `calc * 80 / 100` for a physical-type move.
- `include/constants/abilities.h`: 14, 37, 47, 55, 62, 63, 74.

## MAY CHANGE

- `src/core/BattleFormulas.lua`: `abilityAdjustedStats`, its use in
  `calculateBaseDamage` (including the crit raw-stat branches),
  `accuracyCheck` optional `attackerAbility`/`moveType`.
- `src/core/BattleEngine.lua`: the four accuracy call sites pass the
  attacker's ability and move type.
- `tests/battle_status_engine_test.lua`: oracles; the Guts burn test now
  includes the status boost.

## Acceptance

Numeric oracles for each term and its condition; accuracy boundaries for
Compound Eyes and Hustle; engine passes the ability; full no-ROM suite and
repository checker pass.

## Evidence (Worker, 2026-10-14)

Status engine 164/0; full suite and repository checker in the PR.
