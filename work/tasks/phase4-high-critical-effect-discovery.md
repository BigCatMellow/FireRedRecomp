# Task: Phase 4 high-critical effect discovery

- Status: `ACTIVE`
- Type: `PHASE 4 / BATTLE RULES / READ-ONLY DISCOVERY`

## Goal

Source-lock FireRed `EFFECT_HIGH_CRITICAL` (43): enumerate its verified-ROM
move records, trace its battle-script and critical-roll semantics, and decide
whether it is a self-contained bounded implementation leaf. Do not implement
the effect in this task.

## Required evidence

1. Identify every positive-power effect-43 record in the verified FireRed US
   v1.0 ROM with move id, name, power, accuracy, and crit-relevant metadata.
2. Cite the stock effect id, script route, and `Cmd_critcalc`/critical-stage
   behavior; distinguish it from effect 17, Vital Throw, and ordinary damage.
3. Map the source behavior to the current `BattleEngine` and `BattleFormulas`
   critical paths, including RNG-draw consequences and any missing state.
4. Classify the leaf as implementable, blocked on a named prerequisite, or
   requiring further discovery. Update only task/STATE/HANDOFF/EXECUTION_MAP.

## MUST NOT CHANGE

No gameplay behavior, bridge configuration, tests, UI, AI, trainer layouts,
held items, move-admission policy, or other effect family. Discovery does not
authorize an implementation or a Phase 4 completion claim.
