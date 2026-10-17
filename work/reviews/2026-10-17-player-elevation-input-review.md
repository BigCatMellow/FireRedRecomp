# Live player elevation input — independent implementation review

- Verdict: **PASS** for the bounded transient ownership prerequisite.
- Exact PR #44 implementation: `4b1ac5fd37b96aa00c659e464eca609a0a22b235`.
- Authority: `9ea26858e2764ad02f5ef073935054b2660128f8`,
  [implementation task](../tasks/phase5-player-elevation-input.md).
- Accepted source/design: `7e0cb02` / independent review `ce387cb`,
  [source lock](../reports/phase5-player-elevation-input-source-lock.md).
- Public source independently reconfirmed clean at
  `c75f352304d529f6ba92d4f74b9cf8b5c3810788`.

## Findings

No material correction required against the adopted criteria.

- Exactly five authorized implementation paths changed; task criteria remain
  unchanged. Main's intervening `c5e2235` delta is coordination only.
- PlayerMovement owns transient C/E, known/unknown state, reason/provenance,
  pending spawn/step and map/coordinate identity. Known E=0 is distinct from
  unknown. Missing or malformed height, missing generation, stale coordinates
  and changed destinations invalidate without inventing a height.
- Fresh production bootstrap establishes 0/0 at its final tile; pending spawn
  sampling precedes movement and also runs while standing/blocked. Begin
  samples destination/origin; frame16 finish samples destination/destination
  before existing story dispatch. Literal source-derived tests cover 0/15
  retention, origin15-to-nonzero finish recovery, first/later steps and frames
  1/15/16. Unknown history cannot recover at begin or finish0/15.
- The source assignments/order at `event_object_movement.c:5110–5125,
  5309–5348,8400–8411` agree with the implementation and accepted lock.
  Existing public position, pixel, facing, collision, ledge and scheduler
  cadence remain unchanged; no retail callback-frame parity is asserted.
- All selected production owners were inspected: construction/binding, fresh
  bootstrap, four normal-input directions, common map load, warp, connection,
  save restoration, three story placements, both whiteouts, Mart direct
  movement/takeover, ledge, developer command and automated camera helper.
  Same-position placement explicitly invalidates; load invalidates before
  decoding/replacement; unqualified motion cannot inherit normal-step work.
- Production assertions execute extracted actual main functions/closures,
  real PlayerMovement and scheduler with synthetic map/services. They inspect
  owned state at the existing story call, not an ignored extra argument.
  Tests isolate each placement caller from common load invalidation and cover
  pending-work cancellation. Serialized-state comparison permits only the
  pre-existing location update. No new session/save fields or gameplay
  elevation consumer were introduced.

## Independent execution

All local checks cleared `POKEPORT_ROM` and `POKEPORT_RUNTIME_REPLAY` where
applicable; no ROM, private runner, replay or live LÖVE traversal occurred.

| Check | Result |
| --- | --- |
| PlayerMovement focused tests | 105 passed, 0 failed |
| Actual production-owner tests | 78 passed, 0 failed |
| EarlyStory regression | 25 passed, 0 failed |
| Fresh bootstrap regression | 12 passed, 0 failed |
| Map connections regression | 4 passed, 0 failed |
| Full `scripts/test_all.sh` | 193 files PASS, no-ROM mode |
| Repository checker before review addition | PASS: 321 Lua / 368 Markdown / 1230 targets |
| `git diff --check 9ea2685 HEAD` | PASS |

Full-suite receipt: `/tmp/firered-elevation-review-full-20261017.log`.
The Worker's pre-edit 192-file baseline is attributed Worker evidence, not
represented as a Reviewer baseline rerun.

Independent negative proof used memory-only mutations, never modified tracked
code and never committed a fault:

1. Loaded PlayerMovement with its finish guard replaced by
   `if false and step and self.elevationStep == step then` before running the
   unchanged production suite. Result: **71 passed / 7 failed**, including
   `PRODUCTION finish sampling precedes dispatch`, all four direction
   convergence assertions and both recovery assertions.
2. Supplied the actual-main extraction with only
   `invalidateElevation("warp_placement")` omitted. Result:
   **76 passed / 2 failed**: same-position warp validity and cancellation of
   pending elevation work. Neither coordinate mismatch nor the stubbed common
   loader concealed this missing explicit owner.

These final-suite totals differ from the Worker's earlier witness totals
because the final suite includes additional pending-work assertions. Original
implementation files remained unchanged and the worktree was clean afterward.

Independently queried exact-head public metadata: both
[39058678397](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/39058678397)
(pull_request) and
[39058676358](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/39058676358)
(push) completed successfully for `4b1ac5f`.

## Exact next allowance

After final review-head public CI passes, Orchestrator may merge and reconcile
this transient ownership prerequisite, then compile the smallest remaining
Viridian-gate task under the persistent goal. This review does not itself
authorize that successor.

No C0/C2/C3 handler, tutorial, coordinate eligibility, traversal, normal-save
parity or Phase5/7 completion is accepted. Unsupported relocation histories
remain explicitly unknown until qualified bootstrap or proven normal-finish
convergence; a future elevation-sensitive consumer must reject unknown.
Existing guarded battle/replay evidence debt remains unaffected.
