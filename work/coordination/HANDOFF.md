# FireRedRecomp Coordination Handoff

- Record role: `HANDOFF`
- Primary information class: `TASK CONTEXT`
- Status: `READY_FOR_WORKER`
- Lifecycle: `ACTIVE`
- Authority: coordination only; root `AGENTS.md` and active task contract control implementation
- Canonical status owner: [`../roadmaps/CAPABILITY_CHECKLIST.md`](../roadmaps/CAPABILITY_CHECKLIST.md)
- Parent balance evidence: [`../evidence/pokemon-firered-balance-translation-manifest.md`](../evidence/pokemon-firered-balance-translation-manifest.md)
- Active task: [`../tasks/pokemon-firered-balance-foundation.md`](../tasks/pokemon-firered-balance-foundation.md)
- Machine state: [`STATE.json`](STATE.json)

## Summary

The frozen package translation manifest independently passed at
`6da2c4b1fec866e60b04c84a534a29f570bb03e6`. It found two real missing target
seams: per-move category resolution and composable learnset additions. The
active task adds those capabilities only; it may not add frozen balance values.

The previous Phase 3 bridge task remains paused by explicit human
reprioritization and is unmodified.

## Worker package

Implement only the category/learnset foundation task. Required evidence:

1. unchanged unmodded Gen-3 golden behavior;
2. deterministic synthetic category and learnset-overlay tests;
3. full no-ROM suite;
4. prohibited-scope diff check; and
5. exact revision routed to an independent Reviewer.

If any `main.lua` learnset consumer is unavailable before mod runtime setup,
or a category change conflicts with an effect path, stop with the first exact
seam. Do not insert the balance package to make a test pass.

## Boundaries

### MAY CHANGE

- category resolver/event seams, pure level-up addition merge, common main
  learnset resolver, focused tests, and task/coordination/review evidence.

### MUST NOT CHANGE

- package data, generated category map, mods content, move values, species,
  trainers, encounters, AI, economy, items/TM compatibility, save format,
  ROM policy/content, Phase 3 work, or independent-review requirement.

## After independent PASS

Dispatch the separate frozen-package mod task. That task—not this one—will
materialize all 355 category records, eight move overrides, 13 natural
additions, and negative-scope evidence.

## Next role

`WORKER`
