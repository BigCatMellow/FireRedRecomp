# Task: Phase 4 Flail/Reversal effect discovery

- Status: `READY FOR INDEPENDENT REVIEW`
- Type: `PHASE 4 / BATTLE RULES / READ-ONLY DISCOVERY`

## Goal

Source-lock FireRed `EFFECT_FLAIL` (99) and determine whether its two records
form the next bounded dynamic-base-power leaf. Do not implement it.

## Evidence and conclusion

Effect 99 routes to `BattleScript_EffectFlail` (`data/battle_scripts_1.s:123,
1341-1343`), which first runs `remaininghptopower` then the ordinary Hit script.
The two records are Flail and Reversal, both stored power 1, accuracy 100, PP
15, priority 0, Normal and Fighting respectively (`src/data/battle_moves.h:
2278-2289,2330-2341`). `Cmd_remaininghptopower`
(`src/battle_script_commands.c:7929-7941`) scales attacker current/max HP to
48 and maps it to dynamic power: <=1:200, <=4:150, <=9:100, <=16:80,
<=32:40, otherwise 20 (`sFlailHpScaleToPowerTable:731-739`).

This is a bounded candidate because attacker HP and maxHP already exist. It
must set dynamic base power before the ordinary accuracy/PP/crit/type/random/
damage path, without changing generic move data or other effect families. A
later implementation needs exact scaling-boundary tests for both parsed moves,
ordinary RNG/accuracy behavior, immunity, and no leakage to ordinary power-1
moves. It needs its own bridge route and review before any implementation.

## MUST NOT CHANGE

No gameplay code, tests, workflow, bridge route/request, move admission, UI,
AI, items, or Phase 4 completion status.
