# Task: source-lock effect 45 recoil-on-miss

- Task ID: `P4-F1-RECOIL-IF-MISS-DISCOVERY`
- Status: `DISCOVERY COMPLETE — PENDING INDEPENDENT EXACT-REPORT REVIEW`
- Type: `RESEARCH / SOURCE-LOCK DISCOVERY`
- Parent capability gate: Phase 4 move-effect family chain.
- Selected effect: `EFFECT_RECOIL_IF_MISS` (45), Jump Kick #26 and Hi Jump Kick #136.
- Risk: `MEDIUM` — a wrong miss-branch formula or ordering could misdirect a
  later bounded implementation and confuse ordinary recoil with crash damage.

## Goal and source of truth

Lock the narrow Gen 3 FireRed behavior of effect 45 from pinned public source
`pret/pokefirered c75f352304d529f6ba92d4f74b9cf8b5c3810788`, especially:

- the two exact move records in `src/data/battle_moves.h`;
- `BattleScript_EffectRecoilIfMiss` and its miss branch in
  `data/battle_scripts_1.s`;
- `Cmd_attackcanceler`, `Cmd_accuracycheck`, `Cmd_ppreduce`,
  `Cmd_damagecalc`, `Cmd_adjustnormaldamage`, `Cmd_manipulatedamage`, and
  `Cmd_tryfaintmon` in `src/battle_script_commands.c`;
- the current project's broad positive-power admission and ordinary
  accuracy/PP/damage/event seams.

The paired report is
[`phase4-recoil-if-miss-source-discovery.md`](../reports/phase4-recoil-if-miss-source-discovery.md).
It is the exact source lock and must be reviewed independently before any
effect-45 design or implementation authority.

## MAY CHANGE

1. `work/reports/phase4-recoil-if-miss-source-discovery.md`.
2. This task's research evidence and review handoff only.

## MUST NOT CHANGE

Battle engine/controller/UI code, move admission policy, formulas, event
schemas, tests, workflows, save state, AI, task routes, bridge configuration,
supported-ROM policy, canonical Phase 4 status, or any other effect family.

Do not implement Jump Kick/Hi Jump Kick crash behavior, add a generic recoil
or miss API, reuse ordinary actual-hit recoil, add crash presentation, or
alter the existing current support/exclusion posture. Do not inspect ROM,
private runner state, media, or runtime behavior as part of this source lock.

## Acceptance criteria

1. Establish the effect constant and exact complete move membership: Jump Kick
   #26 and Hi Jump Kick #136, including power, Fighting type, accuracy, PP,
   target, priority and flags. State that ordinary effect 48/198 recoil is
   distinct and excluded.
2. Describe successful-hit and accuracy-miss control flow in source order,
   including attack cancellation, accuracy, announcement, PP timing, the
   pre-existing `MOVE_RESULT_DOESNT_AFFECT_FOE` gate, crash message, damage
   commands, integer half/minimum/cap formula, attacker-only HP update,
   attacker faint check, and common MoveEnd.
3. Record RNG/accuracy boundaries without inventing a whole-turn RNG claim:
   ordinary accuracy is before the miss branch; no `critcalc` occurs inside
   the crash branch; ordinary damage adjustment remains a source command with
   its own random/item state.
4. Compare each required source action with the current engine/controller
   seams. Explicitly call out that current effect 45 is admitted by positive
   power but its miss path returns after a generic `miss` event, omitting the
   crash formula/message/self-faint handling.
5. Record the smallest future effect-45 design boundary, without drafting an
   implementation task, API, tests, bridge route, or claiming current support.
6. Use pinned public source and current-project read-only checks only. An
   independent exact-report PASS is required before any separate design task.

## Stop / escalate when

Stop and record the unresolved fact if source behavior is ambiguous, a required
cross-component state is unsupported, or evidence would require ROM/private
runner inspection. Do not guess, add a fallback, or widen into generic recoil,
generic miss handling, status, items, protection, or multi-battle behavior.

## Completion and handoff

Research artifact is complete in the paired report at the inspection base
`dad1274d6fbab88ca99a56169fde22142ec19bf6`. It remains `PENDING INDEPENDENT
EXACT-REPORT REVIEW`; no review verdict is claimed here. On independent PASS,
the only permitted successor is a separately authorized bounded effect-45
design discussion. This discovery task itself authorizes no implementation,
route, worker request, ROM check, or Phase 4 status advancement.
