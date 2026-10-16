# P5-05 — player elevation input lifecycle source lock

- Task ID: `P5-05-PLAYER-ELEVATION-INPUT-SOURCE-LOCK`
- Status: `READY_FOR_REVIEWER` — bounded research submitted; independent acceptance pending
- Type: `RESEARCH`; source-only, no implementation authority
- Parent capability gate: [Phase 5/7 scripted traversal](../roadmaps/CAPABILITY_CHECKLIST.md)
- Assigned role: `WORKER` acting as bounded researcher
- Independent reviewer: separate `REVIEWER`, exact report/source verification
- Prerequisites: parent [northbound report](../reports/phase5-viridian-northbound-gate-discovery.md) at `684f69caa0f4efba2953b2782f0340d11913a0ac` independently [PASS](../reviews/2026-10-15-viridian-northbound-gate-discovery-review.md) in `ba86377`, PR42 merged `ae3d559`; final public runs `38812239244` / `38812232691` PASS. Accepted projection `d280751` remains terminal
- Runtime baseline: `ba669fb420d68f54c8dab362c21bc0faf874f372`; pin actual dispatch base and classify later relevant changes
- Risk: LOW — documentation only; incorrect timing could otherwise produce false coordinate-trigger eligibility

## Goal

Resolve the precise missing prerequisite selected by the parent report:
initialization and ordinary-walking update timing of the effective player
elevation read by completed-step coordinate eligibility. Produce enough
source-backed ownership/timing evidence to propose one minimal live runtime
integration, or identify one exact remaining UNKNOWN. Do not repeat the Old
Man tutorial investigation or create an unconsumed selector as a substitute.

## Source of truth

Public pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788` only.
Parent anchors: `src/field_control_avatar.c:345–348` reads PlayerGetElevation;
`src/field_player_avatar.c:1092–1094` returns object previousElevation;
`src/event_object_movement.c:8400–8411` updates elevation with 0/15 retention.
These establish values, not lifecycle timing. Trace only necessary callers,
avatar/object initialization, coordinate shifts and normal walking callbacks
through the first and later eligible completed-step reads.

Inspect existing `src/core/PlayerMovement.lua`, `import/MapBlockData.lua`,
`main.lua` loadMap/playerMovementTask/tryEarlyStoryTriggerAt and their existing
tests. Distinguish current runtime ownership from proposed behavior. Source
initialization, update ordering, and map-load/reposition input preservation
remain discovery questions; do not assume raw height or constant elevation3.

## MAY CHANGE

- `work/reports/phase5-player-elevation-input-source-lock.md` (new)
- This task file (Worker status and exact evidence only)

Reviewer may separately add its own review under `work/reviews/`. Worker must
not edit coordination/roadmap/review files or self-certify acceptance.

## MUST NOT CHANGE

No runtime, tests, saved state/schema, import formats, collision rules,
movement implementation, existing Pallet/lab predicates, coordinate VM,
tutorial/battle/reward adapters, renderer, workflow/runner/probe/request, ROM
or extracted content. No full movement-engine or world inventory. Do not
reopen accepted projection/Party/Dex work or consume an old bridge allowance.
No traversal, retail parity, normal-save or phase-completion claim.

## Acceptance criteria

1. Pin source/runtime revisions and give symbol plus file/line citations for
   the actual avatar bootstrap elevation producer and ordinary movement
   sequence. Show current/previous coordinate transitions, elevation writes,
   frame/callback ordering and completed-step consumer, including first step.
   Separate proven scheduling from a call graph that does not prove ordering.
2. Derive literal expected state/read sequences for ordinary nonzero heights,
   current0, current15, previous15, blocked/noncompleted motion and standing
   input, insofar as source establishes them. Identify when no update occurs;
   do not infer this merely because tile position did not change.
3. Classify production entry owners: bootstrap/loadMap, normal step and known
   relocation calls. For map-load, connections, warps, save restoration or
   forced movement, identify whether inputs/timing are represented or outside
   the proposed slice. Trace only the boundary needed to prevent guessed
   initialization; no requirement to solve every movement mode. Any excluded
   transition must have an explicit stop/fail-closed proposal, not a silent
   reset that corrupts the next ordinary-step predicate.
4. Map source states to current live runtime owners and exact missing wiring.
   Propose exactly one next bounded integration with explicit MAY CHANGE
   runtime/test paths, source-derived literal oracles, production-path tests,
   regressions, evidence needs and stops. Prefer an end-to-end elevation input
   slice over disconnected utility code. It must preserve other story paths
   and cannot claim C0/C2/C3 execution, tutorial or traversal completion.
   If not source-ready, name one precise unresolved prerequisite instead.
5. Record reproducible commands actually run, separately from proposed tests.
   Do not bury UNKNOWNs or claim implementation/ROM acceptance from research.

## Required evidence

- Baseline: clean isolated worktree, exact source/runtime revisions and parent
  public CI receipts. Parent runtime192-file no-ROM PASS is carried evidence;
  no repeat full local suite for this documentation-only task.
- Focused: pinned source caller/assignment/scheduling checks, runtime ownership
  searches, repository checker before/after, `git diff --check`. If executing
  synthetic observations, report exact commands and distinguish them from
  source-derived future assertions. No checked-in helper/test is authorized.
- Full verification: public no-ROM CI on report PR. ROM/replay N/A for this
  research; any later implementation must state its own evidence requirements.
- Review evidence: independent exact-head report/source/scope review, recorded
  separately, and green final PR head before merge.

## Stop / escalate when

Source uncertainty, unsupported repositioning or scheduling, private inputs,
another source revision, or required general movement/collision work exceeds
this boundary. Record the precise unresolved seam and finish unaffected
findings; do not guess or recursively invent a new research project. No
runtime edits until a separate bounded implementation contract is adopted.

## Completion and handoff

Worker publishes the two-path report PR and records revision, changed paths,
commands/results, UNKNOWNs and one next-leaf proposal. Reviewer decides
PASS/NEEDS_FIX/BLOCK. Orchestrator reconciles only accepted source discovery,
then compiles the smallest evidenced successor without another broad inventory.
Canonical phase statuses and outstanding guarded battle/replay gates remain
unchanged. A source-known integration proposal should include its bounded
design/allowlist/oracles so the next task can use it without repeating research.

## Worker evidence / handoff — 2026-10-16

- [Source lifecycle and bounded implementation proposal](../reports/phase5-player-elevation-input-source-lock.md).
- Fresh isolated branch `work/p5-player-elevation-source-20261015`, dispatch
  base `d9c6318176efeff5f4a403e7eaa521430a89bf88`; runtime unchanged from
  `ba669fb420d68f54c8dab362c21bc0faf874f372`. Clean public source checkout
  verified at `c75f352304d529f6ba92d4f74b9cf8b5c3810788`.
- Resolved actual spawn producer, begin/finish coordinate sampling and
  CB1-before-CB2 completed-step observation. Origin15 suppresses begin, not
  finish after both coords become a nonzero destination. Standing/blocked
  pending-spawn sampling explicitly distinguished from no-flag behavior.
- Exactly one proposed successor: live elevation ownership in PlayerMovement
  and existing main bootstrap/step/relocation paths, five literal allowed
  paths and source-derived unit/production oracles. No throwaway selector,
  ignored argument, gate handler or tutorial implementation. Existing gameplay
  consumer is absent; future C0 handler must read state and reject unknown.
- Unsupported relocations invalidate; bootstrap or ordinary finish on1–14
  can establish known state. History-dependent 0/15 remains unknown. No save
  schema or collision expansion, no retail/traversal/phase completion claim.
- Actual source scheduler/caller/assignment reads, runtime ownership search,
  and synthetic tick16/missing-elevation observation PASS. Baseline checker
  PASS (320 Lua, 365 Markdown, 1216 local targets). Final repository checker
  PASS (320 Lua, 366 Markdown, 1219 targets); working/index whitespace PASS.
  Fresh origin/main `4d9fb2f24f2d85d788c9cadc0d7121bbaccb32a4` differs only
  in STATE/HANDOFF; runtime, task and AGENTS have no intervening changes.
  Parent 192-file no-ROM and PR42 CI evidence carried, not rerun. No ROM,
  private runner, replay, runtime or test changes.
- Independent Reviewer to verify exact published head, source timing,
  bounded exclusions/proposal and two-file research scope before acceptance.
