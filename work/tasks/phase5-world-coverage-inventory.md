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

## Evidence / Worker handoff — 2026-10-02

- Worker artifact: [bounded inventory](../reports/phase5-world-coverage-inventory.md),
  ready for independent review; this does not change the task's coordination
  status or authorize Phase 5 design/implementation.
- Pins: repository `a1b35a22782ab7684999eb6f9ea21751d3596657`, public source
  `c75f352304d529f6ba92d4f74b9cf8b5c3810788`. Concurrent Restore HP work is
  excluded from the runtime evidence basis.
- Aggregate source inventory: 13 maps, 61 objects, 53 warps (36 internal/17
  boundary), 20 coordinate triggers, 37 background events, 11 connections
  (8 internal/3 boundary), 12 map hooks, 105 distinct `(map, script)` entry
  references. Stable IDs/source-pointer rules enumerate all records without
  publishing a map dump. The report contains an executable no-ROM reproducer.
- Live callback gaps are distinct from decoding and accepted Phase 3/Parcel
  leaves. The sole proposed next source lock is Viridian old-man on-transition
  state projection; its coordinate/tutorial/battle/UI continuation remains
  separately blocked. No playable-to-Brock, full script support, or canonical
  status claim is made.
- Verification: the report's exact embedded reproducer PASSed all 13 rows,
  aggregate totals, edge/kind partitions and global-label count. The repository
  checker PASSed 276 Lua files, 181 Markdown files and 542 local targets using
  committed baseline `6395a4793cc0fb9b3250801018600550636e0ff5` plus only these
  two prospective artifacts (concurrent working-tree changes were not inputs).
  Whitespace/scope checks passed. The referenced field/importer/controller
  paths were unchanged between the runtime pin and that baseline.
- No ROM, gameplay, full-suite repeat, runtime/test/map/route edits, installs or
  environment changes. The checker used the pre-existing isolated Lua binary
  directly; this is an authoring check, not new clean-target/desktop evidence.
- Reviewer next action: independently assess the exact report/task revision
  against this contract; Orchestrator owns review dispatch and reconciliation.
