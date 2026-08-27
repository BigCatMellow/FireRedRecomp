# Review: bounded Viridian Parcel/Dex runtime progression

- Task: [`work/tasks/viridian-parcel-runtime-integration.md`](../tasks/viridian-parcel-runtime-integration.md)
- Reviewer: `/root/parcel_final_review` (independent helper)
- Verdict: `APPROVED`

## Acceptance criteria check

- `PASS` — Mart scene 0 grants one Parcel, scene 1 is non-shop, and scene 2
  reaches the existing real Mart UI.
  - Evidence: reviewer source trace and the verified-ROM replay marker show
    Mart scene 1 on entry, followed by `bought=5` only after Dex completion.
- `PASS` — live movement reaches Oak and persists the bounded source-derived
  Dex sequence before the purchase/catch path.
  - Evidence: verified-ROM replay reports `routeSouth=13,0`, `lab=1027@6,4/5`,
    `dex=true`, then catches through the real UI path.
- `PASS` — fresh-process save/restart confirms the required persistent state.
  - Evidence: `parcel=0 dex=true labScene=6 martScene=2`, party 2, and a
    positive reduced Poké Ball count in the replay restart marker.
- `PASS` — focused test and both suites pass.
  - Evidence: reviewer reproduced `lua5.1 tests/viridian_parcel_story_test.lua`
    (16/0), `bash scripts/test_all.sh` (119 files), and the verified-ROM
    replay; owner also reproduced the verified-ROM 119-file suite.

## Applicable review lenses

- [x] Functional / acceptance
  - The reviewer inspected the task contract, current diff, live replay, and
    the authoritative local decomp state transitions.
- [x] Authority / permission boundary
  - The diff stays within the bounded controller/replay/test/documentation
    paths and does not claim the parent task's visible-cutscene parity.

## Findings

No blocking findings. Future work remains in the parent task: visible scripted
movement, messages, fanfares, and generic map-script parity are not approved
or claimed by this review.

## Evidence checked

- `lua5.1 tests/viridian_parcel_story_test.lua`
- `bash scripts/test_all.sh`
- `POKEPORT_ROM=/home/mellow/Documents/Projects/Pokemon_ReComp_FireRed/FireRed/pokefirered-master/pokefirered.gba bash scripts/runtime_natural_capture_replay.sh`
- Local FireRed `ViridianCity_Mart` and `PalletTown_ProfessorOaksLab` scripts

## High-risk completion / release summary

N/A — medium-risk task; publication remains a separately authorized action.

## Reviewer limits

- Missing context/evidence: none.
- New requirements discovered: none; visible-cutscene parity remains in the
  already-existing parent task.
