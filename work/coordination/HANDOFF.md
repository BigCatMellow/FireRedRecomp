# FireRedRecomp Coordination Handoff

- Record role: `HANDOFF`
- Primary information class: `TASK CONTEXT`
- Status: `BLOCKED_WORKER_ENVIRONMENT`
- Lifecycle: `ACTIVE`
- Authority: coordination state only; root `AGENTS.md` owns publication authority
- Canonical status owner: [`../roadmaps/CAPABILITY_CHECKLIST.md`](../roadmaps/CAPABILITY_CHECKLIST.md)
- Active task: [`../tasks/oak-parcel-dex-presentation-north.md`](../tasks/oak-parcel-dex-presentation-north.md)
- Machine state: [`STATE.json`](STATE.json)

## Current state

Orchestrator reconciled the latest live state. There is no Reviewer result and no implementation revision to review. Phase 3 remains `IN PROGRESS`; the north-facing Oak Parcel/Dex presentation remains the smallest current critical-path task.

The blocker is execution infrastructure, not task definition. The prior Worker recovered the exact runtime insertion point, confirmed the presenter and focused test already exist, and published no gameplay change because the scheduled environment lacked a safe writable checkout or bounded edit path for the large existing `main.lua`.

## Decision

Preserve the current Oak task. Do not dispatch unrelated work merely to keep the loop active. Do not advance capability or phase status.

## Required unblock

Provide Worker with either:

1. a writable repository checkout, or
2. a safe bounded patch/edit capability for existing files.

Final acceptance also requires the project's private verified-ROM evidence environment. No ROM, extracted assets, generated caches, or other prohibited game content may be committed.

## Resume sequence

Once the edit path is repaired:

```text
WORKER
→ resume the same Oak presenter task
→ apply only the already-scoped main.lua integration
→ run available focused/no-ROM evidence
→ run required private verified-ROM evidence where available
→ record exact revision/evidence
→ REVIEWER independently verifies exact revision
→ ORCHESTRATOR reconciles parent Phase 3 gate
```

## Do not redo

- Do not restart source-order investigation for the presenter.
- Do not replace the existing task graph or roadmap.
- Do not widen into generic script/addobject behavior or other Oak orientations.
- Do not bypass the canonical Mart/Parcel/Dex path with synthetic state injection.
- Do not mark Phase 3 complete from this leaf task alone.
- Do not ask again for task-bounded publication authority; root `AGENTS.md` already grants it.

## Latest Orchestrator result

At `2026-09-10T16:00:00Z`, Orchestrator preserved `BLOCKED_WORKER_ENVIRONMENT`, made no status advancement, dispatched no unrelated package, and left the exact Oak task ready to resume after the execution substrate is repaired.
