# P5-01: first-corridor world coverage inventory

- Record role: `RESEARCH / EVIDENCE`, not implementation authority.
- Worker result: `READY_FOR_REVIEWER`; source-only inventory, no traversal claim.
- Runtime/repository pin: `a1b35a22782ab7684999eb6f9ea21751d3596657`.
- Public reference pin: `c75f352304d529f6ba92d4f74b9cf8b5c3810788`
  in the local `pokefirered` source clone. All reference paths below mean this
  revision, not a moving upstream branch.
- Contract: [P5-01](../tasks/phase5-world-coverage-inventory.md).

## Boundary and interpretation

The selected corridor is fresh bedroom → Pallet/starter/rival → Route 1 →
Viridian Mart Parcel → return to Oak for Dex → Viridian old-man control →
Route 2 south → forest south gate → forest → north gate → Route 2 north →
Pewter → Brock's gym and its victory/reward continuation. Revisits count once.
This is a source/topology boundary, not proof that every step is reachable or
that this is a complete collision-level route. Route 2 is one source map even
though its east-side branches are outside this progression segment.

The 13 maps below include their entire event arrays for reproducible counts.
Optional houses, Pokémon Centers, Route 22 rival, museum, Diglett's Cave,
Route 2 east/Cut branches, Route 21 and Route 3 are boundary destinations only;
their interiors/events are not recursively inventoried. Running Shoes triggers
are counted because they reside in Pewter's array, but their continuation is
beyond the selected first-gym endpoint.

Classification is by evidence axis. `REPRESENTED` means the named structure or
bounded behavior exists with the stated evidence; it never means retail parity.
`BLOCKED` means a specific live semantic seam is absent/refused at the runtime
pin, not that a player has been observed physically stuck. A missing gate could
instead permit an invalid bypass. `UNKNOWN` means route-specific live proof was
not located. Counts of decoded records cannot upgrade live status.

## Exhaustive bounded metadata inventory

Stable map IDs come from `data/maps/map_groups.json` (`group_order` and
zero-based position within its group). For each map, `O`, `W`, `C`, `B` and `N`
identify, respectively, zero-based indices in `object_events`, `warp_events`,
`coord_events`, `bg_events` and `connections` of
`data/maps/<MapName>/map.json`. A count `n` enumerates exactly IDs `0..n-1`;
zero means an empty set. This gives every counted record a source JSON pointer
without publishing coordinates, layouts, text, graphics or a generated map dump.
`H` counts top-level `map_script` entries in that map's `scripts.inc`, in order.
`S` counts distinct non-null script labels referenced by O/C/B within that map;
the stable script key is `(map ID, label)`, anchored at its event's `script` field.
It is not a bytecode/opcode count or a transitive script-call inventory.

```tsv
map_id	map_name	O	W	C	B	N	H	S
4,1	PalletTown_PlayersHouse_2F	0	1	0	3	0	2	3
4,0	PalletTown_PlayersHouse_1F	1	4	0	1	0	0	2
3,0	PalletTown	3	3	3	5	2	2	11
4,3	PalletTown_ProfessorOaksLab	10	3	6	4	0	3	16
3,19	Route1	2	0	0	1	2	0	3
3,1	ViridianCity	9	5	4	5	3	1	17
5,3	ViridianCity_Mart	3	3	0	0	0	2	3
3,20	Route2	7	10	0	2	2	0	5
15,0	Route2_ViridianForest_SouthEntrance	2	4	0	0	0	0	2
1,0	ViridianForest	11	6	0	8	0	1	17
15,3	Route2_ViridianForest_NorthEntrance	3	4	0	0	0	0	3
3,2	PewterCity	7	7	7	6	2	1	19
6,2	PewterCity_Gym	3	3	0	2	0	0	4
TOTAL	13_maps	61	53	20	37	11	12	105
```

Object kinds: 60 ordinary, one clone. Coordinate kinds: 20 triggers.
Background kinds: 34 signs, three hidden items. There are 103 globally distinct
O/C/B script-label spellings, but 105 distinct `(map, label)` references.
All 13 map/header/event structure families are REPRESENTED by importers;
all individual records default to UNKNOWN for route-specific live execution
except the bounded behaviors and explicit blockers identified below. In
particular, a sign type is not evidence that all its script branches work.

Warp destinations, grouped with multiplicity (each row accounts for every W):

| Source map | Internal destinations × count | Boundary destinations × count |
| --- | --- | --- |
| House 2F | House 1F ×1 | — |
| House 1F | Pallet ×3; House 2F ×1 | — |
| Pallet | House 1F ×1; Oak Lab ×1 | Rival's House ×1 |
| Oak Lab | Pallet ×3 | — |
| Route 1 | — | — |
| Viridian | Mart ×1 | Pokémon Center 1F, House, Gym, School ×1 each |
| Viridian Mart | Viridian ×3 | — |
| Route 2 | Forest north gate ×2; south gate ×2 | Diglett's Cave north entrance ×1; Route 2 House ×1; east building ×4 |
| Forest south gate | Route 2 ×3; forest ×1 | — |
| Forest | South gate ×3; north gate ×3 | — |
| Forest north gate | Forest ×3; Route 2 ×1 | — |
| Pewter | Gym ×1 | Museum 1F ×2; Mart, House1, Pokémon Center 1F, House2 ×1 each |
| Pewter Gym | Pewter ×3 | — |

Total: 36 internal + 17 boundary = 53 warp records; this does not collapse
adjacent door tiles into one record. The 11 directed connections are Pallet
up→Route 1/down→Route 21 north; Route 1 up→Viridian/down→Pallet; Viridian
up→Route 2/down→Route 1/left→Route 22; Route 2 up→Pewter/down→Viridian;
Pewter down→Route 2/right→Route 3. Eight stay inside; three cross the boundary.
Warp and connection structures are REPRESENTED; actual traversal of every
listed record remains UNKNOWN. Accepted corridor portions are qualified below.

## Entry points and gates

All 12 H entries are structurally REPRESENTED by
[MapScripts](../../import/MapScripts.lua), but their generic live dispatch is
BLOCKED: [main](../../main.lua) `loadMap` consumes events/connections, not
`header.mapScriptsPtr`. No production MapScripts caller was found. Existing
bounded controllers are substitutes for selected outcomes, not proof these
hooks execute. Exact H labels in `data/maps/<MapName>/scripts.inc` are:

| Map | H order: type → label |
| --- | --- |
| House 2F | TRANSITION → `PalletTown_PlayersHouse_2F_OnTransition`; WARP_INTO_MAP_TABLE → `PalletTown_PlayersHouse_2F_OnWarp` |
| Pallet | TRANSITION → `PalletTown_OnTransition`; FRAME_TABLE → `PalletTown_OnFrame` |
| Oak Lab | TRANSITION → `PalletTown_ProfessorOaksLab_OnTransition`; WARP_INTO_MAP_TABLE → `PalletTown_ProfessorOaksLab_OnWarp`; FRAME_TABLE → `PalletTown_ProfessorOaksLab_OnFrame` |
| Viridian | TRANSITION → `ViridianCity_OnTransition` |
| Viridian Mart | LOAD → `ViridianCity_Mart_OnLoad`; FRAME_TABLE → `ViridianCity_Mart_OnFrame` |
| Forest | TRANSITION → `ViridianForest_OnTransition` |
| Pewter | TRANSITION → `PewterCity_OnTransition` |

The other six maps have zero H entries. The 20 coordinate entries partition as
follows; labels use the stated map prefix plus `_EventScript_`:

| Stable C IDs | Source condition and script-label suffix | Live classification |
| --- | --- | --- |
| Pallet C0–1 | `VAR_MAP_SCENE_PALLET_TOWN_OAK=0`; `OakTriggerLeft`, `OakTriggerRight` | REPRESENTED only by bounded EarlyStory escort, not source-script execution |
| Pallet C2 | `VAR_TEMP_2=1`; `SignLadyTrigger` | BLOCKED as generic coordinate dispatch; no bounded live handler found |
| Oak Lab C0–2 | `VAR_MAP_SCENE_PALLET_TOWN_PROFESSOR_OAKS_LAB=2`; `LeaveStarterSceneTrigger` | REPRESENTED bounded stay-for-starter control |
| Oak Lab C3–5 | Same variable `=3`; `RivalBattleTriggerLeft`, `RivalBattleTriggerMid`, `RivalBattleTriggerRight` | REPRESENTED bounded early-rival control; all-starter/outcome matrix UNKNOWN |
| Viridian C0 | `VAR_MAP_SCENE_VIRIDIAN_CITY_OLD_MAN=0`; `RoadBlocked` | BLOCKED: no generic coordinate/player-movement callback |
| Viridian C1 | `VAR_MAP_SCENE_VIRIDIAN_CITY_GYM_DOOR=0`; `GymDoorLocked` | BLOCKED; boundary gym, not this gym's objective |
| Viridian C2–3 | Old-man variable `=1`; `TutorialTriggerLeft`, `TutorialTriggerRight` | BLOCKED: coordinate dispatch, scripted facing and special tutorial continuation |
| Pewter C0–3 | `VAR_MAP_SCENE_PEWTER_CITY=0`; `GymGuideTriggerTop`, `GymGuideTriggerMid`, `GymGuideTriggerBottom`, `GymGuideTriggerRight` | BLOCKED: generic coordinate/movement sequence |
| Pewter C4–6 | Same variable `=1`; `RunningShoesAideTriggerTop`, `RunningShoesAideTriggerMid`, `RunningShoesAideTriggerBottom` | BLOCKED; counted but post-endpoint continuation excluded |

Object/background script references not covered by a named bounded seam retain
UNKNOWN live status, with the explicit family blockers below taking precedence
for the affected behavior. This default covers every S record, not just the
105 count. It does not assert that an undecoded or uncalled script is working.

## Runtime, assertion and receipt map

Test links here identify inspected assertions, **not new execution**. Accepted
receipts are named separately. Historical pins retain their original limits;
the [behavior ledger](../../docs/behavior-ledger.md) is not an every-map proof.

| Required seam / source anchor | Current live owner and classification | Existing assertions / accepted evidence and limit |
| --- | --- | --- |
| Map/header/events/connections; all W/N above | `main.loadMap`, `tryWarpAt`, `tryConnectionAt`, `PlayerMovement`: REPRESENTED general structures and bounded reloads; each unproven edge UNKNOWN | [Map events](../../tests/map_events_test.lua), [connections](../../tests/map_connections_test.lua), [map generalization](../../tests/map_generalization_test.lua) and [player movement](../../tests/player_movement_test.lua). Synthetic structures or selected ROM maps, not all 13 traversed. Warp fallback/first-walkable and discrete connection swaps are not retail seamless/elevation parity. |
| New bedroom → Pallet → starter/rival → Route 1 | `NewGameFlow`, `EarlyStory`, `main.tryEarlyStoryTriggerAt`: REPRESENTED bounded path | [Early-story assertions](../../tests/early_story_test.lua), [ROM assertions](../../tests/early_story_rom_test.lua); [Phase 3 PASS](../reviews/2026-09-12-phase3-complete-runtime-exit-review.md) at `4f4f29ec` proves normal boot through Route 1 loss and normal save/fresh reload. No first-gym route or all cutscene branches. |
| Mart `OnLoad`/`OnFrame`/`ParcelScene`; Lab `ReceiveDexScene` | `ViridianParcelStory` and bounded Mart/Oak presenters: REPRESENTED leaf; generic hooks BLOCKED | [Story assertions](../../tests/viridian_parcel_story_test.lua) cover Parcel/addition guards, capacity/idempotency and old-man scene becoming 1. [North Oak PASS](../reviews/oak-parcel-dex-presentation-north-final-review.md), `2d8c3221`, run `34547647645`: terminal Dex/Lab6/Mart2/Parcel0 plus fresh-process state. Only accepted orientation/sequence; this is later evidence than the older ledger's canonical-Parcel caution. No old-man gate proof follows from the variable write. |
| Script invocation and side effects, all S | `main.startScript` → `DialogueRunner.buildWorld` → `ScriptInterpreter`: REPRESENTED message/lock/face/removal/Mart hooks; generic state/movement/warp/give-item/mon/trainer/special callbacks BLOCKED in this live world | [Dialogue](../../tests/dialogue_runner_test.lua) and [interpreter fixtures](../../tests/script_interpreter_unit_test.lua). Fixture-supplied setters/hooks are not production wiring. Absent live setters/hooks can no-op; unsupported decoding can error. Live yes/no/branch correctness for arbitrary NPCs is UNKNOWN. |
| Object lifecycle, 61 O | `main.loadMapObjectEvents`, `ObjectEventState`: hide-flag filtering and normal templates REPRESENTED; Route 2 O6 clone BLOCKED (explicitly skipped) | [Object state](../../tests/object_event_state_test.lua), [integration](../../tests/object_event_state_integration_test.lua). Clone targets Viridian's `LOCALID_VIRIDIAN_BORDER_TREE`; no copied geometry is included here. Whether that boundary affects a walk is UNKNOWN. |
| NPC movement and dynamic appearance | `ObjectEventState:tick`, `main.npcMovementTask` and `npcImageFor`: eight source movement occurrences BLOCKED; Viridian O3 dynamic graphics BLOCKED | [Graphics assertions](../../tests/object_event_graphics_info_test.lua) and object-state assertions distinguish supported movement/static graphics from refusals. Seven LOOK_AROUND and one FACE_DOWN_AND_UP are not tick handlers; main catches errors and disables those ticks. Graphics VAR IDs raise without live variable resolution. These are code findings, not a fresh visual replay. |
| Hidden/background interactions | `main.tryStartInteraction`: NPC then kind-0 background script; three hidden-item B records BLOCKED in this interaction path, other sign scripts UNKNOWN unless bounded evidence applies | [Map events](../../tests/map_events_test.lua) decode kinds, not give-item/hidden-flag/bag effects. Item pickup and persistent removal must not be inferred from parser support. |
| Route 1/2/forest encounters and healing/resources | Completed-step wild path, session bag/party/save: REPRESENTED bounded Phase 3/capture seams; this corridor's encounters/resources UNKNOWN | Phase 3 receipt covers Route 1 loss. Ledger separates capture component/backing evidence from UNKNOWN full-party live PC reload. No Center/interior, full healing/menu/TM, route-wide encounter or safe-resource proof is supplied here. |
| Forest trainers and gym trainers | `TrainerSightline`, `main.resolveTrainerId/startTrainerBattle`, factory/orchestrator: REPRESENTED bounded one/two-foe no-held-item singles; two source three-foe trainers explicitly BLOCKED | [Sightline](../../tests/trainer_sightline_test.lua), [trainer-party ROM assertions](../../tests/phase4_trainer_party_rom_test.lua); [accepted two-sided leaf](../reviews/2026-09-15-phase4-two-sided-replacement-state-review.md), `4a583b6a`, is not ordinary-world forest/Brock traversal. Admitted trainer metadata is not an all-move/battle/script proof. |
| Brock `DefeatedBrock` / `GiveTM39` continuation | Generic trainer-script continuation and live flags/vars/item callback chain BLOCKED; durable badge/reward success UNKNOWN | `data/maps/PewterCity_Gym/scripts.inc`: trainer result must lead to defeated/BADGE01 flags, Pewter scene 1, guide/aide visibility, gym trainer flags and capacity-aware TM39 reward. Ordinary trainer settlement is not this continuation. No accepted Brock → badge/TM/save/reload receipt located. |

The eight unsupported movement occurrences are Oak Lab O0/O2, Viridian O3,
forest north gate O0/O1, Pewter O0/O1 (LOOK_AROUND), and forest O8
(FACE_DOWN_AND_UP, Anthony). The source movement histogram is FACE_DOWN 26,
FACE_LEFT 6, FACE_UP 5, FACE_RIGHT 4, WANDER_AROUND 5,
WANDER_UP_AND_DOWN 4, WANDER_LEFT_AND_RIGHT 2, LOOK_AROUND 7,
FACE_DOWN_AND_UP 1 = 60 ordinary objects. Initial facing support is separate
from unsupported per-tick behavior.

Source trainer IDs/party sizes from `include/constants/opponents.h`,
`src/data/trainers.h` and `src/data/trainer_parties.h` are Rick 102/2,
Doug 103/3, Sammy 104/1, Anthony 531/2, Charlie 532/3, Liam 142/2 and
Brock 414/2. Doug/Charlie fail the current one/two-foe guard. The remaining
records fit that size boundary, not a claim they are playable: normal forest
records use no-item/default-move parties and CHECK_BAD_MOVE; Liam uses
no-item/custom moves with CHECK_BAD_MOVE; Brock uses no-item/custom moves and
AI flags 7, which passes the existing early-rival AI flag admission. Brock must
not be incorrectly labeled rejected solely for AI flags. Move-effect,
AI-behavior, approach/dialogue and post-battle continuation coverage remain
separate Phase 4/5/6 dependencies.

## Exactly one proposed next source lock

Select **Viridian old-man on-transition state projection** only. This is the
earliest identified *new progression-control seam* beyond the accepted bounded
starter/Parcel/Dex behavior, not a claim that all earlier optional scripts or
presentation are complete. Reference anchors are
`data/maps/ViridianCity/scripts.inc:ViridianCity_OnTransition`,
`ViridianCity_EventScript_SetOldManBlockingRoad`,
`...SetOldManStandingByRoad`, `...SetOldManNormal`, and Viridian O3
(`LOCALID_TUTORIAL_MAN=4`, `OBJ_EVENT_GFX_VAR_0`).
`include/constants/vars.h` fixes the old-man scene at `0x4051` and
`VAR_OBJ_GFX_ID_0` at `0x4010`.

Source scene 0 selects lying graphics and a blocking template position/facing;
scene 1 selects standing graphics and a different position/LOOK_AROUND; scene
≥2 assigns normal graphics without those explicit template writes. The accepted
Parcel/Dex commit sets scene 1, but `loadMap` never runs this transition and
static sprite resolution rejects its VAR graphics. This isolates a concrete
missing state-to-object seam instead of guessing that all scripts need a VM
rewrite. Source `ScrCmd_setobjectxyperm` and `ScrCmd_setobjectmovementtype`
(`src/scrcmd.c`) mutate object-event templates; they are not synonymous with
moving an already spawned NPC. Neither command is presently decoded by name
or opcode `0x63`/`0x65` in `ScriptBytecode`.

The later source-lock task should establish exact map-entry/template/spawn
ordering, scene 0/1/≥2 behavior on fresh entry and re-entry, dynamic graphics
lookup, hide/local-ID handling, and what prior template mutations survive.
It must identify the smallest testable ordinary-entry boundary before any
design. Do not implement a generic hook dispatcher, template editor or graphics
resolver from this inventory. The exact ordering/persistence details are still
UNKNOWN here and are the proposed discovery's work.

Crucially, this projection alone cannot close the northbound gate. Viridian C0
also needs the source RoadBlocked movement; C2/C3 call `DoTutorialBattle`, whose
`StartOldManTutorialBattle` special/waitstate, scene-2 write and Teachy TV reward
cross battle, callback and UI boundaries. They remain separately BLOCKED and
are exclusions from the proposed projection discovery's implementation scope
(there is no implementation scope yet). Forest/Pewter hooks, NPC movement
expansion, clone objects, arbitrary flags/scripts, trainer expansion, Brock
reward, Running Shoes and other candidate families are not co-selected.

Phase 4 battle gates, Phase 6 inventory/menu gates, save-backed state mutation,
and field callback ordering must stay separate in subsequent contracts.
Independent inventory review must PASS before any Phase 5 design or
implementation; this recommendation creates neither task authority nor a new
canonical capability status.

## Reproduction and checks

Run the following from the repository with a local public-source clone at the
shown location (or change only `ref` to that clone). It uses `git show` at the
immutable source pin, prints aggregate metadata only and performs no ROM I/O
or writes. Map names are taken from the TSV above, so the report itself defines
the bounded input set rather than an implicit recursive world crawl.

```python
import collections, json, pathlib, re, subprocess
ref = "/home/home/FireRedRecomp-reference/pokefirered"
pin = "c75f352304d529f6ba92d4f74b9cf8b5c3810788"
report = pathlib.Path("work/reports/phase5-world-coverage-inventory.md").read_text()
table = re.search(r"```tsv\n(.*?)\n```", report, re.S).group(1)
rows = [line.split("\t") for line in table.splitlines()[1:]]
expected = rows[:-1]
def source(path):
    return subprocess.check_output(["git", "-C", ref, "show", pin+":"+path], text=True)
groups = json.loads(source("data/maps/map_groups.json"))
ids = {name: (g, n) for g, group in enumerate(groups["group_order"])
       for n, name in enumerate(groups[group])}
maps = {row[1]: json.loads(source("data/maps/"+row[1]+"/map.json")) for row in expected}
inside = {m["id"] for m in maps.values()}
totals = [0]*7
edges, kinds, movement, global_labels = collections.Counter(), collections.Counter(), collections.Counter(), set()
for row in expected:
    name, m = row[1], maps[row[1]]
    scripts = {e["script"] for key in ("object_events", "coord_events", "bg_events")
               for e in m[key] if e.get("script") not in (None, "0", "NULL")}
    hooks = re.findall(r"^\s*map_script\s+(\w+),\s*(\w+)",
                       source("data/maps/"+name+"/scripts.inc"), re.M)
    counts = [len(m[k]) for k in ("object_events", "warp_events", "coord_events", "bg_events")]
    counts += [len(m.get("connections") or []), len(hooks), len(scripts)]
    assert row[0] == "%d,%d" % ids[name]
    assert counts == list(map(int, row[2:])), (name, counts)
    totals = [a+b for a, b in zip(totals, counts)]
    global_labels.update(scripts)
    for e in m["warp_events"]:
        edges["warp_internal" if e["dest_map"] in inside else "warp_boundary"] += 1
    for e in m.get("connections") or []:
        edges["connection_internal" if e["map"] in inside else "connection_boundary"] += 1
    for key in ("object_events", "coord_events", "bg_events"):
        for e in m[key]:
            kinds[key+":"+e["type"]] += 1
            if key == "object_events" and e["type"] == "object":
                movement[e["movement_type"]] += 1
    print(row[0], name, *counts)
assert len(maps) == 13 and totals == [61, 53, 20, 37, 11, 12, 105]
assert totals == list(map(int, rows[-1][2:])) and len(global_labels) == 103
assert dict(edges) == {"warp_internal": 36, "warp_boundary": 17,
                       "connection_internal": 8, "connection_boundary": 3}
assert dict(kinds) == {"object_events:object": 60, "object_events:clone": 1,
                       "coord_events:trigger": 20, "bg_events:sign": 34,
                       "bg_events:hidden_item": 3}
print("PASS", totals, dict(edges), dict(kinds), dict(movement))
```

Worker evidence: the pinned-source enumeration reproduced all 13 rows, totals,
edge partition, event-kind partition, movement histogram and trainer sizes.
Runtime callback inspection used the repository pin, excluding concurrent
Restore HP changes. No ROM, gameplay, map/art/text dump, implementation or
environment change was used. No full-suite repeat was required for this
read-only research package. Documentation/scope check results are recorded in
the task handoff; independent acceptance is still pending.
