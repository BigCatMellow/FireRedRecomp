# FireRedRecomp Coordination Handoff

- Status: `READY_FOR_WORKER`
- Canonical status owner: [`../roadmaps/CAPABILITY_CHECKLIST.md`](../roadmaps/CAPABILITY_CHECKLIST.md)
- Active task: [`../tasks/phase4-foe-only-multimon-trainer-orchestration.md`](../tasks/phase4-foe-only-multimon-trainer-orchestration.md)

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
The guarded foe-only multi-Pokémon implementation is ready for independent
review. It uses the existing forced-switch primitive only after the faint
message sequence, settles EXP/EV per defeated foe, and postpones the trainer
flag until the final foe is defeated.

## Phase 2 resume point

The remaining input is user-owned trusted retail captures for both documented
anchors, with FireRed revision, emulator/device, frame/timing, 240×160 crop, and
filter provenance. Do not commit that media. On receipt, execute the scoped
comparison task, create text-only discrepancy records, and independently review
them before any parity claim. Phase 2 remains `IN PROGRESS`.
