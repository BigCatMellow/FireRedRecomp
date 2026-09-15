# Task: Phase 4 OHKO effect discovery

- Status: `DISCOVERY COMPLETE — PENDING INDEPENDENT REVIEW`
- Type: `PHASE 4 / BATTLE RULES / READ-ONLY DISCOVERY`

## Goal

Source-lock FireRed `EFFECT_OHKO` (38), enumerate its verified-ROM records,
and decide whether its represented-state subset is a bounded implementation
leaf. Do not implement it in this task.

## Evidence and conclusion

The supported FireRed US v1.0 ROM has four effect-38 records: Guillotine #12
(Normal), Horn Drill #32 (Normal), Fissure #90 (Ground), and Sheer Cold #329
(Ice). Each has stored power `1`, accuracy `30`, PP `5`, target `0`, priority
`0`; Normal records have flags `19` and Ground/Ice records flags `18`.

`EFFECT_OHKO` is defined in `include/constants/battle_move_effects.h:42` and
routes to `BattleScript_EffectOHKO` at `data/battle_scripts_1.s:761-772`:
attack cancellation, announcement, PP reduction, special accuracy command,
type calculation, no-effect branch, then `tryKO` and successful
`trysetdestinybondtohappen`. `Cmd_accuracycheck`'s
`NO_ACC_CALC_CHECK_LOCK_ON` path skips ordinary accuracy RNG but depends on
unrepresented sure-hit, Protect, and airborne/underground/underwater state.
`tryKO` (`src/battle_script_commands.c:7119-7187`) checks Focus Band RNG before
Sturdy; after a successful ordinary KO roll it may apply Endure/Focus Band, all
unrepresented. Its ordinary represented-state path always rolls once, then
succeeds only when attacker level is at least defender level and
`Random()%100 + 1 < 30 + attackerLevel - defenderLevel`; a lower-level attempt
therefore still consumes that one roll before failing. On success it sets damage
to target current HP, then shared hit/faint handling applies. Type immunity
branches before `tryKO` and consumes no KO roll. Successful Destiny Bond
bookkeeping is excluded with status state.

This is eligible only as a bounded represented-state leaf: preserve existing
cancellation/announcement/PP/type/no-effect/shared faint behavior; do not add
or emulate Lock-On, Protect, invulnerability, Sturdy, Focus Band, Endure,
Destiny Bond, abilities, held items, doubles/links, or generic accuracy policy. A later
implementation must prove all four records, lower/equal/higher level behavior,
strict success boundary and one KO RNG draw even on lower-level failure, no KO
RNG on immunity, PP ordering, target-HP KO/faint, and ordinary-move regression. It
requires its own route, review, probe, Worker request, and canonical review.

## MUST NOT CHANGE

Battle behavior, admission policy, UI, AI, trainer layouts, held items,
abilities, main wiring, generated data, bridge configuration, Phase 2's
external-reference blocker, or Phase 4 completion status.
