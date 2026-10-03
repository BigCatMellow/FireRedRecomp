# Viridian Old Man projection design

- Task: [P5-03-OLD-MAN-DESIGN](../tasks/phase5-viridian-old-man-projection-design.md).
- Authority: accepted P5-02 source lock `4fbd0d6`, FireRed reference pin
  `c75f352304d529f6ba92d4f74b9cf8b5c3810788`.
- Status: design only; no runtime, callback, or progression implementation.

## Exact bounded contract

The sole input is a live `GameSession` whose current map is Viridian City
(group 3, map 1) and whose decoded normal object template has local ID 4 and
graphics ID 240. Read only `session:getVar(0x4051)`. The projection must run
once for each Viridian map load/transition after map events are decoded and
before `ObjectEventState.new` creates live NPCs. It must be a map-specific
call at that existing owner seam, not an opcode handler or generic map-script
dispatcher. It writes neither the scene var nor any flag/save field.

It derives a temporary copy of that one decoded template. All unrelated object
templates remain byte-for-byte equivalent in the passed list. The copy's
literal values are:

| scene | graphics resolved for this live object | x/y | movement type |
| --- | --- | --- | --- |
| `0` | 34, `OLD_MAN_LYING_DOWN` | 21/11 | `FACE_DOWN` (8) |
| `1` | 32, `OLD_MAN_1` | 21/8 | `LOOK_AROUND` (1) |
| `>=2` | 32, `OLD_MAN_1` | the decoded template's 21/6 | its decoded `LOOK_AROUND` (1) |

Graphics are resolved in this bounded projection rather than asking the
generic graphics decoder to resolve dynamic ID 240. This matches the source's
`VAR_OBJ_GFX_ID_0` writes while respecting the current decoder's deliberately
fail-closed dynamic-ID boundary. The source's permanent coordinate/movement
commands are represented by reconstructing the appropriate projection on every
Viridian map entry from the persisted scene variable. This is sufficient for
the selected project seam; it is not a new generic persistent-template model
or a claim about retail in-memory template lifetime.

## Unknown and refusal policy

Missing session, wrong map, absent/local-ID-mismatched template, non-240 base
graphics, non-integer scene, or a scene below zero is a fail-closed no-op with
an explicit diagnostic; it must not mutate an arbitrary NPC or substitute a
fallback graphic. Values at least two follow the source's `call_if_ge` branch.
The selected contract makes no assertion about maps not currently loaded or
about later direct script writes to object templates.

## Owners and exclusions

`GameSession` remains the owner of the already-persisted scene var;
`loadMapObjectEvents` is the only integration/timing owner; `ObjectEventState`
owns the one projected live record; and `npcSprite` receives only resolved
static graphics. `MapEvents` remains decoder-only. `ScriptBytecode`,
`ScriptInterpreter`, and `DialogueRunner` gain no command or hook.

Excluded: coordinate triggers, player/NPC movement, interaction text, tutorial
battle and its controller, Teachy TV/item/flags, scene-two write, generic
transition callbacks, generic dynamic-graphics support, renderer changes,
save-format/persistent-object policy, and all other Viridian paths.

## One later implementation boundary

One implementation task may add only a small map-specific pure projection
helper plus the `loadMapObjectEvents` call and focused tests for all three
scene cases, refusal controls, and unchanged unrelated templates. It may touch
only the helper/integration/test paths named by that later task. It must not
implement tutorial/callback/script behavior or expand to a reusable world-state
system. Independent design review precedes that task.

## Evidence

Read P5-02's source anchors and inspected existing session, map-load,
object-state and graphics-decoder seams. No ROM, runtime/test execution,
map/script/importer edit, generated data, route or coordination state was used
or changed. Independent exact-revision review is required.
