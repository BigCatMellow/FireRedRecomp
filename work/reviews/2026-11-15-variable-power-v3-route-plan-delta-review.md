# Variable-power V3 route plan — delta re-review

Verdict: **PASS** for delta `3056bc5..3975948`. The plan task
[`local-worker-bridge-phase4-variable-power-v3-route-plan.md`](../tasks/local-worker-bridge-phase4-variable-power-v3-route-plan.md)
is at `3975948`. This PASS permits compiling the route-configuration task
only. It grants no workflow edit, probe, request, ROM, runner, merge or status
authority.

## Scope of the delta

- The only changed path is the plan task.
- `git diff --check 3056bc5..3975948` passes.
- `lua5.1 scripts/check_repository.lua` passes.

Beyond the prior findings, the delta contains only the two disclosed
additions:

- the Status revision note (line 4);
- the operator-decision line for the 8-path package (lines 14-16).

## Prior findings

1. **Resolved: the `DONE` status.**
   - The package is now `git diff 49d0f45 fbe5b6f`, which has 8 paths,
     including the final-head review.
   - Relaying `9d761f4` unchanged is explicitly forbidden.
   - The request (gate 5) must be byte-identical to that diff.
   - The handoff checklist now names the 8 paths.
2. **Resolved: the public source.**
   - `origin/work/v3-acceptance-reconciliation-20261030` is at `e733394`, and
     `fbe5b6f` is an ancestor of it. Both full SHAs are cited.
   - The LÖVE non-claim is stated.
3. **Resolved: the replay echo.**
   - The echo string is literal and matches the one I specified.
   - The trainer-party precedent (workflow line 502) is cited.
   - The inventory wording is explicitly not reused.
4. **Resolved: the authority gate.**
   - The rule "gates 2-4 MUST NOT create or modify any package path on main"
     is present.
   - The authorization task path is named.
   - The STATE/HANDOFF/TASK_REGISTER edits for gates 4 and 6 follow
     `c9ca2ab`/`e83fc45`.
   - The V3 task status advances only after the outcome review PASSes.
5. **Resolved: the evidence lines.**
   - Three verbatim lines are required.
   - A SKIP blocks an outcome PASS.
   - `N passed` is acceptable: the fixture prints `4 passed`.

## Independent checks against current `origin/main` `794b919`

- `git apply --check` of `49d0f45..fbe5b6f`: exit 0.
- `git merge-tree --write-tree origin/main fbe5b6f`: clean.
- None of the 8 paths changed on main since `49d0f45` (0 paths in
  `git diff --name-only`).

## Non-blocking open items, to carry into the configuration task

- **Erratum, plan lines 85-86.** The plan says "None of the eight paths
  exists ... on main". That is false:
  - `src/core/BattleEngine.lua`, `tests/phase4_move_effect_inventory_test.lua`
    and `work/reports/phase4-move-effect-inventory.md` exist on main and are
    modified by the patch. They are unchanged since `49d0f45`.
  - The other five paths are new.

  The configuration task should state this correctly. The gate-5
  `git apply --check` remains the guard.
- **Coordination owner.** The operator approved Claude taking over the V3
  relay's `work/coordination/LOCAL_RUNNER_BRIDGE.md` edits while Codex is
  usage-limited. The plan does not record this. The configuration task should
  record that approval as its authority for the gate-2 ledger edit.
