# Recalibrated delivery plan — 2026-10-02

This is the concise current routing view. The capability checklist remains the
canonical phase-status authority; task contracts and independent reviews remain
the authority for individual leaves.

## Outcome and dependency model

The completion path is:

```text
P0 reproducibility + P2 trusted reference evidence + P4 battle/trainer rules
       + P5 maps/scripts/field + P6 player UI
    → P7 checkpointed new-game-to-credits route
    → P8 representative presentation/performance
    → P9 offline postgame
    → P10 import/play/mod/update/diagnose release gate
```

`P7` is the convergence gate: story checkpoints identify which P4/P5/P6
primitive must be completed next. Phase 8 should run alongside progression only
where a selected checkpoint needs a presentation primitive; it must not delay
rule or traversal work without an evidenced dependency.

## Near horizon — current to next battle closure

1. Recover the sole queued `P4-F3-ROUTE` probe (`3c03876`, run `36981539166`)
   when `firered-mint` returns. Do not create a duplicate probe.
2. Independently review that readiness-only result. Only a PASS unlocks one
   `phase4-restore-hp-effect` request.
3. Implement/review/reconcile the ordinary Recover (105) / Slack Off (303)
   leaf exactly as contracted. This does not implement generic healing or
   excluded intercept/cancellation state.
4. Use the accepted move inventory to rank the next effect family by early
   story need, represented prerequisites and bounded testability. Select one.
5. In parallel, compile a source-backed trainer-configuration inventory and
   gym-ready regression matrix only after the selected battle primitives are
   known; do not start broad trainer or gym implementation speculatively.

## Parallel unblockers

- `P0-04` is evidence-blocked, not failed product behavior. First conduct a
  read-only discovery of supported first-run documentation, tool discovery and
  reproducible desktop/refusal observation. A later reviewed repair may then
  update documentation/tooling and repeat clean-clone verification.
- Phase 2 remains blocked on user-owned provenance-rich retail Oak/Pallet
  captures. No generated substitute is valid. Keep its comparison task ready,
  but do not make this external input block independent P0/P4 work.

## Mid horizon — credits path

1. Produce a machine-checkable P5 map/script/warp coverage inventory, select
   the first progression-critical Kanto segment, then source-lock one missing
   opcode/field primitive at a time.
2. Produce P6 UI-state/no-dev-fallback inventory so menu work is driven by
   normal player paths rather than developer shortcuts.
3. Create P7 checkpoint corpus first. Each segment task must name its missing
   P4/P5/P6 prerequisites and prove the resulting checkpoint without manual
   state edits.
4. Reconcile representative P2/P8 presentation evidence at title, Oak, field,
   battle, menu and credits anchors as those checkpoints become available.

## Late horizon

Postgame begins only after a stable credits route. Release/modding work begins
only after core data/script/map/UI/audio/battle shapes stabilize. Public mod API
scope, packaging/signing, store credentials, device coverage and release remain
human-owned decisions; they are not inferred from a green test suite.

## Dispatch policy

At most one behavior-changing critical-path Worker package is active. Disjoint
research/review may run in parallel. Every task follows source lock → bounded
contract/route → Worker evidence → independent review → reconciliation. A
runner outage, missing reference evidence or clean-target gap is recorded as a
specific blocker, never bypassed.
