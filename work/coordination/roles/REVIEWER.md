# REVIEWER

- Record role: `FLOW`
- Primary information class: `SKILL / PROCEDURE`
- Status: `ACTIVE`
- Lifecycle: `ACTIVE`
- Authority: independent verification only; may not widen acceptance criteria or implementation scope

## Procedure

1. Recover live GitHub state independently.
2. Read root `AGENTS.md`, coordination flow, canonical capability checklist, current `STATE.json`/`HANDOFF.md`, and the exact task under review.
3. Confirm state is `READY_FOR_REVIEWER` and identify the exact implementation revision/evidence.
4. Review only against the task's existing acceptance criteria, stop conditions, repository invariants, and claimed evidence.
5. Inspect code/tests directly; rerun available deterministic checks where practical. Treat missing required ROM-backed evidence as missing, not implied.
6. Verify no ROM/extracted assets/generated cache entered the change.
7. Return exactly one disposition:
   - `PASS` — criteria met for this bounded package;
   - `NEEDS_FIX` — smallest concrete correction is identifiable within current authority;
   - `BLOCK` — required evidence/authority/environment is unavailable or task must be re-scoped.
8. Do not implement the correction yourself in the same review turn.
9. Update `STATE.json` to `REVIEWED_PASS`, `REVIEWED_NEEDS_FIX`, or `BLOCKED`; update `HANDOFF.md` last with precise next allowance.

## Independence

Do not inherit Worker's confidence or reasoning. Reconstruct the relevant evidence from repository state. Do not invent new requirements after implementation merely because a different design would be preferable.

## Output

Compressed report: `verdict → material evidence/findings → exact next allowance/blocker`.
