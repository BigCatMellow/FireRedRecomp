# FireRed ReComp — MAPSL Execution Plan

- Record role: `MAP`
- Primary information class: `DERIVED EXECUTION INDEX`
- Status: `ACTIVE`
- Lifecycle: `ACTIVE`
- Authority: routing and assignment aid only; it never overrides root `AGENTS.md`, the capability checklist, an active task contract, source/ROM evidence, or independent review
- Accountable owner: `ORCHESTRATOR`
- Canonical status: [`CAPABILITY_CHECKLIST.md`](CAPABILITY_CHECKLIST.md)
- Strategic scope: [`../../docs/roadmap.md`](../../docs/roadmap.md)
- Live relay: [`../coordination/STATE.json`](../coordination/STATE.json) and [`../coordination/HANDOFF.md`](../coordination/HANDOFF.md)
- Detailed history: [`../../docs/handoffs/firered-recomp-checklist.md`](../../docs/handoffs/firered-recomp-checklist.md)
- Companion routing index: [`EXECUTION_MAP.md`](EXECUTION_MAP.md)

## Purpose

This is the future-orchestrator map. It turns the strategic roadmap into
small, assignable MAPSL packages without pretending that a package is approved
or complete before its task contract and evidence say so. An Orchestrator uses
the first eligible row, creates or reuses its exact task contract, and advances
only after independent review of the exact revision.

```text
human objective / constraints
→ canonical capability gate
→ one bounded task contract
→ WORKER evidence
→ independent REVIEWER verdict
→ ORCHESTRATOR reconciliation
→ next eligible row or explicit blocker
```

## Role assignment contract

| Role | Owns | Must not do |
| --- | --- | --- |
| `USER` | Product/scope choices, legally obtained ROM/reference media, external accounts/devices, and any decision that changes the release boundary | Treat an unreviewed claim as proof |
| `ORCHESTRATOR` | Recover state, select one eligible leaf, write the task/state/handoff, reconcile a reviewed result, and update derived maps | Implement or self-review a Worker change; declare a phase done without its exit gate |
| `RESEARCHER` | Source/ROM lock one uncertain behavior, enumerate dependencies, and propose a bounded contract | Implement behavior or widen scope from research alone |
| `WORKER` | Implement only an active `READY_FOR_WORKER` task, run required evidence, publish permitted bounded work, and route the exact revision | Self-approve, change capability status, or broaden a task |
| `REVIEWER` | Independently inspect the exact task/revision and return `PASS`, `NEEDS_FIX`, or `BLOCK` | Implement its own correction or add new acceptance after the fact |

## Mandatory lifecycle for every executable leaf

The steps below are part of **every** leaf, including a documentation or
research leaf. They are written once here so individual tasks do not copy
conflicting procedures.

| Step | Assigned to | Required result | Handoff condition |
| --- | --- | --- | --- |
| `M0.1 Recover` | ORCHESTRATOR | Read `AGENTS.md`, capability checklist, state, handoff, active task, latest review, and relevant source evidence | Stop if owners disagree; reconcile before dispatch |
| `M0.2 Bound` | ORCHESTRATOR + RESEARCHER when facts are uncertain | A task with goal, source-of-truth, prerequisites, MAY/MUST NOT change, acceptance, evidence, and stop conditions | `READY_FOR_WORKER` only when a fresh Worker can act without material guessing |
| `M0.3 Baseline` | WORKER | Required no-ROM baseline and any stated ROM/runtime prerequisite | Record an environmental block exactly; do not invent results |
| `M0.4 Execute` | WORKER | Smallest coherent implementation or research artifact inside the task boundary | Preserve deterministic/reproducible evidence |
| `M0.5 Verify` | WORKER | Focused tests plus required full suite, ROM test, replay, or source fixture | Commit/publish only within standing task authority |
| `M0.6 Review` | REVIEWER | Independent verdict tied to the exact commit/revision and task acceptance | `NEEDS_FIX` names only the smallest allowed correction |
| `M0.7 Reconcile` | ORCHESTRATOR | State/handoff/status-map update; select next eligible leaf or record blocker | Advance a phase only when its canonical exit gate is proved |

## Dispatch rules

1. Default to exactly one `READY_FOR_WORKER` critical-path implementation
   package. Research/review may run only when it has no writable overlap.
2. A later row is ineligible until every listed dependency has `REVIEWED PASS`
   or the row explicitly states that the dependency is external/parallel.
3. A source-uncertain rule gets a `RESEARCHER` discovery leaf before any
   implementation leaf. Do not convert a generic fallback into parity.
4. Every behavior-changing Worker leaf requires a focused deterministic test;
   battle, importer, save, map, or story leaves additionally require the
   relevant source/ROM/replay evidence named by their task.
5. `USER`-owned material (retail captures, device testing, store credentials)
   remains a blocking input, never an excuse to manufacture evidence.
6. The plan is a queue, not an authority grant. A row becomes executable only
   after the Orchestrator compiles its task contract and records it in
   `STATE.json`/`HANDOFF.md`.

## Current relay — do this before any new roadmap work

| ID | Status | Assigned role | Prerequisites | Required result / evidence | Next owner |
| --- | --- | --- | --- | --- | --- |
| `P4-PAIN-01` | `CLOSED — REVIEWED PASS` | REVIEWER | [Correction review](../reviews/2026-09-19-pain-split-fixture-correction-review.md), base `d793981` | Exactly two flags fixtures `51` → `18`; original nine-path allowlist and exclusions preserved | ORCHESTRATOR |
| `P4-PAIN-02` | `CLOSED` | ORCHESTRATOR | Fixture-scope PASS; user selected existing private runner | [Active task](../tasks/phase4-pain-split-effect.md) permits one corrected request with exact digest | WORKER |
| `P4-PAIN-03` | `READY_FOR_WORKER` | WORKER | Corrected task, route, and probe remain current; 148-file local baseline PASS | Implement only effect 91, run focused/no-ROM/verified-ROM/replay evidence, publish exact revision | REVIEWER |
| `P4-PAIN-04` | blocked on `P4-PAIN-03` | REVIEWER → ORCHESTRATOR | Exact Worker revision and evidence | Verdict; if PASS, record this leaf closed and select the next source-locked effect family | ORCHESTRATOR |

## Phase 0 — reproducibility and release baseline

| ID | Assigned role | Dependency | Deliverable and acceptance | Evidence / next handoff |
| --- | --- | --- | --- | --- |
| `P0-01` Behavior-ledger audit | RESEARCHER | Existing ledger and implemented subsystems | Enumerate renderer, importer, save, battle, map/script rows with source location, runtime owner, and test/replay link; mark unknowns | Reviewer checks no subsystem claim lacks evidence; Orchestrator updates ledger task status |
| `P0-02` Save migration contract | RESEARCHER → WORKER | Current `SaveFileCodec` schema | Define supported-version matrix, migration/refusal policy, corruption behavior, and deterministic fixtures for every persisted schema | Focused codec tests; reviewer checks old/new behavior is explicit |
| `P0-03` CI proof | WORKER | Test command matrix and no-ROM-compatible suite | CI runs clean checkout no-ROM tests, Lua syntax/static checks, and docs link/check policy; ROM tests remain opt-in and never upload ROM data | Green public run; Orchestrator records first verified CI evidence |
| `P0-04` Clean-clone verification | REVIEWER | `P0-02`, `P0-03` | Fresh clone installs/runs documented commands and rejects missing/invalid ROM safely | PASS updates Phase 0 only if all Phase-0 exit terms are met |

## Completed foundations — Phase 1 and Phase 3

| ID | Assigned role | Dependency | Deliverable and acceptance | Evidence / next handoff |
| --- | --- | --- | --- | --- |
| `P1-REG` Regression triage only | ORCHESTRATOR → WORKER if needed | Direct regression evidence | Phase 1 is `DONE`; create a bounded importer/canonical-data correction only for a demonstrated decoder, schema, or viewer regression | Existing full-sweep/data-viewer evidence remains the baseline; do not reopen Phase 1 as general refactoring |
| `P3-REG` Regression triage only | ORCHESTRATOR → WORKER if needed | Direct regression evidence | Phase 3 is `DONE`; create a bounded vertical-slice correction only when the continuous replay regresses | Preserve the reviewed boot-to-reload replay; do not redo the completed proof |

## Phase 2 — renderer, input, and scene-runtime parity

`P2-CAMERA` is already reviewed pass. Do not repeat it absent regression.

| ID | Assigned role | Dependency | Deliverable and acceptance | Evidence / next handoff |
| --- | --- | --- | --- | --- |
| `P2-01` Retail-reference intake | USER | Capture instructions from existing Phase 2 comparison task | Supply legally owned retail Oak and Pallet captures with ROM revision, device/emulator, timing, crop, and filter provenance; keep media out of git | Orchestrator verifies provenance and opens comparison task |
| `P2-02` Oak/Pallet discrepancy comparison | RESEARCHER | `P2-01`; existing harness | Produce text-only per-anchor discrepancy report with reproducible crop/frame assertions; distinguish artifact/tool uncertainty from runtime mismatch | Reviewer checks evidence provenance; Orchestrator chooses smallest renderer correction or closes gate |
| `P2-03` Renderer correction leaf | WORKER | Specific accepted discrepancy from `P2-02` | Correct one isolated composition/priority/palette/window/animation mismatch; no gameplay changes | Focused pixel/replay test + independent review; loop to `P2-02` only for affected anchor |
| `P2-04` Phase-2 gate reconciliation | ORCHESTRATOR | All representative anchors reviewed | Confirm screenshot-comparison exit criterion, or retain exact unmatched anchors | Update capability checklist only on complete evidence |

## Phase 4 — battle engine completion program

### Reusable per-effect family chain

Apply this exact five-step chain to every uncovered FireRed move-effect family.
It prevents a backlog of unbounded “implement move effects” requests.

| Step | Assigned role | Output | Required evidence |
| --- | --- | --- | --- |
| `P4-F1 Discover` | RESEARCHER | Exact move IDs/effect IDs, ROM/source control-flow order, RNG order, represented-state prerequisites, and exclusions | ROM record fixture + cited source path; reviewer PASS |
| `P4-F2 Design/route` | ORCHESTRATOR + REVIEWER | Literal file allowlist, acceptance matrix, replay selection, and stop conditions | Fresh-worker-readiness review; no implementation yet |
| `P4-F3 Implement` | WORKER | Narrow dispatcher/rules/controller change plus tests | Focused no-ROM + verified-ROM records + stated replay + full suite |
| `P4-F4 Independent review` | REVIEWER | `PASS` / smallest `NEEDS_FIX` / `BLOCK` against the exact task | Re-run proportionate tests and inspect scope/content boundary |
| `P4-F5 Reconcile` | ORCHESTRATOR | Close only the family, update admission matrix, select the next family | Capability checklist remains `IN PROGRESS` until its stress/early-game gate passes |

### Battle workstream queue

| ID | Assigned role | Dependency | Deliverable and acceptance | Evidence / next handoff |
| --- | --- | --- | --- | --- |
| `P4-01` Finish Pain Split | Roles per current relay | `P4-PAIN-01..04` | Exact effect-91-only completion | Follow active task; then use `P4-F1` |
| `P4-02` Effect-family inventory refresh | RESEARCHER | Latest `BattleEngine` admission matrix | Recompute every FireRed move/effect as represented, candidate, blocked-on-state, or intentionally rejected; rank by story-critical coverage and prerequisite cost | ROM-backed inventory test; Orchestrator selects one family only |
| `P4-03` Story-critical effect families | Roles per `P4-F1..F5` | `P4-02` selection | One family at a time: multi-turn, weather, trapping, forced switch, status, screens, protection, items/abilities only after their state prerequisites are explicitly modeled | Per-family source lock, tests, replay, review |
| `P4-04` General trainer battle matrix | RESEARCHER → WORKER | Stable multi-mon/switch/effect foundations | Enumerate real early-route/gym/rival trainer configurations, AI flags, items, party layouts, loss/win flags, and battle scripts; implement only selected missing primitive | ROM fixtures + deterministic trainer replays + review |
| `P4-05` Gym-ready regression suite | WORKER → REVIEWER | `P4-03`, `P4-04` enough for chosen early gyms | Seeded/replay matrix covering turn order, faint/replacement, capture, loss, EXP/EV, effects, and save/load legality | Independent PASS unlocks story dependencies, not Phase 4 completion |
| `P4-06` Full Phase-4 stress matrix | ORCHESTRATOR → WORKER → REVIEWER | All supported move/species families and early-game gyms | Fuzz/golden/replay coverage for every supported family and explicit unsupported-state errors | Canonical Phase-4 exit review before any `DONE` claim |

## Phase 5 — overworld and field systems

| ID | Assigned role | Dependency | Deliverable and acceptance | Evidence / next handoff |
| --- | --- | --- | --- | --- |
| `P5-01` World coverage inventory | RESEARCHER | Imported maps/events/scripts | Map every map, connection, warp, event type, metatile behavior, and field gate as implemented/blocked/unknown | Generated text inventory + invalid-reference scan; select first progression-critical gap |
| `P5-02` Script opcode families | Roles per `P4-F1..F5` adapted to scripts | `P5-01` | One opcode family at a time: movement, camera, fades, sound, multichoice, map callbacks, object visibility, special calls | Decoded ROM scripts + headless VM tests + reviewed runtime replay |
| `P5-03` Field-move framework | RESEARCHER → WORKER | Script/object/tile gate primitives | Shared data-driven field-action contract; then Cut, Flash, Fly, Strength, Surf, Rock Smash as separate leaves | Source/flag/tile fixtures and map replays; no ad hoc story booleans |
| `P5-04` Traversal systems | WORKER | Required map and field primitives | Running shoes, bike, fishing, repel, Itemfinder, Safari, daycare, Game Corner each as a distinct task | Deterministic state tests; story gate remains flag/var-driven |
| `P5-05` Map graph/reachability | WORKER → REVIEWER | `P5-01..04` for selected route | Automated legal-warp/map-walk graph from Pallet through Elite Four, with explicit exclusions and no invalid target | Reproducible traversal report; unlocks story-route proof |

## Phase 6 — player-facing menus and progression UI

| ID | Assigned role | Dependency | Deliverable and acceptance | Evidence / next handoff |
| --- | --- | --- | --- | --- |
| `P6-01` UI state inventory | RESEARCHER | Existing bag/party/mart/PC/save data layers | Catalog every UI entry point, dev-key fallback, data owner, and missing transition | Reviewer validates no data/UI ownership is conflated |
| `P6-02` Party and PC operations | WORKER | Party/PC save models; `P6-01` | Summary, switch, held-item, move learning, PC deposit/withdraw/release as individually bounded states | Save/load and menu-state tests; no duplicated storage model |
| `P6-03` Progression screens | WORKER | Flags/Dex/item models | Pokédex, Town Map, Trainer Card, Options, badges/key items/National Dex as separate UI tasks | State-gated tests and source-backed menu behavior |
| `P6-04` Service menus | WORKER | Battle/party/item primitives | Centers, shops, tutors, name rater, move deleter, daycare, trades | Transaction/replay tests; review each service family |
| `P6-05` No-dev-fallback audit | REVIEWER | `P6-01..04` | Walk every required main-story UI path and reject developer-only keys/placeholders | Independent completion evidence for the Phase-6 exit gate |

## Phase 7 — story, scripts, and cutscenes

| ID | Assigned role | Dependency | Deliverable and acceptance | Evidence / next handoff |
| --- | --- | --- | --- | --- |
| `P7-01` Checkpoint corpus design | RESEARCHER | Save/session/map/battle contracts | Ordered checkpoint corpus: expected map, party, flags, inventory, music, exits, and allowed loss/reload state | Reviewer checks source/progression coverage; corpus becomes task fixture source |
| `P7-02` Story segment implementation | WORKER | Required P4/P5/P6 primitive and one `P7-01` checkpoint | Implement exactly one ordered segment: Parcel → gyms → Rockets → Silph → Tower → Safari/Surf → Cinnabar → Giovanni → Victory Road → Elite Four → Champion | Deterministic checkpoint replay and independent review per segment |
| `P7-03` Cutscene parity leaf | WORKER | Segment script primitives | Add only the movement/camera/fade/audio/multichoice behavior used by the selected segment | Source-locked script trace + runtime replay |
| `P7-04` Credits-path proof | WORKER → REVIEWER | All required segments | Clean new game reaches credits without manual state edits/skips | Multi-process checkpoint/replay corpus and independent exit review |

## Phase 8 — audio and presentation parity

| ID | Assigned role | Dependency | Deliverable and acceptance | Evidence / next handoff |
| --- | --- | --- | --- | --- |
| `P8-01` Audio/visual coverage matrix | RESEARCHER | Current renderer/audio systems | Inventory music, SFX, cries, battle/field/UI animation, weather, fades, sprites, and performance gaps by story impact | Source/asset-pointer inventory; choose one family |
| `P8-02` Playback/effect families | WORKER | `P8-01` selected family | Implement one decoder/player/effect family without changing rules behavior | Deterministic timing/sequence tests; bounded runtime capture where permitted |
| `P8-03` Representative presentation audit | REVIEWER | P2 reference assets plus P7 checkpoints | Text-only discrepancy matrix across title, Oak, field, battle, menu, and credits anchors | Corrections re-enter `P2-03`/`P8-02`; no vague parity claim |
| `P8-04` Performance/correctness gate | WORKER → REVIEWER | Stock 240×160 path | Cold-cache/warm-cache budget plus visual/audio regression suite on supported environments | Independent Phase-8 exit review |

## Phase 9 — postgame and secondary modes

| ID | Assigned role | Dependency | Deliverable and acceptance | Evidence / next handoff |
| --- | --- | --- | --- | --- |
| `P9-01` Sevii progression inventory | RESEARCHER | Credits-path proof | Source-map/story dependency graph for Islands, National Dex, Celio, Ruby/Sapphire, altered encounters/trainers | Review scope and select one ordered island segment |
| `P9-02` Offline postgame segments | WORKER | `P9-01` + required P4/P5/P6 primitives | One Island/quest chain at a time, flag/var-driven and checkpointed | Segment replay + review |
| `P9-03` Secondary offline systems | WORKER | Relevant base systems | Trainer Tower, Union Room prerequisites, records, Mystery Gift stubs only where offline value is defined | Deterministic tests; no wireless/link claim |
| `P9-04` Postgame completion proof | REVIEWER | All offline segments | Normal save completes all offline single-player content | Independent exit review; link remains separately gated |

## Phase 10 — modding and release engineering

| ID | Assigned role | Dependency | Deliverable and acceptance | Evidence / next handoff |
| --- | --- | --- | --- | --- |
| `P10-01` Mod API design | RESEARCHER → REVIEWER | Stable data/script/map/UI/audio/battle shapes after parity | Versioned API proposal, ownership/conflict rules, deterministic load order, save compatibility matrix | Human scope decision before implementation; no speculative public API |
| `P10-02` Mod loader/SDK | WORKER | Approved `P10-01` | Registry, validation, isolated test mod, headless SDK, diagnostics | Conflict/load-order/save migration tests |
| `P10-03` Product operations | WORKER | Importer/save/runtime stable | First-launch ROM flow, updates, logs, recovery, input/display/accessibility settings, packaging/signing | Clean-machine install/play/diagnose test |
| `P10-04` Release candidate gate | ORCHESTRATOR → REVIEWER → USER | P0–P10 exit gates | Evidence matrix for import → play → save → mod → update → diagnose; legal-content audit and known-issue disposition | Human release decision; no automatic public release |

## Cross-phase dependency map

```text
P0 reproducibility ────────────────────────────────┐
P2 representative visual evidence ────────────────┤
P4 battle-rule/trainer matrix ──┐                 │
P5 maps/field/script primitives ├─→ P7 credits ───┼─→ P8 presentation ─→ P9 postgame ─→ P10 release
P6 menus/progression UI ────────┘                 │
P7 checkpoint corpus ─────────────────────────────┘
```

## Fresh-orchestrator dispatch checklist

Before assigning anyone, answer these in the task and state files:

1. Which exact canonical capability row is being advanced?
2. What is the smallest unmet acceptance item, not merely the nearest code
   file or attractive feature?
3. What source/ROM facts are known, and what requires a discovery leaf?
4. Which role owns the next move, and who independently reviews it?
5. What concrete artifact/tests/replay prove the leaf, and what is explicitly
   *not* proved?
6. What dependency or external input would force a `BLOCK` rather than an
   improvised implementation?
7. Which row becomes eligible after `PASS`?

If any answer is missing, the next action is task compilation—not coding.
