# Effect-45 recoil-on-miss source discovery

- Task: [P4-F1-RECOIL-IF-MISS-DISCOVERY](../tasks/phase4-recoil-if-miss-source-discovery.md).
- Status: `DISCOVERY COMPLETE — PENDING INDEPENDENT EXACT-REPORT REVIEW`.
- Type: `PHASE 4 / BATTLE RULES / READ-ONLY SOURCE LOCK`.
- Project inspection base: `dad1274d6fbab88ca99a56169fde22142ec19bf6`.
- Public source pin: `pret/pokefirered c75f352304d529f6ba92d4f74b9cf8b5c3810788`.

This report locks only `EFFECT_RECOIL_IF_MISS` (45), the Jump Kick/Hi Jump
Kick crash-on-miss family. It does not implement the effect, repair the broad
positive-power admission fallback, add an event, or authorize a design,
route, ROM check, or test package.

## Identity and exact move records

The pinned effect constants define `EFFECT_RECOIL_IF_MISS = 45` at
[`battle_move_effects.h:47`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/include/constants/battle_move_effects.h#L47).
The complete pinned move table has exactly two records with this effect:

| Move | ID | Effect | Power | Type | Accuracy | PP | Secondary chance | Target | Priority | Flags |
| --- | ---: | ---: | ---: | --- | ---: | ---: | ---: | --- | ---: | --- |
| Jump Kick | 26 | 45 | 70 | Fighting | 95 | 25 | 0 | `MOVE_TARGET_SELECTED` (0) | 0 | Makes contact, Protect-affected, Mirror Move-affected, King's Rock-affected |
| Hi Jump Kick | 136 | 45 | 85 | Fighting | 90 | 20 | 0 | `MOVE_TARGET_SELECTED` (0) | 0 | Makes contact, Protect-affected, Mirror Move-affected, King's Rock-affected |

The records are [Jump Kick, `battle_moves.h:314-325`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/data/battle_moves.h#L314-L325)
and [Hi Jump Kick, `battle_moves.h:1634-1645`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/data/battle_moves.h#L1634-L1645).
The move IDs are [26 and 136 in `moves.h`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/include/constants/moves.h#L28-L29)
and [136](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/include/constants/moves.h#L138).
The effect table routes effect 45 to `BattleScript_EffectRecoilIfMiss` at
[`battle_scripts_1.s:67`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L67).

No other pinned move record is assigned effect 45. The selection is therefore
the two-record family, not a generic recoil or generic crash behavior. The
ordinary `EFFECT_RECOIL = 48` family (Take Down, Submission, and Struggle) and
`EFFECT_DOUBLE_EDGE = 198` are distinct effects and are not bundled here.

## Locked source control flow

The owner is
[`BattleScript_EffectRecoilIfMiss:810-833`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L810-L833).
The following is the source order for ordinary valid represented battlers,
with shared cancellation/interception state recorded as a boundary rather than
silently approximated.

### Common entry and successful hit

1. `attackcanceler` runs first. It can stop the move for battle outcome,
   fainted attacker, inability-to-act/obedience paths, ability interception,
   no PP, and other shared cancellation state. The command begins at
   [`battle_script_commands.c:798`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/battle_script_commands.c#L798).
2. `accuracycheck BattleScript_MoveMissedDoDamage, ACC_CURR_MOVE` consumes the
   ordinary accuracy decision for effect 45. The move records' 95 and 90
   accuracy fields are therefore real accuracy inputs; effect 45 is not an
   always-hit exception. The accuracy command's normal random comparison is
   [`battle_script_commands.c:971-1064`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/battle_script_commands.c#L971-L1064).
3. On a successful accuracy check, control jumps to
   `BattleScript_HitFromAtkString`, the ordinary sequence:
   `attackstring`, `ppreduce`, `critcalc`, `damagecalc`, `typecalc`,
   `adjustnormaldamage`, attack animation/wait, target HP bar/data update,
   result presentation, secondary-effect dispatch, target faint check, and
   common `BattleScript_MoveEnd`. The shared sequence is visible at
   [`battle_scripts_1.s:241-269`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L241-L269).
4. A successful hit has no extra crash damage. It is an ordinary damaging
   hit using the move's 70/85 power and Fighting type. If ordinary typecalc
   makes it ineffective, the normal hit path does not mutate target HP; the
   miss-only crash branch is not entered merely because the type result is
   zero.

### Accuracy miss branch

On the accuracy miss edge, control enters `BattleScript_MoveMissedDoDamage`:

1. `attackstring` then `ppreduce` run on this branch. Thus an ordinary miss
   still announces the used move and spends one PP, subject to the shared
   cancellation/no-PP/interception rules that can prevent reaching this
   branch. `Cmd_attackstring` and `Cmd_ppreduce` are at
   [`battle_script_commands.c:1067-1119`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/battle_script_commands.c#L1067-L1119).
2. The script pauses for `B_WAIT_TIME_LONG`, emits `resultmessage`, waits
   again, then tests `MOVE_RESULT_DOESNT_AFFECT_FOE` before doing crash
   damage. If that bit is already set, it jumps straight to common
   `BattleScript_MoveEnd`; no crash string or attacker HP mutation occurs.
   This is a pre-existing no-effect/failed-move gate, not a post-damage type
   recalculation.
3. Otherwise it prints `STRINGID_PKMNCRASHED` and waits. This is a distinct
   source-visible crash message after the miss result, not the ordinary
   damage/recoil message. The script does not run `attackanimation`,
   `effectivenesssound`, target `healthbarupdate`, or target `datahpupdate` on
   this branch.
4. It then runs `damagecalc`, `typecalc`, and `adjustnormaldamage`. There is no
   `critcalc` in this miss branch. `Cmd_damagecalc` calls the ordinary
   `CalculateBaseDamage` core and applies the current critical/damage
   multipliers; `Cmd_adjustnormaldamage` performs the source 85-100% random
   damage adjustment and shared item/endure/focus-band checks. The relevant
   command owners are
   [`battle_script_commands.c:1158-1170`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/battle_script_commands.c#L1158-L1170)
   and
   [`battle_script_commands.c:1503-1541`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/battle_script_commands.c#L1503-L1541).
   The effect-specific branch does not claim that item/endure state is
   represented by this project.
5. `manipulatedamage DMG_RECOIL_FROM_MISS` transforms the computed damage in
   [`battle_script_commands.c:6100-6118`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/battle_script_commands.c#L6100-L6118):
   integer-divide by two, promote zero to one, then cap the result to
   `floor(target.maxHP / 2)`. The cap is based on the *target* max HP even
   though the resulting damage is applied to the attacker. There is no second
   minimum-one step after the cap; a max-HP-one target therefore exposes the
   literal zero-after-cap edge. This is the source formula and must not be
   replaced with ordinary 25%/33% recoil or an attacker-max-HP cap.
6. The script clears `MOVE_RESULT_MISSED`, sets
   `HITMARKER_IGNORE_SUBSTITUTE`, updates the attacker's health bar and data,
   and runs `tryfaintmon BS_ATTACKER`. The attacker can faint from the crash;
   the target is not damaged and no target faint check occurs on this branch.
   It then restores `MOVE_RESULT_MISSED` and enters common MoveEnd. The
   `IGNORE_SUBSTITUTE` marker is a source detail; it is not permission to
   invent Substitute state in the bounded project.

The ordering has two important consequences. First, the no-effect guard is
tested before the branch's own `typecalc`; it gates pre-existing
`MOVE_RESULT_DOESNT_AFFECT_FOE` state from cancellation/protection-like paths,
not a newly computed type immunity. A hit that reaches ordinary typecalc and
is Fighting-immune follows the ordinary no-effect hit route and does not
automatically become a crash. Second, crash damage's random draws are after
the accuracy-miss draw and after the crash/result messages; there is no
additional accuracy or crit roll inside the crash branch.

## RNG, PP, faint, and presentation boundaries

- **Accuracy:** effect 45 uses the normal accuracy check (one accuracy draw
  when that command reaches its ordinary random comparison). Shared
  cancellation, semi-invulnerability, protection, and sure-hit paths can
  short-circuit or redirect that command; this report does not collapse them
  into a single RNG claim.
- **PP:** one ordinary PP reduction follows the accuracy decision on both the
  normal hit path and the miss branch. A no-PP/cancellation path can end before
  `ppreduce`, as in the shared source command. There is no PP refund after the
  crash or after attacker faint.
- **Crash amount:** base damage, type calculation and normal 85-100% damage
  adjustment happen before the effect-45 half-and-target-maxHP cap. The
  source's `DMG_RECOIL_FROM_MISS` operation is not the ordinary recoil-family
  fraction of actual target HP damage.
- **Faint ordering:** only `tryfaintmon BS_ATTACKER` is present after the
  crash HP update. The ordinary successful path separately checks the target
  after its target HP update. The crash branch therefore can produce an
  attacker faint without a target HP change.
- **Messages/events:** the source-visible sequence is used-move announcement,
  miss result, crash message when the pre-existing no-effect bit is absent,
  attacker HP-bar/data update, optional attacker faint, then common MoveEnd.
  Exact wait constants and message text are source constants; this report
  does not claim LÖVE timing or visual parity.

## Current project comparison

Project anchors are from inspection base `dad1274` and are evidence of seams,
not a change authorization.

| Source requirement | Existing project seam | Gap / boundary |
| --- | --- | --- |
| Admit exactly effect 45 records | [`BattleEngine:supportsMove:860-870`](../../src/core/BattleEngine.lua#L860) admits positive-power moves through the broad fallback | Jump Kick and Hi Jump Kick are admitted as ordinary positive-power moves, but the effect-specific miss branch is absent; admission is not implementation parity. |
| Accuracy then PP | [`resolveMove:1042-1078`](../../src/core/BattleEngine.lua#L1042) performs ordinary accuracy, decrements PP on both outcomes, and emits `miss` | This ordering is a useful seam for effect 45, but no crash path follows `not hit`; it returns immediately. |
| Ordinary successful hit | [`resolveMove:1210-1310`](../../src/core/BattleEngine.lua#L1210) has crit/base/type/random damage and target HP handling | The successful effect-45 route is close to the shared hit route; no new recoil-on-hit is implied. Existing state limits still apply. |
| Source crash damage | [`BattleFormulas.calculateBaseDamage`](../../src/core/BattleFormulas.lua#L228) and [`applyRandomDamageMultiplier`](../../src/core/BattleFormulas.lua#L412) provide reusable formula seams | No caller applies them after a miss, no target-maxHP half cap exists, and no effect-45 amount/event contract exists. Existing `RECOIL_MOVES` is actual-hit recoil and is not a substitute. |
| Self HP update and attacker faint | [`checkFaint` and `applyDamage`](../../src/core/BattleEngine.lua#L779-L857) plus existing recoil handling at `1326-1337` | Existing `applyDamage` targets the defender; existing recoil is derived from actual target damage. A miss crash must mutate attacker only and check attacker faint before MoveEnd. |
| No-effect route | [`resolveMove:1284-1298`](../../src/core/BattleEngine.lua#L1284) emits `noEffect` and returns after typecalc | This represents ordinary successful type immunity, not the source miss-branch pre-existing `DOESNT_AFFECT_FOE` guard. The distinction must remain explicit. |
| Source crash message and ordered HP presentation | Controller maps `miss`, `damage`, and `recoil` at [`BattleSceneController.lua:186-212`](../../src/core/BattleSceneController.lua#L186) and `258-264` | No crash-specific event/message exists. Reusing ordinary recoil would misstate the cause/order and ordinary miss currently has no HP event. |
| Persist HP/PP | [`BattlePartyBridge.persistPartyBattler:178-192`](../../src/core/BattlePartyBridge.lua#L178) persists current HP and PP | A persistence seam exists, but no effect-45 crash integration is verified or authorized by discovery. |

The exact current mismatch is therefore narrow and concrete: effect 45 is
admitted, and successful hits use the generic hit path, but a missed Jump
Kick/Hi Jump Kick emits only the generic `miss` event and returns without the
source's crash message, target-maxHP-capped half-damage formula, attacker HP
update, or attacker faint check.

## Hard unresolved exclusions and smallest future boundary

The source's `attackcanceler`, protection/interception flags, Substitute
marker, held-item/endure/focus-band behavior in normal damage adjustment,
abilities, status, semi-invulnerability, doubles/links, called/mirrored move
provenance, malformed battlers, and animation/timing are unresolved or
outside the current represented singles boundary. A source lock is not a
claim that these systems are implemented. In particular, the move records'
Protect/Mirror Move/King's Rock/contact flags do not authorize adding those
systems here.

If independently reviewed, the smallest future design boundary is one literal
effect-45 leaf for Jump Kick #26 and Hi Jump Kick #136 in represented singles:
retain shared cancellation, ordinary accuracy/PP and successful-hit flow;
on the one allowed miss branch, preserve the pre-existing no-effect gate,
emit a dedicated crash result, compute source damage in the stated command
order, halve/floor and target-maxHP-cap it, update only attacker HP, check
attacker faint, restore the miss result, and finish the action. It must define
RNG draw order and explicit event/controller ownership without reusing
ordinary actual-hit recoil. This paragraph is a proposed boundary only; it
is not an implementation task, API design, route, test package, or behavior
authorization.

## Evidence and handoff

Only pinned public source and the current project text/code were read. No ROM,
private runner, media, runtime experiment, or gameplay test was used. The
effect constants, move records, script routing/body, command owners, current
engine/controller seams, inventory row, and existing effect-45 exclusion note
were checked read-only.

Only this report and its paired task may change in this discovery step.
Independent exact-report PASS is required before any effect-45 design task or
implementation authority. No Phase 4 advancement or current-engine support
claim is made here.
