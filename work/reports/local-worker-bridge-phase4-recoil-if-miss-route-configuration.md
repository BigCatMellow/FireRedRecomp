# Effect-45 bridge configuration — Worker evidence

- Task: [P4-F3-RECOIL-IF-MISS-ROUTE-CONFIG](../tasks/local-worker-bridge-phase4-recoil-if-miss-route-configuration.md).
- Status: `CONFIGURATION READY FOR INDEPENDENT REVIEW`.
- Published/local baseline: `a5a268edef077f5daef285462a33dea14104f81a`.
- Authority: [route plan](phase4-recoil-if-miss-route-plan.md) at `04636d1`
  and [independent PASS](../reviews/2026-10-12-recoil-if-miss-route-plan-review.md).

The workflow now contains exactly five new `phase4-recoil-if-miss-effect`
arms: selector, target validation, focused commands, replay, and publication.
Validation/staging use the ten reviewed literal paths. Focused execution has
the five reviewed Lua commands in order, including party-bridge persistence
evidence. The mandatory replay command is configured; no implementation or
replay fixture was created.

The new publication arm first checks all ten required paths with `test -f`.
Any absent/non-file artifact stops the route before any staging. Only after
the complete preflight does it run individual `git add -- "$path"` calls.
This is local to the new route; neighboring conditional staging behavior and
all shared guards remain unchanged. Bridge procedure documentation records
the identical surface, missing-artifact failure, exclusions and future gates.

## Static verification

Live `git ls-remote origin refs/heads/main` matched the baseline. The original
workflow SHA-256 matched the accepted plan:
`fb98001cd06ab8ff368f9ccbb0d079ebb809865709a1708ce2dfa55b6199edac`.

A read-only Python/PyYAML 6.0.1 harness parsed the changed workflow and passed
each extracted shell block to `bash -n`. For controlled route checks it ran
only the selected shell blocks with inert shell functions replacing `git`,
`lua5.1`, `lua`, and replay `bash`. Patch target input and file-presence tests
were simulated; no patch file, ROM environment, real execution command or
publication target was used. The only real Git harness input was read-only
`git show` of the baseline; selector output used `/dev/null`.

| Check | Result |
| --- | --- |
| YAML parse; all 12 shell blocks `bash -n` | PASS |
| Original behavior preservation | Removing each of the five inserted arms reproduced its baseline shell text exactly; every other step and changed-step non-shell metadata compared equal. |
| Selector positives | Four PASS: bare and dated `.patch`, bare and route-dated `.probe`. |
| Selector negatives | Five rejected: unknown, wrong prefix, leading extra character, wrong suffix, and `.patch.bak`. |
| Validation | All ten literal paths accepted; seven forbidden variants rejected before any Git call: main, formulas, party-bridge runtime, STATE, shared test data, `.bak`, and traversal prefix. |
| Unknown route | Validation, focused, replay, and publication each rejected before any stub execution call. |
| Focused/replay dispatch | Exactly five ordered test calls and exactly the required replay call. |
| Publication equality | Validation and staging lists matched the reviewed ten paths in order; all-present stub case staged exactly those ten, then reached only stub commit/push. |
| Missing required artifacts | Ten separate cases, each omitting one required file, failed before any stub Git call, including staging. |
| Probe separation | All seven patch-only predicates unchanged; probe-completion predicate unchanged. No actual probe ran. |

Whitespace and read-only repository syntax/local-target checks, including
this initially untracked report, are recorded in the task handoff. Static
stub success proves dispatch/control flow only; it does not prove runner
availability, the private SHA gate, tests, replay, or gameplay behavior.

## Boundaries and next action

No runtime/test/replay implementation, requests/probes, private runner or ROM
inspection, test-suite execution, shared-guard change, accepted-plan change,
coordination change beyond the permitted bridge procedure, or capability
advancement occurred. All effect-45 design exclusions remain unchanged,
including ordinary recoil separation, literal IDs, immune early exit, and
no normal lifecycle/save-reload claim from explicit bridge persistence.

Independent exact configuration review is next. Only its PASS permits the
Orchestrator to compile a separately bounded fresh readiness-probe task.
Configuration alone authorizes no probe, retry, request or gameplay patch.
Worker performed no staging, commit or push; parent owns publication.
