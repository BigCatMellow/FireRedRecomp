# FireRedRecomp Coordination Handoff

- Record role: `HANDOFF`
- Primary information class: `TASK CONTEXT`
- Status: `READY FOR INDEPENDENT REVIEW`
- Lifecycle: `ACTIVE`
- Authority: coordination only; root `AGENTS.md` and active task contract control review
- Canonical status owner: [`../roadmaps/CAPABILITY_CHECKLIST.md`](../roadmaps/CAPABILITY_CHECKLIST.md)
- Active task: [`../tasks/phase3-complete-runtime-exit-replay.md`](../tasks/phase3-complete-runtime-exit-replay.md)
- Machine state: [`STATE.json`](STATE.json)

## Current Worker handoff — Phase 3 complete runtime exit replay identity correction

The Worker corrected the sole `NEEDS_FIX` finding from the independent review
at [`../reviews/2026-09-19-phase3-complete-runtime-exit-replay-review.md`](../reviews/2026-09-19-phase3-complete-runtime-exit-replay-review.md).
The implementation/evidence revision is
`333d048809c2c3a53f51cee016e685afdea911cb` (`Assert identity in Phase 3
complete replay`). A fresh independent Reviewer must assess that revision and
this coordination handoff; this is not a Worker approval or parent-gate
reconciliation.

The normal-save route now makes success conditional on both the identity that
flows through the normal Oak/new-game result and the actual session identity
that the normal `K` callback saves: male (`0`), player `RED`, rival `GREEN`.
The separate fresh-load route makes success conditional on the same identity
decoded from the newly loaded session. Its output remains observational, but
each PASS now depends on those predicates. The wrapper requires
`identity=RED/GREEN/0` in both process outputs before emitting its aggregate
`identity=asserted` marker; it no longer synthesizes `RED/GREEN` in that
marker.

Worker evidence on the corrected revision, with the private FireRed US v1.0
image SHA-1 verified as `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`:

- `lua5.1 tests/phase3_complete_runtime_exit_replay_test.lua`: PASS.
- `luac5.1 -p main.lua` and `bash -n scripts/runtime_phase3_complete_exit_replay.sh`: PASS.
- `POKEPORT_ROM=<verified private ROM> bash scripts/runtime_phase3_complete_exit_replay.sh`: PASS. The normal-save process emitted `identity=RED/GREEN/0`; the fresh `L`-load process independently emitted `identity=RED/GREEN/0`; the wrapper emitted the aggregate PASS marker only after validating both.
- `env -u POKEPORT_ROM bash scripts/test_all.sh`: 144 test files PASS in no-ROM mode.
- `POKEPORT_ROM=<verified private ROM> bash scripts/test_all.sh`: 144 test files PASS in ROM mode.

No gameplay, save layout, supported-ROM policy, ROM content, or prohibited
surface changed. Next action: a fresh independent Reviewer reproduces the
focused test, isolated complete replay, and both suites against the exact
revision, then returns `PASS`, `NEEDS_FIX`, or `BLOCK`. Do not reconcile the
parent Phase 3 gate or canonical capability status without that review.

## Superseded Worker handoff — Phase 3 complete runtime exit replay

The bounded evidence implementation is ready for independent review. It adds
only replay-driver plumbing, one focused contract test, and one runtime wrapper;
normal gameplay behavior was not changed.

The published Worker implementation/evidence revision is
`a675cdf8f632d4bf7a4b23aa0b0f55dc17644baa`. Reviewer must assess that exact
revision against
[`../tasks/phase3-complete-runtime-exit-replay.md`](../tasks/phase3-complete-runtime-exit-replay.md),
not treat this handoff as a self-approval.

Evidence reproduced locally using the private verified FireRed US v1.0 ROM
(SHA-1 `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`):

- `lua5.1 tests/phase3_complete_runtime_exit_replay_test.lua`: PASS.
- `POKEPORT_ROM=<verified private ROM> bash scripts/runtime_phase3_complete_exit_replay.sh`: PASS. The normal-title-boot process emits title/Oak/identity, bedroom/Pallet, Route 1 wild-defeat, money `2960`, recovered lead HP, and normal-save evidence; a second LÖVE process emits normal-load party continuity. The wrapper emits the single final `RUNTIME_REPLAY phase3_complete_exit PASS` marker.
- `env -u POKEPORT_ROM bash scripts/test_all.sh`: 144 files PASS.
- `POKEPORT_ROM=<verified private ROM> bash scripts/test_all.sh`: 144 files PASS.

The wrapper uses a freshly created temporary XDG sandbox, verifies the normal
`K` callback produced a nonempty save there, and supplies that same sandbox to
the fresh `L`-load process. It does not add ROM content or alter save layout.

Next action: independent Reviewer runs the focused test, complete replay, and
both suites on the exact commit; only then may Orchestrator reconcile the
parent Phase 3 gate. `STATE.json` is `READY_FOR_REVIEWER`.

## Completed prerequisite

The bounded category/learnset foundation is implemented at
`1939d3b62f29a2ad9e75e1d0f1b0d1abb1c7ce70`.
It adds no frozen package data or mod package.

- explicit move categories are resolved centrally, with unmodded Gen-3 fallback;
- all damage transformation/event paths retain an explicit category;
- a `battleLearnsetAdditions` empty-base namespace and pure merge route all
  nine live learnset consumers through one resolver;
- focused checks passed: 46 BattleFormulas, 8 overlay, 392 BattleEngine;
- `luac5.1 -p main.lua` and the 141-file no-ROM suite passed.

ROM-dependent checks were not run because no `POKEPORT_ROM` path was supplied.
This is recorded missing evidence, not a pass claim.

## Independent reviewer verdict

The independent Reviewer returned `PASS` on corrected revision
`25e3d88e2b7ae5e4b693e1da831abfe2b5bda6db` after independently verifying:

1. no frozen move/category/learnset values or mod content appeared;
2. no prohibited game surface changed;
3. Gen-3 fallback and explicit category behavior are both directly tested;
4. all nine former direct main learnset consumers use the common resolver;
5. additions preserve decoded base rows and fail closed on invalid/duplicate
   values, including sparse arrays; and
6. the test claims reproduce in the available no-ROM environment.

- sparse additions now fail closed rather than truncating at the first gap;
- focused category, overlay, and engine checks; syntax; and the 141-file
  no-ROM suite reproduce; and
- no frozen package data, mod content, ROM data, or prohibited scope appears.

## Completed package gate

The independent Reviewer returned `PASS` at
`bb0476cedd9831e5a43d086e52bced1769982c3c`. The source-locked package is
complete; the next task must not change its values.

## Completed balance-validation task

The Worker evidence is committed at `6db8d9c0` (`Strengthen balance validation
matrix evidence`) and is ready for independent review under
[`../tasks/pokemon-firered-balance-representative-validation.md`](../tasks/pokemon-firered-balance-representative-validation.md).

The orchestration operator reproduced the required supported-ROM evidence at
that revision: the FireRed US v1.0 SHA-1 was
`41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`; the focused matrix passed 13/0;
the actual LÖVE runtime reported `RUNTIME_BALANCE_MOD PASS`; and the full
suite passed all 143 test files in ROM mode. These are review inputs, not a
self-approval or task closure.

The Reviewer must verify the exact task criteria and negative scope directly,
then return `PASS`, `NEEDS_FIX`, or `BLOCK`. Do not adjust frozen package
values or prohibited surfaces based on validation results.

## Independent reviewer result

`PASS` at `6db8d9c0ba37b6c83464660ca82cc04e9fa68aa9`.

The Reviewer independently verified that the validation range from the prior
reviewed package gate changes only runtime observation plumbing, focused
validation, and coordination/task records; it does not alter the frozen mod
package, ROM/imported data, trainers, encounters, AI, items/TM compatibility,
economy, held-candidate controls, save layout, Phase 3 records, or prohibited
assets. The actual LÖVE process, using the locally verified FireRed US v1.0
ROM SHA-1 `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`, emitted
`RUNTIME_BALANCE_MOD PASS` for the gameplay-impacting package and passed the
Route 1 replay. The focused ROM matrix passed 13/0 and directly covers the
eight overridden fields, all 13 additions, physical Fire/Water, Special
Ghost/Flying, both physical Poison exceptions, raw Gen-3 fallback controls,
the named watch matrix, finite TM19/TM30 allocation arms, held non-promotion,
and unload. `bash scripts/test_all.sh` also passed all 143 files in ROM mode.

The reviewed task is now closed. Its durable implementation evidence is at
[`../evidence/2026-09-18-pokemon-firered-balance-implementation-evidence.md`](../evidence/2026-09-18-pokemon-firered-balance-implementation-evidence.md).
This result does not merge or release anything, reopen frozen values, or
advance Phase 3.

## Current reviewer result — bridge parser-disambiguation correction

The independent Reviewer returns `PASS` on published subject
`63d4bf517b09a441b6769fb7f61b6afa3657d709` (`origin/master` and local
`HEAD`), including parser-correction implementation
`b7eaaec77eb98b336b0c25299580dd6cbafab4a0`. The durable record is
[`../reviews/2026-09-19-local-worker-bridge-parser-disambiguation-review.md`](../reviews/2026-09-19-local-worker-bridge-parser-disambiguation-review.md).

The Reviewer independently reproduced focused syntax/bridge coverage, the
143-file no-ROM suite, and the 143-file verified-ROM suite after independently
confirming the supplied private ROM's required SHA-1. An adversarial patch with
an allowed `main.lua` header and unallowlisted workflow markers was rejected
before fake `git apply --check` could run. Conversely, an applicable allowed
Lua-comment deletion line beginning `--- ` reached the apply check rather than
being treated as a preamble marker. Mode-only, malformed-header, source-path,
explicit routing, trusted-main-only, exact-ROM-gate, test/replay-before-publish,
and route-specific staging invariants remain intact.

This PASS closes only the bounded bridge prerequisite. The Orchestrator may
restore the existing `phase3-complete-runtime-exit-replay.md` task to
`READY_FOR_WORKER`; it must not advance Phase 3 or treat its continuous replay
as implemented or reviewed.

## Superseded reviewer result — bridge header-validation correction

The fresh independent Reviewer returns `NEEDS_FIX` on handoff subject
`49aa6b7589faf1d7a3c3a3b550a6e83043b2c2a8` (implementation
`616d802e41a4006cf19894a8a27ca4de68c34ae6`). The durable record is
[`../reviews/2026-09-19-local-worker-bridge-header-validation-review.md`](../reviews/2026-09-19-local-worker-bridge-header-validation-review.md).

The correction properly validates both paths of every parseable `diff --git`
header, including mode-only changes, but it removed validation of textual
`---`/`+++` marker paths. An independent probe constructed an allowed
`diff --git a/main.lua b/main.lua` header with textual markers for the
unallowlisted workflow file. The validator accepted it and `git apply --check`
accepted it too. The pre-apply allowlist is therefore still bypassable.

Reproduced evidence:

- `bash scripts/test_local_worker_bridge_patch_targets.sh` passed. It accepts
  an authorized mode-only header and rejects an unauthorized mode-only target,
  unauthorized source path, and malformed header.
- `env -u POKEPORT_ROM bash scripts/test_all.sh` passed 143 files.
- A locally available private ROM matched
  `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`; its 143-file ROM-mode suite
  passed.
- The header/marker mismatch probe above was accepted, demonstrating the
  remaining security defect.

Worker may only amend the focused target validator and deterministic
non-gameplay coverage: validate both paths of every `diff --git` header and
every textual `---`/`+++` path that `git apply` may use, fail closed on
malformed/unallowlisted values, and prove the allowed-header/unallowlisted-marker
bypass is rejected before `git apply --check`. No gameplay/runtime replay
implementation, policy, permissions, ROM content, or save-layout change is
authorized. Do not restore `work/tasks/phase3-complete-runtime-exit-replay.md`
to Worker or advance Phase 3 without a fresh independent `PASS`.

## Current publication blocker

The remote-isolated Reviewer could not resolve the local parser-disambiguation
subject `b7eaaec77eb98b336b0c25299580dd6cbafab4a0`; an exact fetch from `origin`
reported it was not a remote ref. The local branch has the bounded commits and
test evidence, but no review verdict can bind until the subject is published.

Direct publication to `origin/master` requires explicit human authorization.
Do not retry or work around that shared-repository boundary. Once authorized,
publish only the existing bounded commits and request a fresh independent
review of the exact remote-visible revision.

## Prior local review scope — parser-disambiguation correction

The Worker repaired only the focused bridge validator and deterministic
non-gameplay coverage after the marker-validation review. Within each
`diff --git` section, it treats paired `---`/`+++` records as actionable file
markers only before the first `@@` hunk; it still validates both header paths
and every actionable marker path against the unchanged route allowlist before
`git apply --check`. Post-hunk `--- ` and `+++ ` lines are hunk content, so a
valid deleted Lua comment is not misclassified as a file marker.

The exact revision is recorded in the Worker delivery. Evidence on that
revision:

- `bash -n scripts/validate_local_worker_bridge_patch_targets.sh scripts/test_local_worker_bridge_patch_targets.sh`: PASS.
- `bash scripts/test_local_worker_bridge_patch_targets.sh`: PASS. It proves
  the allowed-header/unallowlisted-workflow-marker spoof is rejected before a
  fake `git apply --check`, while an authorized applicable `main.lua` patch
  containing a Lua-comment deletion record beginning `--- ` reaches and passes
  the real `git apply --check`.
- `env -u POKEPORT_ROM bash scripts/test_all.sh`: 143 test files PASS in
  no-ROM mode.
- A local private ROM matched the required SHA-1
  `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`; with it as `POKEPORT_ROM`, the
  full suite passed 143 test files in ROM mode.

No gameplay/runtime replay implementation, public-PR policy, permissions,
supported-ROM policy, ROM content, or save-layout surface changed. The
Reviewer must independently assess the exact revision and return `PASS`,
`NEEDS_FIX`, or `BLOCK`. Do not restore
`work/tasks/phase3-complete-runtime-exit-replay.md` to Worker or advance Phase
3 without that fresh `PASS`.

## Superseded reviewer result — marker validation correction

The fresh independent Reviewer returns `NEEDS_FIX` on subject
`f7aa498dbe17e40d144557b9cd9614f1779b9096`, reviewing correction
implementation `e8c9c32c782728ca5d06cf679c808a01e8cb1d24`. The durable record
is [`../reviews/2026-09-19-local-worker-bridge-marker-validation-final-review.md`](../reviews/2026-09-19-local-worker-bridge-marker-validation-final-review.md).

The correction successfully rejects the prior allowed-header/unallowlisted-
marker spoof before `git apply --check`, but it mistakes a normal unified-diff
deletion line for a file marker whenever an authorized Lua source line begins
`-- `. An independently constructed, valid and applicable `main.lua` patch
that changes the first Lua comment passed `git apply --check` but the validator
rejected it as a malformed old-file marker. Legitimate allowed patches are
therefore blocked.

Worker may amend only the focused validator and deterministic non-gameplay
coverage, plus directly accurate task/coordination documentation. The repair
must distinguish the actionable marker preamble from hunk content while
retaining validation of both `diff --git` paths and every actionable marker
before `git apply`. It must prove both: (1) the allowed-header/unallowlisted-
marker spoof still fails before `git apply --check`; and (2) a valid authorized
Lua deletion line beginning `--- ` reaches and passes `git apply --check`.

Independent checks reproduced: focused syntax/test passed; no-ROM suite passed
143 files; both local ROM candidates matched
`41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`; and the ROM-mode suite passed
143 files. Do not restore `work/tasks/phase3-complete-runtime-exit-replay.md`
to Worker or advance Phase 3 without a fresh independent `PASS` on the repair.

## Superseded worker routing — marker validation correction

Worker correction subject: `e8c9c32c782728ca5d06cf679c808a01e8cb1d24`
(`Validate bridge patch file markers`). This corrects only the bridge target
validator, its deterministic non-gameplay coverage, bridge procedure text, and
the active task record.

Before `git apply --check`, the validator now validates both paths of every
parseable `diff --git` header and each actionable paired `---`/`+++` marker.
Malformed, unpaired, wrong-prefix, or unallowlisted marker paths fail closed;
`/dev/null` is accepted only for one side of a creation/deletion pair. Existing
mode-only header protection and all explicit route allowlists are retained.

Focused deterministic evidence:

- `bash -n scripts/validate_local_worker_bridge_patch_targets.sh
  scripts/test_local_worker_bridge_patch_targets.sh`: PASS.
- `bash scripts/test_local_worker_bridge_patch_targets.sh`: PASS. The test
  first confirms `git apply --check` accepts an allowed `main.lua` header with
  unallowlisted workflow-file markers, then substitutes a fake `git` executable
  and proves the validator rejects the patch before `git apply --check`.
- `env -u POKEPORT_ROM bash scripts/test_all.sh`: PASS, 143 test files in
  no-ROM mode.
- The available private ROM matched SHA-1
  `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`; `POKEPORT_ROM=<verified private
  ROM> bash scripts/test_all.sh`: PASS, 143 test files in ROM mode.

No gameplay/runtime replay implementation, public-PR policy, permissions,
supported-ROM policy, ROM content, or save-layout surface changed. Reviewer
must independently assess `e8c9c32c` and return `PASS`, `NEEDS_FIX`, or
`BLOCK`; Phase 3 remains in progress pending that verdict.
