# Task: Phase 4 False Swipe effect discovery

- Status: `ACTIVE`
- Type: `PHASE 4 / BATTLE RULES / READ-ONLY DISCOVERY`

## Goal

Source-lock FireRed `EFFECT_FALSE_SWIPE` (101): enumerate its verified-ROM
record, trace its script and damage-floor semantics, and decide whether it is a
self-contained bounded implementation leaf. Do not implement the effect.

## Required evidence

1. Identify every positive-power effect-101 ROM record and relevant fields.
2. Cite the stock effect id, script route, and exact HP-floor/damage ordering.
3. Map the source behavior to the current `BattleEngine` HP application path,
including immunity, multi-hit, RNG, and already-fainted target constraints.
4. Classify the leaf as implementable, blocked, or requiring further discovery;
update only task/STATE/HANDOFF/EXECUTION_MAP.

## MUST NOT CHANGE

No gameplay behavior, bridge configuration, tests, UI, AI, trainer layouts,
held items, move-admission policy, or other effect family. Discovery is not
permission to implement or claim Phase 4 completion.
