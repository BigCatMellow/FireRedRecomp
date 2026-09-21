# External project review addendum triage — 2026-09-21

- Input: user-supplied addendum to the external review.
- Claimed source examined by that reviewer: `BigCatMellow/MAPS_Lean` at
  `39a1d69` (2026-09-20), including its operative pilot adapter, portable
  deployment design and applicable playbooks.
- Relationship to the prior
  [external-review triage](2026-09-21-external-project-review-triage.md):
  correction and refinement, not a replacement for its repository-specific
  code-quality observations.
- Status: `RECORDED — NO REMEDIATION OR POLICY CHANGE AUTHORIZED`.

## Material correction: no binding MAPS_Lean external-pilot standard

The initial external assessment compared this project largely with MAPS_Lean
wiki summaries. The addendum reports that MAPS_Lean's actual portable-deployment
roadmap has not selected or run a first external pilot (`D3` is not started),
and that FireRedRecomp is not a sanctioned MAPS_Lean pilot. Its `AGENTS.md` and
human authorizations therefore remain the sole authority for work here.

Consequences:

- Do **not** describe FireRedRecomp as failing a MAPS_Lean compliance checklist.
- Do **not** import MAPS_Lean's internal SQLite/LangGraph/hcom control plane,
  merge gates or internal-only playbook machinery. Their absence here is
  correct, not a gap.
- Treat MAPS_Lean's pilot guidance and risk table as useful design precedent
  only. Any FireRedRecomp process change still needs the local authority that
  changes its own `AGENTS.md`/coordination contract.
- The existing task-template/role separation is a local design functionally
  similar to MAPS_Lean concepts; it is not a copied or externally binding
  template.

## Findings strengthened by the addendum

| Topic | Addendum-supported conclusion | Future handling |
| --- | --- | --- |
| Proportionality | The reported pilot adapter says to choose the smallest useful operating depth. Its cited checks-and-balances table maps low risk to owner checks, medium risk to relevant tests plus independent review, and high risk to explicit task/evidence/review/visible summary. Uniform high-depth handling of isolated leaves remains a project-process concern. | Human decision before changing process. Compare a local L/M/H policy with the unproven lightweight portable `.maps/` convention; preserve independent review where required. |
| Reviewer independence | The reported operative standard excludes the author, a direct continuation/rotation successor, and a materially shared-editing co-author from independent review. | If local review metadata is changed, record reviewer identity/lineage and an affirmative exclusion check for those three cases. Do not retrofit unsupported claims into old reviews. |
| Friction learning | The addendum provides a concrete five-class schema and requires a verified countermeasure rather than a merely merged note. | If adopted locally, use its cited fixed classes: `operator-request`, `recurring-stall`, `tool-gap`, `drift`, `process-gap`; keep severity separate. This is a policy decision, not a spontaneous new log. |
| One fact / one authority | The addendum reports direct support for one canonical writer and derived views. | The observed FireRedRecomp duplicate-state problem remains valid, but consolidate only after a human chooses the local authority matrix and migration plan. |
| Local paths | Worktree isolation itself is appropriate; durable raw absolute paths are the issue. | Later replace durable local-path pointers with branch/revision references, while retaining optional local setup notes outside canonical state. |

## New consideration: private-runner operational independence

The addendum identifies a MAPS_Lean internal operational-independence gate for
repeatable setup/deployment workflows. Whether that method applies to this
single-operator private runner is undecided locally. The review finds no
first-time provisioning/recovery runbook.

Do not call this a violation. If the human elects to apply the method, create a
separate, security-reviewed private-runner runbook task covering recovery,
portable non-secret configuration, credential scope/provenance and an
appropriate reproduction check. If declined as not applicable, record that
explicitly in a local decision note to prevent repeated ambiguity.

## Decision queue for the project owner

No answer is assumed. When execution resumes and already-in-flight reviews are
complete, present these related choices together:

1. **Process depth:** retain current uniform orchestration; adopt a local
   risk-to-proof policy; or trial MAPS_Lean's lightweight external-file
   convention for low/medium work. The latter is reported as unproven because
   MAPS_Lean has not yet run an external pilot.
2. **Coordination authority:** choose a sole-writer/derived-view matrix before
   changing `STATE.json`, handoff, register, maps or automation.
3. **Review metadata:** decide whether future reviews must state an
   independence/lineage exclusion check.
4. **Friction learning:** adopt the cited fixed-schema log, adapt it, or leave
   the current process unchanged.
5. **Private runner runbook:** apply the operational-independence method or
   expressly mark it not applicable to the current single-operator model.
6. **Content policy:** clarify treatment of factual transcribed mechanics data
   separately from ROM/media/extracted assets.

The earlier branch-disposition decision (`master` harvest/park/drop) and bridge
hardening decision remain separate high-risk choices.

## Findings unaffected by this correction

The addendum does not weaken repository-specific findings that require their
own direct evidence: `main.lua` and battle-dispatch structural debt; source-text
tests; broad move fallback; evidence labels for non-LÖVE replay scripts; bridge
patch-target validation; divergent branches; and test-runner reporting. These
are candidates for future source-locked tasks, not automatic defects or parity
failures.

## Explicit non-actions

This report does not activate a `.maps/` directory, move current coordination
files, add a friction log, alter reviewer verdicts, change the bridge, provision
a runner, or treat MAPS_Lean's internal procedures as authority over this
repository. The user-requested execution pause remains unchanged.
