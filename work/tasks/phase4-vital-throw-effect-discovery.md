# Task: Phase 4 Vital Throw effect discovery

- Status: `DISCOVERY COMPLETE — PENDING INDEPENDENT REVIEW`
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

## Evidence and conclusion

The preserved FireRed source checkout at
`Documents/Projects/Pokemon_ReComp_FireRed (copy)/Disassembled_Games/Classic/pokefirered-master`
defines `EFFECT_VITAL_THROW` as 78
(`include/constants/battle_move_effects.h:82`) and `MOVE_VITAL_THROW` as 233
(`include/constants/moves.h:237`). Its sole positive-power record is Vital
Throw #233: Fighting, power 70, accuracy 100, PP 10, selected-target, priority
-1 (`src/data/battle_moves.h:3032-3042`). The prior admission inventory's
`78:1` classification is therefore confirmed.

Effect 78 routes to ordinary `BattleScript_EffectHit`
(`data/battle_scripts_1.s:102`), retaining ordinary PP, critical, type,
damage, and HP handling. Its distinct rule is in the shared accuracy command:
after the semi-invulnerability checks, `Cmd_accuracycheck` takes the same
`JumpIfMoveFailed` no-random-accuracy branch for `EFFECT_ALWAYS_HIT` and
`EFFECT_VITAL_THROW` (`src/battle_script_commands.c:993-998`). Thus Vital
Throw ignores the normal accuracy/evasion calculation and consumes no accuracy
RNG draw despite its stored accuracy being 100. This is not interchangeable
with effect 17: it is a separately numbered effect and must remain a separate
bounded leaf.

Turn order needs no new rule. Stock `GetWhoStrikesFirst` compares chosen move
priorities before speed and tie RNG (`src/battle_main.c:3505-3528`); Vital
Throw's priority -1 consequently resolves after a priority-0 move regardless
of speed, while ordinary priority ordering still governs interactions with
other nonzero-priority moves. The current `BattleFormulas.getWhoStrikesFirst`
already implements that comparison (`src/core/BattleFormulas.lua:512-533`) and
`BattleEngine.runTurn` already supplies both parsed move records to it
(`src/core/BattleEngine.lua:1482-1494`). No order prerequisite is missing.

`BattleEngine.resolveMove` presently exempts only effect 17 from its ordinary
accuracy call (`src/core/BattleEngine.lua:841-859`), so effect 78 incorrectly
uses `BattleFormulas.accuracyCheck` and consumes an extra RNG draw. A
self-contained implementation leaf is eligible: add an explicit effect-78
constant and extend only that existing no-roll predicate, preserving existing
priority routing, PP, critical, type, damage, and HP paths. The proof must
cover its one ROM record, modified accuracy/evasion stages with no accuracy
draw, the remaining critical/damage draw sequence, and priority -1 against a
priority-0 move. No stateful prerequisite or move-admission-policy change is
needed.
