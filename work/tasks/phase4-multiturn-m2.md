# Task: locked multi-turn moves, slice M2 (semi-invulnerable)

- Task ID: `P4-MULTITURN-M2`
- Status: `DONE — independently reviewed PASS WITH CORRECTIONS (applied)`; ROM fixture pending
- Reviews: [design](../reviews/2026-10-14-multiturn-m2-design-review.md),
  [implementation](../reviews/2026-10-14-multiturn-m2-implementation-review.md)
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
Whirlpool (trap family blocked), double battles, Transform. Gust, Sky
Uppercut, Surf and the Fly/Dig/Dive turn-2 hit draw one fewer `Random()`
than source (the tracked plain-hit `seteffectwithchance` gap). Oak's
tutorial accuracy short-circuit runs before the semi check in source
(unreachable: no semi-invulnerable foe in the first battle).

## Evidence (Worker, 2026-10-14)

Multi-turn 64/0 at 396b34b. After the review corrections: multi-turn 83/0
(19 new checks: every accuracy site, OHKO/Pain Split failure, Earthquake/
Explosion no-effect texts, Hi Jump Kick crash, Bounce air, x2 per move);
mutations of each correction and multiplier are killed; full suite 171 PASS.

## Follow-up correction (2026-10-15): Jump Kick crash against a Ghost semi target

The M2 implementation review's F3 (applied above) had a Jump Kick / Hi Jump
Kick against a semi-invulnerable Ghost print "missed" and then crash **for
1 HP**. The independent [protection design review](../reviews/2026-10-15-protection-design-review.md)
(F2) found that source loses **no** HP there, and a trace of
`BattleScript_MoveMissedDoDamage` at the pin confirms it:

1. `AccuracyCalcHelper`'s semi-invulnerable miss sets only `MISSED`
   (`src/battle_script_commands.c:966-990`); no `CheckWonderGuardAndLevitate`,
   so the `DOESNT_AFFECT_FOE` test after `resultmessage`
   (`data/battle_scripts_1.s:858`) is false and "kept going and crashed!"
   prints (`:859`). This part of F3 was right.
2. `damagecalc` (`bsc.c:1209-1223`) does not touch `gMoveResultFlags`.
3. `typecalc` against a Ghost calls `ModulateDmgByType(TYPE_MUL_NO_EFFECT)`,
   which sets `MOVE_RESULT_DOESNT_AFFECT_FOE` and gives 0 damage
   (`bsc.c:1239-1250`, called from `:1312-1318`).
4. `adjustnormaldamage` takes its `Random()` before its zero test
   (`bsc.c:1558-1569`): one draw.
5. `manipulatedamage DMG_RECOIL_FROM_MISS` turns 0 into 1 (`bsc.c:6465-6470`).
6. `bicbyte gMoveResultFlags, MOVE_RESULT_MISSED` (`bs1.s:865`) clears only
   `MISSED`; `DOESNT_AFFECT_FOE` stays, and `MOVE_RESULT_NO_EFFECT` is
   `MISSED | DOESNT_AFFECT_FOE | FAILED` (`include/constants/battle.h:203`).
7. `healthbarupdate BS_ATTACKER` and `datahpupdate BS_ATTACKER` both run
   only when `!(gMoveResultFlags & MOVE_RESULT_NO_EFFECT)` (`bsc.c:1713`,
   `:1758`): **both are skipped**, so the 1 is never subtracted.
   `tryfaintmon BS_ATTACKER` finds the user alive.

Result: "X used HI JUMP KICK!", "X's attack missed!", "X kept going and
crashed!", **no HP change**, one random draw. The engine's semi-invulnerable
crash leaf (`BattleEngine.lua`, effect-45 miss branch) now sets the loss to 0
for an immune target and keeps the text and the draw; a non-immune digger is
unchanged. Changed assertion: `tests/battle_multiturn_test.lua` "Hi Jump Kick
vs a Ghost digger crashes for 1" → "crash text, no HP lost" (`crash.amount
== 0`, HP unchanged, 1 draw), plus a new exact non-immune check (crash for
12). Reachable only with Sableye or Shedinja digging or flying, as before.
