# FireRedRecomp Coordination Handoff

- Record role: `HANDOFF`
- Primary information class: `TASK CONTEXT`
- Status: `READY_FOR_WORKER`
- Lifecycle: `ACTIVE`
- Authority: coordination state only; root `AGENTS.md` and active task contracts own authority
- Canonical status owner: [`../roadmaps/CAPABILITY_CHECKLIST.md`](../roadmaps/CAPABILITY_CHECKLIST.md)
- Parent gameplay gate: [`../tasks/phase3-exit-proof.md`](../tasks/phase3-exit-proof.md)
- Blocked evidence task: [`../tasks/phase3-complete-runtime-exit-replay.md`](../tasks/phase3-complete-runtime-exit-replay.md)
- Active prerequisite: [`../tasks/local-worker-bridge-complete-runtime-route.md`](../tasks/local-worker-bridge-complete-runtime-route.md)
- Machine state: [`STATE.json`](STATE.json)

## Summary

Orchestrator reconciled the latest Worker `BLOCKED` result. The complete Phase 3 runtime replay remains the correct smallest parent-proof leaf, and Worker found no gameplay defect. The blocker is only that the guarded Local Worker Bridge does not yet recognize this evidence task.

A separate bounded infrastructure prerequisite now owns that mismatch:

`work/tasks/local-worker-bridge-complete-runtime-route.md`

It must extend the already-reviewed explicit bridge-routing pattern with one narrow `phase3-complete-runtime-exit-replay` route. It may not implement the replay or alter gameplay.

Phase 3 remains `IN PROGRESS`; canonical capability status is unchanged.

## Why this prerequisite exists

The live bridge correctly fails closed on unknown routes. Its current explicit routes cover the prior Oak Parcel/Dex and title/Oak tasks, but not the new complete-runtime replay package.

The blocked evidence task authorizes bounded replay/test support and `main.lua` replay-driver plumbing, but does not authorize changing `.github/workflows/local-worker-bridge.yml`. Worker therefore stopped at the authority boundary instead of weakening the bridge.

## Active Worker package

Execute only:

`work/tasks/local-worker-bridge-complete-runtime-route.md`

Expected bounded result:

1. add explicit request/probe selection for `phase3-complete-runtime-exit-replay`;
2. add only its hard-coded authorized target allowlist;
3. add its explicit focused-test command;
4. add its explicit runtime-replay command;
5. add explicit publish staging limited to authorized files;
6. preserve the full no-ROM and verified-ROM suite gates;
7. preserve exact FireRed US v1.0 SHA-1 verification;
8. preserve trusted `push` to `main` only and no public-PR self-hosted execution;
9. prove route recognition with a non-gameplay probe or equivalent deterministic validation;
10. route the exact bridge-maintenance revision to independent Reviewer.

Do not add a wildcard/generic fallback or infer permissions from task prose.

## Boundaries

### MAY CHANGE

- `.github/workflows/local-worker-bridge.yml`
- `work/coordination/LOCAL_RUNNER_BRIDGE.md` if needed
- focused bridge validation/probe support if required
- active task / coordination / review documentation

### MUST NOT CHANGE

- `main.lua` or gameplay/runtime behavior
- the complete-runtime replay implementation itself
- public-PR execution policy
- supported-ROM policy or exact ROM SHA gate
- save format/layout
- ROM/cache/BIOS/extracted content
- broader repository permissions
- independent-review requirement

## After independent PASS

Orchestrator must restore:

`work/tasks/phase3-complete-runtime-exit-replay.md`

as `READY_FOR_WORKER`.

Worker can then produce the evidence-only continuous artifact:

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

If that run exposes a real gameplay defect, Worker must stop on the first exact failing seam rather than modify gameplay under the evidence-only task.

## Status truth

- Phase 3: `IN PROGRESS`
- title/Oak entry leaf: `REVIEWED PASS`
- complete-runtime replay leaf: blocked behind this bounded bridge prerequisite
- active package: `local-worker-bridge-complete-runtime-route.md`
- gameplay defect discovered: no
- canonical capability status: unchanged

## Next role

`WORKER`

Execute the bridge prerequisite only, publish only inside its standing bounded authority, record exact evidence/revision, and route to independent Reviewer.

## Continuous-improvement check

This is the same concrete bridge limitation encountered when dispatch moved from Oak Parcel/Dex to title/Oak: explicit fail-closed routing intentionally requires a new route for each authorized large-file task. That is a security property, not evidence for a generic bridge redesign. The smallest correction is therefore another explicit route, not broader automation architecture.
