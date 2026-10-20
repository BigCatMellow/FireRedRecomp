# P5-06 — bounded Viridian scene-0 roadblock integration design

- Task ID: `P5-06-VIRIDIAN-ROADBLOCK-DESIGN`
- Status: `CLOSED — REVIEWED PASS` — design only; reconciled after PR45 merge
- Type: `DESIGN / bounded necessary source checks`; no runtime authority
- Parent capability gate: [Phase 5/7 first-corridor progression](../roadmaps/CAPABILITY_CHECKLIST.md)
- Assigned role: `WORKER` acting as bounded designer
- Independent reviewer: separate `REVIEWER`, exact design/source/scope review
- Prerequisites: [northbound source lock](../reports/phase5-viridian-northbound-gate-discovery.md), PR42 merged `ae3d559`; [elevation lifecycle/source design](../reports/phase5-player-elevation-input-source-lock.md), PR43 merged `871f3f1`; [elevation implementation PASS](../reviews/2026-10-17-player-elevation-input-review.md), exact `4b1ac5f`, review `6de803d`, PR44 merged `75b49f3`
- Runtime baseline: `75b49f3a3cbeb877137372a40a0b92973172fad1`
- Risk: LOW for docs; future implementation risks input leaks, wrong event priority, stale elevation and unfinished forced-movement locks

## Goal

Specify one implementable, live C0 RoadBlocked slice: eligible completed step,
lock/message/close, one forced down step, wait, release/end. Consume the now
accepted effective-elevation owner rather than repeat its research. Produce
the bounded design, literal runtime/test allowlist, acceptance oracles and
guarded evidence/route requirements together, without another broad inventory
or redundant source/route-plan document. No catching tutorial in this package.

## Source of truth

Public pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788` only.
Accepted parent report already locks C0 map3/1, (22,11), elevation3, scene
var0x4051 equality0; source priority; script actions; absence of persistent
scene/reward writes; and re-entry behavior. C2/C3/tutorial and gym C1 excluded.

Use `data/maps/ViridianCity/scripts.inc:188–201` for RoadBlocked, text color,
message/close, PLAYER walk_down/waitmovement/release. Follow only additional
callees necessary to resolve message acknowledgment/reveal/close semantics,
script-forced walk start/completion, lock ownership and release-frame input.
Do not infer these from the existing Mart presenter's behavior without source
support. Ordinary movement/elevation timing and bootstrap are already accepted;
do not redo them. Any new UNKNOWN must be precise and relevant to C0.

Compare current `main.lua` completed-step/input/scheduler/dialogue/presenter
owners, `PlayerMovement` and `DialogueRunner`/ScriptBytecode boundaries. Reuse
existing text decoding/rendering where faithful. Resolve text from the player's
ROM through supported data, not copied dialogue or guessed pointer literals.
Accepted Old Man pre-spawn projection and Party/Dex work remain terminal.

## MAY CHANGE

- `work/reports/phase5-viridian-roadblock-design.md` (new)
- This task file (Worker status and exact evidence only)

Reviewer may separately add its independent review. No Worker coordination,
roadmap or review edits; no self-acceptance.

## MUST NOT CHANGE

Runtime/tests, save data/schema, imports/assets, renderer, workflow/bridge/
runner/probes/requests or canonical status. No C1/C2/C3, catching tutorial,
Teachy TV, broader trainer/warp/encounter logic, generic VM/movement scheduler,
other maps, new UI system or accepted projection redesign. No ROM/private
paths, extracted dialogue/assets, caches or screenshots in artifacts.

## Acceptance criteria

1. Specify exact live admission inputs and dispatch location: qualified completed
   step, current map, decoded C0 identity/scene predicate and valid effective E.
   Distinguish event elevation0 wildcard from known player E0 and unknown E.
   Define malformed/missing event/script/scene/elevation handling without
   claiming a refused unsupported context is playable or silently treating
   missing state as a source default. Nonselected entries/maps remain unchanged.
2. Define source-locked states/transitions and owners for message reveal and
   acknowledgment, close-before-move, forced one-tile down action, completion,
   unlock/end and retrigger. Include actual input buttons and their priority,
   held/new-press behavior and same-frame release leakage constraints. Establish
   whether scripted walk checks collision/ledge predicates or bypasses them;
   do not copy ordinary-input or Mart behavior on assumption. Preserve source
   lack of persistent scene/reward writes; only ordinary location changes may
   follow the forced move.
3. Map integration to actual production paths. Source trainer/on-frame priority
   precedes coordinates; coordinates precede warp/wild work. Current global
   order differs. Propose the smallest C0-specific compliant boundary, without
   silently reordering unrelated Pallet/lab or other gameplay. Specify player/
   NPC/input locks, text renderer ownership, scheduler cadence, map teardown,
   interruption/refusal and prevention of nested coordinate/encounter dispatch
   during forced movement. Preserve elevation invalidation/provenance rules;
   do not present this scripted step as qualified ordinary input.
4. Propose exactly one cohesive implementation with literal runtime/test/task
   paths, API/state design, source-derived assertions and stops. Prefer a
   narrow presenter/adapter using existing services over generic script VM
   expansion. Include production extraction/runtime tests, correct and wrong
   elevation/scene/map, re-entry, input isolation and persistent-state identity.
   Tests must observe real field dispatch through message/move/release, not
   merely a helper returning an unused action. Name the smallest specific
   blocker instead if a safe implementation is not yet source-ready.
5. Include the complete evidence plan and necessary guarded-route proposal in
   this same report: baseline/focused/full no-ROM commands, source assertions,
   SHA-verified-ROM fixture(s), and a deterministic C0 runtime witness covering
   trigger/message/forced step/release. Label fixture setup versus normal
   traversal proof. Specify exact future command/selector/allowlist requirements
   and existing route limitations; if route changes are needed, identify them
   without implementing or submitting anything. This P5 gameplay slice is not
   a P4 fast-lane deferral. Old probe/request allowances remain consumed.
6. Keep actual source/runtime checks separate from proposed tests/evidence.
   Record exact revisions, commands/results, exclusions and UNKNOWNs. No code,
   route readiness, gameplay/traversal/ROM or phase-completion acceptance here.

## Required evidence

- Baseline: clean isolated worktree, exact pinned source/runtime; prior
  independently accepted193-file no-ROM suite is attributed parent evidence.
  No repeat full local suite required for this documentation-only design.
- Focused: reproducible narrow source/control-flow and current-owner checks;
  repository checker before/after and working/staged `git diff --check`.
- Full verification: public no-ROM CI on design PR and final review head.
  No ROM/replay/runner execution in this task; future evidence plan only.
- Review: exact independent source/design/scope verdict before reconciliation.

## Stop / escalate when

Required behavior needs new persistent state, broader VM/renderer/collision
architecture, another source revision/private input or an unbounded movement
investigation. Finish known bounded findings and state the precise prerequisite.
Do not implement or relabel missing guarded evidence as a no-ROM PASS. New
product/human decisions remain outside delegated routine authority.

## Completion and handoff

Worker publishes two-path design PR with exact checks and one implementation/
evidence proposal. Reviewer decides PASS/NEEDS_FIX/BLOCK independently.
Orchestrator adopts only the accepted bounded design and dispatches its next
required implementation/evidence prerequisite; do not invent another redundant
planning layer. Canonical Phase5/7 and the complete northbound/tutorial gate
remain open. No code or guarded request is authorized by this task itself.

## Worker evidence and handoff — 2026-10-17

Orchestrator closure — 2026-10-18: exact `a7e12e0` independently PASS in
[review `1199a74`](../reviews/2026-10-18-viridian-roadblock-design-review.md).
Final review-head CI `39095715464`/`39095718009` passed; PR45 merged
`6006ab6fbc7b9f1dd60a88dcbf6a8b0a08692947`. This closes design only.
Next: [bounded bridge configuration](local-worker-bridge-phase5-viridian-roadblock-route-configuration.md).
All runtime, guarded evidence, tutorial, presentation and phase exclusions remain.

- [C0 design, nine-path implementation and guarded-route proposal](../reports/phase5-viridian-roadblock-design.md).
- Isolated branch `work/p5-viridian-roadblock-design-20261017`, base
  `d59f28f844ec9a45abec0f307bae92525c932501`; tracked runtime unchanged from
  `75b49f3a3cbeb877137372a40a0b92973172fad1`. Clean public source verified at
  `c75f352304d529f6ba92d4f74b9cf8b5c3810788`.
- Narrow source checks resolved two-page/NEW A/B acknowledgment, non-reveal-all
  speedup, close-before-movement, collision/ledge bypass, wait/release order and
  release-frame input isolation. Existing normal-glyph/style limits explicitly
  excluded from visual parity; no guessed pointers or shared renderer expansion.
- One cohesive implementation proposal and complete guarded fixture/replay/
  selector/allowlist plan supplied together. Existing projection/shared replay
  routes do not cover it; no consumed probe/request reused. No runtime/test,
  workflow, ROM, private runner or replay action taken.
- Own baseline checker PASS (321 Lua, 370 Markdown, 1242 local targets);
  clean revisions/runtime comparison and documented source/current-owner reads.
  Parent193-file baseline attributed, not rerun. Final checker PASS (321 Lua,
  371 Markdown, 1246 local targets); working and staged `git diff --check` PASS.
  Fresh `origin/main` at `53de0780842ce9c6d4dee94e68d760805d601b7d` changes
  only coordination STATE/HANDOFF since dispatch; task/runtime authority is
  unchanged. Exact public head/CI handed to separate Reviewer before reconciliation.
- Review remains independent; no C0/gameplay/traversal/route-readiness or phase
  acceptance claimed. C1/C2/C3/tutorial and accepted projection remain excluded.
