# FireRedRecomp Coordination Handoff

- Record role: `HANDOFF`
- Primary information class: `TASK CONTEXT`
- Status: `READY_FOR_REVIEWER`
- Lifecycle: `ACTIVE`
- Authority: coordination state only; root `AGENTS.md` and the active task own authority
- Canonical status owner: [`../roadmaps/CAPABILITY_CHECKLIST.md`](../roadmaps/CAPABILITY_CHECKLIST.md)
- Parent gameplay gate: [`../tasks/phase3-exit-proof.md`](../tasks/phase3-exit-proof.md)
- Active gameplay task: [`../tasks/phase3-title-oak-entry-proof.md`](../tasks/phase3-title-oak-entry-proof.md)
- Machine state: [`STATE.json`](STATE.json)

## Summary

Worker completed the bounded title/new-game → Oak/identity → fresh-bedroom package and published the tested implementation at exact revision:

`8bdbda903fb0574cb169968976d4b40ce96d3563`

The change is intentionally narrow:

```text
normal title A/START input
-> existing Oak intro
-> existing Oak A continuation
-> existing NewGameFlow identity path
-> existing fresh-session bootstrap
-> Player's House 2F (map 4,1) at 6,6
```

No generic scene-stack architecture, Phase 2 Oak visual-parity work, Phase 4 battle work, Mart/Parcel/Dex behavior, save-layout expansion, ROM policy change, or prohibited content was added.

Phase 3 remains `IN PROGRESS`. Worker does not have authority to close the gameplay leaf or parent Phase 3 gate without independent Reviewer PASS.

## Exact implementation

Published implementation revision:

`8bdbda903fb0574cb169968976d4b40ce96d3563`

Changed files:

- `main.lua`
- `tests/phase3_title_oak_entry_test.lua`
- `scripts/runtime_title_oak_entry_replay.sh`

The bridge request that produced the tested implementation was finalized at:

`6e54f06ff72fc3732256d471d7d722b95767e29b`

Local Worker Bridge run:

`34604493910`

## Evidence

All guarded bridge gates passed before publication:

1. explicit `phase3-title-oak-entry-proof` route selection — PASS;
2. private FireRed US v1.0 SHA-1 `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc` — VERIFIED;
3. bounded target validation + `git apply --check` — PASS;
4. patch application + `git diff --check` — PASS;
5. focused test — `PASS: Phase 3 title -> Oak entry seam contract`;
6. no-ROM suite — `PASS: 122 test files (no-ROM mode; ROM-dependent checks skip cleanly)`;
7. verified-ROM suite — `PASS: 122 test files`;
8. route-specific runtime replay — PASS;
9. publish verified bounded implementation — PASS.

Runtime evidence emitted:

```text
RUNTIME_REPLAY title_oak_entry PASS title=true oak=true identity=true map=1025 pos=6,6 party=0 money=3000 bagEmpty=true pcPotion=true dexZero=true names=RED/GREEN gender=0
```

This proves the replay starts in the title view, reaches Oak through normal START input, reaches the existing identity flow through normal A input, and reaches the fresh-session bedroom boundary without calling `GameSession.fromNewGame` directly from the replay.

The final state is the exact established Player's House 2F boundary used by the already-proven bedroom → Pallet runtime path: map group 4, map 1, coordinate 6,6.

## Reviewer assignment

Independently review only exact implementation revision:

`8bdbda903fb0574cb169968976d4b40ce96d3563`

Verify it against `work/tasks/phase3-title-oak-entry-proof.md`, especially:

- the title input reaches the existing Oak intro rather than bypassing it;
- Oak/identity progression uses normal runtime input seams;
- the replay does not construct a post-Oak session fixture;
- identity continuity is preserved into the new session;
- initial map/coordinates, party, bag, money, PC Potion, and Dex state match the fresh-session boundary;
- the implementation stayed within the task's allowed surface;
- the focused, no-ROM, verified-ROM, and runtime evidence is sufficient and reproducible;
- there is no regression or hidden widening into unrelated systems.

Return `PASS`, `NEEDS_FIX`, or `BLOCK` against the agreed task criteria only.

## Do not widen into

- Phase 2 Oak Nidoran/platform/fade/shrink visual parity;
- true camera/reference screenshot parity;
- generic scene-stack architecture;
- general script-interpreter expansion;
- Phase 4 trainer battles or move/effect work;
- already-passed Mart/Parcel/Dex presenter behavior;
- save-layout/sector expansion;
- supported-ROM policy changes;
- ROM, BIOS, cache, screenshot, or extracted-content publication.

## Next role

`REVIEWER`

Independent Reviewer verifies revision `8bdbda903fb0574cb169968976d4b40ce96d3563` only.

## After independent PASS

Orchestrator must re-evaluate the full [`../tasks/phase3-exit-proof.md`](../tasks/phase3-exit-proof.md) acceptance against accumulated deterministic evidence before changing canonical Phase 3 status.

A PASS on this title/Oak leaf does not by itself authorize Phase 3 `DONE`.

```text
Phase 3 title/Oak entry proof
-> Worker implementation/evidence: 8bdbda903fb0574cb169968976d4b40ce96d3563
-> all required Worker evidence PASS
-> READY_FOR_REVIEWER
-> REVIEWER
-> ORCHESTRATOR re-evaluates full Phase 3 exit proof after PASS
```
