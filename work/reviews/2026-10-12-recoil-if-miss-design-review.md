# Effect-45 resumed design — independent review

Verdict: **PASS** for the bounded design at exact revision
`b3280f9f7a8e3e9b414d2c1d9f1f9c9b19806c13`, parent
`4dd22e1d80ea40e485ee134e59499183e31847f3`.
This accepts design only; it does not establish gameplay support, authorize
implementation or routes, or close Phase 4.

- [Task](../tasks/phase4-recoil-if-miss-design.md) SHA-256:
  `255bc925c8f8572558012da56f9cd47c0803608c8c7ed9f8753dd902369e3ed1`.
- [Report](../reports/phase4-recoil-if-miss-design.md) SHA-256:
  `9e5c9b4cdea14565b3a3f4a04ab5fe4d2c2008caacb4ef6debb5a4afc96a6fb0`.
- Independently recovered live `main` first at the parent, then at published
  review checkpoint `32e3bfb4e33383b3f1cfda018e751f17aca46dfa` with
  `READY_FOR_REVIEWER` for this exact design pair.

## Criteria and source authority

Reviewed against the design task as explicitly reactivated at `4dd22e1`,
the original source lock at `c218da6`, and the controlling entry-state
supplement at `ba69269` with its
[independent PASS](2026-10-12-recoil-if-miss-entry-state-review.md).
The earlier BLOCK at `f31ae69` remains identifiable in history and is not
misrepresented as a completed design. The revised report expressly supersedes
the incomplete earlier immunity description.

1. **Literal selection and successful hits.** The report selects the
   conjunction of effect 45 and IDs 26/136, keeps broad admission separate
   from support, and leaves other moves and ordinary effects 48/198 recoil
   untouched. Successful accuracy retains the existing hit calculation and
   immunity flow, without adding crash damage or new RNG.

2. **Both ordinary failure outcomes are source-backed.** After shared
   accuracy and one PP deduction, an immune ordinary failure produces
   `useMove` then `noEffect` and completes without miss/crash, adjustment
   draw, HP update, or attacker faint. Nonimmune failure produces miss then
   crash. This correctly incorporates the accepted source helper's ordinary
   immunity precheck, resultmessage selection, and earlier no-effect guard.
   Newly introduced late-only immunity remains explicitly conditional and
   outside ordinary reachability; it is neither an invented fixture nor a
   minimum-one damage oracle.

3. **The proposed current-code projection is bounded and coherent.** Direct
   inspection of `BattleFormulas.typeCalc` confirms a pure local damage/flag
   calculation over parsed rows, with no RNG, model mutation, or global
   state. Its `noEffect` flag identifies any zero type multiplier, handles
   either target type and duplicate types, and skips the Foresight marker
   while retaining later rows. Reading only that flag with a harmless positive
   seed and discarding temporary damage/effectiveness flags represents the
   ordinary source precheck within the stated exclusions. It does not require
   a new flag API, species hardcode, or generic miss/admission change.

4. **Calculation and action-local RNG are precise.** The accepted 1/1 reset
   values justify noncritical base damage, normal attack/defense stages and
   defender Reflect even after a preceding critical action. The sequence is
   base, STAB/type, random adjustment, integer half, zero-to-one, target-max-HP
   cap, then clamp actual loss to attacker HP. No second minimum follows the
   cap. Temporary type effectiveness flags do not become presentation events.
   Nonimmune failure consumes accuracy then adjustment; immune failure only
   accuracy. The report preserves the successful-hit RNG path and separates
   speed ties, later actions and excluded systems from these local counts.
   Arithmetic examples do not claim legal retail battlers or executed tests.

5. **Engine/controller/faint ownership is explicit.** A dedicated crash
   result belongs only to the literal nonimmune miss leaf. The engine owns
   model HP/PP and attacker faint; ordinary recoil or defender damage events
   are not substitutes. The controller translates the crash result into
   announcement followed by a separate invisible attacker HP entry. Inspection
   of `_applyInvisibleEntries` and `advanceMessage` confirms this supplies the
   intended message-before-display-HP ordering; HP metadata attached only to
   a text entry would not. Model HP may already be final while messages drain.
   Existing completion and forced-switch guards prevent the remaining action
   from attacking the just-fainted attacker. The design adds no replacement
   subsystem or common MoveEnd parity claim.

6. **FirstBattle and persistence boundaries remain intact.** The first
   damaging player accuracy bypass cannot enter the ordinary failure branch.
   The report preserves that bypass and does not set the tutorial damage flag
   or emit its tip on crash. Direct code inspection confirms the defender
   damage helper carries those tutorial side effects and is not a valid
   switched-side shortcut. `persistPartyBattler` already owns model HP/PP
   persistence; the design proposes no save field or format change and leaves
   fatal-crash lifecycle/save integration as required later evidence.

The future acceptance outline covers both records/sides, literal boundaries,
successful and immune branches, rounding/cap and actual-HP clamp edges, faint
and forced continuation, RNG sentinels/PP, screens/stages/prior-critical state,
firstBattle, message-by-message HP ordering, persistence and unrelated-family
regressions. These are acceptance expectations, not tests, fixtures, commands,
or implementation authority. All stated exclusions remain in force.

## Exact scope and verification

The exact commit changes only the permitted report and appends task evidence/
handoff. The task's reactivated criteria and stop conditions are unchanged.
No runtime, tests, formulas, event schema, admission, controller, save, AI,
workflow, route, request, probe, ROM policy, or phase-status change occurs.

Independently reproduced both reviewed artifact hashes, the accepted source
and supplement task/report hashes, and the four reported project-code hashes.
The engine, formulas, controller and party bridge remain unchanged from
`c218da6` through this reviewed revision. Read the actual owner functions
rather than relying on the Worker's seam descriptions.

`git diff --check 4dd22e1 b3280f9` passed. The independent repository checker
at the exact design tree passed: **280 tracked Lua, 269 tracked Markdown,
847 local targets**. This is documentation/source-consistency evidence only.
No new source semantics, gameplay tests, runtime, replay, ROM, private runner,
or route action was used for this design review.

## Exact next allowance

After reconciling this design PASS, the Orchestrator may compile at most one
separately bounded, fail-closed effect-45 route or implementation-authority
decision under the existing publication and independent-review gates. That
successor must preserve the accepted design's literal family, immune early
exit, nonimmune crash ordering, evidence requirements and exclusions.

This PASS itself authorizes no route configuration, runner observation/probe,
request, implementation, test edit/execution, or gameplay-support assertion.
Any successor requires its own explicit task boundary and required review;
Phase 4's full move/effect matrix remains open.

Only this review artifact was authored. No correction, coordination edit,
staging, commit or push was performed by the Reviewer.
