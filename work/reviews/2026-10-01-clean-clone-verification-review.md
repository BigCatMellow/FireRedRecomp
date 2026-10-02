# P0-04 clean-clone verification — independent review

Verdict: **PASS for the constrained verification report. P0-04 completion
remains BLOCK.** This accepts the accurately bounded evidence and blocker, not
a complete first-run or Phase 0 gate.

- Task: [P0-04](../tasks/phase0-clean-clone-verification.md).
- Exact report/task commit: `d0e0bad7985e6797487ac339147a8e13d9c50369`.
- Parent: `1a312f67751ccdd8fdb1b38ea9d85884cd6ed7d8`.
- Observed fresh-clone revision: `7a2e7ad7f6eec1a41c97f613143598b5de9c5a10`.
- Artifact: [clean-clone report](../reports/phase0-clean-clone-verification.md).

## Independently verified evidence

Recovered current public main at the exact report revision and inspected the
task, report, source entrypoints and retained disposable clone. The clone has
the reported detached HEAD, the public HTTPS origin, a clone-origin reflog
followed by checkout of the exact pin, and no object alternates linking it to
the working repository. Its tracked, untracked and ignored-file status is
clean. Logs, synthetic input and temporary desktop/XDG output are outside it.
These facts support fresh-checkout isolation; they do not make the host a
pristine OS or reproduce every original invocation flag.

History comparison confirms the observed README, runtime/importer, test runner,
repository checker and public workflow are unchanged from the clone pin through
the later dispatch and reviewed report. The report correctly retains the
original observed revision rather than claiming a newly cloned later main.

| Evidence | Independent result and boundary |
| --- | --- |
| Repository checker | Reran the documented command in the preserved clone with the declared toolchain PATH: exit 0, **276 tracked Lua / 158 tracked Markdown / 428 local targets PASS**. |
| Full no-ROM suite | Read the retained log: **151 test files PASS**, explicit ROM skips and no failure summary. This is verified recorded execution, not a fresh full-suite rerun by this Reviewer. |
| Configured missing input | Repeated the documented environment-variable test entrypoint using the nonexistent relative input: exit 1, refusal at ROM verification before decoding. |
| Synthetic invalid input | Verified the retained 78-byte input is plain ASCII and repeated the same test entrypoint: exit 1, unrecognized-hash refusal with the supported-US-v1.0 requirement. No valid ROM was used. |
| Clean state after checks | Tracked/untracked/ignored status remained empty after the independent checker and refusal checks. No fixture, save, cache or generated file was added inside the clone. |

The refusal cases stop in the first ROM-dependent test through the real
`RomImporter.verify` gate, followed by `os.exit(1)`; `test_all.sh` has
`set -euo pipefail`. They neither run a successful ROM suite nor use an importer
mock. Reading the test and production verifier confirms rejection precedes
address lookup and ROM-data decoding. The report correctly calls this
command-line refusal evidence, not demonstrated desktop refusal UX.

## Prerequisite and desktop limits

The default environment still lacks `lua5.1` and `love` on PATH. With the
already provisioned wrappers, the observed versions match Lua 5.1.5 and LÖVE
11.5; host observations also match Linux Mint 22.2/x86_64, Git 2.43.0 and Bash
5.2.21. The existing LÖVE wrapper supplies packaged library/Lua module paths,
so this is a real declared toolchain deviation, not proof that the documented
commands work on an unprovisioned machine. No installation or repair was
performed by this review.

`docs/FIRST_RUN.md` is absent both from the pinned Git tree and the clone. The
task-named guide therefore could not be followed. Using the available README
for the constrained observation is explicit and does not silently substitute a
new first-run contract.

For desktop evidence, the retained runtime log is empty and there is no usable
capture. The later missing/invalid desktop case directories have no runtime
observations. The report records an X-display-open capture failure and stopping
the owned process; those original terminal/cleanup observations were not
independently replayed here. They are not used as positive GUI proof. No new GUI
experiment, display repair or screenshot was attempted by the Reviewer.
A process reportedly remaining present cannot establish a visible prompt,
refusal, successful window, gameplay or presentation parity. Desktop first-run
and refusal behavior consequently remain unverified, exactly as reported.

## CI comparison and change boundary

At the clone pin, the public workflow checks out source, installs Lua 5.1, then
runs the same checker and no-ROM suite on push/pull request with read-only
contents permission. It does not launch LÖVE or supply the two refusal inputs.
The report distinguishes that static coverage comparison from local results,
new CI receipts, private-runner execution and verified-ROM/replay evidence.
No workflow was dispatched or rerun by this review.

The exact report commit changes only its two authorized text artifacts and
passes `git diff --check`. No runtime/test/workflow/documentation repair,
dependency change, ROM/media/save, user configuration or canonical status
change is present. The report is aggregate-only and does not expose machine
paths or private ROM information. The task handoff presents a blocked result;
older queue/status wording is for the parent to reconcile, not a reason to
treat the task as successfully completed.

## Exact next allowance

The Orchestrator may accept this constrained report and record the P0-04
blocker. Preserve the passing CLI observations; neither repeat them solely
because GUI evidence is missing nor promote them to pristine-machine or
complete desktop acceptance. Missing-guide/prerequisite resolution or a usable
desktop observation requires a separately bounded follow-up; this review
authorizes no installation, repair or project change. Phase 0 and broader save
safety remain open, and no private-ROM or retail visual-parity claim follows.

Only this review file was authored. No task/state/coordination edit, commit,
push or dispatch was performed; reconciliation belongs to the parent.
