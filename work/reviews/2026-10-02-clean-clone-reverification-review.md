# Clean-clone reverification — independent review

Verdict: **PASS for the accurately blocked report. P0-04 remains BLOCK.**
Only documented prerequisite discovery/stop behavior and checkout cleanliness
are verified; no dependent CLI, refusal or desktop acceptance is implied.

- Task: [P0-04-REVERIFY](../tasks/phase0-clean-clone-reverification.md).
- Exact report/task revision: `93c465440d928b4a3c9628485f70f0ca48e54b9b`.
- Parent and fresh-clone pin: `6dcb2e609a702d0d02b2547dc133b594800b87b6`.
- Reviewed documentation: `d4f7fe8aa0cb1825ef6f1f5f13977ead1f7d6e92`, accepted
  by its [independent review](2026-10-02-first-run-documentation-repair-review.md).
- Artifact: [reverification report](../reports/phase0-clean-clone-reverification.md).

## Independent evidence

Recovered public main at the exact report revision and inspected its two-file
diff, task, report and documented preflight. The preserved disposable clone is
distinct from the original P0-04 checkout, has the public HTTPS origin, detached
HEAD at the stated pin, a clone-origin reflog followed by that checkout, and no
object alternates or shared Git-directory indirection. Its README and FIRST_RUN
are tracked and unchanged from the independently reviewed documentation.
Tracked, untracked and ignored-file status is clean before and after review
checks. Those facts support the claimed fresh-checkout isolation; they are not
pristine-OS evidence or reconstruction of every original clone command flag.

The local evidence directory contains the clone and the two reported external
prerequisite logs. The retained logs agree with the report. Independently
repeated only the same read-only prerequisite checks from that clone root:

| Check | Independent result |
| --- | --- |
| Exact first Bash block extracted from FIRST_RUN | **Exit 127**, `Missing prerequisite: lua5.1`; the block stops before its version commands. |
| Documented `love --version` | **Exit 127**, command not found; no app is launched and no runtime version/display is established. |
| Default command discovery | Git, Bash and `sha1sum` available; `lua5.1`, `lua` and `love` absent. |
| Separate available-tool/host observations | Git 2.43.0, Bash 5.2.21, coreutils `sha1sum` 9.4; Linux Mint 22.2, Linux x86_64. |
| Final checkout state | No tracked, untracked or ignored changes. |

No alternate executable path, isolated wrapper, modified PATH, package install,
display injection or environment repair was used for those review checks. No
valid ROM, synthetic input or application state was accessed or created.

## Scope and NOT RUN boundaries

The conditional already-provisioned profile is not satisfied on this target.
Stopping before the repository checker, full suite and both configured-input
refusal cases follows FIRST_RUN. Missing Lua is not successful importer refusal
and supplies no new file/link counts, suite pass, ROM skips or hash result.
Missing LÖVE likewise provides no window, prompt, visible refusal, screenshot,
display-usability or process-liveness proof. Every dependent case is correctly
marked **NOT RUN** rather than inferred from the historical constrained run.

No fresh XDG/app-state sandbox is needed when no runtime launches. The retained
evidence contains no synthetic-input, desktop-run or capture result contradicting
those NOT RUN entries. The report does not transfer old CLI results to the new
clone or substitute CI/private-runner evidence for missing local execution.
This review did not execute any of those dependent checks either.

The exact commit changes only the authorized report and task evidence/handoff
section and passes `git diff --check`. The documentation, runtime, scripts,
tests, workflow, toolchain, user settings and canonical status remain unchanged.
Its aggregate report records versions, revision and result categories without
private paths, ROM content or environment dumps. No repair or workaround is
hidden in the authored diff. Older task/coordination queue wording is for the
parent to reconcile, not evidence that the blocked verification succeeded.

## Exact next allowance

The Orchestrator may accept the report and record the missing-prerequisite
blocker. A prerequisite-ready target or host-preparation decision requires
separate authority; this review authorizes no install, wrapper/PATH change,
display injection, ROM acquisition or further workaround. A later authorized
fresh verification must still produce its own CLI/refusal and desktop evidence.
The documentation/stop behavior is now evidenced, but clean-target completion,
P0-04 and broader Phase 0/save-safety gates remain open.

Only this review artifact was written. No repair, task/state/coordination edit,
commit, push, workflow dispatch or phase advancement was performed.
