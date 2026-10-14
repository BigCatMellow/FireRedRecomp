# Task: locked multi-turn moves, slice M2 (semi-invulnerable)

- Task ID: `P4-MULTITURN-M2`
- Status: `IMPLEMENTED — awaiting independent review`; ROM fixture pending
- Lane: full relay. Owner delegation 2026-10-14 ("Keep going"); battle files.
- Builds on: [M1](phase4-multiturn-m1.md); design
  [proposal, M2 addendum](../reports/phase4-multiturn-design-proposal.md).
- Families (8 moves): 155 Fly/Dig/Dive/Bounce, 147 Earthquake, 149 Gust,
  152 Thunder, 207 Sky Uppercut; Twister, Magnitude and Surf gain their
  semi-invulnerable hits and doubles.

## Source lock (pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`)

See the M2 addendum: `data/battle_scripts_1.s:239-243,1822-1858,1888-1891,
1916-1919,1969-2008,2704-2706`; `src/battle_script_commands.c:958-1001,
1020-1028,8618-8634`; texts `src/battle_message.c:139-142`.

## MAY CHANGE

- `src/core/BattleEngine.lua`: `semiInvulnerable` state, kinds by move,
  `semiInvulnerableMiss`/`accuracyRoll` at every accuracy site, the
  short-circuit effects (ALWAYS_HIT, Vital Throw, OHKO, Pain Split), the x2
  multipliers, Bounce/Thunder paralysis, clearing (turn 2, cancel, faint).
- `src/core/BattleSceneController.lua`: four texts.
- Tests: multi-turn additions, inventory partition, new
  `tests/phase4_semi_invulnerable_effect_rom_test.lua`; report rows.

## Known limits

Weather (Thunder accuracy in rain/sun), Lock-On/Mind Reader, Protect,
Whirlpool (trap family blocked), double battles.

## Evidence (Worker, 2026-10-14)

Multi-turn 64/0; full suite and repository checker in the PR.
