# Task: Phase 4 Psywave effect discovery

- Status: `DISCOVERY COMPLETE — PENDING INDEPENDENT REVIEW`
- Type: `PHASE 4 / BATTLE RULES / READ-ONLY DISCOVERY`

## Goal

Source-lock FireRed `EFFECT_PSYWAVE` (88), enumerate its verified-ROM move
record, and decide whether it is a self-contained bounded implementation leaf.
Do not implement it in this task.

## Evidence and conclusion

The supported FireRed US v1.0 ROM contains exactly one positive-power
effect-88 record: Psywave #149 (`effect=88`, stored power `1`, Psychic type
`14`, accuracy `80`, PP `15`, target `0`, priority `0`, flags `50`).

Stock source defines `EFFECT_PSYWAVE` as 88 in
`include/constants/battle_move_effects.h:92` and routes it to
`BattleScript_EffectPsywave` in `data/battle_scripts_1.s:112,1202-1211`. Its
order is attack cancellation, ordinary accuracy, move announcement, PP
reduction, type calculation, clearing only nonzero effectiveness presentation,
then `psywavedamageeffect` and `adjustsetdamage`. It does not run ordinary
critical, base-damage, or random-damage commands.

`Cmd_psywavedamageeffect` at `src/battle_script_commands.c:7557-7566` repeats
`Random() % 16` while it is 11 through 15, then uses the accepted value `r` to
set damage to `floor(attacker level * (r * 10 + 50) / 100)`. Thus accepted
values 0..10 yield 50%..150% of attacker level in 10% steps, and the formula
has one or more draws after the ordinary accuracy draw. The script does not
jump after `typecalc`: an immune target still executes every rejected/accepted
Psywave sampling draw before `BattleScript_HitFromAtkAnimation` suppresses HP.
This immunity draw order is a seeded-replay contract, not merely presentation.
`adjustsetdamage` is the no-normal-random-damage adjustment path
(`src/battle_script_commands.c:5601-`); its Focus Band/endure branches,
including their item RNG, are excluded because this engine has none of those
state families. Nonzero effectiveness must not alter the selected amount or
presentation.

This is an eligible bounded leaf: the engine already has attacker level, a
deterministic `next16()` RNG, ordinary cancellation/accuracy/PP/type/no-effect,
and shared HP/faint handling. It currently incorrectly admits effect 88 through
the generic ordinary-Hit path, which performs critical/base/normal-random
damage. A later bounded branch must instead run after shared accuracy/PP,
perform existing `typeCalc` and clear its nonzero presentation, execute the
Psywave rejection sampler even if that result is no-effect, then preserve
no-effect or apply the sampled damage through shared HP/faint handling. It must
not run ordinary critical/base/normal-random damage. Tests must prove the one
record, accepted low/high values, rejected-roll retry and draw count, floor
semantics, ordinary miss/PP, immunity's complete sampling order, no
critical/base/random-damage draws, shared faint handling, and regression of
ordinary moves. It must not generalize random formulae, introduce
held-item/endure/ability/doubles/link state, or claim Phase 4 completion. It
requires its own fail-closed Worker route, independent review, probe, Worker
request, and post-publication review.

## MUST NOT CHANGE

Battle behavior, admission policy, UI, AI, trainer layouts, held items, main
wiring, generated data, bridge configuration, Phase 2's external-reference
blocker, or Phase 4 completion status.
