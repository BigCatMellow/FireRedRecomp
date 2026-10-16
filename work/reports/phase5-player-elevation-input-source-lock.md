# P5-05 — player elevation lifecycle lock and bounded integration proposal

- Status: `READY_FOR_REVIEWER`; source research only, no implementation approval.
- Task: [elevation input source lock](../tasks/phase5-player-elevation-input-source-lock.md).
- Public pret source: `c75f352304d529f6ba92d4f74b9cf8b5c3810788`, clean checkout.
- Dispatch base: `d9c6318176efeff5f4a403e7eaa521430a89bf88`; all tracked Lua
  identical to runtime baseline `ba669fb420d68f54c8dab362c21bc0faf874f372`.
  Pre-publication main `4d9fb2f24f2d85d788c9cadc0d7121bbaccb32a4` changes
  only STATE/HANDOFF; runtime, task and AGENTS unchanged.
- Result: bootstrap and ordinary on-foot normal-step elevation ownership and
  observation order are source-known. Propose one live PlayerMovement state
  integration below. Unsupported relocation histories remain explicitly unknown;
  a normal finish on height 1–14 can re-establish both fields without guessing.
- The [accepted parent lock](phase5-viridian-northbound-gate-discovery.md) is
  terminal. This report does not repeat tutorial/projection discovery. It does
  not implement or prove C0/C2/C3 execution, traversal or normal-save parity.

## Proven producer and scheduler order

All C source citations refer to the pinned pret revision. Abbreviate stored
`currentElevation` as C and stored `previousElevation` as E. E is the effective
player elevation, **not necessarily the height of the previous tile**.

1. Fresh local object creation: `src/overworld.c:2134–2148`
   `InitObjectEventsLocal` resets objects and calls `InitPlayerAvatar`.
   `src/field_player_avatar.c:1286–1315` sets template elevation 0, spawns the
   player, sets NOT_MOVING/T_NOT_MOVING and normal controllable state.
   `src/event_object_movement.c:1206–1212,1312–1372` clears the object (including
   fixedPriority), gives current/previous coords the same spawn coordinate,
   sets C/E from the zero template, and sets triggerGroundEffectsOnMove.
   Spawn call chain is `1622–1628 → 1599–1619 → 1549–1596 → 1312`;
   sprite creation itself does not perform the elevation update.
2. Normal sprite callback: the MOVEMENT_TYPE_PLAYER callback table at
   `src/event_object_movement.c:230–242,1686–1698` selects
   `MovementType_Player` (`src/field_player_avatar.c:126–133`), which calls
   `UpdateObjectEventCurrentMovement` (`src/event_object_movement.c:5110–5125`).
   Order is spawn ground effects, movement action, begin-step ground effects,
   finish-step ground effects. Spawn processing consumes the pending flag
   before any held movement can shift coordinates.
3. Sampling: spawn/begin/finish gates are
   `src/event_object_movement.c:8721–8768`; each calls
   `UpdateObjectEventElevationAndPriority:8378–8386`. fixedPriority skips the
   update. Otherwise `ObjectEventUpdateElevation:8400–8411` samples grid
   heights at current and previous coords. Either sampled 15 leaves C/E
   unchanged; otherwise C becomes current height and E becomes current height
   only when nonzero. The pending ground-effect flags are then cleared.
4. Scheduling, not just a call graph: `src/main.c:241–249` calls callback1
   before callback2. `src/overworld.c:1394–1415,1449–1464,1480–1485` runs
   CB1 transition-state/input processing **before** player_step, while CB2
   runs script/tasks then AnimateSprites. `src/sprite.c:304–316` invokes each
   in-use sprite callback. Thus a sprite's completed walk/finish sampling in
   CB2 is observed by the **following** CB1, before another step is started.
5. Normal walk selection: `src/field_player_avatar.c:485–531,811–818,843–846`
   selects normal walking only after collision/mode checks and sets its held
   action. `src/event_object_movement.c:5238–5243,5649–5709` executes that action;
   Step0 initializes then immediately advances the first movement frame.
   `InitNpcForMovement:5309–5330` shifts previous coords to origin and current
   coords to destination (`ShiftObjectEventCoords:2249–2254`), sets begin flag,
   and initializes the normal step. The begin sample therefore sees
   **destination/origin**.
6. `sSpeedNormalStepFuncs:8866–8883` has sixteen Step1 entries;
   `NpcTakeStep:8933–8945` completes on the sixteenth. At completion,
   `UpdateMovementNormal:5339–5346` calls `ShiftStillObjectEventCoords:2294–2296`
   before raising the finish flag. Both coordinate fields now equal the
   **destination**; finish sampling sees destination/destination. The action
   marks heldMovementFinished in that sprite callback.
7. Next CB1: `UpdatePlayerAvatarTransitionState`
   (`src/field_player_avatar.c:746–783`) recognizes the finished moving action
   as T_TILE_CENTER; `src/field_control_avatar.c:94–143` marks tookStep only
   for MOVING and non-forced tile context. `ProcessPlayerFieldInput:193–227`
   obtains the position, checks trainer/on-frame priority, then step scripts.
   `GetPlayerPosition:345–348` reads dest coords and `PlayerGetElevation`
   (`src/field_player_avatar.c:1092–1094`), namely E after the finish update.

Fresh map setup uses `LoadMapInStepsLocal` (`src/overworld.c:1848–1933`),
including object initialization in case 4, before the load loop returns
(`2043–2045`) and CB1/CB2 overworld callbacks are installed (`1527–1542` for
new game, `1578–1589` for ordinary map loading). This does **not** imply a
frame-exact fade or all on-warp script outcome. At raw creation C/E are 0/0;
the first player sprite callback samples the spawn before its first movement.
Even if ordinary input is accepted on that first callback cycle, no first
completed-step coordinate read can precede spawn/begin/finish processing.

## Literal ordinary-state/read oracles

These are deductions from the cited assignments/order, not observations of a
running ROM. Pair notation is `(C,E)`. Ordinary means non-fixed-priority,
normal one-tile on-foot movement; collision eligibility itself is not expanded.

| Starting history / sampled heights | Spawn or begin result | Finish result and next eligible E read |
| --- | --- | --- |
| Fresh spawn height 3; both coords spawn | (0,0) → (3,3) | Before movement E=3; first normal 3→4 ends (4,4), reads 4 |
| Fresh spawn height 0 | (0,0) → (0,0) | First 0→3 begins/finishes (3,3), reads 3 |
| Fresh spawn height 15 | (0,0) retained | First 15→3 begin retains (0,0); finish (3,3), reads 3 |
| Known (3,3), origin 3 → destination 0 | Begin (0,3) | Finish (0,3), reads 3, not 0 |
| Known (3,3), origin 3 → destination 15 | Begin retains (3,3) | Finish retains (3,3), reads 3 |
| Known (3,3), origin 15 → destination 4 | Begin retains (3,3) because previous sample is 15 | Finish (4,4) because previous coords now destination; reads 4 |
| Known (3,3), origin 15 → destination 0 | Begin retains (3,3) | Finish (0,3), reads 3 |
| Known (3,3), origin 0 → destination 4 | Begin (4,4) | Finish (4,4), reads 4 |
| Unknown history → completed normal destination 1–14 | Begin may remain unknown | Finish assigns both fields to that height; history no longer matters |
| Unknown history → completed normal destination 0 or 15 | No general E recovery | E remains unknown; 0 may establish only C, never invent E |

Blocked/standing is not synonymous with “no sampling.” Ordinary collision
selects walk-in-place (`src/field_player_avatar.c:884–887`);
`InitMoveInPlace`/completion (`src/event_object_movement.c:6133–6182`) sets no
begin/finish ground-effect flags or coordinate displacement. Ordinary standing
uses `PlayerFaceDirection` (`field_player_avatar.c:475–477,890–893`);
`FaceDirection` (`event_object_movement.c:5276–5282`) makes both coords current
but does not request an elevation sample. With no pending flags these actions
do not update C/E and do not produce an ordinary tookStep. However a pending
spawn/reset flag still samples before the stationary action. For example,
fresh spawn on height 3 plus blocked input must still establish (3,3).
Mid-walk callbacks after begin and before finish do not resample absent new
flags; stopping at frame 15 must not expose a completed-step observation.
Frozen/locked script and fixedPriority contexts are not inferred from this
normal-input slice; source spawn processing itself precedes the frozen check.

## Runtime ownership and relocation boundary

Runtime citations refer to `ba669fb`, unchanged at dispatch. There is currently
no C/E state. `src/core/PlayerMovement.lua:50–58,95–127` keeps visual tile coords
at origin until tick16; destTileX/Y already hold the destination. Preserve
these public position/rendering semantics; do not move tileX/Y at begin just
to imitate the source's internal coordinate fields. Raw height already comes
from `import/MapBlockData.lua:24–35` and `main.lua:2276–2284`.

`main.lua:809–833` ticks movement and dispatches the completed step. Its input
loop runs the scheduler before accepting the next movement (`4470–4476,
4680–4694`), unlike source CB1/CB2 frame placement. The proposal preserves the
runtime cadence and requires finish elevation before same-tick dispatch; it
does not promise retail callback-frame parity. Future read boundary is
`tryEarlyStoryTriggerAt:2504–2507`; **no existing Viridian gameplay handler
consumes elevation there**. Tests may observe the owned state at that boundary;
do not add an ignored fifth argument or a throwaway event filter to imply use.

| Runtime entry owner | Source distinction / proposed bounded treatment |
| --- | --- |
| `loadWalkAssets:1886–1904` creates a debug first-walkable-tile player | Not a source save/new-game entry. Construct with unknown elevation until an explicit qualified bootstrap or normal finish converges. |
| `bootstrapFreshSession:2406–2434` loads map then sets actual starting tile | Qualified fresh-avatar producer: initialize C/E=0/0 at the final tile and perform pending spawn sampling before movement. Do not sample the old tile during loadMap. |
| `loadMap:2276–2305` | Common map-generation boundary invalidates existing elevation/pending step before replacing block data, even for same map ID. It is not universally equivalent to InitObjectEventsLocal. |
| Warp `2318–2342`; connection `2358–2387` | Runtime replaces map then directly repositions. Source normal load may create a fresh avatar, whereas connection camera adjustment preserves/translates object coords (`event_object_movement.c:2299–2322`). Full warp/on-warp/connection timing not locked here: invalidate, do not blindly zero/reseed or sample off-map data. |
| Saved-state restore `2479–2493`; whiteout placements `4454–4456,4531–4533` | Saved location alone does not prove effective elevation history; invalidate. No new saved field, schema, restore parity or fabricated E=3. |
| Oak escort/starter-stop/rival placements `2511–2525` | Existing abbreviated sequences directly mutate position. Explicitly invalidate at each placement (including same-tile placements); preserve every existing story result and predicate. |
| Mart presenter `2676–2688`; ledge branch `PlayerMovement:100–106`; developer walking `main.lua:3533–3540` | Treat script-owned/forced or developer motion as unqualified for this slice. Explicitly invalidate; do not accidentally recover merely because they call the same tick method. Existing motion/replay behavior otherwise unchanged. |

Normal gameplay calls `tryMove` at `main.lua:4690–4693`; automated path helper
`535–558` also calls it and must be classified explicitly by the implementation
as test/developer rather than granted provenance by call shape. Ordinary
movement after an excluded transition may recover only at an explicitly
qualified normal finish with in-bounds destination height 1–14. This is a
source-derived convergence rule, **not** parity for the excluded transition.
Unknown 0/15 history stays unknown. If the next gate needs that unknown
history before convergence, stop that future elevation-sensitive path;
do not block/change existing unrelated gameplay while implementing this input
prerequisite. Running/surfing/jumps/fixedPriority/Quest Log and map mutation
during a step are outside the qualified ordinary model.

## Exactly one successor proposal — live elevation input ownership

Proposed ID `P5-05-PLAYER-ELEVATION-INPUT`, implementation only after an adopted
task and independent acceptance of this lock. Literal five-path allowlist:

- `src/core/PlayerMovement.lua`
- `main.lua` — only bootstrap, normal-step, relocation invalidation and narrow
  production-test seams needed for this ownership
- `tests/player_movement_test.lua`
- `tests/phase5_player_elevation_input_test.lua` (new)
- `work/tasks/phase5-player-elevation-input.md` (task/evidence)

Bounded design:

1. Add transient C/E plus validity/provenance and pending spawn/normal-step
   sampling state to the existing PlayerMovement instance, not a disconnected
   utility or saved schema. Invalid reads return unknown/nil plus a reason,
   never a sentinel that could compare equal to event elevation. Keep a narrow
   getter for effective E; names are implementation choices, semantics are not.
2. Wire an in-bounds decoded-height reader and map-generation identity from
   main. Qualified fresh bootstrap resets at the **final** start coordinate to
   0/0 with pending spawn. Process spawn before the first action even when no
   movement starts; blocked input must not discard pending spawn. Missing,
   malformed or out-of-map height is unknown, never default 0 or 3.
3. Qualified normal motion captures origin/destination. At its first movement
   tick sample spawn if pending, then destination/origin for begin; at tick16
   sample destination/destination for finish **before** completed-step dispatch.
   Intermediate ticks preserve state. Existing timing, collision, public
   coordinates, pixels, direction changes and ledge outcome stay unchanged.
4. Main explicitly marks ordinary-input provenance, invalidates at the entry
   owners above, and ensures script/developer/ledge motion cannot silently
   requalify itself. Detect coordinate/map-generation mismatch before starting
   or finishing an owned step as a fail-closed backstop; explicit invalidation
   remains necessary for same-coordinate relocations. Cancel pending elevation
   work on invalidation; do not carry a source-map sample into a new map.
5. Unknown history may become known only after the qualified normal finish
   convergence above, or an explicit qualified fresh-avatar bootstrap. Do not
   claim E=0 is invalid: known fresh/retained zero is distinct from unknown.
   Keep values known across subsequent ordinary 0/15 transitions per the table.
6. Actual ownership must run in production load/bootstrap and scheduler paths,
   not only through a unit API. Tests capture C/E/validity immediately before
   the existing completed-step story dispatch using the actual production
   function/closure and synthetic inputs. No generic exported test architecture
   or unrelated main refactor. The eventual C0 handler will need to read E and
   refuse unknown state; **that handler is absent and is not this proposal**.

Required future assertions: every table row, first/later step, pending-spawn
standing/blocked versus ordinary no-flag standing/blocked, frames1/15/16,
15→4 begin-retain/finish-change, and known E=0 versus unknown. Production
tests must exercise qualified bootstrap, actual normal input/tick/dispatch
ordering, a later step, map load/warp/connection/save/story relocation
invalidation, same-coordinate invalidation, stale step/map generation,
script/ledge/developer nonqualification, and recovery only on ordinary finish
1–14. Assert no persistent var/flag/party/bag writes from elevation ownership.
Tests that only construct a new helper and never run main's paths are insufficient.

Regression commands for the future implementation: focused
`lua5.1 tests/player_movement_test.lua`,
`lua5.1 tests/phase5_player_elevation_input_test.lua`,
`lua5.1 tests/early_story_test.lua`,
`lua5.1 tests/fresh_save_bootstrap_test.lua`, and
`lua5.1 tests/map_connections_test.lua`; repository checker, full no-ROM suite
before/after and green public CI. Any required guarded evidence must be
specified by the compiled implementation task, not inferred from this report.
No local ROM/runner authority is conveyed.

Stops: a sixth implementation path, a new persistent field, changing collision
or existing story predicates/order, unsupported movement presented as normal,
missing map sample or provenance, or inability to test actual production
owners without broader architecture. Unknown relocation behavior must remain
unknown until convergence, not trigger another blanket movement investigation.
These are bounded exclusions, not unresolved bootstrap/normal-walk scheduling.

## Executed research checks / handoff

- Clean source and isolated dispatch worktree; exact revisions above.
  `git diff --exit-code ba669fb HEAD -- '*.lua'` passed. Parent runtime
  192-file no-ROM PASS and parent PR42 final public runs `38812239244` /
  `38812232691` are carried evidence, not rerun claims.
- Source searches actually run: `rg -n 'ObjectEventUpdateElevation|UpdateObjectEventElevationAndPriority|InitPlayerAvatar|ShiftObjectEventCoords|RunTasks|AnimateSprites|ProcessPlayerFieldInput' src/event_object_movement.c src/field_player_avatar.c src/overworld.c src/field_control_avatar.c`;
  `rg -n 'callback1|callback2' src/main.c`;
  `rg -n 'MovementType_Player|UpdatePlayerAvatarTransitionState|PlayerWalkNormal|PlayerFaceDirection' src/field_player_avatar.c`.
  Numbered reads of the cited ranges established flags/order, not search hits
  alone. Reproduce critical writes using
  `nl -ba src/event_object_movement.c | sed -n '5110,5125p;5309,5348p;8378,8412p;8721,8768p'`.
- Runtime ownership search: `rg -n 'playerMovement\.(tileX|tileY)|PlayerMovement.new|playerMovement:tryMove|playerMovement:tick' main.lua`;
  read PlayerMovement, production owners and existing movement tests.
- Executed synthetic Lua observation (not a source oracle or future test):

```lua
local P = require('src.core.PlayerMovement')
local p = P.new(4, 4, P.RIGHT)
p:tryMove(P.RIGHT, function() return false end)
assert(p.tileX == 4 and p.destTileX == 5)
for i = 1, 15 do p:tick() end
assert(p.moving and p.tileX == 4)
p:tick()
assert(not p.moving and p.tileX == 5)
assert(p.currentElevation == nil and p.previousElevation == nil)
```

Run via `lua5.1 -` in repository root: PASS; confirms current origin-until-
tick16 representation and missing elevation fields only. No runtime file or
test file was edited. Source-derived table assertions above are proposed,
not claimed executed against an implementation.

Baseline checker PASS: 320 tracked Lua, 365 tracked Markdown, 1216 targets.
Final checker/whitespace/publication evidence is in the task handoff. Full
local suite not repeated for docs; public no-ROM PR CI required. ROM/replay
N/A. Reviewer must independently verify this exact lock and five-path
successor proposal. Publication is not acceptance or phase advancement.
