# Recalibrated delivery plan — routing reconciled 2026-10-16

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

## Near horizon — accepted battle leaves to first-corridor integration

1. Restore HP (`dc8ad06`) and bounded Magnitude (`7b47c73`) are independently
   accepted; their requests are terminal. Preserve their exclusions.
2. [Effect45 implementation `cfdbb96` independently passed](../reviews/2026-10-13-recoil-if-miss-implementation-outcome-review.md).
   Its guarded request is terminal. Owner-merged fast-lane batches PR10–15
   add 17 bounded families with final independent PASS records; inventory
   snapshot `3adc7e8` had85 represented families and nine pending ROM fixtures;
   newer owner work throughPR41 retains its own records, not those stale totals.
   Status S1–S4 are not
   fast-lane eligible: the accepted design also requires changed-RNG/turn-order
   guarded replay evidence, absent from the merged records. Retain bounded
   no-ROM PASS results without promoting these missing gates. Scope the
   evidence package separately; never reuse a consumed request.
3. Recover existing first-corridor integration work before inventing another
   effect batch: normal START Pokédex-count PR5's source-bound correction
   passed independent review and merged `52fbf69`. Party design PR3 also passed
   and merged `239c25f`; PR6 SUMMARY independently passed and merged `ba669fb`.
   [P5-05 northbound source discovery](../tasks/phase5-viridian-northbound-gate-discovery.md)
   independently passed and merged PR42 `ae3d559`; its selected
   [elevation lifecycle source lock](../tasks/phase5-player-elevation-input-source-lock.md)
   also passed and merged PR43 `871f3f1`. Execute the adopted five-path
   [live elevation ownership implementation](../tasks/phase5-player-elevation-input.md),
   with production tests and explicit invalidation of unsupported histories.
   No gameplay handler or predicate change is included. No rendered Pokédex,
   full Party UI or normal traversal proof is implied. Memento's trainer-AI
   reserve-count gap is separately under read-only feasibility inspection;
   engine acceptance does not establish AI support.
4. At each leaf closure, reassess the next playable checkpoint and rank
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
research/review may run in parallel. Eligible P4 families use the owner-approved
fast lane in root AGENTS: one combined source/design/allowlist task, branch/PR,
public no-ROM CI and one independent review; ROM fixtures run later through
an authorized guarded suite. Other tasks retain their existing contract and
required route/evidence gates. A
runner outage, missing reference evidence or clean-target gap is recorded as a
specific blocker, never bypassed.
