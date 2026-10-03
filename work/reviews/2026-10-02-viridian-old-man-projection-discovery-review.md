# Viridian Old Man projection discovery — independent review

Verdict: **PASS** — source lock only; no design or implementation authority.

- Reviewed revision: `4fbd0d6f5684116483d6f55515c10a08b8ce82eb`.
- Task: [P5-02 Old Man discovery](../tasks/phase5-viridian-old-man-projection-discovery.md).
- Artifact: [source-lock report](../reports/phase5-viridian-old-man-projection-discovery.md).
- Immutable reference: `pret/pokefirered`
  `c75f352304d529f6ba92d4f74b9cf8b5c3810788`.

## Boundary and exact revision

The exact commit changes only the permitted discovery task and report. It adds
no runtime, decoder, importer, script, map, test, route, ROM, generated-data,
state, UI, battle, or implementation change; `git diff --check` passes. The
reference checkout resolves to the stated immutable source revision and has no
tracked local difference.

## Source order independently confirmed

At the pinned source, `ViridianCity_MapScripts` registers the sole
`MAP_SCRIPT_ON_TRANSITION` hook. `ViridianCity_OnTransition` first sets the
world-map flag, then evaluates the mutually exclusive old-man scene branches,
then performs the unrelated Gym-door check and ends. Each selected branch has
the following literal order:

- scene `0`: write `VAR_OBJ_GFX_ID_0` (`0x4010`) to Old Man lying-down
  graphics `34`, then permanently set tutorial local ID `4` to `(21,11)`, then
  set its movement type to `FACE_DOWN`;
- scene `1`: write the same graphics variable to Old Man 1 graphics `32`, then
  permanently set local ID `4` to `(21,8)`, then set `LOOK_AROUND`; and
- scene `>=2`: write Old Man 1 graphics `32` only; this branch has no
  coordinate or movement-template command.

The constants and Viridian template agree with the report: the scene variable
is `0x4051`; local ID `4` has dynamic graphics ID `240` (`OBJ_EVENT_GFX_VAR_0`)
and the initial template position is `(21,6)`. The source command bodies call
`SetObjEventTemplateCoords` and `SetObjEventTemplateMovementType`, supporting
the report's careful classification as template projection rather than a
tutorial interaction or battle.

## Decoder/live-runtime distinction

Current code decodes object and coordinate templates and has a generic
`setvar` interpreter hook. It does not document/execute the two
template-mutation commands; an unknown script opcode halts decoding rather
than guessing its width. `GameSession:setVar` can persist the scene value, and
the accepted Parcel/Dex controller already writes it to `1`. However,
`loadMapObjectEvents` rebuilds NPC state from decoded templates on every load,
`ObjectEventState` exposes no projection mutation API, and the graphics
decoder explicitly rejects dynamic IDs at or above `240` for lack of live
script-variable resolution. The report is therefore correct not to equate the
persisted scene variable, source decoding, or arbitrary script execution with
a live on-transition projection.

## Exclusions and next allowance

The report preserves the required exclusions: scene-zero road coordinate
behavior; scene-one tutorial triggers, facing/movement, special battle,
waitstate, item/UI and scene-two continuation; generic callback dispatch;
renderer overhaul; save/world-state policy; Parcel progression; and full
Viridian traversal. It does not claim ROM evidence, live behavior, or a
complete solution.

This PASS permits only one later design-only contract for map-entry projection
of this single scene variable onto local ID `4`, including an explicit lifetime
decision and three-branch test plan. It does not authorize code, a generic
script VM, coordinate dispatch, tutorial behavior, or any broader Phase 5
work.

Only this review file was authored. No design, implementation, task, state, or
commit was changed by the Reviewer.
