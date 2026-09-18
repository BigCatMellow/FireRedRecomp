# Task: Phase 4 Pain Split effect discovery

- Status: `DISCOVERY COMPLETE — PENDING INDEPENDENT REVIEW`
- Type: `PHASE 4 / BATTLE RULES / READ-ONLY DISCOVERY`

## Goal

Source-lock FireRed `EFFECT_PAIN_SPLIT` (91), Pain Split #220, and determine
whether its two-sided HP sequence and currently rejected zero-power admission
can form one bounded implementation leaf. Do not implement it here.

## Evidence and conclusion

The source record is Pain Split #220: effect 91, power 0, Normal type, accuracy
100, PP 20, selected-target 0, priority 0, and Protect/Mirror-Move flags.
`BattleScript_EffectPainSplit` at `data/battle_scripts_1.s:1235-1251` runs
cancellation, announcement, PP, then `accuracycheck` with
`NO_ACC_CALC_CHECK_LOCK_ON`: the represented no-state path consumes zero
accuracy RNG before `painsplitdmgcalc`.
The command at `src/battle_script_commands.c:7674-7689` rejects Substitute;
otherwise it computes `floor((attackerHP + targetHP)/2)` and stores signed
attacker and target HP deltas. The script then applies the attacker delta first,
copies the stored target delta, applies the target second, and prints shared
pain. It has no ordinary crit/base/random/type-damage path.

This is potentially bounded only after a separate design confirms exact
two-sided HP event ordering and a literal admission exception for effect 91.
The engine currently rejects it because `supportsMove` admits only positive
power, stat-stage, and screen moves. Do not broaden generic zero-power
admission. Protect, Substitute, Mirror Move, Lock-On/sure-hit,
semi-invulnerability, held items, abilities, status, doubles/links, generic
healing, and Phase 4 completion remain excluded.

## MUST NOT CHANGE

Battle behavior, admission policy, UI/controller, bridge configuration, Phase
2's trusted external-reference blocker, or Phase 4 completion status.
