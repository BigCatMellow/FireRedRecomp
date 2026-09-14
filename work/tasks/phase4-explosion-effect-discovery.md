# Task: Phase 4 Explosion effect discovery

- Status: `ACTIVE`
- Type: `PHASE 4 / BATTLE RULES / READ-ONLY DISCOVERY`

## Goal

Source-lock FireRed `EFFECT_EXPLOSION` (7): inventory every positive-power
record, trace exact attacker/target HP and faint ordering, and decide whether
the family is a self-contained bounded implementation leaf. Do not implement
the effect.

## Required evidence

1. Identify every positive-power effect-7 ROM record and relevant move fields.
2. Cite the stock effect id, script route, damage, self-KO, and faint ordering.
3. Map the source behavior to the current `BattleEngine` paths, including RNG,
   forced-switch interaction, and any missing state.
4. Classify implementation eligibility and update only coordination documents.

## MUST NOT CHANGE

No battle behavior, tests, bridge configuration, UI, AI, trainer layouts,
held items, move-admission policy, or other effect family. Discovery does not
authorize an implementation or Phase 4 completion claim.

## Evidence and conclusion

The preserved FireRed source checkout defines `EFFECT_EXPLOSION` as 7
(`include/constants/battle_move_effects.h:11`). Its two positive-power records
are Self-Destruct #120 (Normal, 200 power, 100 accuracy, PP 5, priority 0) and
Explosion #153 (Normal, 250 power, 100 accuracy, PP 5, priority 0)
(`include/constants/moves.h:124,157`; `src/data/battle_moves.h:1563-1573,
1992-2002`).

The effect routes to `BattleScript_EffectExplosion`
(`data/battle_scripts_1.s:31,376-412`). After cancellation/string/PP, the
script runs `tryexplosion`, which scans every battler for Damp; on success it
sets the attacker's HP to zero *before* accuracy (`Cmd_tryexplosion` and
`Cmd_setatkhptozero`, `src/battle_script_commands.c:6255-6321`). A miss still
reaches the final attacker `tryfaintmon`. On a hit, ordinary critical, type,
random-damage, and HP commands run, then `tryfaintmon BS_TARGET` runs before
`tryfaintmon BS_ATTACKER`. The normal damage formula also halves the defender's
pre-stage defense for effect 7 (`src/pokemon.c:2505-2507`).

The script's nonstandard sequence is material: each target loop executes
`critcalc`, `damagecalc`, `typecalc`, and `adjustnormaldamage` before
`accuracycheck` (`data/battle_scripts_1.s:388-397`). Therefore an Explosion
miss has already consumed the critical and random-damage draws before its
result message and final attacker faint. This is unlike the current engine,
which rolls accuracy before PP/critical/damage and returns immediately on a
miss (`src/core/BattleEngine.lua:841-859`); merely adding a self-KO after that
return cannot reproduce retail RNG or ordering.

The current engine has no ability state/Damp and deliberately documents
Explosion defense halving as unported (`src/core/BattleFormulas.lua:97-105`).
It also cannot express the stock order safely: `resolveMove` returns on a miss
without self-KO, and `runTurn`'s post-resolve faint path checks the defender
while a pending forced replacement can halt the turn before the source-required
attacker faint. Existing recoil code has the opposite attacker-before-target
ordering, so it cannot be reused. Effect 7 is not yet a self-contained
implementation leaf. It requires a focused self-KO/faint-resolution ordering
design covering an attacker already at zero HP, target-first faint events,
forced replacements, the no-ability/Damp boundary, and defense halving without
changing ordinary damage or the effect-7 accuracy-after-crit/random sequence.
