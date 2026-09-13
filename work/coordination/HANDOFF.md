# FireRedRecomp Coordination Handoff

- Status: `READY_FOR_WORKER`
- Canonical status owner: [`../roadmaps/CAPABILITY_CHECKLIST.md`](../roadmaps/CAPABILITY_CHECKLIST.md)
- Active task: [`../tasks/phase4-player-forced-replacement-ui.md`](../tasks/phase4-player-forced-replacement-ui.md)

## Published evidence

Phase 2 camera is closed at `4c5456f3`. The deterministic Oak/reference
implementation harness is closed and independently reviewed at `0017727c`:
guarded run `34767029627` passed validation, focused/no-ROM/verified-ROM suites,
two exact 240×160 Oak captures, two exact 240×160 Pallet captures, repeat
self-diffs, and publication. Capture media remains outside git.

## Parallel critical path

Phase 2 comparison remains blocked only on user-owned retail captures. That does
not block independent Phase 4 work. No-item trainer-party construction is now
published and independently reviewed at `f40c4021` (guarded run `34776145784`).
Foe-only multi-Pokémon orchestration is now independently reviewed and published
at `8533cf6a` (guarded run `34777072801`): it uses the forced-switch primitive
only after faint messages, settles EXP/EV per foe, and flags the trainer only
after the final foe. The next separate leaf is player forced-replacement UI
discovery; do not infer it from the foe-only path. Discovery is now complete:
existing engine and party bridge seams suffice. The active package is the
explicit bridge route for trainer-only forced replacement.

## Phase 2 resume point

The remaining input is user-owned trusted retail captures for both documented
anchors, with FireRed revision, emulator/device, frame/timing, 240×160 crop, and
filter provenance. Do not commit that media. On receipt, execute the scoped
comparison task, create text-only discrepancy records, and independently review
them before any parity claim. Phase 2 remains `IN PROGRESS`.
