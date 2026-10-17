# P5-05 — live player elevation input ownership

- Task ID: `P5-05-PLAYER-ELEVATION-INPUT`
- Status: `READY_FOR_REVIEWER` — implementation submitted; independent acceptance pending
- Type: `IMPLEMENTATION`
- Parent capability gate: [Phase 5/7 scripted traversal](../roadmaps/CAPABILITY_CHECKLIST.md), effective elevation prerequisite for future Viridian coordinate eligibility
- Assigned role: `WORKER`
- Independent reviewer: separate `REVIEWER`, exact implementation/source/assertions review
- Prerequisites: [elevation lifecycle lock and five-path proposal](../reports/phase5-player-elevation-input-source-lock.md) at `7e0cb02c20f50b8d91662a72d00da379b7a053a7` independently [PASS](../reviews/2026-10-16-player-elevation-input-source-lock-review.md) in `ce387cb`; PR43 merged `871f3f1` after final CI `38842293132` / `38842296655` PASS. Accepted northbound report PR42 remains terminal
- Runtime baseline: `ba669fb420d68f54c8dab362c21bc0faf874f372`; pin current dispatch base and preserve unrelated owner work
- Risk: MEDIUM — main.lua movement ownership changes can retain stale map state; bounded transient data only, no new gameplay handler

## Goal

Implement source-locked transient player elevation ownership in the actual
bootstrap/ordinary-input/movement/relocation paths. At the completed-step
dispatch boundary, a qualified normal step must have the proven current and
effective elevation, or explicitly unknown state. Preserve existing movement,
rendering, story and saved-state behavior. This prerequisite does not execute
C0/C2/C3 or change any story predicate; the gameplay consumer is future work.

## Source of truth

Adopt the independently accepted report's bounded design, literal state table,
source citations, relocation classification and five-path proposal. Public
pret source is `c75f352304d529f6ba92d4f74b9cf8b5c3810788` only.

Core sequence: raw fresh avatar C/E=0/0; pending spawn sampling precedes first
movement; ordinary begin samples destination/origin; finish samples
destination/destination before completed-step read. Either sampled15 retains
both fields; otherwise current height updates C, and updates E only if nonzero.
Current runtime position/pixel/frame semantics stay intact; this task does
not attempt retail callback-frame parity or general collision/movement parity.

UNKNOWNs: unsupported relocation/forced-mode histories are not newly solved.
Invalidate them explicitly; only qualified fresh bootstrap or proven ordinary
finish convergence onto in-bounds height1–14 may re-establish valid E. Unknown
is not numeric0. Do not substitute a source-known primitive for evidence of
an unsupported lifecycle.

## MAY CHANGE

- `src/core/PlayerMovement.lua`
- `main.lua` — only elevation bootstrap, ordinary input/step ownership,
  relocation invalidation and narrow production-test seams necessary here
- `tests/player_movement_test.lua`
- `tests/phase5_player_elevation_input_test.lua` (new)
- This task file (status and exact implementation/test evidence)

Reviewer may add its own independent review under `work/reviews/`. Worker may
not edit reviews, coordination, roadmaps, source report or acceptance criteria.
No separate design/report layer is required: this task adopts the reviewed
source/design proposal and contains the implementation evidence.

## MUST NOT CHANGE

No save format/serialized state, party/bag/flags/vars, collision admission,
frame count, public movement coordinates/pixels/directions, ledge outcome,
existing Pallet/lab predicates/results, encounter ordering, NPC movement,
generic script VM, coordinate handlers, tutorial/battle/rewards, rendering,
import data/formats, shared test architecture or unrelated refactor.
No ignored fifth onStep argument, throwaway Viridian filter or fabricated
gameplay consumer. No ROM/assets/caches/private paths, runner/workflow/probe/
request changes or revival of a consumed allowance. No phase/gate parity claim.

## Acceptance criteria

1. Existing PlayerMovement owns C/E, validity/provenance and pending lifecycle
   state. A narrow effective-elevation getter returns unknown/nil with a
   reason when history is not established; known E=0 remains distinguishable.
   Decoded-height reader and map-generation identity come from production.
   Missing/malformed/out-of-map samples must not become default0 or3.
2. Qualified fresh bootstrap initializes0/0 at its final actual starting tile,
   then processes pending spawn before first action, including standing or
   blocked input. Debug first-walkable construction is not qualified bootstrap.
   At normal tick1 perform pending spawn then begin; at tick16 perform finish
   before existing completed-step dispatch. Intermediate ticks do not resample.
3. Literal report table cases are asserted independently of implementation:
   nonzero, current0, current15, origin15→4 begin-retain/finish-change,
   origin15→0, fresh0/fresh15, frames1/15/16, first/later steps, standing/blocked
   with and without pending spawn, and known0 versus unknown. Unknown history
   recovers only at qualified fresh bootstrap or ordinary finish1–14, not at
   begin or finish0/15. Preserve public position/rendering and collision rules.
4. Wire actual production owners named by the report. Common loadMap invalidates
   before data replacement even for the same map ID. Warp/connection/restore/
   whiteout, abbreviated story placement, Mart/script/ledge/developer motion
   explicitly invalidate, including same-coordinate placements. Such movement
   must not silently obtain normal provenance through a shared tryMove/tick.
   Coordinate/map-generation mismatch is a backstop; invalidation cancels
   pending elevation work and prevents source-map samples reaching a new map.
5. Tests exercise actual production function/closure paths with synthetic data:
   qualified bootstrap; normal input→tick→dispatch; a later step; all selected
   relocation classes; same-position invalidation; stale generation/step;
   script/ledge/developer nonqualification; permitted and forbidden recovery.
   Observe owned state immediately before the existing story-dispatch call.
   A helper-only test or spy on an ignored argument is insufficient. No broad
   exported testing API or unrelated main restructuring to obtain coverage.
6. Assert elevation ownership does not mutate persistent session vars/flags,
   party, bag or serialized fields. Existing movement/early-story/bootstrap/
   connection regressions and full no-ROM suite pass. Include a negative witness
   showing the production assertion fails when finish sampling is delayed past
   dispatch or when a relocation retains stale valid E; record exact mutation
   and restore it without committing the fault.

## Required evidence

- Baseline: isolated clean worktree, exact runtime/source hashes; full no-ROM
  `bash scripts/test_all.sh` and `lua5.1 scripts/check_repository.lua` before
  implementation. Preserve unrelated changes and record real file count.
- Focused: `lua5.1 tests/player_movement_test.lua`,
  `lua5.1 tests/phase5_player_elevation_input_test.lua`,
  `lua5.1 tests/early_story_test.lua`,
  `lua5.1 tests/fresh_save_bootstrap_test.lua`, and
  `lua5.1 tests/map_connections_test.lua`; literal/source timing and production
  negative witness; working/index `git diff --check`.
- Full verification: complete no-ROM suite and repository checker after change,
  green public CI on implementation and final review head.
- Guarded ROM/replay: not required to accept this narrowly transient ownership
  slice, which deliberately does not change gameplay consumers, save or event
  eligibility. No ROM/replay/normal-route parity is claimed. Any expansion into
  those behaviors stops this task and requires separate authority/evidence;
  existing guarded battle/replay debt is unaffected, not waived.
- Independent review: exact published revision, source timing/limits, every
  owner/invalidation path, assertion quality and five-path scope; separate
  PASS/NEEDS_FIX/BLOCK record before merge/reconciliation.

## Stop / escalate when

A sixth implementation path, new persistent state, changed gameplay predicate/
collision/order, unknown mode being treated as normal, or broad architecture
change is necessary. Missing samples/provenance are expected fail-closed states,
not permission to invent values. If a required owner cannot be covered in the
five paths, report exact need before expanding. Do not disable unrelated
gameplay merely because elevation is unknown; no current handler consumes it.

## Completion and handoff

Worker publishes a bounded PR and records exact commits, paths, baseline/final
commands/results, production coverage, negative witness and exclusions here.
Reviewer independently verifies against this contract. Orchestrator merges
only after PASS and green final head, reconciles this ownership prerequisite,
then selects the next unmet Viridian gate dependency. Do not repeat accepted
source discovery or mark Phase5/7 or the northbound gate complete.

## Worker implementation and evidence — 2026-10-17

- Isolated branch `work/p5-player-elevation-input-20261016`, authority/base
  `9ea26858e2764ad02f5ef073935054b2660128f8`. Source hash verified
  `c75f352304d529f6ba92d4f74b9cf8b5c3810788`. Exactly the five allowed paths
  changed; no source-report, coordination, workflow, saved schema or consumer
  changes. No ROM/private runner/replay action.
- PlayerMovement now owns transient C/E, validity/reason, fresh-avatar or
  normal-finish provenance, map/coordinate ownership and pending spawn/step.
  Production decoded-height/generation readers are bound at construction;
  debug construction remains unknown. Fresh-session bootstrap qualifies only
  at its final starting tile. Begin/finish sampling preserves existing public
  positions, pixels, collision and 16-frame timing.
- Actual field input explicitly marks normal provenance. Map loads (including
  same-ID loads), warp/connection/save/story/whiteout placements, script/
  developer calls and ledges invalidate. Mart's direct ticking also invalidates
  an already-moving player, preventing takeover of pending normal provenance.
  Missing/malformed samples, missing generation and stale coordinates/steps
  fail closed. Unknown history recovers only at qualified ordinary finish1–14
  or fresh bootstrap; known E0 and unknown remain distinct.
- Production tests execute actual main functions/closures with synthetic map
  services: debug/fresh bootstrap, all four input directions, first/later
  step dispatch, map-loader invalidation before decode, same-position placement
  classes with a pending normal step, both whiteout owners, Mart takeover,
  ledges, developer walking and automated camera-helper ownership. They inspect
  C/E immediately before the existing story call, not an ignored extra argument.
  Serialized session comparison permits only the existing location update;
  elevation ownership changes no vars/flags/party/bag/save fields. No gameplay
  handler consumes E yet; the future gate remains unimplemented.

### Executed checks (not carried evidence)

- Own pre-edit baseline on 2026-10-16 at `9ea2685`, clean isolated worktree:
  `bash scripts/test_all.sh` **192 files PASS, no-ROM mode**; receipt
  `/tmp/firered-elevation-baseline-20261016.log`. Then
  `lua5.1 scripts/check_repository.lua` PASS (320 Lua, 368 Markdown,
  1230 targets). This was run before the first runtime patch, not borrowed
  from the earlier parent 192-file receipt.
- Focused final checks: `lua5.1 tests/player_movement_test.lua` **105 PASS**;
  `lua5.1 tests/phase5_player_elevation_input_test.lua` **78 PASS**;
  `lua5.1 tests/early_story_test.lua` **25 PASS**;
  `lua5.1 tests/fresh_save_bootstrap_test.lua` **12 PASS**;
  `lua5.1 tests/map_connections_test.lua` **4 PASS**.
- Full after-change command:
  `env -u POKEPORT_ROM -u POKEPORT_RUNTIME_REPLAY bash scripts/test_all.sh`
  **193 files PASS**, ROM-dependent checks skipped; receipt
  `/tmp/firered-elevation-final-20261017.log`. No guarded evidence claimed.
- Negative witness 1: temporarily changed the PlayerMovement finish guard from
  `if step and self.elevationStep == step then` to
  `if false and step and self.elevationStep == step then`. Production suite
  then reported **63 PASS / 7 FAIL**, including
  `PRODUCTION finish sampling precedes dispatch`; restored the guard and
  verified identical pre/post SHA-256 before continuing. Receipt
  `/tmp/firered-elevation-negative-witness-20261017.log`.
- Negative witness 2: temporarily removed main's explicit
  `invalidateElevation("warp_placement")`. The actual warp caller test stubs
  common loadMap and uses an unchanged position, so neither generation nor
  coordinate mismatch hides the missing owner. It reported **71 PASS / 1 FAIL**:
  `PRODUCTION same-position warp invalidates`. Restored the line and verified
  identical main SHA-256. Receipt
  `/tmp/firered-elevation-relocation-witness-20261017.log`. Counts reflect the
  suites at witness time; six later pending-work assertions explain final78.
- Both deliberately faulty mutations are absent from the final diff. Working
  and staged whitespace checks PASS; final repository checker PASS (321 Lua,
  368 Markdown, 1230 targets). Fresh pre-publication origin/main
  `c5e22355921bc098bb615a21745dbffd85298710` differs from the authority base
  only in STATE/HANDOFF; runtime, task and AGENTS unchanged. Exact public
  head/CI are handed to the separate Reviewer.

Independent Reviewer must verify the exact implementation/source limits,
production ownership and five-path scope. Worker does not self-approve this
prerequisite or claim C0/C2/C3, tutorial, traversal, save parity or phase closure.
