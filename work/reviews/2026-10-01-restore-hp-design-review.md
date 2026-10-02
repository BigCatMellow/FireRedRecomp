# Restore HP design — independent review

Verdict: **PASS** for the bounded ordinary-path design only. No material
correction is required against the existing task criteria.

- Task: [P4-F2-RESTORE-HP-DESIGN](../tasks/phase4-restore-hp-design.md).
- Exact design/task revision: `4863567dce1950aa15e9b33798f82953b3bda4df`.
- Parent: `d0e0bad7985e6797487ac339147a8e13d9c50369`.
- Artifact: [ordinary Recover / Slack Off design](../reports/phase4-restore-hp-design.md).
- Accepted source lock: `1f89f0d53b1df3b22ea974eb99d9caed6f86c7f1` and its
  [independent review](2026-09-29-restore-hp-source-discovery-review.md).
- Reference pin: `pret/pokefirered c75f352304d529f6ba92d4f74b9cf8b5c3810788`.

## Independent checks and scope

Public main independently resolved to the exact design revision at review
recovery. The Orchestrator explicitly dispatched this exact review; older task
status wording does not authorize implementation. Inspected the two-file diff,
pre-change criteria, full design, accepted F1 report/review, and actual engine,
controller, formulas, importer, party bridge, main and inventory seams.

The change adds only the authorized report and task evidence/handoff; it does
not rewrite task criteria. No runtime, tests, workflow, route, coordination,
save policy, canonical status, ROM, media or generated content entered it.
`git diff --check` passes. All six cited runtime/importer files are unchanged
from accepted `a739ddc` through the exact reviewed revision. The reference
checkout matches its pin and has no tracked differences.

An independent repository check read the exact revision's Git objects, not
concurrent working-tree edits: **276 Lua / 162 Markdown / 449 local targets,
zero errors**. A separate recount of the literal inventory fixture confirmed
the existing totals and the two-member effect-32 delta below. These are
read-only static checks, not gameplay or ROM-backed evidence. No full suite,
private runner, ROM, replay or implementation experiment was used or needed
for this design review.

## Contract findings

1. **Admission is literal and bounded.** The proposed optional `moveId`
   parameter admits effect 32 only with ID 105 or 303, power exactly 0 and
   target exactly USER 16. Missing/other IDs or wrong shapes fail before the
   positive-power fallback; all non-32 behavior is preserved. This correctly
   distinguishes current rejection from future support. `BattleMove` records
   contain no ID, while `resolveMove` and the controller already own the slot's
   catalog key. Resolving the effective ID before engine admission and passing
   the player key at the controller are the two existing runtime call seams;
   neither requires an importer, AI or selection-policy expansion.
2. **PP, arithmetic and result order match the ordinary source lock.** Direct
   inspection of `BattleScript_EffectRestoreHp`, `Cmd_ppreduce`,
   `Cmd_tryhealhalfhealth`, `Cmd_datahpupdate` and
   `BattleScript_AlreadyAtFullHp` confirms announcement, one PP before viability,
   half-own-max floor/minimum one, own-max clamp and distinct full-HP feedback.
   The proposed shared PP owner plus zero-power dispatch avoids double spending
   and the current nil stat-entry path. Actual gain is distinguished from
   requested healing. MaxHP 1 is correctly treated as already full for any
   valid living actor, not as a revival fixture.
3. **Accuracy and RNG claims are properly limited.** Both source move records
   and constants match the specified identities/metadata. Neither effect-body
   branch performs accuracy, critical, damage-RNG or effectiveness calculation;
   the explicit accuracy exemption also bypasses tutorial accuracy handling.
   No tutorial progress flag is set. Isolated-action RNG is distinguished from
   speed-tie/opponent/cancellation draws. Existing chosen-no-PP and all-empty
   Struggle behavior remains a bounded compatibility rule, not new retail
   parity; dead actors are outside direct-call recovery tests.
4. **Event and controller contracts fit the existing queue.** Success appends
   `restoreHP` with actor side, before HP, clamped HP and actual gain after
   `useMove`; full HP appends only `restoreHPFull` after that announcement.
   The controller expands success to an invisible own-HP snapshot followed by
   distinct recovery text, and full HP to text without an HP entry. Existing
   `_applyInvisibleEntries` / `advanceMessage` ordering can present this without
   reading later whole-turn model HP early or mutating engine state. No generic
   failure, drain, faint, outcome or new cross-turn result is needed. Source
   bar-before-data protocol, animation, pauses, layout, localization and timing
   are explicitly not equated to this project snapshot protocol.
5. **Integration and inventory boundaries are accurate.** The party bridge
   already copies HP/PP and main calls it on turn changes; those owners are
   identified without requesting changes or claiming recovery persistence.
   The inventory currently calls `supportsMove` without an ID and rejects
   both effect-32 members. Its literal recount is 354 moves, 214 effects,
   216 positive / 138 zero, 248 admitted / 106 rejected, and 111 uncovered
   admitted positive-power moves. Authorizing the two IDs alone implies
   250 / 104 admissions/rejections, leaving those other totals unchanged.
   The design requires a later explicit ID-aware inventory adjustment and
   preserves historical evidence rather than silently relabeling it.

## Exclusions and exact next allowance

The source's Snatch flag and actual interception path remain a hard unresolved
boundary, not silently ignored parity. Shared cancellation, obedience,
status/inability-to-act, move restrictions, generic items/abilities, called or
intercepted provenance, PP suppression, Substitute and general MoveEnd remain
excluded. Existing side-timer cleanup does not stand in for MoveEnd. The
ordinary-domain precondition is explicitly not a detector for missing systems.

The design also retains persistence/save/restart safety, full tutorial/turn
parity, AI/roster completeness, doubles/links, malformed/revival state and
retail presentation exclusions. Milk Drink 208/effect 157, Softboiled, field
recovery, Rest, Present, Wish, Swallow, Ingrain, weather healing, generalized
healing APIs and new cross-turn state are not included. Direct source checks
confirm that Milk Drink is a separate family.

The later test outline is prospective, includes negative admission controls,
both sides, HP/PP/event/RNG boundaries, controller snapshot order, old-code
regression proof, inventory reconciliation and future guarded ROM evidence.
It neither supplies that evidence nor authorizes code, tests, route changes or
a private-runner request now. After parent reconciliation, this PASS permits
only shaping a separately authorized narrow implementation contract consistent
with these limits. It is not effect completion or Phase 4 advancement.

Only this review file was authored. No task/state/coordination edits, commit,
push, implementation or dispatch was performed by the Reviewer.
