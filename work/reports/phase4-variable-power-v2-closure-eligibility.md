# Phase 4 variable-power V2 (Fury Cutter, effect 119) — closure-eligibility audit

- Task: [`P4-VARIABLE-POWER-V2`](../tasks/phase4-variable-power-v2.md)
- Status: audit only. No closure, no runner request, no merge.
- Base: `origin/main` `df53c77`.
- Delegated by the coordination owner (Codex "rina") with two rules. First,
  the existing ROM receipt alone does not close any full-relay gate that is
  still owed. Second, satisfied and missing gates must be named explicitly.
- Template: the V3 full-relay gate sequence in the merged
  [V3 route plan](../tasks/local-worker-bridge-phase4-variable-power-v3-route-plan.md),
  "Successor gates", gates 1-6, plus gate-6 coordination.

## Verdict: **NOT ELIGIBLE** for full-relay closure

V2 is owed the full relay:

- [AGENTS.md:116-117](../../AGENTS.md) requires it for "new persistent or
  cross-turn battle state".
- V2 adds a per-battler cross-turn counter (task Lane line 5; design
  proposal:62, "V2, Fury Cutter (full relay, engine only)").

V2 never went through the relay:

- It landed on main through PR #55, merged as `77405ec` on 2026-10-21, after
  one bounded no-ROM implementation review.
- Its route plan, route configuration, probe, implementation authority,
  request, V2 guarded run, outcome review and coordination reconciliation do
  not exist.

The evidence a relay exists to produce is already present. The V2 ROM fixture
ran non-skipped in the verified-ROM suite of V3's guarded run, and an
independent review confirmed it. Under rule 1, though, that receipt closes
none of the gates that are still owed. The procedural gates (1-5 below) also
cannot be satisfied retroactively by a bridge request: the code is already on
main, so a V2 patch would have nothing to apply. Closing them needs a
decision by the coordination owner or operator, not more Worker evidence.

## Gate table

| # | Gate | State | Evidence | Reasoning |
| --- | --- | --- | --- | --- |
| 0a | Design and design review (precondition) | SATISFIED | `work/reports/phase4-variable-power-design-proposal.md:62`; `work/reviews/2026-10-21-variable-power-design-review.md` | V2 is specified as its own package, D3, engine only, with no replay named. |
| 0b | Bounded implementation review (precondition) | SATISFIED | `work/reviews/2026-10-21-variable-power-v1-v2-implementation-review.md:3,12` reviewed `0663e1d` as PASS WITH CORRECTIONS. Correction F4 was applied (task "Review (2026-10-21)"). | Source conformance and no-ROM tests were reviewed independently. The ROM fixture could not run (review:65-68). |
| 1 | Route plan | MISSING | No `work/tasks/local-worker-bridge-phase4-variable-power-v2-*` file. `git log --all -i --grep='fury cutter'` shows only the design commits (`7016f4d`, `d1ad194`), `0663e1d`, merge `77405ec` and the receipt commit `02c3cab`. | No literal V2 selector, allowlist or focused commands were ever planned or reviewed. |
| 2 | Route configuration | MISSING | `.github/workflows/local-worker-bridge.yml` has no `phase4-variable-power-v2` arm. | No V2-selected route exists. |
| 3 | Readiness probe | MISSING | No `work/local-runner/probes/phase4-variable-power-v2*` file. | It was never run, because there was no route to probe. |
| 4 | Implementation authority | MISSING | No V2 authorization task or review. | PR #55 was merged by the owner (`BigCatMellow`) with no recorded GitHub review; the in-repo review was the only gate. |
| 5 | Request | MISSING | No `work/local-runner/requests/phase4-variable-power-v2*` file. | The code reached main directly, at `0663e1d` and `77405ec`, not through bridge publication. |
| 6a | Guarded run | MISSING | No V2-selected run. **Substitute evidence exists, but this gate is not closed:** run `43782148986` / job `133021540905` (head `65fceaa`, which contains `0663e1d`; route `phase4-variable-power-v3-effect`). Its verified-ROM step printed `phase4_variable_power_v2_effect_rom_test: 2 passed, 0 failed; exact 1-member source family` and ended `PASS: 207 test files (ROM mode: verified ROM supplied)`. Recorded in inventory row 119 (`work/reports/phase4-move-effect-inventory.md:225`, PR #77). | The ROM-evidence content of a V2 run is present, from the shared suite. A V2 focused arm, V2 target validation and V2 publication never ran. Rule 1 forbids treating this as the gate. |
| 6b | Outcome review | MISSING | `4819085` (`work/reviews/2026-11-15-variable-power-v2-inventory-receipt-review.md`) verifies only that the row-119 line is verbatim from the log. `922ee70` (the V3 outcome review) does not quote V2. | No review has judged V2 acceptance against a relay authority. |
| 6c | Coordination | MISSING | No V2 entry in `work/coordination/STATE.json`, `TASK_REGISTER.md` or `HANDOFF.md` (grep for `VARIABLE-POWER-V2` or `Fury` returns nothing). | Its status was never reconciled. The task's `DONE` status overstates it, just as V3's premature `DONE` was corrected in `fbe5b6f`. |
| — | Runtime replay | NOT-APPLICABLE | The design names no V2 replay (engine only). For V3, review `3056bc5` finding 3 PASSed the same no-replay decision. | Engine-only family, matching V3. |

## Smallest action to close each MISSING gate

Gates 1-5 have no Worker-only path for code that is already on main: a V2
bridge request would be an empty patch. Two options:

- **(a) Recommended: owner ratification.**
  1. The coordination owner or operator records an explicit decision. It
     ratifies the PR #55 merge in place of gates 1-5 for code already on main.
     It accepts the verified-ROM step of run `43782148986`, as verified by
     `4819085`, as the gate-6a ROM evidence.
  2. That decision is an authority decision. Only rina or the operator can
     make it; this audit does not.
  3. Then one independent V2 outcome review (gate 6b). It judges `0663e1d` as
     present on `65fceaa` against that ratification, cites the
     already-verified V2 line and the ROM-mode PASS line, and makes no LÖVE
     claim.
  4. Then gate-6c coordination: the proposal text, drafted separately for
     rina, plus a status advance on the V2 task after that PASS.
- **(b) Not recommended: a full V2 relay.** It would need a V2 route
  (plan, configuration and probe), a request that can actually apply (for
  example, a docs-only receipt edit carried through a V2 route), a guarded
  run and an outcome review. That is six gates to reproduce evidence that
  already exists, and the request would carry no V2 code.

Per-gate actions:

| Gate | Option (a) | Option (b) |
| --- | --- | --- |
| 1-5 | Covered by the owner's ratification decision | One reviewed artifact each, as in V3 |
| 6a | The same ratification accepts run `43782148986`'s verified-ROM step | One V2-selected guarded run |
| 6b | One independent V2 outcome review | The same |
| 6c | STATE, HANDOFF and TASK_REGISTER edits and a V2 status advance, after 6b | The same |

## Exclusions

- This audit closes no gate.
- It creates no request, probe or route.
- It makes no LÖVE, runtime, battle-parity, Brock AI, phase or
  capability-checklist claim.
- The only other repository change is the V2 task's status line, corrected
  so it no longer says `DONE`.
