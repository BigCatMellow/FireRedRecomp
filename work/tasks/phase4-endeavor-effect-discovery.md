# Task: Phase 4 Endeavor effect discovery

- Status: `CLOSED — REVIEWED PASS`
- Type: `PHASE 4 / BATTLE RULES / READ-ONLY DISCOVERY`

## Goal

Source-lock FireRed `EFFECT_ENDEAVOR` (189), enumerate its verified-ROM record,
and decide whether it is a self-contained bounded implementation leaf. Do not
implement it in this task.

## Evidence and conclusion

The supported FireRed US v1.0 ROM has one effect-189 record: Endeavor #283
(`effect=189`, stored power `1`, Normal type `0`, accuracy `100`, PP `5`,
target `0`, priority `0`, flags `51`).

`EFFECT_ENDEAVOR` is defined in `include/constants/battle_move_effects.h:193`
and routes to `BattleScript_EffectEndeavor` at
`data/battle_scripts_1.s:2474-2486`. Crucially, it runs cancellation,
announcement, PP reduction, then `setdamagetohealthdifference` before accuracy:
it fails immediately when target HP <= attacker HP; otherwise it stores
targetHP-attackerHP, runs ordinary accuracy, typecalc/no-effect, clears only
nonzero effectiveness presentation, and applies that stored amount through the
set-damage path. `Cmd_setdamagetohealthdifference` is exact at
`src/battle_script_commands.c:8973-8984`.

This is an eligible bounded leaf: both battlers already expose current HP, and
the engine has cancellation/PP/accuracy/type/no-effect/shared HP-faint paths.
A later branch must preserve the source order: viability failure occurs after
PP but before accuracy (zero accuracy RNG); an otherwise viable move consumes
ordinary accuracy RNG; immunity occurs after that roll and causes no HP loss.
It must not run ordinary critical/base/random damage, add generic formula
support, Protect or Substitute handling, held-item/endure/ability/status state,
doubles/links, or Phase 4 completion. Endeavor is Protect-affected through its
ordinary `Cmd_accuracycheck` path, while `adjustsetdamage` has Substitute,
Focus Band, and Endure branches; all are explicitly excluded because this
engine lacks those state families, so no Focus Band RNG is modeled. It requires
its own route, review, probe, Worker request, and canonical review.

## MUST NOT CHANGE

Battle behavior, admission policy, UI, AI, trainer layouts, held items,
abilities, main wiring, generated data, bridge configuration, Phase 2's
external-reference blocker, or Phase 4 completion status.

## Review

Independent source-boundary review passed. The next gate is one separate,
literal, fail-closed Worker-route plan; no configuration or implementation is
authorized by this discovery closure.
