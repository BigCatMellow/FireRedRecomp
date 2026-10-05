# Canceled Local Worker Bridge runs — independent retry review

Verdict: **PASS** — coordination-only, one-rerun-per-existing-run authority.

- Reviewed revision: `98540c588c0c7fa2074f9cb1b8302948b8e6f28b`.
- Task: [canceled bridge-runs retry authorization](../tasks/local-worker-bridge-canceled-runs-retry.md).

## Independence and exact scope

I reviewed the exact authorization independently and authored only this review
file. The commit adds only the retry task and its derived register row; it
does not change a request/probe artifact, workflow, route, runner, ROM policy,
code, tests, task contract, or canonical capability status. `git diff --check`
passes.

## Cancellation evidence and preserved inputs

Public Actions metadata independently confirms both cited runs were terminal
`cancelled` push runs with a canceled `local-worker` job and an empty `steps`
array:

- Restore HP run `37080060017`, job `111078381727`, head SHA
  `6395a4793cc0fb9b3250801018600550636e0ff5`; and
- Viridian route-probe run `37125167854`, job `111321554725`, head SHA
  `f6b914864b21575e7757ffb1da4324c2173522d6`.

The first SHA contains the existing Restore HP patch request and the second
contains the existing P5 readiness probe. Neither canceled job executed any
checkout, route, SHA, patch, test, replay, publication, or implementation
step. Thus a GitHub rerun of those same runs is materially narrower than a new
push: it retains the existing triggering commit/artifact rather than creating
or modifying one.

## Contract and workflow compatibility

The P4 implementation contract already authorizes exactly its one guarded
request and still requires full guarded evidence plus independent exact
implementation review. The P5 route/config contracts already authorize exactly
its one substrate-only probe and still require an executed probe plus
independent probe review before any P5 request. The retry task neither changes
those allowlists nor converts a canceled run into evidence.

The bridge is push-to-`main` only, obtains its input from the triggering
commit, and its concurrency group has `cancel-in-progress: false`. A rerun can
therefore exercise the same original event/commit under the workflow's existing
hard-coded selector, validation, SHA, full-suite, replay, and publication
gates. The P5 input remains probe mode, so its patch-only stages are guarded
to skip; the P4 input remains the already-reviewed patch mode and must complete
all preexisting gates before any publication.

## Availability and fallback limits

The authorization is correctly conditional on a fresh GitHub observation that
`firered-mint` is both online and idle, recorded immediately before each rerun.
It permits at most one rerun of each named run, requires recovery of the exact
resulting job evidence afterward, and forbids rerunning while offline or busy.

If GitHub declines a rerun, if runner availability changes, or if either rerun
fails, the required fallback is to stop and record the outcome. No replacement,
renamed, copied, amended, or newly pushed request/probe may be created, and no
route, scope, patch-byte, ROM, test, or code change is authorized. That
preserves the original independent-review gates and avoids silently turning
runner recovery into broader implementation authority.

Only this review file was authored. No rerun, task/register edit, artifact,
workflow, code, state, or commit was changed by the Reviewer.
