# FireRedRecomp Coordination Handoff

- Record role: `HANDOFF`
- Primary information class: `TASK CONTEXT`
- Status: `READY FOR WORKER`
- Lifecycle: `ACTIVE`
- Authority: coordination only; root `AGENTS.md` and active task contract control review
- Canonical status owner: [`../roadmaps/CAPABILITY_CHECKLIST.md`](../roadmaps/CAPABILITY_CHECKLIST.md)
- Active task: [`../tasks/local-worker-bridge-complete-runtime-route.md`](../tasks/local-worker-bridge-complete-runtime-route.md)
- Machine state: [`STATE.json`](STATE.json)

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

## Current reviewer result — bridge header-validation correction

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
