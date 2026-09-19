# Independent review: bridge marker-validation correction

- Verdict: `NEEDS_FIX`
- Reviewed subject revision: `f7aa498dbe17e40d144557b9cd9614f1779b9096`
- Correction implementation: `e8c9c32c782728ca5d06cf679c808a01e8cb1d24`
- Active task: `work/tasks/local-worker-bridge-complete-runtime-route.md`
- Scope: infrastructure/execution-substrate review only

## Evidence reproduced

1. The correction changes only the focused bridge validator/test, bridge
   procedure, and active-task record. The explicit complete-runtime route,
   its five-file allowlist, focused test, no-ROM and verified-ROM suites,
   replay command, and explicit staging remain intact.
2. `bash -n scripts/validate_local_worker_bridge_patch_targets.sh
   scripts/test_local_worker_bridge_patch_targets.sh` and
   `bash scripts/test_local_worker_bridge_patch_targets.sh` passed. The
   focused test proves the allowed-header/unallowlisted-marker workflow patch
   is rejected before its fake `git apply --check` can run. It also retains
   authorized and unauthorized mode-only-header coverage.
3. Independent source inspection confirms trusted `push` to `main` only,
   no `pull_request`/`pull_request_target` execution, exactly-one-request
   enforcement, explicit fail-closed route selection, target validation before
   apply, exact FireRed US v1.0 SHA-1 gate, and test/replay-before-publish
   ordering. No gameplay, ROM, permission, public-PR, or save-layout surface
   changed.
4. `env -u POKEPORT_ROM bash scripts/test_all.sh` passed all 143 test files.
   Both locally available candidate ROMs hash to
   `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`; with a verified candidate as
   `POKEPORT_ROM`, `bash scripts/test_all.sh` also passed all 143 test files.

## Required correction

The marker parser treats every physical line starting `--- ` as an old-file
marker, including a normal deletion record inside a unified-diff hunk. This
rejects legitimate allowed `main.lua` patches because Lua comments begin
`-- `. For example, this valid, applicable patch passed `git apply --check`:

```text
diff --git a/main.lua b/main.lua
--- a/main.lua
+++ b/main.lua
@@ -1,4 +1,4 @@
--- Phase 1+2 shell: boots a window, verifies a ROM if POKEPORT_ROM points at
+-- Phase 1+2 shell: boots a window, verifies a ROM if POKEPORT_ROM points at [test]
 -- one, composites a real map into an image and draws it (defaults to
```

But the validator exited before `git apply --check` with:

```text
Malformed or unparseable old file marker: --- Phase 1+2 shell: boots a window, verifies a ROM if POKEPORT_ROM points at
```

The new spoof defense therefore prevents a real authorized patch from passing,
violating the active task's requirement that the dedicated route authorize its
bounded `main.lua` surface. The smallest in-scope fix is to distinguish the
paired file-marker preamble from hunk content while retaining validation of
every actionable marker path and all diff-header paths before `git apply`.
Add deterministic coverage for this valid allowed patch (or an equivalent
authorized Lua deletion line beginning `--- `) and prove it reaches and passes
`git apply --check`; retain the existing allowed-header/unallowlisted-marker
rejection-before-apply proof.

## Verdict

`NEEDS_FIX`

Only the focused validator, deterministic non-gameplay coverage, and directly
accurate coordination/task documentation may change. Do not restore
`phase3-complete-runtime-exit-replay.md` to Worker and do not advance Phase 3
until a fresh independent `PASS` on the corrected exact revision.
