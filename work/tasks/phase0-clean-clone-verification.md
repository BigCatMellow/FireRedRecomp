# Task: clean-clone reproducibility verification

- Task ID: `P0-04`
- Status: `READY_FOR_WORKER`
- Type: `VERIFICATION / CLEAN CHECKOUT`
- Parent gate: Phase 0 reproducibility and release baseline.
- Prerequisites: accepted save contract `63592c3`, CI checks `3478822`, and
  ledger correction `fc43daf`.
- Risk: `MEDIUM` — the result controls reproducibility claims, but must not
  mutate the project or expand product behavior.

## Goal and source of truth

Verify a fresh checkout of the current public repository can follow the
documented no-ROM setup/test path and safely handles missing/invalid ROM input.
Use the current README, `docs/FIRST_RUN.md`, scripts, CI workflow, canonical
capability checklist and exact public revision. Treat the clean environment and
commands actually observed as evidence; do not retrofit documentation or code
within this verification task.

## MAY CHANGE

1. `work/reports/phase0-clean-clone-verification.md`.
2. This task's evidence/handoff section.

## MUST NOT CHANGE

Runtime, tests, workflows, docs, dependency manifests, task routes, canonical
phase status, ROM policy, user configuration, or external services. Do not add
or copy a ROM, media, save, cache, dependency lockfile or generated artifact to
the repository. A missing prerequisite is a reported BLOCK, not a repair
authorization.

## Acceptance criteria

1. Use a newly created disposable directory and fresh clone of exact public
main; record revision and environment/tool versions without secrets or machine
paths.
2. Follow the documented no-ROM first-run/test commands without unstated local
project state. Capture command outcome and all prerequisite deviations.
3. Demonstrate missing-ROM refusal and invalid-ROM refusal through documented
safe paths only, without retaining/copying a valid ROM or revealing paths.
4. Compare observed commands with public CI coverage; clearly distinguish a
clean-clone observation from CI or private-ROM evidence.
5. Produce an aggregate-only report and return PASS / NEEDS_FIX / BLOCK. A
separate independent review is required before any Phase 0 reconciliation.

## Stop / escalate when

Setup requires a missing tool, a network/download authorization, private
credential, valid ROM, or an undocumented manual repair. Record the exact
blocker and preserve the clean checkout; do not install, modify or bypass it.

## Completion and handoff

Worker publishes only this task/report. A separate Reviewer examines the exact
revision and evidence. Even a PASS does not close Phase 0 unless the canonical
checklist's remaining save-safety terms are independently satisfied.

## Worker evidence and handoff — 2026-10-01

Result: **BLOCK** for complete first-run/desktop verification; constrained
README CLI observation PASS. The
[aggregate report](../reports/phase0-clean-clone-verification.md) records the
fresh public clone at `7a2e7ad7f6eec1a41c97f613143598b5de9c5a10`, tool versions,
commands, explicit deviations and evidence limits, without machine paths or
private ROM information. The clone remained clean.

Observed with pre-existing tools exposed through an explicitly authorized PATH
prefix: repository checker **276 Lua / 158 Markdown / 428 targets PASS** and
full **151-file no-ROM PASS**, both exit 0. The documented test entrypoint
refused a configured nonexistent file and separately authored invalid ASCII
input, both exit 1 at ROM verification. No valid ROM or project state was used.

The task-named `docs/FIRST_RUN.md` does not exist at the pin, and Lua/LÖVE were
absent from default PATH. A single isolated Xvfb/XDG `love .` observation could
not capture its display; a visible first-run/refusal result is therefore
unverified. The owned process was stopped, later GUI cases were not attempted,
and no installation, repair, runtime/test/workflow/documentation correction or
phase change was made. Public CI command coverage was compared statically;
local observations are not new CI/private-ROM/replay receipts.

Only this evidence section and the report may be published. Independent review
must assess the exact result; parent owns blocker/status reconciliation and any
separately scoped prerequisite/documentation/desktop follow-up. Preserve the
constrained CLI evidence without claiming pristine-machine or Phase 0 success.
