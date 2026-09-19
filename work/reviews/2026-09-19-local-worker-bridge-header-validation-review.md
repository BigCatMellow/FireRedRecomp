# Independent review: bridge header-validation correction

- Verdict: `NEEDS_FIX`
- Reviewed subject revision: `49aa6b7589faf1d7a3c3a3b550a6e83043b2c2a8`
- Correction implementation: `616d802e41a4006cf19894a8a27ca4de68c34ae6`
- Evidence/state revision: `cde0692edd411f30e5750d01df5e5596e3719f30`
- Active task: `work/tasks/local-worker-bridge-complete-runtime-route.md`
- Scope: infrastructure/execution-substrate review only

## Reproduced evidence

1. `bash -n scripts/validate_local_worker_bridge_patch_targets.sh
   scripts/test_local_worker_bridge_patch_targets.sh` passed.
2. `bash scripts/test_local_worker_bridge_patch_targets.sh` passed: an
   authorized mode-only header is accepted and unauthorized mode-only,
   unauthorized source, and malformed headers are rejected.
3. Additional independent probes confirmed that a mixed allowed/unauthorized
   mode-only patch, an unauthorized source path, and a malformed header with
   trailing fields are rejected before `git apply`.
4. `env -u POKEPORT_ROM bash scripts/test_all.sh` passed all 143 test files.
   Both locally available private ROM candidates hash to
   `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`; the 143-file ROM-mode suite
   also passed. No ROM content was added to git.
5. The route remains explicit with its five-file allowlist, focused test,
   no-ROM and verified-ROM suites, runtime replay, and explicit staging. The
   workflow remains trusted `push` to `main` only, without public-PR execution;
   the exact ROM SHA gate and test/replay-before-publish ordering remain.

## Required correction

The new validator checks both paths of each `diff --git` header, including
mode-only changes, but it no longer validates the paths in textual `---` and
`+++` file markers. `git apply` can act on those marker paths.

I reproduced a valid patch whose header is allowed:

```text
diff --git a/main.lua b/main.lua
```

but whose textual markers target
`.github/workflows/local-worker-bridge.yml`. Against the current checkout,
`PATCH_FILE=<crafted patch> ROUTE=phase3-complete-runtime-exit-replay bash
scripts/validate_local_worker_bridge_patch_targets.sh` succeeded, and `git
apply --check <crafted patch>` also succeeded. Thus an unallowlisted workflow
file can be applied despite every `diff --git` header path being allowlisted.

This violates the task invariant that every patch target be hard-coded
allowlisted before application. The smallest in-scope correction must retain
validation of both paths of every parseable `diff --git` header (including
mode-only changes) and additionally fail closed on malformed or unallowlisted
textual `---`/`+++` marker paths that `git apply` can use (allowing `/dev/null`
only where appropriate). Add deterministic coverage for the allowed-header /
unallowlisted-marker bypass; it must fail before `git apply --check`.

## Verdict

`NEEDS_FIX`

No gameplay, replay implementation, public-PR policy, permissions, ROM policy,
or save-layout work is authorized. Keep
`phase3-complete-runtime-exit-replay` blocked until a fresh independent `PASS`
on the corrected exact revision.
