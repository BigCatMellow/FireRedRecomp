# Variable-power V3 route probe task — independent review

Verdict: **PASS**. It applies to exact revision `2546f2f` (PR #69), based on
main `5652093`.

- Task SHA-256: `3bf876f0927b187f80386132ac1ba7f0496ecd91a1598ddb550b21b8c586b87d`.
- Workflow SHA-256 at `5652093`: `c920505987071b59c2d23def7754e182685f6a940a14bd47a318d0f7ed863dd7`,
  unchanged since config review `8d4c2ff`.

This PASS permits the Worker to create the one literal probe file in a
separate probe PR. The Orchestrator may publish it only after its fresh
prerequisite checks. This PASS grants no request, patch, gameplay or status
authority.

## Independence and scope

I did not author this task, the configuration, or the plan. PR #69 changes
only the task file. `git diff --check` and `check_repository.lua` pass.

Precedent:

- P5-06 probe task `local-worker-bridge-phase5-viridian-roadblock-route-probe.md`;
- probe `9472aec` (PR #50);
- `2026-10-18-viridian-roadblock-route-probe-outcome-review.md`;
- Magnitude probe `phase4-magnitude-effect-route-20261010.probe` and its
  outcome review.

## Findings

1. **The filename is correct.**
   `work/local-runner/probes/phase4-variable-power-v3-effect-route-20261115.probe`:
   - matches the push `paths` filter and the `work/local-runner/probes/*.probe`
     probe-mode arm;
   - is selected by the merged `phase4-variable-power-v3-effect*.probe`
     selector;
   - follows the Magnitude/P5-06 `<route>-route-YYYYMMDD.probe` shape;
   - is not consumed: no such path exists in any ref (`git log --all`).

   The stale-date rule (task lines 35-38) makes the Orchestrator choose a new
   literal filename and never reuse one. That is correct.
2. **The content is correct.**
   - The 24-line ASCII body mirrors `9472aec` line for line: ID, readiness
     list, the same SHA-1 gate value, and the no-authorization sentence.
   - The workflow reads no probe content, so the text is a receipt only.
   - The skipped-step list correctly grows from P5-06's 8 to 9. It names the
     roadblock gate as skipped for "route mismatch" and adds the V3 gate, in
     workflow order.
3. **The step lists are exact and complete.** At `5652093` the job has 15
   steps:
   - 6 have no `if` or are probe-only, and must succeed: checkout, identify,
     select, toolchain, ROM, `Probe complete`.
   - 9 carry `mode == 'patch'` and must skip.

   The names in task lines 94-111 match the workflow byte for byte.
4. **Pre-publication checks.** The Orchestrator must freshly check four
   things:
   - `5652093` is still on main and the selector is unchanged;
   - the runner is online and idle;
   - no bridge run is active or queued;
   - the filename is unconsumed.

   Add the one-file triggering-commit rule: on a PR merge, the first-parent
   diff, which the `Identify bridge request` step's `git diff HEAD^ HEAD`
   uses. Together these match and slightly tighten P5-06 (lines 13, 82).
   Evidence is limited to IDs, step statuses and the probe-file SHA-256, with
   no logs, runner or ROM paths, or ROM data.
5. **No retry.** Task lines 155-158 make one publication consume the sole
   allowance. Any failure is terminal, with no retry, substitution or
   widening. This matches P5-06 line 50.
6. **An outcome review is required.** Task lines 137-142 require an
   independent exact probe-outcome review before gate 4 can be compiled. A
   PASS still authorizes no request. This matches the precedent chain
   (`92cbba8` was followed by its outcome review, then `c9ca2ab`). Gates 2-4
   still must not touch any package path.

## Offline probe-mode simulation

I ran a Python `-I` harness on a throwaway `git archive` tree. It used no
runner, no ROM and no network, and `HOME` was set to an empty temp directory,
so the ROM search finds nothing. All 9 checks PASS:

- **Identify:** a one-file commit adding the literal probe gives
  `mode=probe` with that file. A commit with two probe inputs is rejected.
- **Route:** selection returns `phase4-variable-power-v3-effect`.
- **Toolchain:** the step passes.
- **ROM gate:** it fails closed both on a non-supported dummy file
  (`mismatch`) and with no ROM. I did not run a real ROM.
- **Step outcomes:** evaluating every step's `if` with `mode=probe` and
  `route=V3` runs exactly the 6 named steps and skips exactly the 9 named
  steps.
- **`Probe complete`:** prints the route.

## UNKNOWN

- Live runner state and the real ROM SHA result are deliberately not
  observed. They belong to the Orchestrator's pre-publication checks and the
  outcome review.
