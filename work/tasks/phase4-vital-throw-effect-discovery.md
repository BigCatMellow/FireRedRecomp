# Task: Phase 4 Vital Throw effect discovery

- Status: `ACTIVE`
- Type: `PHASE 4 / BATTLE RULES / READ-ONLY DISCOVERY`

## Goal

Source-lock FireRed `EFFECT_VITAL_THROW` (78): inventory the verified-ROM
record and determine its exact accuracy and turn-order semantics against this
engine. Do not implement the effect.

## Required evidence

1. Identify the effect-78 ROM record and its priority/accuracy fields.
2. Cite stock effect/script, accuracy command, and order behavior.
3. Map those rules to current `BattleEngine` order and accuracy paths,
including RNG consequences and any missing prerequisite.
4. Classify implementation eligibility; update only coordination documents.

## MUST NOT CHANGE

No battle behavior, tests, workflow, UI, AI, trainer layouts, held items,
move-admission policy, or other effect family.
