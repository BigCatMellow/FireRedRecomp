# FireRedRecomp Three-Role Coordination

- Record role: `FLOW`
- Primary information class: `FLOW`
- Status: `ACTIVE`
- Lifecycle: `ACTIVE`
- Authority: coordination procedure only; does not widen task authority
- Canonical owner for three-role flow: this file

## Flow

```text
ORCHESTRATOR
  recover live state
  choose exactly one active bounded task/package
  write successor-ready STATE/HANDOFF
      ↓
WORKER
  implement only that package
  run required verification
  record exact evidence/blocker
      ↓
REVIEWER
  independently inspect exact artifact/revision
  judge only existing acceptance/stop criteria
  PASS / NEEDS-FIX / BLOCK
      ↓
ORCHESTRATOR
  reconcile evidence and canonical status
  close, route smallest correction, or dispatch next package
```

## Shared invariants

- Read root `AGENTS.md` first.
- Recover live GitHub before trusting coordination prose.
- `work/roadmaps/CAPABILITY_CHECKLIST.md` owns project-wide status.
- Active task contracts own implementation scope and acceptance.
- No role may silently widen scope.
- No ROM, BIOS, generated cache, or extracted game assets may be committed.
- Review is independent from implementation.
- A blocked role records the exact blocker rather than improvising.
- Phase status changes require evidence satisfying the checklist gate.
- Keep one bounded package in flight unless explicit parallel authority exists.

## State files

- `STATE.json` — machine-readable current relay.
- `HANDOFF.md` — fresh-agent-readable current state and exact next action.
- `roles/WORKER.md`
- `roles/REVIEWER.md`
- `roles/ORCHESTRATOR.md`

The role completing a turn updates `STATE.json` and `HANDOFF.md` last so the successor can recover a consistent relay.
