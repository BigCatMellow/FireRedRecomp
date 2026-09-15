# FireRedRecomp Coordination Handoff

- Record role: `HANDOFF`
- Primary information class: `TASK CONTEXT`
- Status: `READY_FOR_WORKER`
- Lifecycle: `ACTIVE`
- Authority: coordination state only; root `AGENTS.md` and active task contracts own authority
- Canonical status owner: [`../roadmaps/CAPABILITY_CHECKLIST.md`](../roadmaps/CAPABILITY_CHECKLIST.md)
- Parent balance gate: frozen PR #14 specification at `BigCatMellow/Pilot_Projects@81a0796`
- Active task: [`../tasks/pokemon-firered-balance-translation-manifest.md`](../tasks/pokemon-firered-balance-translation-manifest.md)
- Machine state: [`STATE.json`](STATE.json)

## Summary

The human owner explicitly reprioritized the frozen Pokémon FireRed balance package. Phase 3 remains `IN PROGRESS` but paused; its active bridge task is preserved rather than altered. This bounded task creates no gameplay behavior and owns only exact target translation.

The target is FireRedRecomp revision `f2c240e7a94f7a2329771b0ef06d531eabab64e6`; the source package is pinned to blob `ed4c75e54435f4b8e8889b47fd8e1c292a8a705f` at Pilot_Projects revision `81a0796`.

## Active Worker package

Execute only:

`work/tasks/pokemon-firered-balance-translation-manifest.md`

Expected bounded result:

1. verify the package and target pins;
2. map all frozen rows and negative scope to exact target seams;
3. identify concrete unsupported seams without implementing them;
4. prove manifest completeness/uniqueness mechanically where practical; and
5. route the exact documentation revision to independent Reviewer.

Do not modify runtime behavior, recreate the frozen package, or infer an unsupported representation.

## Boundaries

### MAY CHANGE

- manifest/evidence, active task, coordination, review documentation, and focused validation only.

### MUST NOT CHANGE

- `main.lua`, gameplay/runtime/importer/mod API behavior;
- Phase 3 replay/bridge work;
- supported-ROM policy or exact ROM SHA gate;
- save format/layout;
- trainer, encounter, TM compatibility, held/non-promoted, or economy data;
- ROM/cache/BIOS/extracted content;
- independent-review requirement.

## After independent PASS

Orchestrator dispatches the smallest foundation implementation task: category resolution and a learnset-overlay seam. Frozen move/learnset rows remain unimplemented until that foundation independently passes.

## Status truth

- Phase 3: `IN PROGRESS — PAUSED BY EXPLICIT HUMAN REPRIORITIZATION`
- frozen specification: `ACCEPTED` in PR #14
- active package: `pokemon-firered-balance-translation-manifest.md`
- gameplay change authorized by this package: no
- canonical Phase 3 capability status: unchanged

## Next role

`WORKER`

Execute the translation task only, publish only inside its standing bounded authority, record exact evidence/revision, and route to independent Reviewer.

## Continuous-improvement check

The existing FireRedRecomp mod registry already isolates decoded battle data from source ROM data. The manifest must determine exactly what additional narrow seams are needed before deciding whether package work should be a mod, rather than prematurely widening the engine.
