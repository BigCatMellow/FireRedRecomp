# FireRedRecomp Coordination Handoff

- Record role: `HANDOFF`
- Primary information class: `TASK CONTEXT`
- Status: `BLOCKED`
- Lifecycle: `ACTIVE`
- Authority: coordination state only; root `AGENTS.md` and active task contracts own authority
- Canonical status owner: [`../roadmaps/CAPABILITY_CHECKLIST.md`](../roadmaps/CAPABILITY_CHECKLIST.md)
- Parent gameplay gate: [`../tasks/phase3-exit-proof.md`](../tasks/phase3-exit-proof.md)
- Active task: [`../tasks/phase3-complete-runtime-exit-replay.md`](../tasks/phase3-complete-runtime-exit-replay.md)
- Machine state: [`STATE.json`](STATE.json)

## Summary

Worker recovered the live Phase 3 complete-runtime evidence package and found an execution-substrate blocker before implementation.

The evidence task requires a small `main.lua` replay-driver integration so one deterministic runtime case can start at the normal title/Oak path and continue through the already-existing Route 1 battle/save/reload machinery. This is replay plumbing, not a discovered gameplay defect.

However, the guarded Local Worker Bridge has no explicit route for `phase3-complete-runtime-exit-replay`.

Current bridge routes are only:

- `oak-parcel-dex-presentation-north`;
- `phase3-title-oak-entry-proof`;
- `runner-readiness` probe.

`.github/workflows/local-worker-bridge.yml` therefore fails closed on a `phase3-complete-runtime-exit-replay` request before patch application.

No implementation was published and no test or ROM result was invented.

## Why Worker stopped

The active task MAY CHANGE boundary includes:

- `scripts/` replay support;
- focused tests/assertions;
- bounded `main.lua` replay-driver plumbing;
- task/parent/review/coordination documentation.

It does **not** authorize changing `.github/workflows/local-worker-bridge.yml` or widening the bridge route/allowlist surface.

The Worker role contract also says to use the guarded Local Worker Bridge rather than unsafe whole-file replacement when a scheduler cannot safely patch an existing large file. `main.lua` is exactly that case.

Therefore Worker cannot legitimately repair the missing bridge route from inside this evidence package.

## Exact blocker

`EXECUTION_SUBSTRATE_ROUTE_MISSING`

First blocked step:

```text
publish + execute the bounded main.lua complete-runtime replay patch
through the guarded Local Worker Bridge
```

The bridge has no route for the active task, so the request would fail closed before patch application.

## Required next role

`ORCHESTRATOR`

Scope/dispatch the smallest explicit bridge-maintenance prerequisite for `phase3-complete-runtime-exit-replay`.

That maintenance package should do only what is required to add a fail-closed route with:

1. explicit `phase3-complete-runtime-exit-replay` request/probe selection;
2. a hard-coded target allowlist limited to this evidence task's authorized replay/test/main.lua surfaces;
3. a focused complete-runtime replay test/evidence command;
4. the existing full no-ROM suite gate;
5. the existing exact FireRed v1.0 SHA-1 gate and full verified-ROM suite;
6. the complete-runtime replay command itself;
7. explicit publish staging limited to authorized files;
8. independent Reviewer verification of the exact bridge-maintenance revision.

Do not add a generic fallback route or weaken trusted-main, ROM, test-before-publish, or explicit-target protections.

## After bridge-maintenance PASS

Orchestrator should restore this same active package:

`work/tasks/phase3-complete-runtime-exit-replay.md`

as `READY_FOR_WORKER`.

Worker can then integrate the existing runtime paths into one continuous artifact:

```text
normal boot
→ title / new game
→ Oak intro / identity
→ Player's House 2F
→ Pallet Town
→ Route 1
→ first wild battle
→ defeat or catch
→ normal save
→ fresh-process reload
```

The task remains evidence-only. If that continuous run exposes a real gameplay defect, Worker must stop on the first exact failing seam instead of modifying gameplay.

## Status truth

- Phase 3: `IN PROGRESS`
- title/Oak entry leaf: `REVIEWED PASS`
- complete-runtime replay leaf: `BLOCKED` on missing guarded bridge route
- canonical capability status: unchanged
- gameplay defect discovered this turn: no
- implementation published this turn: no
- tests/ROM evidence claimed this turn: none

```text
Phase 3 complete runtime replay
→ READY_FOR_WORKER
→ Worker recovered existing replay machinery
→ BLOCKED: guarded bridge lacks explicit task route
→ ORCHESTRATOR scopes bounded bridge maintenance
→ REVIEWER verifies bridge maintenance
→ ORCHESTRATOR restores same replay task
→ WORKER
```
