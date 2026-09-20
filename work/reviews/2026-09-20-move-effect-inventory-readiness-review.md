# Move-effect inventory contract readiness review

- Disposition: `PASS` — bounded inventory and route contracts are ready after the evidence-command clarification below.
- Scope: the two `OPEN` successor contracts only; no Pain Split implementation verdict, route configuration acceptance, or inventory completion claim.
- Reviewed checkout: `a430b6fe9741e98b94a01c27636b8a9d189f43b0`.
- Independent live recovery: `git ls-remote origin refs/heads/main` returned `a739ddc88cb44a33d5e6025e619cf1df3fe6a1a8` on 2026-09-20. The checkout's additional changes are coordination/task/review records; engine and bridge match that live revision.
- Inventory contract SHA-256: `cb5acb63476a17e40c1f3316926ecd08de408d126cb2704104d029e81098be78`.
- Original inventory contract SHA-256: `df31a11672957eb347a135184330f1135b6f83dbc367d09619ca33e9dc5c7e11` (`NEEDS_FIX`, corrected below).
- Route contract SHA-256: `9ac0a96310ff7c152486c6b27b20b5d2f88fe8b681ff463915ba0010f810151c`.
- Source pin independently checked: `c75f352304d529f6ba92d4f74b9cf8b5c3810788`.

## Original finding and verified correction

The original inventory contract's Required evidence said the focused command includes
"the guarded verified-ROM invocation." The route contract adds only the
selected-interpreter invocation to the existing focused-test case. That step
currently receives `ROUTE`, not `steps.rom.outputs.path`. The ROM lookup writes
the path to `GITHUB_OUTPUT`; it does not export `POKEPORT_ROM` to later steps.
Consequently, the focused invocation can correctly skip when the runner locates
the ROM through its private directory fallback. The existing full verified-ROM
step explicitly supplies the verified path and will execute the new aggregate
test through `scripts/test_all.sh`.

The requested clarification was: the focused
invocation may skip without an inherited ROM environment; the mandatory
SHA-verified aggregate inventory execution and its non-skipped result come from
the existing full verified-ROM suite. This keeps the exact route commands and
all shared workflow behavior unchanged. Alternatively, an explicit focused-ROM
command would require a corresponding precise route design, but that is not
necessary to satisfy the aggregate-ROM gate. No additional test or gameplay
acceptance is requested.

The Orchestrator corrected only the inventory contract's Required evidence:
the focused invocation may skip without an inherited ROM environment, while
the full SHA-verified-ROM suite must execute this inventory test without
skipping. Recheck on 2026-09-20 confirmed that wording and the final digest
above; the route contract's digest is unchanged. This resolves the sole
readiness finding without route widening, changed commands, or additional
acceptance. The final disposition is `PASS`; the original finding is retained
here as review history.

## Material evidence and accepted boundaries

The three implementation targets agree exactly between the two contracts:
`tests/phase4_move_effect_inventory_test.lua`,
`work/tasks/phase4-move-effect-inventory.md`, and
`work/reports/phase4-move-effect-inventory.md`. Coordination and independent
reviews are excluded from Worker staging. The separate route task confines
configuration to the new selector, literal allowlist, focused command, explicit
no-replay branch, and literal staging, with corresponding route documentation
and one separately reviewed/probed request path. No existing Pain Split route
is reused or widened.

Coverage includes IDs 1–354, excludes sentinel 0, includes zero-power moves,
and accounts separately for unused defined effects. A read-only enumeration of
the pinned source independently produced 354 moves, 216 positive-power moves,
138 zero-power moves, 198 used effects, and 214 defined effects. These are
source counts only; the contracts correctly leave ROM confirmation and any
discrepancy unresolved until evidence exists.

Actual admission and semantic coverage are separate axes; mixed families,
unsupported admitted positive-power fallthroughs, explicit rejection, source
owners, existing tests, limitations, and missing prerequisites are required.
The reviewed engine currently admits positive power except Dream Eater, the
stat-stage/screen sets, and the literal Pain Split exception. Therefore the
historical positive-power-only discovery cannot substitute for this inventory.
Independent expectations and an exhaustive non-overlapping partition make the
planned aggregate check meaningful without altering that predicate.

The report permits numeric identifiers, counts, source symbols, classification,
and evidence links while forbidding ROM content, table dumps, strings, assets,
and caches. Source discovery is pinned and uncertain semantics must stop rather
than being inferred from effect names. Candidate ranking requires demonstrated
early-story relevance, prerequisites, and bounded testability, with exactly one
next discovery proposal and no implementation authorization.

The private-runner design preserves trusted-main dispatch, one request, SHA
verification, fail-closed targets, both complete suites, and independent
configuration review before a separate substrate-only probe. An explicit
no-replay case already exists for constructor-only trainer work; the proposed
inventory exception is justified by its read-only scope. Probe success cannot
prove the inventory or gameplay. Public CI and current probes provide no
alternate ROM inventory acceptance path.

## Checks and exact next allowance

The existing no-ROM suite passed all 149 test files, exit 0, using local Lua 5.1
with `POKEPORT_ROM` and `POKEPORT_RUNTIME_REPLAY` unset. No new inventory test,
ROM execution, route probe, or gameplay replay was run during this readiness
review. No configuration or runtime changes were made.

No repeated baseline was needed for this wording-only recheck. Pain Split's
separate independent implementation PASS is now recorded in
[`2026-09-20-pain-split-implementation-review.md`](2026-09-20-pain-split-implementation-review.md)
for exact implementation `a739ddc88cb44a33d5e6025e619cf1df3fe6a1a8`.

Orchestrator may reconcile that separate implementation PASS and dispatch the
reviewed bounded route-maintenance contract, with source preparation in its
separate allowed paths. Inventory request publication still requires exact
configuration review and a separate probe PASS. This readiness verdict accepts
neither an unimplemented route nor inventory results; it does not close P4-02,
change Phase 2's external-reference blocker, or advance Phase 4. Coordination
updates and publication remain with their assigned owners.
