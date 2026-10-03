# Viridian Old Man state-projection source lock

- Task: [P5-02-OLD-MAN-DISCOVERY](../tasks/phase5-viridian-old-man-projection-discovery.md).
- Reference: `pret/pokefirered c75f352304d529f6ba92d4f74b9cf8b5c3810788`.
- Scope: only the map-entry projection selected by `VAR_MAP_SCENE_VIRIDIAN_CITY_OLD_MAN`.
- Status: discovery evidence only; no runtime behavior, route, or completion claim.

## Source-locked records and order

`include/constants/vars.h` assigns the scene variable `0x4051`; it is set to
one by the accepted Oak-Lab Dex progression source and to two after the Old
Man tutorial. `data/maps/ViridianCity/scripts.inc` registers only
`ViridianCity_OnTransition` for this map. Its source order is world-map flag,
then exactly one scene projection, then the unrelated Gym-door check, then
`end`:

| scene value | exact transition branch | resulting source projection |
| --- | --- | --- |
| `0` | `SetOldManBlockingRoad` | set `VAR_OBJ_GFX_ID_0` (`0x4010`) to lying-down graphics 34; permanently set tutorial local ID 4 to `(21,11)` and `FACE_DOWN` movement type |
| `1` | `SetOldManStandingByRoad` | set the same graphics var to Old Man 1 graphics 32; permanently set local ID 4 to `(21,8)` and `LOOK_AROUND` |
| `>=2` | `SetOldManNormal` | set that graphics var to Old Man 1 graphics 32; no coordinate or movement-template write occurs in this branch |

The map template is separately pinned by `data/maps/ViridianCity/map.json`:
`LOCALID_TUTORIAL_MAN` is local ID 4, `graphics_id=OBJ_EVENT_GFX_VAR_0` (240),
initial `(21,6)`, elevation 3, `LOOK_AROUND`, ranges `(2,3)`, and its NPC
script is `ViridianCity_EventScript_TutorialOldMan`. `include/constants/event_objects.h`
identifies graphics 32 as `OLD_MAN_1`, 34 as `OLD_MAN_LYING_DOWN`, and 240 as
`VAR_0`. `event_data.c:VarGetObjectEventGraphicsId` resolves that VAR slot;
`event_object_movement.c:GetObjectEventGraphicsInfo` resolves IDs >=240 through
it before graphics lookup. `ScrCmd_setobjectxyperm` calls
`SetObjEventTemplateCoords`; `ScrCmd_setobjectmovementtype` calls
`SetObjEventTemplateMovementType`. Thus these are template/projection writes,
not the tutorial interaction/battle itself.

The unrelated tutorial route begins only when the separate coordinate triggers
observe scene one at `(20,8)` or `(22,8)`: it uses scripted facing/movement,
`StartOldManTutorialBattle`, waiting, item/UI behavior and finally sets scene
two. That entire continuation is excluded. Scene zero's road-block coordinate
trigger and generic player-motion dispatch are likewise excluded.

## Current decoded and live seams

The current importer decodes `MapEvents` object templates, including local ID,
graphics ID, position, movement type, ranges, script pointer and flag. It also
decodes coordinate events. `ScriptBytecode` decodes `setvar`, but has no
documented decoder/runner support for `setobjectxyperm` or
`setobjectmovementtype`; an unknown reached opcode stops decoding rather than
guessing its shape. `ScriptInterpreter` can write a supplied `setVar` hook,
but `DialogueRunner` supplies no session-variable hook, so unhooked operations
advance control flow without live state effects.

At runtime `GameSession:setVar` owns persistent event variables and
`ViridianParcelStory` already sets `0x4051` to one at accepted Dex progression.
`loadMapObjectEvents` rebuilds `ObjectEventState` from immutable decoded
templates on every load. `ObjectEventState` stores graphics/position/movement
only at construction; it has no template-projection update API. The renderer's
`ObjectEventGraphicsInfo` intentionally rejects dynamic graphics IDs >=240
because live script-var state is unavailable; `npcSprite` records that failure.
Consequently, setting scene one today does not project graphic 32 or `(21,8)`
onto the live template/NPC, and running an arbitrary Viridian script must not
be mistaken for this map-transition hook.

## Boundaries and one possible successor

No private ROM was required: all facts above are source and current-code
inspection. Exact values after a normal branch are intentionally limited to
the literal source writes; this report does not infer template reset or
cross-map lifetime beyond the cited permanent-template commands. It makes no
claim for the Old Man battle, player coordinates, interaction text, Teachy TV,
flags/items, battle controller, generic script VM, object renderer overhaul,
save policy, or full Viridian traversal.

At most one later task is indicated: a design-only `P5-02` projection contract
for map-entry evaluation of this single scene variable and local ID 4. It would
need to decide the precise in-memory template/live-NPC projection lifetime and
prove the three source branches against decoded Viridian data. It must not
implement generic callbacks, coordinate dispatch, tutorial behavior, or a
general persistent-world-state model.

## Evidence

Inspected the pinned map script/template, constants and C command/graphics
owners; then compared them with `import/MapEvents.lua`, `import/ScriptBytecode.lua`,
`src/core/ScriptInterpreter.lua`, `src/core/DialogueRunner.lua`,
`src/core/ObjectEventState.lua`, `import/ObjectEventGraphicsInfo.lua`,
`main.lua`, and `src/core/ViridianParcelStory.lua`. No ROM, runtime run, tests,
map dump, generated asset, or external state was used or changed. Independent
exact report review is required before any design route.
