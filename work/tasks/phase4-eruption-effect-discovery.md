# Task: Phase 4 Eruption/Water Spout effect discovery

- Status: `READY FOR INDEPENDENT REVIEW`
- Type: `PHASE 4 / BATTLE RULES / READ-ONLY DISCOVERY`

## Goal

Source-lock FireRed `EFFECT_ERUPTION` (190) and determine whether its two
current-HP dynamic-power records are the next bounded leaf. Do not implement.

## Evidence and conclusion

Effect 190 routes to `BattleScript_EffectEruption`, which runs
`scaledamagebyhealthratio` before the ordinary Hit script
(`data/battle_scripts_1.s:214,2488-2490`). The two records are Eruption #284
(Fire) and Water Spout #323 (Water), each power 150, accuracy 100, PP 5,
priority 0 (`include/constants/moves.h:288,327`; `src/data/battle_moves.h:
3695-3707,4202-4214`). Both carry `MOVE_TARGET_BOTH`; this bounded engine is
singles-only and therefore covers its one opposing battler only. Doubles and
native multi-target semantics remain explicitly excluded.

`Cmd_scaledamagebyhealthratio` computes only when stock `gDynamicBasePower` is
zero; it then sets transient power to integer `floor(attacker HP * stored power
/ attacker maxHP)`, changing zero to one (`src/battle_script_commands.c:
8986-8997`), then normal Hit performs its
ordinary cancellation/accuracy/PP/critical/type/random/HP/faint behavior.
This is bounded because HP/maxHP and the direct Hit path already exist. A later
implementation must keep ROM move data unchanged, prove full/partial/positive
underflow HP, both parsed records, ordinary RNG/immunity, and no leakage to
other 150-power moves. The current engine has no pre-seeded transient dynamic
power state, so interactions that could seed it are outside this leaf. It needs
a separate route and review before code.

## MUST NOT CHANGE

No gameplay code, tests, workflow, bridge configuration/request, generic move
admission, UI, AI, items, or Phase 4 completion status.
