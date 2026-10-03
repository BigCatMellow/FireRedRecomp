# Viridian Old Man projection design — independent review

Verdict: **PASS** — bounded design only.

- Reviewed revision: `87644b27a029ba9af0b598a64f732bab7ad60b57`.
- Task: [P5-03 Old Man design](../tasks/phase5-viridian-old-man-projection-design.md).
- Artifact: [projection design](../reports/phase5-viridian-old-man-projection-design.md).
- Source authority: [accepted P5-02 source lock](2026-10-02-viridian-old-man-projection-discovery-review.md), pinned to `pret/pokefirered c75f352304d529f6ba92d4f74b9cf8b5c3810788`.

## Scope and timing

The exact commit changes only the permitted design task and report; no runtime,
decoder, map, script, test, route, ROM, state, or generated artifact is
changed, and `git diff --check` passes. The contract places its one map-specific
projection after Viridian events are decoded and before
`ObjectEventState.new` builds live NPCs in `loadMapObjectEvents`. That matches
the current object-loading owner: it is early enough to give the new live NPC
the resolved values, while avoiding a post-construction mutation mechanism or
a generic map-script callback.

## Exact contract confirmed

The design identifies only Viridian City (group 3, map 1), only local ID `4`,
and only its normal decoded base graphics ID `240`. It reads only persisted
`GameSession:getVar(0x4051)` and creates a temporary copy of that one template.
The literal source-derived projections are correct:

- scene `0` → graphics `34`, `(21,11)`, `FACE_DOWN` (`8`);
- scene `1` → graphics `32`, `(21,8)`, `LOOK_AROUND` (`1`); and
- scene `>=2` → graphics `32`, with the decoded `(21,6)` and decoded
  `LOOK_AROUND` (`1`) retained.

The pinned source independently confirms those branch writes and the base
Viridian template. The design correctly represents retail permanent template
commands by reconstructing the bounded state from the already-persisted scene
on each Viridian map entry, rather than claiming a new general persistent
template model.

## Fail-closed boundaries

Missing session, wrong map, missing/mismatched local-ID template, non-240 base
graphics, non-integer scene, and negative scene values are all explicit
diagnostic no-ops. Values at least two follow the source's `call_if_ge` case.
That policy avoids silently projecting onto an arbitrary NPC or falling back to
unrelated graphics.

Resolving ID `240` only in this projection is also correct. Current
`ObjectEventGraphicsInfo` deliberately rejects dynamic IDs because it lacks
live script-variable state; the design supplies static IDs `32`/`34` to
`npcSprite` without relaxing that global failure boundary. It leaves
`MapEvents`, `ScriptBytecode`, `ScriptInterpreter`, and `DialogueRunner`
decoder/dispatcher semantics untouched.

## Single later boundary and exclusions

The design names only one future boundary: a small map-specific pure helper,
the `loadMapObjectEvents` integration call, and focused three-scene/refusal/
unrelated-template tests. It does not grant implementation authority itself.
Coordinate triggers, tutorial behavior and battle, Teachy TV/items/flags,
scene-two mutation, generic callbacks, generic dynamic graphics, renderer,
save/world-state policy, Parcel changes, and Viridian traversal remain
explicitly excluded.

This PASS permits the Orchestrator to define that one bounded implementation
task. It does not permit code, a general hook or object system, traversal, or
additional Phase 5 scope without a new contract.

Only this review file was authored. No code, task, state, or commit was changed
by the Reviewer.
