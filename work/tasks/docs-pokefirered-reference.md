# Task: make the pokefirered reference portable and pinned

- Task ID: `DOC-POKEFIRERED-REF`
- Status: `READY_FOR_REVIEW`
- Type: `DOCUMENTATION / REFERENCE HYGIENE`
- Parent capability gate: none; human-requested documentation maintenance.
- Risk: `LOW`.

## Goal

Replace the machine-specific FireRed decomp path with a canonical upstream
reference and an explicit pinned revision, while preserving FireRedRecomp's
existing player-supplied-ROM and no-derived-content model.

## MAY CHANGE

1. `docs/reference/source-inventory.md`.
2. `README.md`.
3. This task file.

## MUST NOT CHANGE

Runtime code, importer behavior, tests, workflows, capability/phase status,
supported-ROM policy, coordination state, ROM/media content, or the existing
balance implementation branch.

## Acceptance criteria

1. Name `pret/pokefirered` as the canonical FireRed decomp/reference source.
2. Pin the exact observed upstream revision
   `037335f4c725d7c9aecdac87066f2002b4bd7e14`.
3. Make clear that the decomp is reference-only, not vendored and not a
   FireRedRecomp build/runtime dependency.
4. Document a portable local-checkout convention without claiming an existing
   script dependency.
5. Preserve the player-supplied verified-ROM model and no-ROM/no-extracted-
   content boundary.
6. Keep this change separate from gameplay/balance work.

## Completion and handoff

Documentation-only change. Review the exact diff for scope, link correctness,
reference SHA, and preservation of the content boundary before merge.
