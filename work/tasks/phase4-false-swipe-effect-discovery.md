# Task: Phase 4 False Swipe effect discovery

- Status: `DISCOVERY COMPLETE — PENDING INDEPENDENT REVIEW`
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

## Evidence and conclusion

FireRed defines `EFFECT_FALSE_SWIPE` as 101 and routes it to ordinary
`BattleScript_EffectHit` (`data/battle_scripts_1.s:125`). Its only
positive-power record is False Swipe #206: Normal, power 40, accuracy 100,
PP 40 (`src/data/battle_moves.h:2681-2687`).

`Cmd_adjustnormaldamage` (`src/battle_script_commands.c:1596-1605`, mirrored
at 5619-5628) calculates ordinary damage first. For a target not behind a
Substitute, when the current move is False Swipe and target HP is less than or
equal to final damage, it changes damage to `target HP - 1`. Therefore a
landed, non-immune False Swipe leaves a living target at 1 HP without changing
accuracy, PP, critical, random-damage, or type handling. Endure, Focus Band,
and Substitute share the real command but are absent engine state and excluded.

`BattleEngine` reaches shared `applyDamage` after accuracy, PP, critical, type
no-effect, and random damage. Cap only effect-101 pre-application damage to
`max(0, defender.hp - 1)` after the no-effect return and before `applyDamage`.
An already-fainted target cannot enter this resolver, and no effect-101 record
is multi-hit. This is implementable without new state; prove the record, lethal
floor including HP=1, nonlethal behavior, immunity, and the three-draw path.
