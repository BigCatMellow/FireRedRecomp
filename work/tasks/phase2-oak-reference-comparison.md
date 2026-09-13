# Task: compare Phase 2 Oak/reference captures against trusted external input

- Status: `BLOCKED ON TRUSTED EXTERNAL REFERENCE`
- Type: `PHASE 2 / EXTERNAL EVIDENCE / COMPARISON`

## Goal

Compare published implementation captures for `oak-static` and
`pallet-camera-anchor` against user-owned trusted retail captures. Produce only
text discrepancy records; do not claim parity or change visuals.

## Required external input

For each anchor: a user-owned retail capture, FireRed revision, emulator/device
and version, deterministic frame/timing instructions, exact 240×160 crop and
filter settings. Keep every image outside git.

## Procedure

1. Run the harness at `0017727c` (or record later revision) with verified ROM.
2. Normalize only the external copy to its documented crop; record transforms.
3. Run `tools/pixeldiff/main.lua` outside the repository and record the schema
   defined by the harness task: provenance, command, dimensions, discrepancy,
   and `parity_claim: YES | NO`.
4. Independent review assesses the record. A mismatch becomes a bounded fix;
   self-diff or missing input never becomes parity.

## Boundaries

No rendering/gameplay edits, no media in git, and no parity claim without this
trusted external comparison.
