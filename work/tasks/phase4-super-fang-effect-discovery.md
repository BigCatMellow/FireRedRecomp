# Task: Phase 4 Super Fang effect discovery

- Status: `REVIEWED PASS`
- Type: `PHASE 4 / BATTLE RULES / READ-ONLY DISCOVERY`

## Goal

Source-lock FireRed `EFFECT_SUPER_FANG` (40) and decide whether its single
positive-power record is the next bounded formula leaf. Do not implement it.

## Evidence and conclusion

The FireRed effect constant is 40
(`include/constants/battle_move_effects.h:44`). The only record is Super Fang
#162: Normal, stored power 1, accuracy 90, PP 10, priority 0
(`src/data/battle_moves.h:2109-2121`). Its stock route is
`BattleScript_EffectSuperFang` (`data/battle_scripts_1.s:808-816`): ordinary
attack cancellation, accuracy, and PP precede `typecalc`; the script clears
super-effective/not-very-effective presentation, then sets damage to target
current HP divided by two, with a minimum of one, before the shared hit/faint
tail. `Cmd_damagetohalftargethp` is exact (`src/battle_script_commands.c:7190-
7198`): integer `target.hp / 2`, changed to 1 only when that result is zero.

This is a bounded candidate: it needs no persistent status, item, party,
weather, or switch state. It must preserve type immunity as no-effect, discard
nonzero effectiveness presentation, skip ordinary critical/base/random damage
commands, and use the shared HP/faint path. The current engine instead admits
effect 40 through its broad positive-power route and incorrectly performs the
ordinary formula/crit/random calculation. A later implementation must prove
even/odd/1-HP targets, immunity, miss/PP/RNG behavior, and parsed ROM record
#162 only. It must receive its own route plan, probe, Worker request, guarded
publication, and independent canonical-range review.

## MUST NOT CHANGE

No gameplay code, tests, bridge configuration, move admission policy, UI, AI,
items, trainer layouts, or other effect family. This discovery does not claim
Phase 4 completion.

## Review

Independent source review passed. The next gate is a separate fail-closed
Worker Bridge route plan; no implementation is authorized by this discovery.
