# External project review triage — 2026-09-21

- Input: user-supplied read-only assessment,
  `/home/home/Documents/FireRedRecomp_Review.md`.
- Review snapshot: `main` at `eac7d69`; no review text or external artifacts
  were copied into the repository.
- Triage snapshot: `main` at `a23eed4`.
- Status: `RECORDED — NO REMEDIATION AUTHORIZED BY THIS TRIAGE`.
- Purpose: preserve actionable observations for later bounded work while the
  user-requested execution pause remains in effect. This report is not an
  independent acceptance, security audit, or replacement for source/test/ROM
  evidence.

## Reconciliation of time-sensitive observations

The assessment's evidence cutoff predates the current checkpoint. The following
facts must not be repeated as live truth:

| Assessment observation | Current reconciliation |
| --- | --- |
| `P0-SAVE-ROLLOVER` was `READY_FOR_WORKER` and the codec lacked u32 rollover handling. | Implementation `aec377a` is published, with Worker 93/0 codec, 16/0 roundtrip and 150-file no-ROM evidence. It remains unreviewed; do not claim the defect closed. |
| `P0-03-CHECKS` was not present. | Implementation `3478822` is published; public run `35624624210` / job `106415819660` passed its named repository-check and no-ROM steps. Its independent review is paused without verdict. |
| The no-ROM suite had 149 files. | The current committed tree's repository check observes 275 tracked Lua files, 146 Markdown files and 179 local targets. The previous exact-package suites were 150 files; rerun counts at the exact reviewed revision rather than carrying counts forward. |
| `firered-mint` was offline. | It was online and idle when checked at the stopping checkpoint. No inventory probe/request was submitted; recheck before any action. |
| Coordination had one current active task. | Execution is paused by the user. `HANDOFF.md` and `STATE.json` own the resume queue. |

The reviewer used `origin/master` at `90d2eab`; its alleged divergence and
unique modules are plausible but require a source-locked branch-triage report
before any harvest, archive, deletion, or scope conclusion.

## Findings worth retaining

### High-value, evidence-backed candidates

1. **Bridge patch-target validation (F-C8 / R-06).** The review identifies
   rename, mode-only and binary patch forms that a header-only allowlist parser
   may miss. This is security-relevant even though only main pushers can invoke
   the bridge. First successor should be a read-only comparison of main against
   the claimed `master` validator, then a separately authorized high-risk
   hardening task. Do not import or merge `master` wholesale.
2. **Divergent `master` branch (F-P4 / R-01).** Preserve first, triage second,
   and obtain a human harvest/park/drop decision before moving any unique work.
   Modding runtime and balance-mod content are explicitly outside current Phase
   10 authority unless a new human decision says otherwise.
3. **Single-authority relay drift (F-P2 / R-02–R-04).** The review correctly
   identifies repeated, hand-maintained live-state surfaces. The current
   checkpoint already designates `STATE.json`/`HANDOFF.md` as the resume source,
   but a structural authority-matrix decision is still needed before deleting,
   regenerating, or mechanically enforcing any surface.
4. **`main.lua` and battle-dispatch growth (F-C1 / F-C2).** Treat both as
   structural design debt, not opportunistic refactors. Before a decomposition
   or handler registry, establish behavioral seams/golden traces and replace
   source-text assertions that would make the refactor falsely fail.
5. **Evidence labels (F-C5).** Several Phase 4 scripts appear to execute
   focused Lua tests and echo a `RUNTIME_REPLAY` result rather than exercising
   a LÖVE input replay. Re-label only after source inspection; do not erase
   valid focused/ROM-record evidence or imply that existing battle semantics
   failed.
6. **Fail-closed move admission (F-C3 / R-09).** The inventory's broad
   positive-power fallback is a parity risk. Any ratchet must follow final
   P4-02 private-ROM inventory acceptance and preserve explicitly accepted
   effects; it must not be guessed from the assessment's reported counts.

### Important, but needing a human policy decision

- Proportional task depth (F-P1 / R-05): decide whether low-risk,
  source-locked leaves can batch discovery/design/bridge evidence without
  removing independent review. This changes the project operating contract.
- Reviewer identity/lineage records (F-P5 / R-15): decide the minimum durable
  privacy-preserving identity evidence required for independence.
- Content-policy clarification (F-C10 / R-19): decide whether factual,
  transcribed mechanics data is permitted while ROM/media/extracted assets
  remain prohibited.
- Runner-machine hardening (R-18): requires machine/GitHub authority outside
  ordinary repository implementation.

### Candidates suitable for future bounded research or maintenance

- Complete the existing behavior-ledger audit; its partial report already
  distinguishes stale PC-overflow wording from missing end-to-end evidence.
- Source-lock the branch inventory before any `master` decision.
- Audit source-text tests and separate behavioral tests from structural seam
  checks before `main.lua` extraction.
- Create an evidence-label inventory before renaming Phase 4 replay scripts.
- Record a friction/recurrence mechanism only after the coordination-authority
  decision identifies its sole writer and required safeguards.

## Explicit non-actions

This triage does **not**:

- mark any phase or existing task complete;
- change the paused execution state;
- authorize deletion, archival, merge, or harvest of `master`;
- authorize workflow/bridge changes, runner configuration, or new dependencies;
- treat the assessment's static/code-quality observations as retail-parity
  failures without deterministic source/ROM evidence;
- replace the outstanding independent reviews for `3478822` and `aec377a`.

## Resume ordering with this review accounted for

When the user resumes execution, first complete the already-in-flight
independent reviews and public evidence retrieval described in
[`HANDOFF.md`](../coordination/HANDOFF.md). Then, before selecting another
effect family, compile one read-only `master` branch triage and one evidence
label/source-text-test inventory as separate tasks. Present the resulting
human-decision items (branch disposition, proportional depth, coordination
authority, content policy) together rather than silently selecting a policy.

Only after those decisions should a high-risk bridge hardening or structural
refactor be dispatched. The online private-runner inventory probe remains an
already-authorized independent path, but must use the existing single probe and
its established gate sequence.
