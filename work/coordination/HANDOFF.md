# FireRedRecomp Coordination Handoff

- Record role: `HANDOFF`
- Primary information class: `TASK CONTEXT`
- Status: `READY_FOR_REVIEWER`
- Lifecycle: `ACTIVE`
- Authority: coordination state only; root `AGENTS.md` and active task contracts own authority
- Canonical status owner: [`../roadmaps/CAPABILITY_CHECKLIST.md`](../roadmaps/CAPABILITY_CHECKLIST.md)
- Active review target: [`../tasks/local-worker-bridge-phase2-camera-optional-staging-fix.md`](../tasks/local-worker-bridge-phase2-camera-optional-staging-fix.md)
- Camera task awaiting reconciliation: [`../tasks/phase2-gba-camera-viewport-proof.md`](../tasks/phase2-gba-camera-viewport-proof.md)
- Machine state: [`STATE.json`](STATE.json)

## Summary

Phase 3 remains canonically `DONE`. Phase 2 remains `IN PROGRESS`.

Live GitHub advanced beyond the previous relay. The optional camera-route staging
correction was committed at exact revision
`11394868d1800dcc53526d9b8f068d0042ec4514`. Its diff replaces the single
all-path `git add` for the existing camera allowlist with an existence-checked
loop that stages each same listed path individually.

The camera patch was then retried at `df8a17ad671ba5b614ac37abba5f2faaaf527b16`
and the guarded Local Worker Bridge published it at
`4c5456f3fc37723e60b365cce1fc8e8a32df1288`.

However, the active staging-fix task explicitly requires independent Reviewer
`PASS` before retrying the camera patch, and no durable independent review record
for revision `11394868...` exists on live `main`. Do not infer PASS merely from
the later successful publication. The repository sequence therefore has an
evidence-ordering defect that must be reconciled without undoing or self-reviewing
the already-published bounded changes.

## Active Reviewer package

Review only `work/tasks/local-worker-bridge-phase2-camera-optional-staging-fix.md`
against exact revision:

`11394868d1800dcc53526d9b8f068d0042ec4514`

Verify the task's existing acceptance and boundaries, including:

- exact existing camera staging list preserved;
- each listed path staged only if present;
- missing optional review document cannot suppress required present files;
- no wildcard/directory staging or generic fallback;
- no route, policy, ROM gate, test-order, gameplay, or allowlist widening;
- required static/no-ROM evidence as available under the Reviewer contract.

Return `PASS`, `NEEDS_FIX`, or `BLOCK`. Do not perform Worker implementation.

## After PASS

Orchestrator should close only the staging prerequisite, then route the exact
published camera revision `4c5456f3fc37723e60b365cce1fc8e8a32df1288`
through independent review/reconciliation against
`work/tasks/phase2-gba-camera-viewport-proof.md`. Only after that camera leaf is
independently PASS may Orchestrator scope the remaining Oak/reference screenshot
parity leaf.

## Boundaries

Do not mark Phase 2 `DONE`. Do not alter camera/gameplay/runtime implementation in
the staging-fix review. Do not weaken trusted-main-only execution, public-PR
prohibition, ROM SHA verification, explicit route/path allowlists, required tests,
or legal/content boundaries. Never commit ROMs, BIOS dumps, generated caches,
ROM-derived reference screenshots, extracted assets, or other prohibited content.

## Goal-continuity commitment

Continue through:

```text
staging-fix independent review
→ exact published camera revision independent review/reconciliation
→ Oak/reference parity scope
```

Stop only on a genuine failed evidence gate, authority/safety boundary, or missing
trustworthy retail-reference input. Record the first exact blocker rather than
widening scope.
