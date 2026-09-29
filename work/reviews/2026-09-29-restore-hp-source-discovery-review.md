# Restore HP source discovery — independent review

Verdict: **PASS** for the ordinary represented-state source lock only.

- Task: [P4-F1-RESTORE-HP-DISCOVERY](../tasks/phase4-restore-hp-source-discovery.md).
- Exact report/task commit: `1f89f0d53b1df3b22ea974eb99d9caed6f86c7f1`.
- Parent: `fc43daf053f2acc7e906528ff410fb202b70495d`.
- Project inspection base: `e80f9f2cffde02a7987d5c55b45f8a7cd3b834d2`.
- Reference source: `pret/pokefirered c75f352304d529f6ba92d4f74b9cf8b5c3810788`.
- Reviewed artifact: [source discovery](../reports/phase4-restore-hp-source-discovery.md).

## Evidence and scope

Independently recovered public main at the exact reviewed revision, read the
task/report and their two-file diff, and inspected the cited public reference
source and current project owners directly. Reference HEAD matches the pin and
has no tracked working-tree differences. The task is `READY_FOR_REVIEWER`;
this exact-review dispatch supersedes older coordination queue wording without
changing that coordination here.

Only the authorized report and task changed. No runtime, tests, workflow,
admission, save policy, route, phase status, ROM or extracted content was added.
`git diff --check` on the exact commit passes. A read-only check reproduced all
eight local link occurrences and fourteen pinned-source path/line occurrences;
source meanings were checked directly, not inferred from link existence.

No ROM, private runner, gameplay experiment, full suite or replay was needed or
used. This is independent source/code inspection, not new execution evidence.

## Source findings

The move constants and `src/data/battle_moves.h` records agree:

| Move | ID / effect | Power / accuracy / PP | Target / priority / flags |
| --- | --- | --- | --- |
| Recover | 105 / 32 | 0 / 0 / 20 | USER 16 / 0 / SNATCH_AFFECTED 8 |
| Slack Off | 303 / 32 | 0 / 100 / 10 | USER 16 / 0 / SNATCH_AFFECTED 8 |

Both are Normal with zero secondary-effect chance. Milk Drink is ID 208,
`EFFECT_SOFTBOILED` 157, not effect 32. Its separate record at line 2707 does
not justify inclusion in this discovery. The corrected naming and exclusion
are accurate.

`BattleScript_EffectRestoreHp` at `data/battle_scripts_1.s:673` establishes the
reported order: cancellation, announcement, PP deduction, half-health viability
command, animation/wait, ignore-Substitute marker, attacker health-bar update,
attacker data-HP update, successful feedback/wait, common MoveEnd. The report
does not confuse this order with the current engine's generic damage path.

- `Cmd_tryhealhalfhealth:6332` assigns target to attacker, computes integer
  half-max with minimum one, stores negative requested healing, then tests
  current HP equality with maxHP. It does not mutate HP. The report's ordinary
  valid-state formula and odd-max/near-full examples follow that source.
- `Cmd_datahpupdate:1744`, negative branch at 1789, owns actual HP addition and
  the maxHP clamp; it later emits HP data writeback. `Cmd_healthbarupdate:1708`
  sends the signed requested bar amount first. Requested and actual gains are
  correctly distinguished, and the defender receives no HP change.
- `Cmd_ppreduce:1122` precedes viability. The self-target branch of
  `GetMoveTarget` at `battle_util.c:3122` resolves attacker as target, so the
  ordinary default Pressure condition does not charge an opposing battler's
  extra PP. One PP is spent for both ordinary success and full-HP failure;
  suppression, interception and called-move rules are explicitly excluded.
- `BattleScript_AlreadyAtFullHp:2038` uses the distinct HP-full message and
  short/long waits before MoveEnd. It bypasses healing animation, HP updates
  and success feedback, and does not directly set generic failure flags. The
  source wait constants and message IDs match the report. No LÖVE timing parity
  is inferred.
- Neither this effect body nor the full-HP branch performs accuracy, critical,
  damage-RNG or effectiveness calculation. Slack Off's accuracy field does not
  add an accuracy command. The report correctly limits the no-effect-body-RNG
  claim rather than extending it to turn order, obedience or a whole turn.
- `Cmd_attackcanceler:819` and `BattleScript_NoPPForMove:3509` substantiate the
  separate no-PP path. The report does not equate it with full-HP failure or
  certify the existing project's defensive `noPP` presentation as parity.

## Existing seams and unresolved boundaries

History comparison confirms that BattleEngine, BattleSceneController,
BattleFormulas, BattlePartyBridge and main are unchanged from accepted
`a739ddc88cb44a33d5e6025e619cf1df3fe6a1a8` to the inspection base, and from
that base through the reviewed report commit.

Direct inspection confirms effect 32 is absent from `supportsMove`; the player
controller refuses it before running a turn. The source/action comparison is
accurate: `useMove`, shared PP mutation, ordered invisible HP entries and
save-backed HP/PP persistence are existing seams, not recovery support.
Admission alone would leave the inappropriate accuracy path and possible nil
stat-entry access. This is a code-path observation, not an executed mutation.
The controller's drain/Pain Split/generic-failure messages do not establish the
distinct recovery-success/HP-full contract. Event fields, requested versus
actual amounts, presentation timing and admission remain future decisions.

The report retains the important stop boundary: flags 8 actually reach Snatch
interception in `Cmd_attackcanceler`; `BattleScript_SnatchedMove:3617` changes
ownership and PP/announcement markers. General cancellation and `Cmd_moveend`
also contain stateful interactions. They are hard unresolved exclusions under
the recorded ordinary-path research authorization, not optional behavior
silently approximated away. Substitute, generic ability/item/status machinery,
called/intercepted provenance, doubles/links, malformed/revival cases and
animation/visual parity remain outside this source lock.

## Exact next allowance

After parent reconciliation, this PASS permits consideration of one separately
authorized effect-32 design task for ordinary represented singles Recover and
Slack Off, on either attacker side, with the report's exact exclusions and
missing contracts. It does not approve an event/API design, test package,
implementation, generalized healing, Milk Drink/Softboiled or field recovery.
Full retail effect-32 parity and broader Phase 4 completion remain unproven.

Only this review file is authored by the Reviewer. No task/coordination edits,
commit, push, dispatch or phase advancement was performed; reconciliation and
any next task remain with the Orchestrator.
