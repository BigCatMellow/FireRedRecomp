# P4-02-ROUTE independent probe review

- Disposition: **PASS** — the separately authorized inventory-route probe only.
- Exact probe commit: `97dcae020e05143ab4666a16b9dfdf4d9c9e6e34`.
- Parent: `9c81b90a130c270f6902cdabe3b42f5c983d44ba`.
- Existing configuration: `24f39c424347425be9836e16d529c7706641aa93`, already
  accepted by the [independent configuration review](2026-09-20-move-effect-inventory-route-review.md).
- Authority: the [route task](../tasks/local-worker-bridge-phase4-move-effect-inventory-route.md),
  its explicit one-probe authorization, and the current Orchestrator review
  assignment. Historical runner-offline fields await Orchestrator reconciliation;
  the current handoff authorizes resuming this same probe after runner recovery.

## Exact scope

Local Git inspection and the independent GitHub commit API agree that the
parent-to-probe diff adds exactly one file with six lines and no deletions:
`work/local-runner/probes/phase4-move-effect-inventory-route-20260920.probe`.
The file is plain-text route-readiness description, not an implementation patch
or executable payload. `git diff --check` passes. The exact tree contains no
inventory-prefixed patch under `work/local-runner/requests/`.

The bridge workflow is byte-for-byte unchanged between reviewed configuration
`24f39c4` and probe commit `97dcae0` (`git diff --exit-code` succeeds). Therefore
this probe changes no route, allowlist, permission, trigger, concurrency rule,
SHA gate, test, runtime, publication logic or phase status. No ROM, extracted
content, media, cache or binary fixture appears in its six-line diff.

## Independently recovered guarded receipt

[Run 36335570606](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/36335570606)
is attempt 1 of `.github/workflows/local-worker-bridge.yml`, triggered by a
`push` on `main` at exact `97dcae020e05143ab4666a16b9dfdf4d9c9e6e34`.
It was created `2026-09-27T17:04:30Z` and completed successfully.
[Job 108665649123](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/36335570606/job/108665649123)
(`local-worker`, `17:04:32Z–17:04:37Z`) ran on `firered-mint`, with labels
`self-hosted`, `linux`, `x64`, `firered-local`.

Actual job logs independently establish the following, not merely the green
run summary:

| Required evidence | Observed receipt |
| --- | --- |
| Trusted checkout | Checkout fetched the triggering SHA with depth 2; `git log -1 --format=%H` printed exact `97dcae020e05143ab4666a16b9dfdf4d9c9e6e34` at `17:04:35.0060662Z`. The runner's older initial checkout was replaced; it was not used as the probe revision. |
| Exactly one probe / correct selector | The existing one-changed-bridge-file check passed. Route-step environment names the exact authorized `.probe`; actual output at `17:04:35.0872734Z` is `Selected explicit bridge route: phase4-move-effect-inventory`. |
| Lua toolchain | Git availability check succeeded; actual interpreter output at `17:04:35.1105379Z` identifies **Lua 5.1.5**. |
| Private ROM gate | Logged executed script sets expected SHA-1 `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`, checks the private file exists, computes `sha1sum`, and fails on inequality. Actual output at `17:04:35.6961663Z` confirms `ROM SHA-1 verified for FireRed US v1.0.` |
| Probe completion | The `mode == 'probe'` step succeeded. At `17:04:35.7168544Z` it confirms the explicit inventory route; at `17:04:35.7172255Z` it confirms runner/toolchain/checkout/hash-gate readiness. |

The successful private hash comparison is trusted-runner evidence. Reviewer
did not access, copy, decode or upload the ROM, and no private file path is
needed in this report. Readiness is established for this exact run, not a
guarantee that the runner will remain available indefinitely.

## Patch-only branch did not execute

The job API marks **all seven** patch-only steps `skipped`:

1. Validate bounded patch targets.
2. Apply bounded patch.
3. Run task-focused test.
4. Run no-ROM suite.
5. Run verified-ROM suite.
6. Run task runtime replay.
7. Publish verified bounded implementation.

Direct workflow inspection confirms each remains guarded by
`steps.request.outputs.mode == 'patch'`. Logs go from probe completion to
post-job cleanup; no patch/test/publication branch ran. The run's artifact API
returns `total_count: 0`. The probe commit itself was intentionally published
to trigger this run; there was **no inventory patch request or guarded
implementation publication** in this operation.

Metadata and logs were independently read using `gh run view 36335570606`
with run/job JSON, the run/job REST endpoints, and
`gh api repos/BigCatMellow/FireRedRecomp/actions/jobs/108665649123/logs`.
No workflow was dispatched or rerun by Reviewer. Runtime/full suites were not
repeated locally: this six-line probe changes no implementation, and skipped
tests are the required probe behavior, not missing gameplay evidence to infer.

## Exact next allowance

Orchestrator may reconcile this PASS and mark the route's separate probe
prerequisite satisfied. This unlocks only the later bounded `P4-02` inventory
request through the already reviewed route. Preserve the current main task
record; the prepared branch's reviewed test/report may be transported without
replacing newer coordination with its stale task hunk.

The later inventory request still requires its exact published implementation,
focused execution, full no-ROM suite, **non-skipped full SHA-verified-ROM
aggregate inventory execution**, explicit no-replay branch, and independent
final review. The probe ran none of those tests. This PASS does not accept the
inventory, authorize the selected next move-effect discovery, prove battle
behavior, or close Phase 4 or any other capability gate.

Reviewer wrote only this review; no implementation, coordination, commit,
push, request or workflow-dispatch action was performed.
