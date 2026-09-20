# Task: refresh the complete move-effect inventory

- Task ID: `P4-02`
- Status: `BLOCKED` — source/test preflight PASS; private runner offline
- Type: `RESEARCH / DETERMINISTIC INVENTORY`
- Parent capability gate: Phase 4 move/effect and stress matrix in [`../roadmaps/CAPABILITY_CHECKLIST.md`](../roadmaps/CAPABILITY_CHECKLIST.md).
- Assigned role: `RESEARCHER` for source classification, `WORKER` for the bounded verification artifact.
- Independent reviewer: separate `REVIEWER` helper.
- Prerequisites: independently accepted Pain Split revision; separately reviewed and probed inventory bridge route before any request publication.
- Risk: `LOW` — read-only classification and tests; inaccurate coverage claims could misroute later implementation.

## Goal

Refresh coverage for every real FireRed move and every defined effect, including
zero-power moves, then select exactly one next discovery family using early-story
relevance, represented prerequisites, and bounded testability. This task changes
no battle behavior and cannot mark Phase 4 complete.

## Source of truth

- Exact reviewed `BattleEngine.lua` revision after Pain Split; existing source-backed tests and task reviews.
- Supported ROM SHA-1 `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`, parsed through existing importer code on the private runner.
- `pret/pokefirered` revision `c75f352304d529f6ba92d4f74b9cf8b5c3810788`: `include/constants/moves.h`, `include/constants/battle_move_effects.h`, `src/data/battle_moves.h`, `data/battle_scripts_1.s`, relevant command implementations, and early trainer/learnset source when ranking candidates.
- Historical [`phase4-move-admission-matrix-discovery.md`](phase4-move-admission-matrix-discovery.md) is a baseline, not current evidence.
- Unknowns: ROM confirmation of refreshed counts; prerequisites of uncovered effects. Classify uncertain semantics explicitly and do not infer them from constant names.

## MAY CHANGE

Only these implementation/report artifacts:

1. `tests/phase4_move_effect_inventory_test.lua`
2. `work/tasks/phase4-move-effect-inventory.md`
3. `work/reports/phase4-move-effect-inventory.md`

After the route prerequisite passes, one task-bounded request may be transported
through `work/local-runner/requests/phase4-move-effect-inventory-<date>-v1.patch`.
Orchestrator owns coordination and Reviewer owns independent review records;
those are not Worker patch targets. Source preparation may proceed in parallel
with route maintenance because their writable paths and acceptance are separate.
Do not publish the implementation request before route review and probe PASS.

## MUST NOT CHANGE

Runtime code, admission policy, engine/controllers, AI, importer/data models,
save state, UI, battle effects, route configuration from this task, generic
healing, supported ROM policy, or phase status. No ROM, extracted table dump,
game strings/art/media, generated cache, or reference media in git. The report
may contain test metadata: move/effect numeric identifiers, aggregate counts,
source symbols, classification, and evidence links.

## Acceptance criteria

1. Cover real move IDs 1–354 exactly once; exclude sentinel 0. Enumerate all defined effect IDs, identifying unused effects separately. Independently confirm source-derived preliminary counts (354 moves, 216 positive-power, 138 zero-power, 198 used of 214 defined effects) against the supported ROM; report discrepancies rather than forcing these values.
2. Treat admission and semantic coverage as separate axes. For each family, record actual admission plus represented-with-stated-limits, candidate, blocked-on-state, or intentionally rejected. A positive-power fallback never proves effect behavior. Explain any mixed family with per-move distinctions.
3. Include member IDs/counts, source script/command owner, existing implementation/test evidence, and concrete missing prerequisites. Explicitly enumerate unsupported admitted positive-power fallthroughs and intentionally rejected cases. Bound every represented claim to existing engine limitations.
4. The Lua test SHA-verifies the ROM, reads all records through existing import code, checks an exhaustive non-overlapping expected inventory/count partition, and invokes actual `BattleEngine:supportsMove` for every real record. Expected admission/classification must come from independently reviewed expectations, not be derived from the predicate being tested. Print aggregate diagnostics only; never retain or dump the parsed table. Skip cleanly without a ROM.
5. Rank a small shortlist using demonstrated early-story trainer/learnset use, prerequisite cost, and testability; propose exactly one next source-lock discovery task. Do not implement or authorize that family here.
6. Complete the dedicated route's focused test, full no-ROM and SHA-verified-ROM suites. No runtime replay is required because this package only inspects data and admission; no gameplay is changed. Independent review must assess the exact report/test revision and runner evidence.

## Required evidence

- Baseline: `env -u POKEPORT_ROM bash scripts/test_all.sh` against the accepted Pain Split revision.
- Focused: `lua5.1 tests/phase4_move_effect_inventory_test.lua`; the existing focused step may skip without an inherited ROM environment.
- Full: existing full no-ROM and verified-ROM suites on `firered-mint`. The latter explicitly injects the SHA-verified `POKEPORT_ROM` and must run this inventory test without skipping; this is the guaranteed ROM-backed inventory evidence. Retain the explicit no-replay route branch.
- Review: exact request/implementation revision, guarded run, and independent review under `work/reviews/`.

## Stop / escalate when

Required source behavior cannot be classified without guessing, source/ROM
counts disagree, the source pin cannot be verified, a required route/probe is
missing, the runner/ROM is unavailable, or a proposed change touches runtime
behavior. Record user-owned blockers and continue independent authorized work;
never invent evidence or bypass the route.

## Completion and handoff

Worker records exact paths, source pin, partition counts, checks, guarded run,
and published revision. Reviewer returns PASS / NEEDS_FIX / BLOCK. Orchestrator
reconciles `P4-02`, updates derived routing, and dispatches the one selected
discovery family. Phase 2's external references and Phase 4's broader exit gate
remain open.

## Dispatch — 2026-09-20

Pain Split is independently accepted at `a739ddc`. The
[contract readiness review](../reviews/2026-09-20-move-effect-inventory-readiness-review.md)
passes after clarifying that guaranteed non-skipped ROM evidence comes from the
full verified-ROM suite. Source/test preparation may begin in an isolated local
worktree while `P4-02-ROUTE` adds the reviewed route in the main checkout.
These packages have disjoint writable paths; neither may change gameplay.
Worker must wait for exact configuration review and a successful separate
probe before publishing the inventory request. Local source counts and a
no-ROM skip cannot close this task.

## Prepared artifact and preflight result

Preparation `688433a3093dc15db32d62bd5a59fd7a84ac0cd0` is preserved on GitHub
branch `work/move-effect-inventory`. The
[independent preflight review](../reviews/2026-09-20-move-effect-inventory-preflight-review.md)
passes its exact source/report/test artifacts: all 354 memberships and 214
dispatch owners matched pinned source, actual admission matched 248/106,
150 no-ROM test files passed, and nine controlled mismatch cases failed safely.
This is source/test evidence only; overall acceptance remains blocked on the
separate probe and non-skipped guarded SHA-ROM execution.

When the runner returns, resume the same authorized probe, then transport only
the new test/report from the prepared revision through the dedicated route.
This task's coordination/evidence record is already maintained on main and
need not be replaced by its older prepared-branch copy. No effect-32 discovery
or Phase 4 completion follows until final inventory acceptance.
