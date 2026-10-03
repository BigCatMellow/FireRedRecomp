# P5-01 world coverage inventory — independent review

Verdict: **PASS** — bounded source-only coverage inventory and one later
source-lock candidate only.

- Reviewed task/report revision: `7712d634a860395376067e2bafb0b843a022e722`.
- Parent/runtime evidence pin: `a1b35a22782ab7684999eb6f9ea21751d3596657`.
- Public-source pin: `pret/pokefirered`
  `c75f352304d529f6ba92d4f74b9cf8b5c3810788`.
- Reviewed artifacts: [P5-01 task](../tasks/phase5-world-coverage-inventory.md)
  and [first-corridor inventory](../reports/phase5-world-coverage-inventory.md).

## Exact boundary and independent reproduction

The reviewed commit changes only the task and aggregate report. It contains no
runtime, test, importer, map, script, route, ROM, generated-data, traversal,
or implementation change; `git diff --check` passes. The runtime pin is an
ancestor of the reviewed commit, and the reviewed runtime/importer paths have
no diff between that pin and the inventory revision. Concurrent Restore HP
working-tree files were therefore neither read as evidence nor included in
this decision.

I ran the report's embedded no-ROM reproducer verbatim against the local
reference checkout at the stated immutable pin. It passed all 13 named rows
and reproduced exactly:

- 61 objects, 53 warps, 20 coordinate triggers, 37 background events,
  11 connections, 12 hooks, and 105 distinct `(map, script)` references;
- 36 internal / 17 boundary warps and 8 internal / 3 boundary connections;
- 60 ordinary plus one clone object, 20 triggers, 34 signs, and three hidden
  items; and
- 103 global script-label spellings plus the stated movement histogram.

The reproducer reads only the report's bounded map-name table and `git show`
objects at the source pin. It emits aggregate metadata only and neither opens
a ROM nor writes source data. This is a reproducible first-corridor inventory,
not an implicit all-Kanto crawl or a map/content dump.

## Source decoding versus live execution

The report consistently keeps those axes separate. Current code decodes map
script structures (`MapHeader.mapScriptsPtr` and `MapScripts.resolve`), but
repository searches locate their consumers in importer-focused tests rather
than a production map-hook dispatcher. `main.loadMap` loads map/event objects,
while its explicit post-warp callback is the separately bounded Viridian Mart
Parcel presentation. The report consequently classifies source hooks and
general script callbacks as structurally represented but live-blocked or
UNKNOWN unless a named bounded seam has independent evidence. That is the
correct limitation; decoded events, warps, connections, object templates, or
trainer metadata are not misrepresented as successful gameplay traversal.

The source anchors for the selected seam also reproduce at the reference pin:
`ViridianCity_OnTransition` branches on the old-man scene variable; scene 0
sets lying graphics/template position and facing, scene 1 sets standing
graphics/position and `LOOK_AROUND`, and scene at least 2 selects normal
graphics. The Viridian map record identifies the tutorial man with dynamic
`OBJ_EVENT_GFX_VAR_0`, while the road/tutor coordinate entries remain separate
source callbacks. This supports a narrow state-to-object projection question;
it does not demonstrate that transition hooks, coordinate triggers, tutorial
battle, UI, flags, or persistent template mutation currently execute live.

## Single next candidate and remaining exclusions

The report selects exactly one candidate: **Viridian old-man on-transition
state projection**. It explicitly leaves RoadBlocked, tutorial coordinate and
special/battle continuation, generic script dispatch, dynamic NPC movement,
other flags, forest/Pewter hooks, clone objects, trainer expansion, Brock
continuation, Running Shoes, map reachability, and all traversal work outside
that candidate. It creates no implementation authority and makes no claim of
a playable route to Brock, complete-world coverage, private-ROM proof, or
Phase 5 completion.

This PASS permits the Orchestrator to create only a later, separately reviewed
source-lock discovery for that one projection seam. Any design, runtime
implementation, generic hook/callback system, traversal proof, or additional
candidate requires a new bounded task.

Only this review file was authored. No task, state, source, runtime, request,
or commit was changed by the Reviewer.
