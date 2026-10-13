# Recalibrated delivery plan — routing reconciled 2026-10-11

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

1. Restore HP (`dc8ad06`) and bounded Magnitude (`7b47c73`) are independently
   accepted; their requests are terminal. Preserve their exclusions.
2. The accepted rerank `ca11770` selected effect 45; source lock `c218da6`
   independently passed. [Source supplement `ba69269` independently passed](../reviews/2026-10-12-recoil-if-miss-entry-state-review.md),
   resolving design `f31ae69`'s source stop and correcting ordinary immunity
   precheck/presentation. [Revised design `b3280f9` independently passed](../reviews/2026-10-12-recoil-if-miss-design-review.md).
   Neither source nor design PASS grants behavior or execution authority.
3. [Route plan `04636d1` independently passed](../reviews/2026-10-12-recoil-if-miss-route-plan-review.md).
   [Configuration `1d40f3c` independently passed](../reviews/2026-10-13-recoil-if-miss-route-configuration-review.md).
   [Probe `667fd16` independently passed](../reviews/2026-10-13-recoil-if-miss-route-probe-outcome-review.md).
   [Implementation authority `96b10ce` passed](../reviews/2026-10-13-recoil-if-miss-implementation-authority-review.md).
   Execute only the bounded [one-request implementation](../tasks/phase4-recoil-if-miss-implementation.md)
   and required reviews. Follow the exact next allowance in
   current coordination; never revive a completed request.
4. At the next leaf closure, reassess the next playable checkpoint and rank
   remaining work by story need, represented prerequisites and bounded
   testability. Select one; retain the full battle matrix as an open gate.
5. In parallel, compile a source-backed trainer-configuration inventory and
   gym-ready regression matrix only after the selected battle primitives are
   known; do not start broad trainer or gym implementation speculatively.

## Parallel unblockers

- P0 first-run discovery `8c92f67` and docs repair `d4f7fe8` passed. Fresh
  reverification `93c4654` remains evidence-blocked on target prerequisites
  and desktop proof. A separate supported-target preparation decision is
  required before retry; historical observations do not prove current readiness.
- Phase 2 remains blocked on user-owned provenance-rich retail Oak/Pallet
  captures. No generated substitute is valid. Keep its comparison task ready,
  but do not make this external input block independent P0/P4 work.

## Mid horizon — credits path

1. Extend the accepted first-corridor P5 inventory (`7712d63`) after selecting
   the next progression gate. The bounded Viridian Old Man projection
   (`d280751`) passed; it supplies no tutorial or traversal proof. Source-lock
   one required missing opcode/field primitive at a time.
2. Use the accepted [P6 field-menu inventory](../reports/phase6-field-menu-coverage-inventory.md)
   and [independent PASS at `ee7535d`](../reviews/2026-10-05-field-menu-coverage-inventory-review.md)
   to select one menu frontier needed by the current checkpoint. Preserve its
   normal/developer-path distinctions and UNKNOWNs; no repeat inventory or UI
   implementation is authorized without a separate bounded task.
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
