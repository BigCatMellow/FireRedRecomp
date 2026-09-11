# FireRedRecomp Coordination Handoff

- Record role: `HANDOFF`
- Primary information class: `TASK CONTEXT`
- Status: `READY_FOR_WORKER`
- Lifecycle: `ACTIVE`
- Authority: coordination state only; root `AGENTS.md` and the active task own authority
- Canonical status owner: [`../roadmaps/CAPABILITY_CHECKLIST.md`](../roadmaps/CAPABILITY_CHECKLIST.md)
- Parent gate: [`../tasks/phase3-exit-proof.md`](../tasks/phase3-exit-proof.md)
- Active task: [`../tasks/phase3-title-oak-entry-proof.md`](../tasks/phase3-title-oak-entry-proof.md)
- Previous passed leaf: [`../tasks/oak-parcel-dex-presentation-north.md`](../tasks/oak-parcel-dex-presentation-north.md)
- Previous review: [`../reviews/oak-parcel-dex-presentation-north-final-review.md`](../reviews/oak-parcel-dex-presentation-north-final-review.md)
- Machine state: [`STATE.json`](STATE.json)

## Current state

The north-facing Oak Parcel/Dex presentation leaf is now closed after
independent `PASS` on implementation revision:

`2d8c3221775044a54668683e500055307fe4d20b`

That PASS does **not** close Phase 3. The canonical checklist remains
`IN PROGRESS`.

Reconciliation of the Phase 3 parent proof shows the smallest explicit
remaining entry gap is:

```text
normal boot
→ title/new-game entry
→ Oak intro / identity flow
→ fresh session initialization
→ Player's House 2F bedroom
```

A new bounded task now owns that gap:

`work/tasks/phase3-title-oak-entry-proof.md`

## Why this is the next package

The repository already contains substantial downstream evidence:

- title-screen rendering exists;
- static Oak speech presentation exists;
- gender/player/rival naming and `NewGameFlow` exist;
- fresh-save bootstrap exists;
- Player's House 2F → 1F → Pallet runtime replay exists;
- Route 1 win/loss/capture evidence exists;
- the canonical Viridian Parcel/Dex/shop/capture/save/reload chain has been
  exercised with the verified ROM;
- the bounded north-facing Oak Parcel/Dex presenter received independent
  `PASS`.

The Phase 3 parent still lacks deterministic evidence that a **normal runtime
boot** connects the title/new-game and Oak/identity pieces into the bedroom
without directly constructing a post-Oak session fixture.

## Exact Worker allowance

`WORKER`

1. Read `AGENTS.md`, the Worker role contract, this handoff,
   `work/tasks/phase3-exit-proof.md`, and
   `work/tasks/phase3-title-oak-entry-proof.md`.
2. Characterize the live normal boot/title/new-game path first.
3. Prefer an evidence-only deterministic replay/assertion artifact if the
   existing runtime already reaches Oak/identity and the bedroom correctly.
4. If the path fails, identify the first exact missing seam and make only the
   smallest integration correction permitted by the active task.
5. Verify player/rival identity plus initial location and fresh-session state;
   do not skip the entry flow with synthetic post-Oak state injection.
6. Run focused checks, the no-ROM suite, and the verified-ROM suite where the
   environment supports them.
7. Publish only within the standing task-bounded authority and route the exact
   revision/evidence to independent Reviewer by updating `STATE.json` and
   `HANDOFF.md` last.

## Explicit boundaries

Do **not** widen this task into:

- Phase 2 Oak Nidoran/platform/fade/shrink visual-animation parity;
- true reference screenshot/camera parity;
- a new general scene-stack architecture;
- generic script-interpreter expansion;
- general trainer battle / Phase 4 work;
- save-layout/sector expansion;
- supported-ROM policy changes;
- any ROM/cache/BIOS/extracted game content in git.

If one of those becomes required, record `BLOCKED` with the exact boundary
rather than implementing it under this task.

## After Worker success

Reviewer must independently verify the exact revision and evidence. Only after
that `PASS` may Orchestrator re-evaluate whether the **entire** Phase 3 parent
exit criterion is now proven. No canonical phase advancement is authorized by
this handoff alone.

```text
Oak Parcel/Dex north leaf: REVIEWED PASS
→ Phase 3 title/Oak entry proof: READY_FOR_WORKER
→ WORKER characterizes/proves normal boot → Oak/identity → bedroom
→ REVIEWER independently verifies exact evidence/revision
→ ORCHESTRATOR re-evaluates full Phase 3 exit gate
```
