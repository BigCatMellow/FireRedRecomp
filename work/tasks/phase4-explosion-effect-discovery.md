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
