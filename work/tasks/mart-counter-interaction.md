# Task: counter-mediated NPC interaction

## Contract

- Owner: project maintainer
- Source of truth: FireRed object-event interaction behavior and the current
  `src/core/ObjectEventInteraction.lua` / `main.lua` field path
- Output boundary: pure interaction-target geometry, its runtime wiring, and
  focused tests; no Mart inventory, capture, or unrelated field-system work
- Authority: preserve ordinary adjacent NPC/sign interaction; stop if the
  reference behavior requires unmodeled object collision or elevation rules

## Problem

The live Viridian Mart clerk is at map `(5,3)`, local id `1`, coordinate
`(2,3)`. The reachable player tile `(4,3)` faces a collision counter at
`(3,3)`. Current `findInteractionTarget` checks only that immediate counter
tile, so the real clerk script—and therefore normal `pokemart` purchase—is
unreachable despite the script and UI both being implemented.

## Acceptance criteria

1. Reference-derived geometry recognizes an interactable object behind the
   applicable counter/interaction tile without allowing interaction through
   arbitrary walls or across unrelated blocked tiles.
2. Existing adjacent NPC and sign behavior remains covered by regression tests.
3. A ROM-backed test proves the real Viridian Mart clerk is targetable from
   the legal counter-facing player tile and reaches the existing script path.
4. `POKEPORT_ROM=... bash scripts/test_all.sh` passes.
5. The natural-capture replay is attempted only after this task passes; it is
   not marked complete merely because a test targets the clerk.

## Stop conditions

Stop and re-scope if the real rule depends on a broader field-control system
(elevation, multi-tile objects, or map-specific scripts) not represented in
the current collision model.

## Progress

Implemented the exact one-tile `MB_COUNTER` fallback from
`field_control_avatar.c:GetInteractedObjectEventScript` in
`ObjectEventInteraction.findInteractionTarget`. Focused regression coverage
proves counter fallback, ordinary-wall rejection, and adjacent-object
precedence. The remaining natural-capture work must validate the complete live
Mart route; it must not assume retail Parcel-story parity, because generic
map-script execution is still incomplete.
