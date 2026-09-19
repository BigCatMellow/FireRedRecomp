# Independent review: bridge parser-disambiguation correction

- Verdict: `PASS`
- Reviewed published subject: `63d4bf517b09a441b6769fb7f61b6afa3657d709` (`origin/master` and local `HEAD`)
- Parser-correction implementation: `b7eaaec77eb98b336b0c25299580dd6cbafab4a0`
- Active task: `work/tasks/local-worker-bridge-complete-runtime-route.md`
- Scope: infrastructure/execution-substrate review only

## Independent findings

1. The published subject contains the parser correction as an ancestor, and
   the correction changes only the focused bridge validator/test and accurate
   coordination/task records. It changes no gameplay/runtime implementation,
   ROM/asset content, permissions, public-PR policy, or save-layout surface.
2. The workflow remains trusted `push` to `main` only for controlled request
   and probe paths, requires exactly one such changed file, has no
   `pull_request` or `pull_request_target` trigger, and selects known routes
   explicitly with an unknown-route failure.
3. The complete-runtime route remains a hard-coded five-file surface:
   `main.lua`, its focused test, its replay script, and its complete/parent
   task records. Its focused test, no-ROM suite, verified-ROM suite, runtime
   replay, and publish staging remain explicit and ordered before publication.
4. Before `git apply --check`, the validator now checks both paths in every
   strict `diff --git a/... b/...` header, including mode-only changes. It
   also checks paired `--- a/...` / `+++ b/...` markers only in each section's
   file preamble, rejects malformed/unpaired markers, and rejects unauthorized
   paths. `/dev/null` is accepted only for a one-sided creation/deletion pair.
5. Independent adversarial execution with a fake `git` built an allowed
   `main.lua` header followed by actionable workflow-file markers. The
   validator rejected the unallowlisted workflow path and the fake
   `git apply --check` was not reached. The focused test also independently
   covers authorized mode-only acceptance, unauthorized mode-only and source
   rejection, and malformed-header rejection.
6. An applicable authorized `main.lua` patch deleting a Lua comment whose
   hunk record begins `--- ` was accepted by `git apply --check` and reached
   that check through the validator. A fake-`git` probe independently confirms
   this is not misclassified as a preamble marker.
7. `bash -n scripts/validate_local_worker_bridge_patch_targets.sh
   scripts/test_local_worker_bridge_patch_targets.sh`,
   `bash scripts/test_local_worker_bridge_patch_targets.sh`, and
   `env -u POKEPORT_ROM bash scripts/test_all.sh` passed; the no-ROM suite
   reports 143 test files. A locally supplied private ROM was independently
   hashed to the required FireRed US v1.0 SHA-1
   `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`, and its ROM-mode
   `bash scripts/test_all.sh` run passed all 143 files.

## Verdict

`PASS`

The bridge-maintenance task's existing acceptance criteria are satisfied on
the published subject. This closes only the bounded execution-substrate
prerequisite. It does not prove the complete Phase 3 runtime replay, alter the
canonical Phase 3 status, or authorize any gameplay change.

## Next allowance

The Orchestrator may restore the existing
`work/tasks/phase3-complete-runtime-exit-replay.md` package to
`READY_FOR_WORKER`. No broader dispatch or phase advancement is authorized by
this review.
