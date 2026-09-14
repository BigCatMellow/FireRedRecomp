# FireRedRecomp Coordination Handoff

- Status: `READY_FOR_DISCOVERY`
- Canonical status owner: [`../roadmaps/CAPABILITY_CHECKLIST.md`](../roadmaps/CAPABILITY_CHECKLIST.md)
- Active task: [`../roadmaps/EXECUTION_MAP.md`](../roadmaps/EXECUTION_MAP.md)

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
discovery; do not infer it from the foe-only path. The bounded implementation is
now independently reviewed and published at `8fd9a397` (guarded run
`34783304717`), proving forced PARTY choice, persistence, state sync, and the
no-bench loss branch. Next dispatch is Phase 4 battle-rule/trainer-matrix
discovery, not an assumption that voluntary switching is complete. Discovery
selected trainer-only voluntary switching as the next leaf. It is closed and
published at `3140e267`; it opens a selector only for a current legal
save-backed bench, rejects cancel/stale/forged choices, invokes the existing
switch-before-foe engine action, and preserves both party records. Do not mark
broader player switching or Phase 4 complete from that leaf. Fixed-damage
effects are now closed and published at `c65cf838` (guarded run `34798961274`):
Dragon Rage (40), level damage (attacker level), and SonicBoom (20) reuse the
existing accuracy/PP/type path; type immunity remains a no-effect, while
nonzero effectiveness does not alter fixed damage or presentation. The next
active task is a source-backed admission-matrix discovery. It must distinguish
positive-power moves currently admitted by the engine from effect families the
engine actually represents, before selecting one new bounded implementation
leaf. Held-item trainer layouts remain deferred because battlers do not retain
or apply item state.

## Phase 2 resume point

The remaining input is user-owned trusted retail captures for both documented
anchors, with FireRed revision, emulator/device, frame/timing, 240×160 crop, and
filter provenance. Do not commit that media. On receipt, execute the scoped
comparison task, create text-only discrepancy records, and independently review
them before any parity claim. Phase 2 remains `IN PROGRESS`.
