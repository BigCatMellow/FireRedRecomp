# Player elevation lifecycle source lock — independent review

- Verdict: **PASS** for source research and the bounded successor proposal.
- Exact PR #43 revision: `7e0cb02c20f50b8d91662a72d00da379b7a053a7`.
- Authority: `d9c6318176efeff5f4a403e7eaa521430a89bf88`;
  unchanged runtime: `ba669fb420d68f54c8dab362c21bc0faf874f372`.
- [Task](../tasks/phase5-player-elevation-input-source-lock.md) and
  [report](../reports/phase5-player-elevation-input-source-lock.md).
- Source checkout independently verified clean at
  `c75f352304d529f6ba92d4f74b9cf8b5c3810788`.

## Material findings

No correction required within the existing criteria. Independent source
reconstruction began before the report and agrees with its final claims:

- Fresh avatar template/object creation establishes C/E=0/0 and equal spawn
  coordinates, not an immediate raw-height seed. The flagged spawn update
  occurs in the player sprite callback before held movement shifts coordinates
  (`field_player_avatar.c:1286–1315`; `event_object_movement.c:1312–1372,
  1549–1628,5110–5125,8721–8768`). fixedPriority and pending flags are explicit.
- Normal begin sampling uses destination/origin; finish first collapses both
  coordinate fields to destination and then samples destination/destination
  (`event_object_movement.c:2249–2254,2294–2296,5309–5348`). Thus origin15 can
  suppress begin but not a finish on height4. Each literal table row follows
  from the 0/15 assignments at `8400–8411`, not raw tile-height substitution.
- The ordering is demonstrated beyond a call graph: callback1 precedes
  callback2 (`main.c:241–249`); CB1 evaluates transition/input before movement,
  while CB2 runs sprite callbacks (`overworld.c:1394–1464`,
  `sprite.c:304–316`). Normal movement completes on frame16, sets the finished
  held action and samples finish elevation before the following CB1 completed-
  step read. Fresh spawn processing cannot be skipped by the first such read.
- Standing/collision actions do not themselves request begin/finish sampling,
  but an outstanding spawn flag still samples first. The report correctly
  avoids inferring absence of an update merely from unchanged coordinates.
- Current PlayerMovement keeps visual/public coordinates at origin through
  frame15. Its proposed internal ownership preserves this and the existing
  main scheduler cadence; no retail callback-frame parity is asserted.
- Main's actual creation, bootstrap, map replacement, warp, connection, save,
  whiteout, story placement, presenter, ledge and developer movement seams
  support the reported owner classification. Unsupported histories invalidate
  rather than silently reseed. Recovering after a qualified normal finish on
  in-bounds height1–14 is justified because both assignments then become
  history-independent; height0/15 cannot generally recover E. Same-coordinate
  relocation and stale map/step identity are explicitly covered.

Exactly one five-path successor is proposed. It owns transient state in the
live PlayerMovement instance and production entry/scheduler paths, with
production tests observing state before existing dispatch. It neither passes
an ignored argument nor introduces a throwaway event filter. The missing
gameplay consumer is honestly retained: no C0/C2/C3 eligibility or execution
claim is made. Literal state oracles, production-path assertions, regressions,
unknown-state handling and stop conditions are sufficient to compile that
bounded task without repeating this research.

## Actual independent evidence

- Two authorized paths only versus `d9c6318`: report and task status/evidence.
  Task acceptance unchanged; no runtime/test/asset/runner changes.
- `git diff --check d9c6318 HEAD`: PASS.
- `git diff --exit-code ba669fb HEAD -- '*.lua'`: PASS.
  Intervening main `4d9fb2f` changes only STATE/HANDOFF.
- Reproduced the report's exact synthetic Lua movement witness: PASS;
  frame15 remains moving/origin, frame16 reaches destination, elevation
  fields absent. This is a current-runtime gap witness, not an implemented
  source-oracle suite or ROM observation.
- Repository checker: PASS, 320 Lua / 366 Markdown / 1219 local targets
  before adding this review.
- Independently queried public CI metadata: exact `7e0cb02` runs
  [38842120130](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/38842120130)
  (pull_request) and
  [38842115752](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/38842115752)
  (push) both completed successfully.

Parent 192-file suite and prior PR42 CI remain attributed carried evidence.
No local full suite, ROM, private runner, replay or gameplay action was needed
or performed. Proposed future assertions are not represented as executed.

## Next allowance and retained limits

Orchestrator may accept this source lock and compile the proposed
`P5-05-PLAYER-ELEVATION-INPUT` contract with its five-path boundary, production
ownership/tests, explicit invalidation/convergence and evidence requirements.
This review is not itself implementation authority. Unknown excluded relocation
histories remain unknown until qualified bootstrap or proven convergence;
later elevation-sensitive gameplay must refuse unknown state.

No tutorial, coordinate handler, collision expansion, save-schema change,
traversal, normal-save parity or phase completion is accepted. Existing
guarded evidence gates remain intact. Final review-head public CI must pass
before merge; Orchestrator owns merge and coordination.
