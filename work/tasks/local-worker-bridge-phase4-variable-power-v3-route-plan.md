# Task: plan a guarded route for variable-power V3 (Rollout/Ice Ball, Defense Curl)

- Task ID: `P4-VARIABLE-POWER-V3-ROUTE-PLAN`
- Status: `READY_FOR_REVIEWER` — revised for review `3056bc5` (NEEDS_FIX);
  independent re-review required. No workflow change.
- Type: `ROUTE PLANNING / NO WORKFLOW CHANGE`
- Parent: `P4-VARIABLE-POWER-V3` (`work/tasks/phase4-variable-power-v3.md`,
  not yet on main; PR #58, head
  `9d761f49488156619c3cf87a49bb1958437083c8`, base
  `49d0f4531ed067370a3024deabcbeb7dc564c597`), lane `full relay` per
  [AGENTS.md](../../AGENTS.md) (new cross-turn battle state) and the
  [variable-power design](../reports/phase4-variable-power-design-proposal.md)
  ("V3 ... full relay, engine only").
- Operator decisions, 2026-11-15: full relay chosen. The package is updated
  to the reconciled 8-path diff `49d0f45..fbe5b6f`. This is a scope update the
  operator approved, not new scope.
- Assigned role: `WORKER` (route planning)
- Independent reviewer: `REVIEWER`, not the author of this plan or of PR #58.
- Risk: `MEDIUM` — an imprecise plan could broaden later runner authority.

## Goal

Specify the smallest fail-closed Local Worker Bridge route that can carry the
already-reviewed V3 change (PR #58) as one guarded request, so its ROM fixture
runs non-skipped under the SHA-verified full suite. This task authorizes
documentation only: no workflow, request, probe, ROM or runtime action.

## Source of truth

- PR #58 code and tests at `9d761f4`.
- Bounded reviews:
  - `work/reviews/2026-10-28-variable-power-v3-implementation-review.md`,
    carried by PR #58.
  - The Codex 2026-10-30 final-head review and status reconciliation. They
    are on the pushed branch `origin/work/v3-acceptance-reconciliation-20261030`:
    reconciliation `fbe5b6f` (`fbe5b6fff6e6b317cebef373c4e6a4cc8b3699bf`) and
    its sanity-review PASS `e733394`
    (`e733394805290b84b2e67c421494a137e1354c0a`). Neither is on main.
- What those reviews establish:
  - The bounded no-ROM review PASSed, and full-relay acceptance is unresolved.
  - Missing evidence: the non-skipped supported-SHA ROM fixture, and any live
    LÖVE or runtime observation.
- **LÖVE note:** this relay does not supply live LÖVE observation. The
  outcome review must not claim it.
- Current `.github/workflows/local-worker-bridge.yml` at `794b919`.
- Precedent: the Magnitude chain (plan `1347e5e`, config `57d6b05`, probe
  `92cbba8`, authority `c9ca2ab`, request `1d01fc7`, apply `7b47c73`,
  outcome `e83fc45`), the effect-45 chain, and the Flail plan-in-task shape.

## Exact later selector and patch surface

One explicit route `phase4-variable-power-v3-effect`, selected only by:

```text
phase4-variable-power-v3-effect*.patch
phase4-variable-power-v3-effect*.probe
```

No fallback or existing route may select it; unknown names still fail closed.
Target validation and publication staging must be set-equal to exactly the
eight paths of the reconciled V3 package
(`git diff --name-only 49d0f45 fbe5b6f`):

1. `src/core/BattleEngine.lua`
2. `tests/battle_variable_power_v3_test.lua`
3. `tests/phase4_move_effect_inventory_test.lua`
4. `tests/phase4_variable_power_v3_effect_rom_test.lua`
5. `work/reports/phase4-move-effect-inventory.md`
6. `work/reviews/2026-10-28-variable-power-v3-implementation-review.md`
7. `work/reviews/2026-10-30-variable-power-v3-final-head-review.md`
8. `work/tasks/phase4-variable-power-v3.md`

All eight must exist after application and before evidence. Staging adds
each literal path individually.

The later request is `git diff 49d0f45 fbe5b6f`, unmodified. That is PR #58
plus the reconciliation commit `fbe5b6f`, which does two things:

- it corrects the task status from the rejected `DONE` to `IMPLEMENTED ...
  full-relay acceptance unresolved`;
- it adds the final-head review, which the corrected task links to (public
  CI runs the `check_repository.lua` link check).

On 2026-11-15 the request passes `git apply --check` against `origin/main`
`794b919`, run against a scratch index, and `git merge-tree` is clean. None of
the eight paths exists or has changed on main since `49d0f45`. If main moves,
the request author re-runs `git apply --check` and stops on any conflict.
Relaying `9d761f4` unchanged is not permitted.

## Required later execution arms

Keep the trusted-main, one-input, Lua-toolchain, private-ROM SHA-1,
`git apply --check`, `git diff --check` and patch-only guards unchanged.
Focused arm, through the bridge-selected `$LUA`, exactly in this order:

```bash
"$LUA" tests/battle_engine_test.lua
"$LUA" tests/battle_variable_power_v3_test.lua
"$LUA" tests/phase4_move_effect_inventory_test.lua
"$LUA" tests/phase4_variable_power_v3_effect_rom_test.lua
```

Shared suites stay unchanged and mandatory:
`env -u POKEPORT_ROM bash scripts/test_all.sh`, then `bash scripts/test_all.sh`
with the gated `POKEPORT_ROM`. A focused skip with no ROM is not acceptance.
The verified-ROM suite must run the inventory aggregate and the V3 fixture
non-skipped. That non-skipped result is the missing full-relay evidence.

**Required evidence lines.** The outcome review must quote these lines
verbatim from the verified-ROM `bash scripts/test_all.sh` step:

- the non-SKIP V3 fixture line,
  `phase4_variable_power_v3_effect_rom_test: N passed, 0 failed`;
- the non-SKIP `phase4_move_effect_inventory_test` output;
- the ROM-mode line `PASS: N test files (ROM mode: verified ROM supplied)`.

Any V3 or inventory `SKIP` in that step means the full-relay evidence is
missing, and the outcome review cannot PASS.

## Replay decision — reviewer must confirm

**No route-specific replay is proposed.** The workflow replay arm echoes
exactly:

```bash
echo "No runtime replay is authorized: the accepted V3 design specifies none; focused and verified-ROM suite results are the evidence."
```

The precedent is the trainer-party route arm (workflow line 502), which uses
the `No runtime replay is authorized: ...` form. The inventory wording
("changes no runtime behavior") would be false here, so it is not reused.
Earlier battle-effect routes do have their own
`scripts/runtime_phase4_*_replay.sh`, but those scripts only re-run their
focused tests with the ROM set. This route does not need one, because:

1. The accepted design's V3 verification plan names none.
2. The Codex final-head review explicitly declines to invent one.
3. PR #58 contains no replay script, and adding one would widen the patch
   beyond the reviewed change.

Review `3056bc5` PASSed this decision (finding 3). Adding a replay script
would be new implementation scope that needs operator re-shape. It is not a
route widening.

## Readiness-probe decision

**One fresh substrate-only probe is required** after configuration PASS and
before any request, as in the Magnitude and effect-45 chains:
`work/local-runner/probes/phase4-variable-power-v3-effect-route-YYYYMMDD.probe`.
It proves only checkout, selector recognition, toolchain and the SHA gate. All
patch, test, replay and publication steps skip.

## Successor gates (each needs an independent review; none is skippable)

**Rule:** gates 2-4 MUST NOT create or modify any package path on main, or
the gate-5 `git apply --check` would fail.

1. **Route plan (this task).** Review:
   `work/reviews/YYYY-MM-DD-variable-power-v3-route-plan-review.md`.
2. **Route configuration.**
   - Task: `work/tasks/local-worker-bridge-phase4-variable-power-v3-route-configuration.md`.
   - Changes: the workflow (selector, allowlist, focused, replay and staging
     arms) and `work/coordination/LOCAL_RUNNER_BRIDGE.md`, per Magnitude
     `57d6b05`.
   - Evidence: offline stub evidence in
     `work/reports/local-worker-bridge-phase4-variable-power-v3-route-configuration.md`.
   - Review: `...-variable-power-v3-route-configuration-review.md`.
3. **Probe.**
   - Task: `work/tasks/local-worker-bridge-phase4-variable-power-v3-route-probe.md`.
   - Probe: the one-file probe named above.
   - Review: `...-variable-power-v3-route-probe-outcome-review.md`.
4. **Implementation authority.**
   - Task: `work/tasks/local-worker-bridge-phase4-variable-power-v3-implementation-authorization.md`.
   - Review: `...-variable-power-v3-implementation-authorization-review.md`.
   - Coordination, per Magnitude `c9ca2ab`:
     - `work/coordination/STATE.json`: set the active relay to the V3
       authorization.
     - `work/coordination/HANDOFF.md`: add the V3 relay entry at the top.
     - `work/coordination/TASK_REGISTER.md`: add one row for the V3
       implementation authorization (`READY_FOR_REVIEWER`).
5. **Request.** One file,
   `work/local-runner/requests/phase4-variable-power-v3-effect-YYYYMMDD.patch`,
   byte-identical to `git diff 49d0f45 fbe5b6f`.
6. **Outcome.**
   - The bridge's `Apply verified local Worker patch` commit.
   - Review: `...-variable-power-v3-implementation-outcome-review.md`, with
     the evidence lines quoted above.
   - Coordination, per Magnitude `e83fc45`:
     - `work/coordination/STATE.json`: reconcile the V3 outcome.
     - `work/coordination/TASK_REGISTER.md`: update the V3 row's status.
     - Advance the status of `work/tasks/phase4-variable-power-v3.md` only
       after the outcome review PASSes.

PR #58 itself is not merged by this relay. After publication, the operator
decides whether to close it as superseded.

## MUST NOT CHANGE

This plan does not change the workflow, bridge procedure, requests or probes,
runtime or tests, runner or ROM, coordination, capability status, PR #58,
existing route behavior or any other effect family. It adds no generic
selector, wildcard allowlist or inferred command.

## Evidence

- Documentation only. `lua5.1 scripts/check_repository.lua` and
  `git diff --check origin/main` pass on this revision.
- Nothing was run against a ROM, LÖVE, the runner or a workflow.

## Handoff

Reviewer returns `PASS | NEEDS_FIX | BLOCK`. It must verify:

- selector specificity;
- eight-path validation and staging equality with `49d0f45..fbe5b6f`;
- the four focused commands and both suite commands;
- the replay decision (above);
- the probe requirement;
- the successor list.

Only a PASS permits compiling the route-configuration task. That task grants
no bridge edit, probe or request by itself.
