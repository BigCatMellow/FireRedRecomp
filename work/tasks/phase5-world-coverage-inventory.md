# Task: inventory progression-critical world coverage

- Task ID: `P5-01`
- Status: `READY_FOR_WORKER`
- Type: `RESEARCH / READ-ONLY COVERAGE INVENTORY`
- Parent capability: Phase 5 overworld and field systems.
- Risk: `LOW` — report only; it cannot claim traversal or implement scripts.

## Goal

Create an evidence-backed, machine-checkable text inventory of the earliest
Pallet-to-first-gym progression surface: maps, connections, warps, object/event
types, script entry points and known field/UI/battle gates. Classify each as
represented, explicitly blocked, or UNKNOWN, then select exactly one earliest
progression-critical missing primitive for a later source-lock task.

## Source of truth

Pinned public reference source, current importer/map/script/runtime code,
accepted Phase 3 path evidence, behavior ledger and canonical roadmap. Source
decoding is not proof that a live callback exists; distinguish each clearly.

## MAY CHANGE

1. `work/reports/phase5-world-coverage-inventory.md`.
2. This task's evidence/handoff section.

## MUST NOT CHANGE

Runtime, tests, maps/scripts/importer behavior, task routes, save/UI/battle
policy, capability status, ROM/media, generated map dumps, external state or
user settings. Do not perform gameplay traversal, use a private ROM, add a
generic script feature, or authorize implementation.

## Acceptance

1. Define the bounded first segment and enumerate its source maps/warps/events
and progression gates with stable identifiers/source anchors.
2. Map each required live seam to current runtime owner and existing assertion/
review evidence, or mark it UNKNOWN/blocked without inferring coverage.
3. Identify dependencies on Phase 4 battle, Phase 6 UI, state/flags and script
callbacks separately from map decoding.
4. Produce aggregate-only, reproducible inventory data and select one smallest
next source-lock discovery. No complete-world or playable-route claim.
5. Independent review must PASS before any Phase 5 implementation/design task.

## Stop

Stop when source behavior needs a ROM/private data or when the first missing
primitive cannot be selected without a product decision. Record the fact and
do not widen to all Kanto.
