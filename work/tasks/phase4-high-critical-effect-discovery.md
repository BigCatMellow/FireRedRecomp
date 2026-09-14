# Task: Phase 4 high-critical effect discovery

- Status: `DISCOVERY COMPLETE — PENDING INDEPENDENT REVIEW`
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

## Evidence and conclusion

The preserved FireRed source checkout at
`Documents/Projects/Pokemon_ReComp_FireRed (copy)/Disassembled_Games/Classic/pokefirered-master`
defines `EFFECT_HIGH_CRITICAL` as 43 in
`include/constants/battle_move_effects.h:47` and routes it to ordinary
`BattleScript_EffectHit` in `data/battle_scripts_1.s:67`. It therefore retains
the ordinary accuracy, PP, type, damage, and HP paths. Its only distinct rule
is inside `Cmd_critcalc`: `src/battle_script_commands.c:1184-1204` adds one to
the critical stage when the move has effect 43, clamps the stage, and consumes
the same one `Random()` draw against `sCriticalHitChance`. The table at line
588 is `{16, 8, 4, 3, 2}`; effect 43 alone is stage 1 (1/8), instead of the
ordinary stage 0 (1/16). It does not change crit multiplier, hit order, or RNG
draw count.

The stock move constants and move data identify eight positive-power records:
Karate Chop #2, Razor Leaf #75, Crabhammer #152, Slash #163, Aeroblast #177,
Cross Chop #238, Air Cutter #314, and Leaf Blade #348. This matches the prior
verified-ROM admission inventory (`43:8`).

`BattleFormulas.critRoll` already represents the exact stage table at
`src/core/BattleFormulas.lua:193-453`, including clamping. `BattleEngine`
currently calls it with literal stage 0 in both ordinary and multi-hit paths
(`src/core/BattleEngine.lua:940` and `1235`). A bounded effect-43 leaf is thus
implementable: select stage 1 only for effect 43 at those existing call sites,
preserve one critical draw and all other paths, and prove the eight ROM records
plus stage-1 boundary seeds. Multi-hit must be explicitly excluded because no
effect-43 move is multi-hit; no absent state is required.
