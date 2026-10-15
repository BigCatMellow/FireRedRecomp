# P5-05 — source-lock the remaining Viridian northbound gate

- Task ID: `P5-05-VIRIDIAN-NORTHBOUND-DISCOVERY`
- Status: `READY_FOR_REVIEWER` — Worker research submitted; independent acceptance pending
- Type: `RESEARCH / SOURCE DISCOVERY`; no implementation authority
- Parent capability: Phase 5/7 first-corridor progression in [capability checklist](../roadmaps/CAPABILITY_CHECKLIST.md)
- Assigned role: `WORKER` acting as bounded researcher
- Independent reviewer: separate `REVIEWER`; exact source/report verification
- Runtime baseline: `ba669fb420d68f54c8dab362c21bc0faf874f372`
- Prerequisites: [P5 inventory PASS `7712d63`](../reviews/2026-10-02-world-coverage-inventory-review.md), [Old Man projection PASS `d280751`](../reviews/2026-10-10-viridian-old-man-projection-outcome-review.md), [bounded Party SUMMARY PASS](../reviews/2026-10-15-party-summary-implementation-review.md) merged `ba669fb`
- Risk: LOW — documentation only; main risk is mistaking decoded events or ordinary battle support for a working story gate

## Goal

Produce one reproducible source/runtime lock for Viridian's remaining Old Man
northbound gate, and select the smallest eligible implementation prerequisite.
The accepted pre-spawn projection is terminal; do not redesign or re-review it.
The [accepted inventory](../reports/phase5-world-coverage-inventory.md) explicitly
left RoadBlocked and tutorial coordinate/special continuation uncovered.
Current main stores coordinate events but routes completed steps through the
bounded EarlyStory path. Establish the actual missing execution seam rather
than assuming the northbound path is blocked correctly or is playable.

## Source of truth and bounded questions

Public pret/pokefirered revision
`c75f352304d529f6ba92d4f74b9cf8b5c3810788` only. Verify the checkout/revision.
Use symbol and pinned file/line citations, not copied game content.

- `data/maps/ViridianCity/map.json:202–238`: only Old Man coordinate entries
  C0/C2/C3; exclude C1 gym door. Lock position, elevation and scene predicates.
- `src/field_control_avatar.c:620–647,1020–1045`: actual coordinate eligibility,
  variable lookup and priority relative to other completed-step events. Follow
  only necessary callees; do not generalize all maps from these entries.
- `data/maps/ViridianCity/scripts.inc:188–240`: RoadBlocked and left/right
  tutorial triggers through DoTutorialBattle. Resolve movement/wait/lock,
  special/waitstate return, scene-2 write and Teachy TV reward ordering.
- `src/battle_setup.c:301–308`: StartOldManTutorialBattle and its return
  callback. Trace only tutorial-flag-dependent setup/control/cleanup required
  to distinguish it from an ordinary wild battle. Determine player party,
  bag, capture destination and other persistent-state effects from source;
  do not assume ordinary capture or ordinary win/loss settlement applies.
- Include the directly shared tutorial-NPC call branch only where it constrains
  the coordinate path; unrelated NPC, gym, Quest Log implementation and other
  maps are not selected. Identify Quest Log as an explicit excluded context
  rather than deleting its source branch from the record.

Compare the pinned runtime's `main.lua` completed-step dispatch and
`tryEarlyStoryTriggerAt`, EarlyStory, ScriptBytecode/ScriptInterpreter,
DialogueRunner, movement/lock, GameSession/bag and relevant existing battle
adapters. Read only the necessary seams. Separate parser/component capability
from actual production wiring and from accepted ROM/replay evidence.

Unknowns are permitted research results: label exact unresolved behavior,
required source/input and whether it blocks the proposed next leaf. Do not
invent a tutorial lifecycle or silently widen existing accepted scope.

## MAY CHANGE

- `work/reports/phase5-viridian-northbound-gate-discovery.md` (new report)
- This task file (status and exact Worker evidence only)

Separate Reviewer may add its own review under `work/reviews/`. Worker may
not edit review, coordination or roadmap files or self-certify acceptance.

## MUST NOT CHANGE

No runtime, tests, imports, map/script data, save schema, renderer, battle AI/
effects, movement implementation, generic hooks/coordinate VM, workflows,
runner configuration, probes or requests. No ROM/private paths, extracted
content, full source tables/dialogue, caches or screenshots in artifacts.
No trainer-party expansion, forest/Brock rewards, Running Shoes or unrelated
P6 follow-up. Do not revive any accepted projection or exhausted bridge input.

## Acceptance criteria

1. Pin runtime/source revisions and give an exact bounded predicate/action/
   callback sequence for scene0, scene1 left/right, and post-tutorial scene2+.
   Identify re-entry/retrigger and failure/return conditions; distinguish
   source semantics from the existing reconstruction boundary.
2. Trace production read/write ownership, movement/input lock and encounter
   ordering, tutorial temporary versus saved state, script continuation and
   item-capacity handling. Mark genuinely missing or uncertain seams explicitly.
3. Map each necessary seam to current code, assertions and accepted evidence
   (or absence), without rerunning the whole 13-map inventory or battle matrix.
4. Select exactly one smallest next leaf, with concrete implementation paths,
   source-derived test oracles, dependencies, evidence requirements and stops.
   Prefer a source-known primitive over bundling a complete tutorial/VM.
   If no implementation leaf is source-ready, name one precise unresolved
   prerequisite instead. The proposal itself is not implementation authority.
5. Provide safe reproducible source-only checks or commands for the key claims;
   report actual executions separately from proposed tests. No traversal,
   retail presentation, normal-save or phase-completion claim.

## Required evidence

- Baseline: parent full192-file no-ROM suite PASS at `ba669fb`; inspect clean
  isolated worktree and exact source/runtime hashes. No repeat suite required
  for documentation-only research.
- Focused: independently reproducible pinned-source/runtime symbol and
  control-flow checks, plus `git diff --check` and repository checker before/
  after. No checked-in helper script or new test file in this scope.
- Full verification: public no-ROM CI on the report PR; private ROM/replay N/A
  because this package changes no behavior and cannot establish route proof.
- Independent review: exact published report/source claims and two-path scope,
  with PASS/NEEDS_FIX/BLOCK recorded separately before reconciliation.

## Stop / escalate

Stop an unresolvable branch at UNKNOWN if it needs private data, a different
source revision, broad unrelated tracing or new authority. Finish unaffected
bounded findings. Never implement a guessed callback or use a broader task to
claim the accepted projection closes this gate. Any implementation requires
its own explicit bounded contract after review.

## Completion and handoff

Worker uses a fresh branch/worktree, publishes one task/report PR and records
exact revision, commands, results, exclusions and selected next leaf. Reviewer
independently verifies it; Orchestrator reconciles only the source lock and
compiles the evidence-backed next task without asking the user to pick it.
This research does not advance canonical phase status or waive outstanding
guarded battle/replay gates.

## Worker evidence and handoff — 2026-10-15

- Report: [bounded source/runtime lock](../reports/phase5-viridian-northbound-gate-discovery.md).
- Fresh branch `work/p5-viridian-northbound-discovery-20261015`, base
  `86bf0aceeb81140dad703efc4fb5ffa3b529029c`; runtime remains `ba669fb`.
  Source checkout clean at `c75f352304d529f6ba92d4f74b9cf8b5c3810788`.
- C0/C2/C3 predicates, source priority, movement/wait, normal tutorial
  continuation and scene-before-item ordering recorded. Live runtime lacks
  selected handlers/effective player elevation/waitstate/tutorial adapter.
- Exactly one proposed next prerequisite: source-only player elevation
  bootstrap/normal-step ownership lock. Update function known; observation
  timing/bootstrap remain UNKNOWN. No disconnected selector or implementation
  authority proposed; abnormal tutorial branches and exact RNG/timing remain
  explicit exclusions/UNKNOWN.
- Actual checks: clean revision/runtime comparison, selected source JSON and
  numbered control-flow reads, synthetic no-ROM missing-handler/elevation/
  waitstate witnesses PASS. Baseline repository checker PASS (320 Lua,
  362 Markdown, 1201 targets). Final repository checker PASS (320 Lua,
  363 Markdown, 1205 targets); both working/index whitespace checks PASS.
  Initial checker rejected the new untracked report link; staging the two
  authorized files resolved that tracking prerequisite without changing checks.
  Parent 192-file no-ROM baseline retained; no full local rerun,
  ROM, private-runner or replay action in this documentation-only package.
- Reviewer handoff: inspect the exact published head, source facts, UNKNOWN
  boundaries and two changed paths; Worker does not self-certify source-lock
  acceptance or advance phase/coordination state.
