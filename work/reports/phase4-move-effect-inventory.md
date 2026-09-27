# Complete move-effect inventory after Pain Split

- Task: `P4-02`; status: `PREPARED — GUARDED ROM EVIDENCE AND INDEPENDENT REVIEW PENDING`.
- Engine baseline: `a739ddc88cb44a33d5e6025e619cf1df3fe6a1a8` (accepted Pain Split).
- Preparation worktree base: `82af91015cc438711d7ae9c6cbb001cdfddd36d1`; no runtime changes.
- Public source pin: `pret/pokefirered c75f352304d529f6ba92d4f74b9cf8b5c3810788`.
- Supported private-ROM SHA-1: `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`.
- This report contains classification/test metadata only. It does not contain a ROM table, move-record bytes, extracted strings, or assets.

## Result and evidence boundary

Source enumeration covers every real move ID **1–354 exactly once** and every
defined effect **0–213**, excluding move sentinel 0. The pinned
[move identifiers](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/include/constants/moves.h),
[effect identifiers](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/include/constants/battle_move_effects.h),
[move-to-effect source records](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/data/battle_moves.h), and
[script dispatch table](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L20) were joined by
numeric identifier. All 214 effect definitions have a dispatch owner;
198 have real move members. Constant names were not used to infer behavior:
script bodies and distinctive commands determine the missing prerequisites.
Existing accepted engine families retain their documented limits.

A separate source-only invocation of the actual current
`BattleEngine:supportsMove` on source-derived effect/power metadata returned
248 admissions and 106 rejections. These are source/predicate observations,
**not a local ROM result**. The checked-in [inventory test](../../tests/phase4_move_effect_inventory_test.lua)
contains literal expected membership, admission and coverage metadata. It does
not read engine tables to construct expectations. It checks partition integrity
before a clean no-ROM skip; with a SHA-verified ROM it invokes the actual
predicate for all 354 parsed real records and checks every expected family and
power class. Only aggregate diagnostics are emitted; records remain in memory.
Source definitions cannot be recovered from a ROM enum, so the test explicitly
labels `defined_source=214`; the ROM gate checks member usage and unused IDs.

| Source-confirmed semantic class | Used families | Moves | Positive power | Zero power | Admitted / rejected |
| --- | ---: | ---: | ---: | ---: | ---: |
| Represented with stated limits | 50 | 137 | 104 | 33 | 137 / 0 |
| Candidate for separate discovery | 20 | 25 | 10 | 15 | 10 / 15 |
| Blocked on additional state or an absent cross-component path | 127 | 191 | 101 | 90 | 101 / 90 |
| Intentionally rejected | 1 | 1 | 1 | 0 | 0 / 1 |
| Total used | 198 | 354 | 216 | 138 | 248 / 106 |
| Defined but unused | 16 | 0 | 0 | 0 | no real-record claim |

`represented` means an existing bounded mechanism plus checked-in tests/source
evidence; it does not mean unrestricted retail parity. `candidate` means a
plausible isolated discovery using represented fields; it is not implementation
authority or proven source parity. `blocked_on_state` includes missing persistent
state, retained inputs, action interception, or cross-component settlement;
it does not prevent a later explicit design. Only effect 8 is deliberately
excluded by the positive-power admission guard. Other rejected zero-power
families are unimplemented, not a policy decision that they should never work.

## Coverage and admission are separate

The **111 admitted, semantically uncovered positive-power records** occupy
61 effects: `2, 4, 5, 6, 26, 27, 31, 34, 36, 39, 42, 45, 75, 76, 77, 80, 81, 89, 92, 104, 105, 117, 119, 121, 122, 123, 125, 126, 128, 129, 135, 140, 144, 145, 146, 147, 148, 149, 150, 151, 152, 154, 155, 158, 159, 161, 169, 170, 171, 182, 185, 186, 188, 196, 197, 200, 202, 203, 204, 207, 209`.
Their precise move members and counts are the `yes / C` and `yes / B` rows
below. They reach ordinary damage because of the positive-power fallback;
admission does not implement their effects. Ten are candidate records and
101 need additional state/path work. This refresh supersedes the older
140-fallback positive-only count; accepted intervening leaves account for the
reduction, while 138 zero-power records are now included explicitly.

Unused defined effects are `12, 14, 15, 21, 22, 55, 56, 61, 63, 64, 74, 96, 110, 131, 141, 163`. All dispatch to
`BattleScript_EffectHit` in this source, including constants whose names imply
stat changes. No invented stat implementation or runtime admission claim is
assigned to these unreferenced IDs.

## Common limits and mixed-family distinctions

All represented rows share the current singles, represented-state boundary.
General persistent status, held items, weather, Protect/Substitute, most ability
interactions, semi-invulnerability, doubles/links and visual parity remain
outside these claims. Explosion has a specific Damp exception, not a general
ability subsystem. Read executable code and current accepted tasks ahead of
older broad header prose: for example, historical comments still call OHKO
unsupported and describe effect198 as having only one member.

The matrix does not merge moves solely because they share an effect number.
Effect0 includes Surf's extra underwater branch, explicitly excluded from
ordinary-hit coverage. Effect48's Struggle member adds PP-exhaustion selection
and neutral type handling absent from its other two members; those special paths
are already tested. Both effect198 members use the same Gen 3 recoil script.
Effect42's Whirlpool member has an underwater branch; effect102's Heal Bell
member has a Soundproof branch absent from Aromatherapy; effect155 distinguishes
Fly, Dig, Dive and Bounce, including Bounce's paralysis. Effect109's behavior
also depends on the user's Ghost type. These distinctions appear in the notes
below. All members of a used family have one power class and the same admission
at this source pin; that coincidence is recorded in the literal expectations,
not assumed by the test for future source/ROM changes.

## Exhaustive family matrix

Membership is the exhaustive partition; numbers are numeric move IDs, not ROM
records. `P` means positive power, `Z` zero power; `—` means unused.
Admission is actual current predicate behavior on source metadata, awaiting ROM
confirmation. `R` = represented with limits, `C` = candidate,
`B` = blocked on state/path, `J` = intentionally rejected, `U` = unused.
R/J evidence codes resolve in the next section. Source-owner links identify
actual script definitions; neighboring alias labels fall through to their shared
body (Protect/Endure, Return/Frustration, sunlight recovery, Mud/Water Sport).

| Effect / source symbol | Members (count; power) | Admission | Class / implementation evidence | Script owner | Limits or missing prerequisite |
| --- | --- | --- | --- | --- | --- |
| 0 `EFFECT_HIT` | 1, 5, 10, 11, 15, 17, 21, 22, 25, 30, 33, 55, 56, 57, 64, 65, 70, 88, 121, 127, 224, 304, 337 (23; P) | yes | R / R1 | [`BattleScript_EffectHit`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L239) | Ordinary singles hit; #57 underwater bonus excluded because semi-invulnerable state is absent. |
| 1 `EFFECT_SLEEP` | 47, 79, 95, 142, 147, 320 (6; Z) | no | B | [`BattleScript_EffectSleep`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L287) | Primary status setter/preconditions; persistent status, action prevention/residual effects and save/UI lifecycle absent. |
| 2 `EFFECT_POISON_HIT` | 40, 123, 124, 188 (4; P) | yes | B | [`BattleScript_EffectPoisonHit`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L321) | Non-stat secondary status via setmoveeffect/seteffectwithchance; application/RNG/persistence/lifecycle absent. |
| 3 `EFFECT_ABSORB` | 71, 72, 141, 202 (4; P) | yes | R / R2 | [`BattleScript_EffectAbsorb`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L325) | Half actual-damage drain and own-max clamp; no Liquid Ooze/items/status. |
| 4 `EFFECT_BURN_HIT` | 7, 52, 53, 126, 257 (5; P) | yes | B | [`BattleScript_EffectBurnHit`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L364) | Non-stat secondary status via setmoveeffect/seteffectwithchance; application/RNG/persistence/lifecycle absent. |
| 5 `EFFECT_FREEZE_HIT` | 8, 58, 59, 181 (4; P) | yes | B | [`BattleScript_EffectFreezeHit`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L368) | Non-stat secondary status via setmoveeffect/seteffectwithchance; application/RNG/persistence/lifecycle absent. |
| 6 `EFFECT_PARALYZE_HIT` | 9, 34, 84, 85, 122, 192, 209, 225 (8; P) | yes | B | [`BattleScript_EffectParalyzeHit`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L372) | Non-stat secondary status via setmoveeffect/seteffectwithchance; application/RNG/persistence/lifecycle absent. |
| 7 `EFFECT_EXPLOSION` | 120, 153 (2; P) | yes | R / R9 | [`BattleScript_EffectExplosion`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L376) | Reviewed Damp scan, self-KO, defense halving and two-sided faint order; no general ability system. |
| 8 `EFFECT_DREAM_EATER` | 138 (1; P) | no | J / J1 | [`BattleScript_EffectDreamEater`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L427) | Explicit admission exclusion: sleeping-target prerequisite absent; drain support does not cover this move. |
| 9 `EFFECT_MIRROR_MOVE` | 119 (1; Z) | no | B | [`BattleScript_EffectMirrorMove`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L466) | Copy-move command needs last-used move history, slot/PP provenance and temporary/permanent persistence. |
| 10 `EFFECT_ATTACK_UP` | 96, 159, 336 (3; Z) | yes | R / R4 | [`BattleScript_EffectAttackUp`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L477) | Pure single-stat stages/clamps and self/foe accuracy path; no prevention abilities/Substitute/Mist. |
| 11 `EFFECT_DEFENSE_UP` | 106, 110 (2; Z) | yes | R / R4 | [`BattleScript_EffectDefenseUp`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L481) | Pure single-stat stages/clamps and self/foe accuracy path; no prevention abilities/Substitute/Mist. |
| 12 `EFFECT_SPEED_UP` | none (0; —) | — | U | [`BattleScript_EffectHit`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L239) | No real move member; source aliases Hit. No runtime coverage/admission claim. |
| 13 `EFFECT_SPECIAL_ATTACK_UP` | 74 (1; Z) | yes | R / R4 | [`BattleScript_EffectSpecialAttackUp`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L485) | Pure single-stat stages/clamps and self/foe accuracy path; no prevention abilities/Substitute/Mist. |
| 14 `EFFECT_SPECIAL_DEFENSE_UP` | none (0; —) | — | U | [`BattleScript_EffectHit`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L239) | No real move member; source aliases Hit. No runtime coverage/admission claim. |
| 15 `EFFECT_ACCURACY_UP` | none (0; —) | — | U | [`BattleScript_EffectHit`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L239) | No real move member; source aliases Hit. No runtime coverage/admission claim. |
| 16 `EFFECT_EVASION_UP` | 104 (1; Z) | yes | R / R4 | [`BattleScript_EffectEvasionUp`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L489) | Pure single-stat stages/clamps and self/foe accuracy path; no prevention abilities/Substitute/Mist. |
| 17 `EFFECT_ALWAYS_HIT` | 129, 185, 325, 332, 345, 351 (6; P) | yes | R / R8 | [`BattleScript_EffectHit`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L239) | Reviewed no-roll/high-critical/priority/HP-floor leaf; shared singles limitations apply. |
| 18 `EFFECT_ATTACK_DOWN` | 45 (1; Z) | yes | R / R4 | [`BattleScript_EffectAttackDown`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L518) | Pure single-stat stages/clamps and self/foe accuracy path; no prevention abilities/Substitute/Mist. |
| 19 `EFFECT_DEFENSE_DOWN` | 39, 43 (2; Z) | yes | R / R4 | [`BattleScript_EffectDefenseDown`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L522) | Pure single-stat stages/clamps and self/foe accuracy path; no prevention abilities/Substitute/Mist. |
| 20 `EFFECT_SPEED_DOWN` | 81 (1; Z) | yes | R / R4 | [`BattleScript_EffectSpeedDown`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L526) | Pure single-stat stages/clamps and self/foe accuracy path; no prevention abilities/Substitute/Mist. |
| 21 `EFFECT_SPECIAL_ATTACK_DOWN` | none (0; —) | — | U | [`BattleScript_EffectHit`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L239) | No real move member; source aliases Hit. No runtime coverage/admission claim. |
| 22 `EFFECT_SPECIAL_DEFENSE_DOWN` | none (0; —) | — | U | [`BattleScript_EffectHit`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L239) | No real move member; source aliases Hit. No runtime coverage/admission claim. |
| 23 `EFFECT_ACCURACY_DOWN` | 28, 108, 134, 148 (4; Z) | yes | R / R4 | [`BattleScript_EffectAccuracyDown`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L530) | Pure single-stat stages/clamps and self/foe accuracy path; no prevention abilities/Substitute/Mist. |
| 24 `EFFECT_EVASION_DOWN` | 230 (1; Z) | yes | R / R4 | [`BattleScript_EffectEvasionDown`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L534) | Pure single-stat stages/clamps and self/foe accuracy path; no prevention abilities/Substitute/Mist. |
| 25 `EFFECT_HAZE` | 114 (1; Z) | no | C | [`BattleScript_EffectHaze`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L564) | normalisebuffs resets both battlers' seven stages; existing fields, event/accuracy/source gate still needed. |
| 26 `EFFECT_BIDE` | 117 (1; P) | yes | B | [`BattleScript_EffectBide`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L575) | setbide needs delayed damage accumulation, locked turns and release lifecycle. |
| 27 `EFFECT_RAMPAGE` | 37, 80, 200 (3; P) | yes | B | [`BattleScript_EffectRampage`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L585) | Multiple-turn repeat and confusion-on-end need forced selection, counters and confusion. |
| 28 `EFFECT_ROAR` | 18, 46 (2; Z) | no | B | [`BattleScript_EffectRoar`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L595) | forcerandomswitch needs living-target phazing/escape, bench selection and rooted/ability veto, distinct from faint replacement. |
| 29 `EFFECT_MULTI_HIT` | 3, 4, 31, 42, 131, 140, 154, 198, 292, 331, 333, 350 (12; P) | yes | R / R3 | [`BattleScript_EffectMultiHit`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L605) | Shared accuracy/PP, per-hit critical/damage, stop-on-KO/immunity; no item/ability hit reactions. |
| 30 `EFFECT_CONVERSION` | 160 (1; Z) | no | C | [`BattleScript_EffectConversion`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L658) | tryconversiontypechange selects among own move types; existing fields, selection/RNG/failure contract needed. |
| 31 `EFFECT_FLINCH_HIT` | 27, 29, 44, 125, 157, 158 (6; P) | yes | B | [`BattleScript_EffectFlinchHit`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L669) | Flinch secondary needs pending-action cancellation and turn-local flag/reset. |
| 32 `EFFECT_RESTORE_HP` | 105, 303 (2; Z) | no | C | [`BattleScript_EffectRestoreHp`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L673) | tryhealhalfhealth BS_ATTACKER heals own maxHP/2, fails at full HP; dedicated admission/events needed. |
| 33 `EFFECT_TOXIC` | 92 (1; Z) | no | B | [`BattleScript_EffectToxic`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L687) | Primary status setter/preconditions; persistent status, action prevention/residual effects and save/UI lifecycle absent. |
| 34 `EFFECT_PAY_DAY` | 6 (1; P) | yes | B | [`BattleScript_EffectPayDay`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L720) | Pay Day secondary needs battle money accumulator and post-battle settlement. |
| 35 `EFFECT_LIGHT_SCREEN` | 113 (1; Z) | yes | R / R6 | [`BattleScript_EffectLightScreen`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L724) | Singles screen damage modifier, duplicate failure and five-turn side timer; no Brick Break effect. |
| 36 `EFFECT_TRI_ATTACK` | 161 (1; P) | yes | B | [`BattleScript_EffectTriAttack`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L731) | Non-stat secondary status via setmoveeffect/seteffectwithchance; application/RNG/persistence/lifecycle absent. |
| 37 `EFFECT_REST` | 156 (1; Z) | no | B | [`BattleScript_EffectRest`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L735) | trysetrest needs sleep preconditions/status update/lifecycle as well as healing. |
| 38 `EFFECT_OHKO` | 12, 32, 90, 329 (4; P) | yes | R / R13 | [`BattleScript_EffectOHKO`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L761) | Reviewed level condition and one KO roll; no Sturdy/Lock-On/Protect/Endure/items. |
| 39 `EFFECT_RAZOR_WIND` | 13 (1; P) | yes | B | [`BattleScript_EffectRazorWind`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L777) | Charge/second-turn script needs locked move state; #143 also flinches, #130 raises Defense on charge. |
| 40 `EFFECT_SUPER_FANG` | 162 (1; P) | yes | R / R10 | [`BattleScript_EffectSuperFang`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L808) | Reviewed floor(target HP/2), minimum-one and shared immunity path. |
| 41 `EFFECT_DRAGON_RAGE` | 82 (1; P) | yes | R / R7 | [`BattleScript_EffectDragonRage`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L818) | Fixed 40/level/20 damage with shared accuracy, immunity and HP; no item/Endure state. |
| 42 `EFFECT_TRAP` | 20, 35, 83, 128, 250, 328 (6; P) | yes | B | [`BattleScript_EffectTrap`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L829) | Wrap secondary needs duration/residual/escape-lock lifecycle; #250 adds underwater interaction. |
| 43 `EFFECT_HIGH_CRITICAL` | 2, 75, 152, 163, 177, 238, 314, 348 (8; P) | yes | R / R8 | [`BattleScript_EffectHit`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L239) | Reviewed no-roll/high-critical/priority/HP-floor leaf; shared singles limitations apply. |
| 44 `EFFECT_DOUBLE_HIT` | 24, 155 (2; P) | yes | R / R3 | [`BattleScript_EffectDoubleHit`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L838) | Shared accuracy/PP, per-hit critical/damage, stop-on-KO/immunity; no item/ability hit reactions. |
| 45 `EFFECT_RECOIL_IF_MISS` | 26, 136 (2; P) | yes | C | [`BattleScript_EffectRecoilIfMiss`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L848) | Miss-only damagecalc/manipulatedamage and attacker faint; exact miss/RNG/type/order contract needed. |
| 46 `EFFECT_MIST` | 54 (1; Z) | no | B | [`BattleScript_EffectMist`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L873) | setmist side timer and stat-drop prevention hooks absent. |
| 47 `EFFECT_FOCUS_ENERGY` | 116 (1; Z) | no | B | [`BattleScript_EffectFocusEnergy`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L884) | setfocusenergy volatile state and critical-stage consumption/reset absent. |
| 48 `EFFECT_RECOIL` | 36, 66, 165 (3; P) | yes | R / R2 | [`BattleScript_EffectRecoil`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L896) | Quarter recoil; #165 additionally implements PP-exhaustion selection and neutral typing; #36/#66 ordinary recoil. |
| 49 `EFFECT_CONFUSE` | 48, 109, 186 (3; Z) | no | B | [`BattleScript_EffectConfuse`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L902) | Confusion duration/self-hit/action gate absent; #207/#260 also change stats, #298 loops non-user targets. |
| 50 `EFFECT_ATTACK_UP_2` | 14 (1; Z) | yes | R / R4 | [`BattleScript_EffectAttackUp2`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L925) | Pure single-stat stages/clamps and self/foe accuracy path; no prevention abilities/Substitute/Mist. |
| 51 `EFFECT_DEFENSE_UP_2` | 112, 151, 334 (3; Z) | yes | R / R4 | [`BattleScript_EffectDefenseUp2`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L929) | Pure single-stat stages/clamps and self/foe accuracy path; no prevention abilities/Substitute/Mist. |
| 52 `EFFECT_SPEED_UP_2` | 97 (1; Z) | yes | R / R4 | [`BattleScript_EffectSpeedUp2`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L933) | Pure single-stat stages/clamps and self/foe accuracy path; no prevention abilities/Substitute/Mist. |
| 53 `EFFECT_SPECIAL_ATTACK_UP_2` | 294 (1; Z) | yes | R / R4 | [`BattleScript_EffectSpecialAttackUp2`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L937) | Pure single-stat stages/clamps and self/foe accuracy path; no prevention abilities/Substitute/Mist. |
| 54 `EFFECT_SPECIAL_DEFENSE_UP_2` | 133 (1; Z) | yes | R / R4 | [`BattleScript_EffectSpecialDefenseUp2`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L941) | Pure single-stat stages/clamps and self/foe accuracy path; no prevention abilities/Substitute/Mist. |
| 55 `EFFECT_ACCURACY_UP_2` | none (0; —) | — | U | [`BattleScript_EffectHit`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L239) | No real move member; source aliases Hit. No runtime coverage/admission claim. |
| 56 `EFFECT_EVASION_UP_2` | none (0; —) | — | U | [`BattleScript_EffectHit`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L239) | No real move member; source aliases Hit. No runtime coverage/admission claim. |
| 57 `EFFECT_TRANSFORM` | 144 (1; Z) | no | B | [`BattleScript_EffectTransform`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L945) | Transform needs temporary copied identity, stats/moves/PP and restoration lifecycle. |
| 58 `EFFECT_ATTACK_DOWN_2` | 204, 297 (2; Z) | yes | R / R4 | [`BattleScript_EffectAttackDown2`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L956) | Pure single-stat stages/clamps and self/foe accuracy path; no prevention abilities/Substitute/Mist. |
| 59 `EFFECT_DEFENSE_DOWN_2` | 103 (1; Z) | yes | R / R4 | [`BattleScript_EffectDefenseDown2`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L960) | Pure single-stat stages/clamps and self/foe accuracy path; no prevention abilities/Substitute/Mist. |
| 60 `EFFECT_SPEED_DOWN_2` | 178, 184 (2; Z) | yes | R / R4 | [`BattleScript_EffectSpeedDown2`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L964) | Pure single-stat stages/clamps and self/foe accuracy path; no prevention abilities/Substitute/Mist. |
| 61 `EFFECT_SPECIAL_ATTACK_DOWN_2` | none (0; —) | — | U | [`BattleScript_EffectHit`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L239) | No real move member; source aliases Hit. No runtime coverage/admission claim. |
| 62 `EFFECT_SPECIAL_DEFENSE_DOWN_2` | 313, 319 (2; Z) | yes | R / R4 | [`BattleScript_EffectSpecialDefenseDown2`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L968) | Pure single-stat stages/clamps and self/foe accuracy path; no prevention abilities/Substitute/Mist. |
| 63 `EFFECT_ACCURACY_DOWN_2` | none (0; —) | — | U | [`BattleScript_EffectHit`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L239) | No real move member; source aliases Hit. No runtime coverage/admission claim. |
| 64 `EFFECT_EVASION_DOWN_2` | none (0; —) | — | U | [`BattleScript_EffectHit`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L239) | No real move member; source aliases Hit. No runtime coverage/admission claim. |
| 65 `EFFECT_REFLECT` | 115 (1; Z) | yes | R / R6 | [`BattleScript_EffectReflect`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L972) | Singles screen damage modifier, duplicate failure and five-turn side timer; no Brick Break effect. |
| 66 `EFFECT_POISON` | 77, 139 (2; Z) | no | B | [`BattleScript_EffectPoison`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L984) | Primary status setter/preconditions; persistent status, action prevention/residual effects and save/UI lifecycle absent. |
| 67 `EFFECT_PARALYZE` | 78, 86, 137 (3; Z) | no | B | [`BattleScript_EffectParalyze`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1005) | Primary status setter/preconditions; persistent status, action prevention/residual effects and save/UI lifecycle absent. |
| 68 `EFFECT_ATTACK_DOWN_HIT` | 62 (1; P) | yes | R / R5 | [`BattleScript_EffectAttackDownHit`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1037) | One-stage secondary stat/chance RNG path; no Serene Grace/Shield Dust/Substitute or non-stat status effects. |
| 69 `EFFECT_DEFENSE_DOWN_HIT` | 51, 231, 249, 306 (4; P) | yes | R / R5 | [`BattleScript_EffectDefenseDownHit`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1041) | One-stage secondary stat/chance RNG path; no Serene Grace/Shield Dust/Substitute or non-stat status effects. |
| 70 `EFFECT_SPEED_DOWN_HIT` | 61, 132, 145, 196, 317, 341 (6; P) | yes | R / R5 | [`BattleScript_EffectSpeedDownHit`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1045) | One-stage secondary stat/chance RNG path; no Serene Grace/Shield Dust/Substitute or non-stat status effects. |
| 71 `EFFECT_SPECIAL_ATTACK_DOWN_HIT` | 296 (1; P) | yes | R / R5 | [`BattleScript_EffectSpecialAttackDownHit`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1049) | One-stage secondary stat/chance RNG path; no Serene Grace/Shield Dust/Substitute or non-stat status effects. |
| 72 `EFFECT_SPECIAL_DEFENSE_DOWN_HIT` | 94, 242, 247, 295 (4; P) | yes | R / R5 | [`BattleScript_EffectSpecialDefenseDownHit`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1053) | One-stage secondary stat/chance RNG path; no Serene Grace/Shield Dust/Substitute or non-stat status effects. |
| 73 `EFFECT_ACCURACY_DOWN_HIT` | 189, 190, 330 (3; P) | yes | R / R5 | [`BattleScript_EffectAccuracyDownHit`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1057) | One-stage secondary stat/chance RNG path; no Serene Grace/Shield Dust/Substitute or non-stat status effects. |
| 74 `EFFECT_EVASION_DOWN_HIT` | none (0; —) | — | U | [`BattleScript_EffectHit`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L239) | No real move member; source aliases Hit. No runtime coverage/admission claim. |
| 75 `EFFECT_SKY_ATTACK` | 143 (1; P) | yes | B | [`BattleScript_EffectSkyAttack`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1061) | Charge/second-turn script needs locked move state; #143 also flinches, #130 raises Defense on charge. |
| 76 `EFFECT_CONFUSE_HIT` | 60, 93, 146, 223, 324, 352 (6; P) | yes | B | [`BattleScript_EffectConfuseHit`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1068) | Confusion duration/self-hit/action gate absent; #207/#260 also change stats, #298 loops non-user targets. |
| 77 `EFFECT_TWINEEDLE` | 41 (1; P) | yes | B | [`BattleScript_EffectTwineedle`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1072) | Two hits plus poison; existing double-hit does not supply secondary status sequence. |
| 78 `EFFECT_VITAL_THROW` | 233 (1; P) | yes | R / R8 | [`BattleScript_EffectHit`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L239) | Reviewed no-roll/high-critical/priority/HP-floor leaf; shared singles limitations apply. |
| 79 `EFFECT_SUBSTITUTE` | 164 (1; Z) | no | B | [`BattleScript_EffectSubstitute`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1082) | Substitute needs separate HP pool, interception and fade lifecycle. |
| 80 `EFFECT_RECHARGE` | 63, 307, 308, 338 (4; P) | yes | B | [`BattleScript_EffectRecharge`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1107) | Recharge needs skip-next-action state and expiry. |
| 81 `EFFECT_RAGE` | 99 (1; P) | yes | B | [`BattleScript_EffectRage`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1118) | Rage needs persistent flag, receiving-hit Attack response and reset. |
| 82 `EFFECT_MIMIC` | 102 (1; Z) | no | B | [`BattleScript_EffectMimic`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1130) | Copy-move command needs last-used move history, slot/PP provenance and temporary/permanent persistence. |
| 83 `EFFECT_METRONOME` | 118 (1; Z) | no | B | [`BattleScript_EffectMetronome`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1143) | Called-move selection/dispatch and exclusion rules absent; #274 additionally needs party move source. |
| 84 `EFFECT_LEECH_SEED` | 73 (1; Z) | no | B | [`BattleScript_EffectLeechSeed`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1153) | Seed/nightmare/roots need residual HP loop; #171 also sleep, #275 escape prevention. |
| 85 `EFFECT_SPLASH` | 150 (1; Z) | no | C | [`BattleScript_EffectSplash`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1168) | PP and no-effect presentation; source also incrementgamestat, so save-stat boundary must be decided. |
| 86 `EFFECT_DISABLE` | 50 (1; Z) | no | B | [`BattleScript_EffectDisable`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1179) | Move-history/counter/selection restriction commands absent; Spite also requires last-used-slot PP provenance. |
| 87 `EFFECT_LEVEL_DAMAGE` | 69, 101 (2; P) | yes | R / R7 | [`BattleScript_EffectLevelDamage`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1191) | Fixed 40/level/20 damage with shared accuracy, immunity and HP; no item/Endure state. |
| 88 `EFFECT_PSYWAVE` | 149 (1; P) | yes | R / R12 | [`BattleScript_EffectPsywave`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1202) | Reviewed rejection-sampled level damage/RNG including immunity; no ordinary critical/base damage. |
| 89 `EFFECT_COUNTER` | 68 (1; P) | yes | B | [`BattleScript_EffectCounter`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1213) | Damage-received history with source/category/turn identity absent. |
| 90 `EFFECT_ENCORE` | 227 (1; Z) | no | B | [`BattleScript_EffectEncore`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1223) | Move-history/counter/selection restriction commands absent; Spite also requires last-used-slot PP provenance. |
| 91 `EFFECT_PAIN_SPLIT` | 220 (1; Z) | yes | R / R15 | [`BattleScript_EffectPainSplit`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1235) | Reviewed admission exception and ordered own-max-clamped HP sharing; no generic healing or excluded state. |
| 92 `EFFECT_SNORE` | 173 (1; P) | yes | B | [`BattleScript_EffectSnore`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1253) | Sleeping-user gate absent; #173 adds flinch, #214 calls another move with special PP. |
| 93 `EFFECT_CONVERSION_2` | 176 (1; Z) | no | B | [`BattleScript_EffectConversion2`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1271) | settypetorandomresistance needs last landed move/type history. |
| 94 `EFFECT_LOCK_ON` | 170, 199 (2; Z) | no | B | [`BattleScript_EffectLockOn`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1282) | Sure-hit owner/expiry flag and accuracy-consumption hooks absent. |
| 95 `EFFECT_SKETCH` | 166 (1; Z) | no | B | [`BattleScript_EffectSketch`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1295) | Copy-move command needs last-used move history, slot/PP provenance and temporary/permanent persistence. |
| 96 `EFFECT_UNUSED_60` | none (0; —) | — | U | [`BattleScript_EffectHit`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L239) | No real move member; source aliases Hit. No runtime coverage/admission claim. |
| 97 `EFFECT_SLEEP_TALK` | 214 (1; Z) | no | B | [`BattleScript_EffectSleepTalk`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1307) | Sleeping-user gate absent; #173 adds flinch, #214 calls another move with special PP. |
| 98 `EFFECT_DESTINY_BOND` | 194 (1; Z) | no | B | [`BattleScript_EffectDestinyBond`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1330) | Destiny Bond/Grudge need volatile lifecycle and faint-time KO/PP response. |
| 99 `EFFECT_FLAIL` | 175, 179 (2; P) | yes | R / R11 | [`BattleScript_EffectFlail`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1341) | Reviewed current-HP power formula for one target; no multi-target or other dynamic-power interactions. |
| 100 `EFFECT_SPITE` | 180 (1; Z) | no | B | [`BattleScript_EffectSpite`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1345) | Move-history/counter/selection restriction commands absent; Spite also requires last-used-slot PP provenance. |
| 101 `EFFECT_FALSE_SWIPE` | 206 (1; P) | yes | R / R8 | [`BattleScript_EffectHit`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L239) | Reviewed no-roll/high-critical/priority/HP-floor leaf; shared singles limitations apply. |
| 102 `EFFECT_HEAL_BELL` | 215, 312 (2; Z) | no | B | [`BattleScript_EffectHealBell`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1357) | Party persistent status/cure missing; #215 checks Soundproof, #312 skips that branch. |
| 103 `EFFECT_QUICK_ATTACK` | 98, 183, 245 (3; P) | yes | R / R1 | [`BattleScript_EffectHit`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L239) | Ordinary hit plus existing priority ordering. |
| 104 `EFFECT_TRIPLE_KICK` | 167 (1; P) | yes | C | [`BattleScript_EffectTripleKick`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1380) | Per-hit accuracy/increasing-power loop differs from fixed double-hit; sequence/RNG/stop contract needed. |
| 105 `EFFECT_THIEF` | 168, 343 (2; P) | yes | B | [`BattleScript_EffectThief`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1436) | Item transfer/swap/recycle/removal needs held-item ownership, loss history and persistence. |
| 106 `EFFECT_MEAN_LOOK` | 169, 212, 335 (3; Z) | no | B | [`BattleScript_EffectMeanLook`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1440) | Escape-prevention owner and switch/run veto lifecycle absent. |
| 107 `EFFECT_NIGHTMARE` | 171 (1; Z) | no | B | [`BattleScript_EffectNightmare`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1455) | Seed/nightmare/roots need residual HP loop; #171 also sleep, #275 escape prevention. |
| 108 `EFFECT_MINIMIZE` | 107 (1; Z) | no | B | [`BattleScript_EffectMinimize`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1472) | Minimize sets volatile bit as well as evasion; damage interactions/reset absent. |
| 109 `EFFECT_CURSE` | 174 (1; Z) | no | B | [`BattleScript_EffectCurse`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1478) | Non-Ghost stat branch differs from Ghost HP-cost/residual curse; curse lifecycle absent. |
| 110 `EFFECT_UNUSED_6E` | none (0; —) | — | U | [`BattleScript_EffectHit`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L239) | No real move member; source aliases Hit. No runtime coverage/admission claim. |
| 111 `EFFECT_PROTECT` | 182, 197 (2; Z) | no | B | [`BattleScript_EffectProtect`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1528) | Shared setprotectlike requires counter/RNG, distinct Protect/Endure interception and turn reset. |
| 112 `EFFECT_SPIKES` | 191 (1; Z) | no | B | [`BattleScript_EffectSpikes`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1540) | Spikes needs side layers and switch-entry damage. |
| 113 `EFFECT_FORESIGHT` | 193, 316 (2; Z) | no | B | [`BattleScript_EffectForesight`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1551) | Foresight bit and accuracy/type consumers absent. |
| 114 `EFFECT_PERISH_SONG` | 195 (1; Z) | no | B | [`BattleScript_EffectPerishSong`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1563) | Perish counters and ordered end-turn faints absent; source visits all battlers/abilities. |
| 115 `EFFECT_SANDSTORM` | 201 (1; Z) | no | B | [`BattleScript_EffectSandstorm`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1585) | Weather duration/residual/damage/accuracy/ability/form hooks absent. |
| 116 `EFFECT_ENDURE` | 203 (1; Z) | no | B | [`BattleScript_EffectEndure`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1529) | Shared setprotectlike requires counter/RNG, distinct Protect/Endure interception and turn reset. |
| 117 `EFFECT_ROLLOUT` | 205, 301 (2; P) | yes | B | [`BattleScript_EffectRollout`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1592) | Rollout/Fury Cutter need hit-sequence counters and reset; #205/#301 additionally consume Defense Curl. |
| 118 `EFFECT_SWAGGER` | 207 (1; Z) | no | B | [`BattleScript_EffectSwagger`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1604) | Confusion duration/self-hit/action gate absent; #207/#260 also change stats, #298 loops non-user targets. |
| 119 `EFFECT_FURY_CUTTER` | 210 (1; P) | yes | B | [`BattleScript_EffectFuryCutter`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1627) | Rollout/Fury Cutter need hit-sequence counters and reset; #205/#301 additionally consume Defense Curl. |
| 120 `EFFECT_ATTRACT` | 213 (1; Z) | no | B | [`BattleScript_EffectAttract`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1641) | Infatuation needs gender, owner identity and action cancellation lifecycle. |
| 121 `EFFECT_RETURN` | 216 (1; P) | yes | B | [`BattleScript_EffectReturn`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1653) | Friendship formula lacks friendship retained in battler input. |
| 122 `EFFECT_PRESENT` | 217 (1; P) | yes | B | [`BattleScript_EffectPresent`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1660) | Random damage versus target-heal sequence and healing events absent. |
| 123 `EFFECT_FRUSTRATION` | 218 (1; P) | yes | B | [`BattleScript_EffectFrustration`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1654) | Friendship formula lacks friendship retained in battler input. |
| 124 `EFFECT_SAFEGUARD` | 219 (1; Z) | no | B | [`BattleScript_EffectSafeguard`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1668) | Safeguard side timer and primary/secondary status-prevention hooks absent. |
| 125 `EFFECT_THAW_HIT` | 172, 221 (2; P) | yes | B | [`BattleScript_EffectThawHit`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1675) | Burn secondary plus frozen-user thaw handling in action cancellation absent. |
| 126 `EFFECT_MAGNITUDE` | 222 (1; P) | yes | C | [`BattleScript_EffectMagnitude`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1679) | magnitudedamagecalculation plus underground/multi-target loop; possible singles subset needs explicit exclusions. |
| 127 `EFFECT_BATON_PASS` | 226 (1; Z) | no | B | [`BattleScript_EffectBatonPass`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1690) | Baton Pass needs selected volatile/stage transfer through switch; ordinary/faint switching is insufficient. |
| 128 `EFFECT_PURSUIT` | 228 (1; P) | yes | B | [`BattleScript_EffectHit`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L239) | Hit dispatch also has trypursuit interception in switching; interception/damage modifier absent. |
| 129 `EFFECT_RAPID_SPIN` | 229 (1; P) | yes | B | [`BattleScript_EffectRapidSpin`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1711) | Rapid Spin cleans trap/seed/spikes; state and cleanup hooks absent. |
| 130 `EFFECT_SONICBOOM` | 49 (1; P) | yes | R / R7 | [`BattleScript_EffectSonicboom`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1715) | Fixed 40/level/20 damage with shared accuracy, immunity and HP; no item/Endure state. |
| 131 `EFFECT_UNUSED_83` | none (0; —) | — | U | [`BattleScript_EffectHit`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L239) | No real move member; source aliases Hit. No runtime coverage/admission claim. |
| 132 `EFFECT_MORNING_SUN` | 234 (1; Z) | no | B | [`BattleScript_EffectMorningSun`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1726) | recoverbasedonsunlight needs weather/ability input and weather-aware heal. |
| 133 `EFFECT_SYNTHESIS` | 235 (1; Z) | no | B | [`BattleScript_EffectSynthesis`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1727) | recoverbasedonsunlight needs weather/ability input and weather-aware heal. |
| 134 `EFFECT_MOONLIGHT` | 236 (1; Z) | no | B | [`BattleScript_EffectMoonlight`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1728) | recoverbasedonsunlight needs weather/ability input and weather-aware heal. |
| 135 `EFFECT_HIDDEN_POWER` | 237 (1; P) | yes | B | [`BattleScript_EffectHiddenPower`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1735) | hiddenpowercalc needs retained IVs for type/power derivation. |
| 136 `EFFECT_RAIN_DANCE` | 240 (1; Z) | no | B | [`BattleScript_EffectRainDance`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1740) | Weather duration/residual/damage/accuracy/ability/form hooks absent. |
| 137 `EFFECT_SUNNY_DAY` | 241 (1; Z) | no | B | [`BattleScript_EffectSunnyDay`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1753) | Weather duration/residual/damage/accuracy/ability/form hooks absent. |
| 138 `EFFECT_DEFENSE_UP_HIT` | 211 (1; P) | yes | R / R5 | [`BattleScript_EffectDefenseUpHit`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1760) | One-stage secondary stat/chance RNG path; no Serene Grace/Shield Dust/Substitute or non-stat status effects. |
| 139 `EFFECT_ATTACK_UP_HIT` | 232, 309 (2; P) | yes | R / R5 | [`BattleScript_EffectAttackUpHit`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1764) | One-stage secondary stat/chance RNG path; no Serene Grace/Shield Dust/Substitute or non-stat status effects. |
| 140 `EFFECT_ALL_STATS_UP_HIT` | 246, 318 (2; P) | yes | C | [`BattleScript_EffectAllStatsUpHit`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1768) | MOVE_EFFECT_ALL_STATS_UP routes to ordered multi-stat script; combined event/chance contract needed. |
| 141 `EFFECT_UNUSED_8D` | none (0; —) | — | U | [`BattleScript_EffectHit`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L239) | No real move member; source aliases Hit. No runtime coverage/admission claim. |
| 142 `EFFECT_BELLY_DRUM` | 187 (1; Z) | no | C | [`BattleScript_EffectBellyDrum`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1772) | maxattackhalvehp HP cost/max Attack; threshold/rounding/failure/event order needed. |
| 143 `EFFECT_PSYCH_UP` | 244 (1; Z) | no | C | [`BattleScript_EffectPsychUp`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1786) | copyfoestats copies target stages; exact fields/failure/presentation contract needed. |
| 144 `EFFECT_MIRROR_COAT` | 243 (1; P) | yes | B | [`BattleScript_EffectMirrorCoat`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1797) | Damage-received history with source/category/turn identity absent. |
| 145 `EFFECT_SKULL_BASH` | 130 (1; P) | yes | B | [`BattleScript_EffectSkullBash`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1807) | Charge/second-turn script needs locked move state; #143 also flinches, #130 raises Defense on charge. |
| 146 `EFFECT_TWISTER` | 239 (1; P) | yes | B | [`BattleScript_EffectTwister`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1822) | Twister checks airborne state for double damage and adds flinch; airborne and action-cancellation lifecycle absent. |
| 147 `EFFECT_EARTHQUAKE` | 89 (1; P) | yes | B | [`BattleScript_EffectEarthquake`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1830) | Earthquake selects/loops targets and doubles against underground state; multi-target and semi-invulnerability absent. |
| 148 `EFFECT_FUTURE_SIGHT` | 248, 353 (2; P) | yes | B | [`BattleScript_EffectFutureSight`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1877) | Delayed attack/Wish needs side/slot scheduling across turns/replacements. |
| 149 `EFFECT_GUST` | 16 (1; P) | yes | B | [`BattleScript_EffectGust`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1888) | Gust checks airborne state for doubled damage; airborne hit-state contract absent. |
| 150 `EFFECT_FLINCH_MINIMIZE_HIT` | 23, 302, 310, 326 (4; P) | yes | B | [`BattleScript_EffectStomp`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1894) | Shared Stomp script checks minimized state, doubles damage and adds flinch for all four member IDs; both volatile paths absent. |
| 151 `EFFECT_SOLAR_BEAM` | 76 (1; P) | yes | B | [`BattleScript_EffectSolarBeam`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1899) | Solar Beam requires weather/ability branch, charge/release and locked-move state. |
| 152 `EFFECT_THUNDER` | 87 (1; P) | yes | B | [`BattleScript_EffectThunder`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1916) | Thunder adds paralysis, ignores airborne state and has weather-aware accuracy; status/weather/airborne paths absent. |
| 153 `EFFECT_TELEPORT` | 100 (1; Z) | no | B | [`BattleScript_EffectTeleport`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1921) | Teleport needs trainer/wild escape restrictions and explicit outcome/controller handling beyond ordinary run. |
| 154 `EFFECT_BEAT_UP` | 251 (1; P) | yes | B | [`BattleScript_EffectBeatUp`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1936) | Beat Up needs eligible-party contributor/base-stat input. |
| 155 `EFFECT_SEMI_INVULNERABLE` | 19, 91, 291, 340 (4; P) | yes | B | [`BattleScript_EffectSemiInvulnerable`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1969) | #19 Fly/#91 Dig/#291 Dive/#340 Bounce use distinct airborne/underground/underwater charge states; #340 also paralyzes. Charge/state/status lifecycle absent. |
| 156 `EFFECT_DEFENSE_CURL` | 111 (1; Z) | no | B | [`BattleScript_EffectDefenseCurl`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2010) | Defense Curl adds volatile flag used by Rollout/Ice Ball; interaction/reset absent. |
| 157 `EFFECT_SOFTBOILED` | 135, 208 (2; Z) | no | C | [`BattleScript_EffectSoftboiled`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2023) | tryhealhalfhealth BS_TARGET; #135/#208 share battle healing and have field use; scope separate from effect32. |
| 158 `EFFECT_FAKE_OUT` | 252 (1; P) | yes | B | [`BattleScript_EffectFakeOut`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2044) | Fake Out needs per-battler first-turn tracking and certain flinch cancellation. |
| 159 `EFFECT_UPROAR` | 253 (1; P) | yes | B | [`BattleScript_EffectUproar`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2068) | Uproar needs repeat lock/duration, wake/sleep suppression and end-turn lifecycle. |
| 160 `EFFECT_STOCKPILE` | 254 (1; Z) | no | B | [`BattleScript_EffectStockpile`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2079) | Stockpile count and Spit Up/Swallow damage/heal consumption paths absent. |
| 161 `EFFECT_SPIT_UP` | 255 (1; P) | yes | B | [`BattleScript_EffectSpitUp`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2090) | Stockpile count and Spit Up/Swallow damage/heal consumption paths absent. |
| 162 `EFFECT_SWALLOW` | 256 (1; Z) | no | B | [`BattleScript_EffectSwallow`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2115) | Stockpile count and Spit Up/Swallow damage/heal consumption paths absent. |
| 163 `EFFECT_UNUSED_A3` | none (0; —) | — | U | [`BattleScript_EffectHit`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L239) | No real move member; source aliases Hit. No runtime coverage/admission claim. |
| 164 `EFFECT_HAIL` | 258 (1; Z) | no | B | [`BattleScript_EffectHail`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2128) | Weather duration/residual/damage/accuracy/ability/form hooks absent. |
| 165 `EFFECT_TORMENT` | 259 (1; Z) | no | B | [`BattleScript_EffectTorment`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2135) | Move-history/counter/selection restriction commands absent; Spite also requires last-used-slot PP provenance. |
| 166 `EFFECT_FLATTER` | 260 (1; Z) | no | B | [`BattleScript_EffectFlatter`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2147) | Confusion duration/self-hit/action gate absent; #207/#260 also change stats, #298 loops non-user targets. |
| 167 `EFFECT_WILL_O_WISP` | 261 (1; Z) | no | B | [`BattleScript_EffectWillOWisp`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2170) | Primary status setter/preconditions; persistent status, action prevention/residual effects and save/UI lifecycle absent. |
| 168 `EFFECT_MEMENTO` | 262 (1; Z) | no | C | [`BattleScript_EffectMemento`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2199) | trymemento/setatkhptozero then two stat drops/faint; existing faint state, failure/order/exclusion design needed. |
| 169 `EFFECT_FACADE` | 263 (1; P) | yes | B | [`BattleScript_EffectFacade`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2247) | Status-dependent damage missing; #265 additionally cures target paralysis. |
| 170 `EFFECT_FOCUS_PUNCH` | 264 (1; P) | yes | B | [`BattleScript_EffectFocusPunch`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2255) | Damage-received history with source/category/turn identity absent. |
| 171 `EFFECT_SMELLINGSALT` | 265 (1; P) | yes | B | [`BattleScript_EffectSmellingsalt`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2263) | Status-dependent damage missing; #265 additionally cures target paralysis. |
| 172 `EFFECT_FOLLOW_ME` | 266 (1; Z) | no | B | [`BattleScript_EffectFollowMe`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2272) | Target redirection/helping-hand needs doubles ally/target model. |
| 173 `EFFECT_NATURE_POWER` | 267 (1; Z) | no | B | [`BattleScript_EffectNaturePower`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2283) | Terrain selects called move/secondary/type; terrain input and corresponding dispatch/status changes absent. |
| 174 `EFFECT_CHARGE` | 268 (1; Z) | no | B | [`BattleScript_EffectCharge`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2292) | Charge volatile timer and later Electric-damage consumption/reset absent. |
| 175 `EFFECT_TAUNT` | 269 (1; Z) | no | B | [`BattleScript_EffectTaunt`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2303) | Move-history/counter/selection restriction commands absent; Spite also requires last-used-slot PP provenance. |
| 176 `EFFECT_HELPING_HAND` | 270 (1; Z) | no | B | [`BattleScript_EffectHelpingHand`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2315) | Target redirection/helping-hand needs doubles ally/target model. |
| 177 `EFFECT_TRICK` | 271 (1; Z) | no | B | [`BattleScript_EffectTrick`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2326) | Item transfer/swap/recycle/removal needs held-item ownership, loss history and persistence. |
| 178 `EFFECT_ROLE_PLAY` | 272 (1; Z) | no | B | [`BattleScript_EffectRolePlay`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2341) | Copy/swap abilities need general ability state beyond bounded Damp check. |
| 179 `EFFECT_WISH` | 273 (1; Z) | no | B | [`BattleScript_EffectWish`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2353) | Delayed attack/Wish needs side/slot scheduling across turns/replacements. |
| 180 `EFFECT_ASSIST` | 274 (1; Z) | no | B | [`BattleScript_EffectAssist`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2362) | Called-move selection/dispatch and exclusion rules absent; #274 additionally needs party move source. |
| 181 `EFFECT_INGRAIN` | 275 (1; Z) | no | B | [`BattleScript_EffectIngrain`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2372) | Seed/nightmare/roots need residual HP loop; #171 also sleep, #275 escape prevention. |
| 182 `EFFECT_SUPERPOWER` | 276 (1; P) | yes | C | [`BattleScript_EffectSuperpower`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2383) | Certain post-hit self Attack/Defense drops; combined stat-effect sequencing absent. |
| 183 `EFFECT_MAGIC_COAT` | 277 (1; Z) | no | B | [`BattleScript_EffectMagicCoat`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2387) | Magic Coat/Snatch need turn-local owner, action interception/redirection and effect filtering. |
| 184 `EFFECT_RECYCLE` | 278 (1; Z) | no | B | [`BattleScript_EffectRecycle`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2398) | Item transfer/swap/recycle/removal needs held-item ownership, loss history and persistence. |
| 185 `EFFECT_REVENGE` | 279 (1; P) | yes | B | [`BattleScript_EffectRevenge`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2409) | Damage-received history with source/category/turn identity absent. |
| 186 `EFFECT_BRICK_BREAK` | 280 (1; P) | yes | C | [`BattleScript_EffectBrickBreak`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2413) | removelightscreenreflect before damage; side fields exist, removal/immunity/order contract needed. |
| 187 `EFFECT_YAWN` | 281 (1; Z) | no | B | [`BattleScript_EffectYawn`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2446) | Yawn needs delayed sleep and status/ability/Safeguard branches. |
| 188 `EFFECT_KNOCK_OFF` | 282 (1; P) | yes | B | [`BattleScript_EffectKnockOff`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2470) | Item transfer/swap/recycle/removal needs held-item ownership, loss history and persistence. |
| 189 `EFFECT_ENDEAVOR` | 283 (1; P) | yes | R / R14 | [`BattleScript_EffectEndeavor`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2474) | Reviewed pre-accuracy HP comparison/difference and generic failure; no Protect/Substitute/Endure. |
| 190 `EFFECT_ERUPTION` | 284, 323 (2; P) | yes | R / R11 | [`BattleScript_EffectEruption`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2488) | Reviewed current-HP power formula for one target; no multi-target or other dynamic-power interactions. |
| 191 `EFFECT_SKILL_SWAP` | 285 (1; Z) | no | B | [`BattleScript_EffectSkillSwap`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2492) | Copy/swap abilities need general ability state beyond bounded Damp check. |
| 192 `EFFECT_IMPRISON` | 286 (1; Z) | no | B | [`BattleScript_EffectImprison`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2504) | Move-history/counter/selection restriction commands absent; Spite also requires last-used-slot PP provenance. |
| 193 `EFFECT_REFRESH` | 287 (1; Z) | no | B | [`BattleScript_EffectRefresh`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2515) | Refresh needs persistent status plus cure/update semantics. |
| 194 `EFFECT_GRUDGE` | 288 (1; Z) | no | B | [`BattleScript_EffectGrudge`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2527) | Destiny Bond/Grudge need volatile lifecycle and faint-time KO/PP response. |
| 195 `EFFECT_SNATCH` | 289 (1; Z) | no | B | [`BattleScript_EffectSnatch`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2538) | Magic Coat/Snatch need turn-local owner, action interception/redirection and effect filtering. |
| 196 `EFFECT_LOW_KICK` | 67 (1; P) | yes | B | [`BattleScript_EffectLowKick`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2550) | Low Kick needs species-weight input and category formula. |
| 197 `EFFECT_SECRET_POWER` | 290 (1; P) | yes | B | [`BattleScript_EffectSecretPower`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2558) | Terrain selects called move/secondary/type; terrain input and corresponding dispatch/status changes absent. |
| 198 `EFFECT_DOUBLE_EDGE` | 38, 344 (2; P) | yes | R / R2 | [`BattleScript_EffectDoubleEdge`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2562) | Third actual-damage recoil for both #38 and #344; Gen 3 source determines behavior. |
| 199 `EFFECT_TEETER_DANCE` | 298 (1; Z) | no | B | [`BattleScript_EffectTeeterDance`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2566) | Confusion duration/self-hit/action gate absent; #207/#260 also change stats, #298 loops non-user targets. |
| 200 `EFFECT_BLAZE_KICK` | 299 (1; P) | yes | B | [`BattleScript_EffectBurnHit`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L364) | Burn/poison script plus special Cmd_critcalc stage; status and exact critical-effect dispatch absent. |
| 201 `EFFECT_MUD_SPORT` | 300 (1; Z) | no | B | [`BattleScript_EffectMudSport`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2620) | Mud/Water Sport volatile halvers and field-wide damage/reset consumers absent. |
| 202 `EFFECT_POISON_FANG` | 305 (1; P) | yes | B | [`BattleScript_EffectPoisonFang`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2632) | Non-stat secondary status via setmoveeffect/seteffectwithchance; application/RNG/persistence/lifecycle absent. |
| 203 `EFFECT_WEATHER_BALL` | 311 (1; P) | yes | B | [`BattleScript_EffectWeatherBall`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2636) | Weather Ball needs weather-derived type/power. |
| 204 `EFFECT_OVERHEAT` | 315, 354 (2; P) | yes | C | [`BattleScript_EffectOverheat`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2640) | Certain self Special Attack drop for #315/#354; exact hit/failure ordering unimplemented. |
| 205 `EFFECT_TICKLE` | 321 (1; Z) | no | C | [`BattleScript_EffectTickle`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2644) | Ordered multi-stat changes and partial success; fields exist, new event/admission contract needed. |
| 206 `EFFECT_COSMIC_POWER` | 322 (1; Z) | no | C | [`BattleScript_EffectCosmicPower`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2679) | Ordered multi-stat changes and partial success; fields exist, new event/admission contract needed. |
| 207 `EFFECT_SKY_UPPERCUT` | 327 (1; P) | yes | B | [`BattleScript_EffectSkyUppercut`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2704) | Sky Uppercut ignores airborne state via hit marker; semi-invulnerability/accuracy interaction absent. |
| 208 `EFFECT_BULK_UP` | 339 (1; Z) | no | C | [`BattleScript_EffectBulkUp`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2708) | Ordered multi-stat changes and partial success; fields exist, new event/admission contract needed. |
| 209 `EFFECT_POISON_TAIL` | 342 (1; P) | yes | B | [`BattleScript_EffectPoisonHit`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L321) | Burn/poison script plus special Cmd_critcalc stage; status and exact critical-effect dispatch absent. |
| 210 `EFFECT_WATER_SPORT` | 346 (1; Z) | no | B | [`BattleScript_EffectWaterSport`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2621) | Mud/Water Sport volatile halvers and field-wide damage/reset consumers absent. |
| 211 `EFFECT_CALM_MIND` | 347 (1; Z) | no | C | [`BattleScript_EffectCalmMind`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2733) | Ordered multi-stat changes and partial success; fields exist, new event/admission contract needed. |
| 212 `EFFECT_DRAGON_DANCE` | 349 (1; Z) | no | C | [`BattleScript_EffectDragonDance`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2765) | Ordered multi-stat changes and partial success; fields exist, new event/admission contract needed. |
| 213 `EFFECT_CAMOUFLAGE` | 293 (1; Z) | no | B | [`BattleScript_EffectCamouflage`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2790) | Terrain selects called move/secondary/type; terrain input and corresponding dispatch/status changes absent. |

## Existing represented evidence

Every R row is tied to executable branches in
[BattleEngine](../../src/core/BattleEngine.lua), shared formula behavior in
[BattleFormulas](../../src/core/BattleFormulas.lua), and existing assertions in
[battle_engine_test](../../tests/battle_engine_test.lua) and
[battle_formulas_test](../../tests/battle_formulas_test.lua). The inventory test
proves data membership/admission only; it does not upgrade these existing tests
into exhaustive state coverage.

| Code | Implementation/source scope | Additional established evidence |
| --- | --- | --- |
| R1 | resolveMove ordinary hit; runTurn priority; source Hit script and Cmd_accuracycheck/critcalc/damagecalc | Existing ordinary miss/type/critical/priority tests; Surf submerged interaction excluded |
| R2 | DRAIN_MOVES/RECOIL_MOVES; actual-damage heal/recoil; Struggle no-PP/type branch; Cmd_negativedamage and SetMoveEffect | Existing drain/recoil/maxHP/immunity/Struggle/faint-order engine tests |
| R3 | MULTI_HIT_MOVES and resolveMultiHit; source multi-hit loop/setmultihitcounter | Existing deterministic count, PP/RNG, per-hit damage, early-faint and immunity tests |
| R4 | STAT_STAGE_MOVES; EffectStatUp/Down and ChangeStatBuffs | Existing stage limits, self/foe accuracy, stat/PP/RNG and unsupported-effect tests |
| R5 | HIT_VARIANT_STAT_MOVES; source seteffectwithchance/SetMoveEffect | Existing secondary chance/target/stat caps/no-effect RNG tests |
| R6 | SCREEN_MOVES, resolveScreenMove, decaySideTimers; source setreflect/setlightscreen | Existing duplicate failure, damage/critical bypass, timer/persistence tests |
| R7 | FIXED_DAMAGE_MOVES; fixed/level damage command paths | [fixed-record test](../../tests/phase4_fixed_damage_effect_rom_test.lua), accepted [task](../tasks/phase4-fixed-damage-effects.md) |
| R8 | Effect-specific no-roll, critical stage, False Swipe floor, existing priority | [always-hit](../../tests/phase4_always_hit_effect_rom_test.lua), [high-critical](../../tests/phase4_high_critical_effect_rom_test.lua), [Vital Throw](../../tests/phase4_vital_throw_effect_rom_test.lua), [False Swipe](../../tests/phase4_false_swipe_effect_rom_test.lua) record/engine tests and corresponding accepted task contracts |
| R9 | Explosion-only self-KO/Damp/defense/RNG/faint sequence | [record test](../../tests/phase4_explosion_effect_rom_test.lua), [task](../tasks/phase4-explosion-effects.md), two-sided replacement tests |
| R10 | CURRENT_HP_DAMAGE_MOVES and post-immunity half-HP path | [record test](../../tests/phase4_super_fang_effect_rom_test.lua), [task](../tasks/phase4-super-fang-effects.md) |
| R11 | flailPowerFromHP / eruptionPowerFromHP | [Flail](../../tests/phase4_flail_effect_rom_test.lua), [Eruption](../../tests/phase4_eruption_effect_rom_test.lua) fixtures and accepted task contracts |
| R12 | Psywave post-type rejection sampling | [record test](../../tests/phase4_psywave_effect_rom_test.lua), [task](../tasks/phase4-psywave-effects.md) |
| R13 | OHKO level/one-roll represented subset | [record test](../../tests/phase4_ohko_effect_rom_test.lua), [task](../tasks/phase4-ohko-effects.md) |
| R14 | Endeavor PP-before-viability, failure event and HP difference | [record test](../../tests/phase4_endeavor_effect_rom_test.lua), [task](../tasks/phase4-endeavor-effects.md) |
| R15 | Pain Split literal zero-power admission, no-RNG ordered HP and scene entries | [record test](../../tests/phase4_pain_split_effect_rom_test.lua), [exact independent review](../reviews/2026-09-20-pain-split-implementation-review.md) |
| J1 | EFFECT_DREAM_EATER explicit supportsMove rejection and sleeping-target source gate | Existing rejection test; source DreamEater script linked in matrix |

For uncovered rows the script command is evidence of a missing requirement,
not a full source lock of that command's branches or RNG schedule. Concrete
command inspections include `Cmd_tryhealhalfhealth` (6332),
`Cmd_normalisebuffs` (6826), `Cmd_friendshiptodamagecalculation` (8228),
`Cmd_maxattackhalvehp` (8399), `Cmd_copyfoestats` (8423),
`Cmd_weightdamagecalculation` (9074), and
`Cmd_removelightscreenreflect` (9441) in pinned
[battle_script_commands.c](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/battle_script_commands.c).
`SetMoveEffect` routes multi-stat secondaries to dedicated scripts and handles
Pay Day's accumulator; a generic damage event cannot substitute for them.
Pursuit is deliberately not classified as covered despite dispatching to Hit:
[switch interception](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/battle_script_commands.c#L8359) is separate.

## Shortlist and exactly one proposed successor

Prioritize demonstrated early-story use, then prerequisite cost and bounded
testability. The following urgency order distinguishes early need from readiness
for a single isolated leaf. It does not claim the corresponding full trainers
are playable or complete.

| Early-story priority | Source-backed use | Missing cost / testability | Discovery readiness |
| --- | --- | --- | --- |
| 1. Poison-hit effect2 | [Rick's level-6 Weedle](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/data/trainer_parties.h#L273) and [Weedle level-1 MOVE_POISON_STING](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/data/pokemon/level_up_learnsets.h#L179) | Persistent poison, end-turn HP, status UI/save and immunity/RNG branches; high cost | Blocked on a separately designed status subsystem |
| 2. Defense Curl effect156 | [Brock's Geodude custom moves](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/data/trainer_parties.h#L5604) | Defense stage exists, but the source also sets a volatile Defense Curl bit consumed by Rollout/Ice Ball; reset/interaction contract needed | Blocked; cannot silently count a stage-only implementation as the family |
| 3. Trap effect42 | [Brock's Onix custom moves](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/data/trainer_parties.h#L5615) | Bind duration/residual HP and run/switch veto; new persistent turn-state path | Blocked on trap lifecycle design |
| 4. Restore-HP effect32 | [Misty's Staryu and Starmie](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/data/trainer_parties.h#L5619) both explicitly have MOVE_RECOVER | Existing HP/maxHP; exact half-max rounding, full-HP failure, PP and presentation form a small isolated matrix | **Selected next source-lock discovery** |

Propose exactly one successor: **effect32 (`EFFECT_RESTORE_HP`), move IDs
105 and 303, represented singles source-lock discovery**. The source script
runs cancellation/announcement/PP, then `tryhealhalfhealth BS_ATTACKER` without
ordinary accuracy or damage. The command uses floor(maxHP/2), promotes zero
to one, and fails when already at full HP; normal HP update clamps healing.
This is enough to justify discovery, not implementation. That next task should
lock success/failure/rounding/PP/RNG/event sequencing and determine a literal
admission exception and dedicated presentation boundary before design/route work.
Do not bundle Softboiled/Milk Drink (effect157), weather healing (132–134),
Rest, Present, Wish, Swallow, Ingrain, or a generic healing API.

Misty is evidence of real need, not a completion claim: her roster also contains
uncovered Water Pulse/Rapid Spin; [trainer data](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/data/trainers.h#L4145)
specifies AI flags and a trainer item. Choosing Recover does not resolve those
trainer, status, hazard, AI or item prerequisites.

## Verification and handoff

Baseline at preparation base passed all **149 no-ROM test files**. A separate
source-only scan confirmed the aggregates above and actual current admission
**248/106**. The new test's literal partition check passes before its explicit
no-ROM skip; `loadfile` syntax validation passes. The full post-change suite
passed **150 no-ROM test files**. A separate in-memory source-metadata harness
passed its positive case and five rejection cases (wrong effect, wrong power
class, missing record, admission drift, rejected SHA). That harness stubs the
importer/SHA and is test-logic evidence only, never ROM confirmation. No local
ROM was opened.

The expected source aggregates still require the **non-skipped private-runner
SHA-verified full suite** through the dedicated inventory route. Focused and
no-ROM skips are not substitutes. The test fails on discrepancies, prints only
aggregate counts/mismatch categories, and does not repair expectations to match
observations. Semantic classifications require independent source/code review;
even a passing ROM admission check is not behavioral parity.

Exact route-configuration review and its separate probe must pass before a
request may be published. This prepared report/test does not close P4-02.
Independent review must inspect the exact eventual implementation revision and
guarded run, then Orchestrator may select the proposed one discovery contract.
Phase 2 reference media and Phase 4's general exit gate remain open.
