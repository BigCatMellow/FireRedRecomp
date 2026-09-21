# Task: preserve newest-save selection across u32 counter rollover

- Task ID: `P0-SAVE-ROLLOVER`
- Status: `IMPLEMENTED — PENDING INDEPENDENT REVIEW`
- Type: `IMPLEMENTATION / SOURCE-LOCKED CORRECTION`
- Parent capability gate: Phase 0 save reliability supporting the explicit P0-02 compatibility contract; broader save safety remains open.
- Assigned role: `WORKER`; independent reviewer: separate `REVIEWER` helper.
- Prerequisites: accepted discovery `b53c387` and independent PASS for save-contract package `63592c3`.
- Risk: `MEDIUM` — changes save generation selection; synthetic regression evidence and independent review are mandatory.

## Goal

Correct the reproduced stale-save selection at the maximum-u32/zero boundary
without changing the format, accepted schema domain or unrelated save policy.
The prerequisite package `63592c3` has
[independent PASS](../reviews/2026-09-21-save-version-contract-review.md).
Only the counter correction below is now authorized.

## Source of truth

- [Accepted discovery](../reports/phase0-save-version-contract.md) and its
  [independent review](../reviews/2026-09-20-save-version-discovery-review.md)
  reproduce returned counter 4294967296, stored zero, and stale selected
  generation 4294967295.
- Pinned FireRed source `c75f352304d529f6ba92d4f74b9cf8b5c3810788`,
  [`src/save.c`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/save.c):
  `gSaveCounter` is u32 (line 85); full-save increment (line 149);
  slot parity (line 176); footer counter (line 188);
  exact maximum-u32/zero special case (lines 534–550).
- Current `src/core/SaveFileCodec.lua` and the reviewed
  [project format](../../docs/save-format.md). This is a project container,
  not retail save import or a physical flash implementation.
- No unresolved design decision is needed for this literal source correction.
  General serial-number arithmetic and malformed API inputs are not in scope.

## MAY CHANGE

1. `src/core/SaveFileCodec.lua` — only u32 generation increment, both-valid-slot counter selection and directly related counter comments.
2. `tests/save_file_codec_test.lua` — targeted generation/footer/selection/corruption regression fixtures.
3. `tests/save_load_roundtrip_test.lua` — targeted save/load/resave boundary continuity evidence if needed.
4. `docs/save-format.md` — counter behavior, resolved rollover limitation and exact evidence only.
5. `docs/behavior-ledger.md` — saving/loading row's rollover evidence/limit only.
6. `docs/handoffs/firered-recomp-checklist.md` — existing save/load row's rollover limit/evidence only, no phase or broader safety closure.
7. This task — exact Worker results.

## MUST NOT CHANGE

Schema/version/header/sector layout, checksum algorithm, counter-consistency
validation, partial-field model, accepted/refused input schemas, migration,
suffix/prior-buffer policy, filesystem/UI/save callers, ROM policy, private
bridge, other runtime/tests, phase status or CI/inventory artifacts. Do not
replace the retail special case with generalized modular ordering, strengthen
decoder acceptance rules or alter corruption/EMPTY/ERROR handling. No real
user-save access, binary fixtures, extracted assets or filesystem-failure claim.

## Acceptance criteria

1. For supported u32 previous counters, encode increments modulo 2^32. Returned generation, all fourteen written footer counters, slot parity and subsequent decoded generation agree at 0xFFFFFFFE → 0xFFFFFFFF → 0 → 1.
2. With both slots valid, zero wins over 0xFFFFFFFF in either physical ordering, matching the pinned source's literal special case. All other unequal pairs retain unsigned larger-value selection; equal values retain slot 0. Do not introduce a half-range or arbitrary-wrap interpretation.
3. Synthetic states with distinct content prove current-state selection through encode/load/resave across the boundary, not merely counter metadata. The complete untouched prior slot remains byte-identical for canonical previous buffers.
4. Both physical orderings and ordinary/equal counter controls are covered. Reverse physical ordering is a synthetic project-decoder predicate control, not a claim that retail writing/loading ignores counter parity. Corrupting the newest wrapped slot still falls back to the valid pre-wrap slot; a single valid slot, two blank slots and no valid nonempty slot retain existing behavior.
5. Boundary expectations use literal u32 values and independently inspect serialized counter bytes. At least the rollover regression must fail against the pre-correction codec; do not merely mirror the new helper's arithmetic in expectations.
6. Keep version-1/unknown/unwrapped refusal, canonical version-2 size, all nine PC corruption fallbacks, normal low-counter roundtrips and full no-ROM suite green. Documentation removes only the demonstrated rollover defect, retaining suffix, filesystem and other limits.
7. Independent review checks exact source correspondence, behavioral diff, meaningful regression coverage and all claimed evidence before closure. Phase 0 and broader save reliability remain open.

## Required evidence

- Baseline: focused codec/roundtrip and full current no-ROM suite; reproduce the old rollover failure with synthetic state.
- Focused: `env -u POKEPORT_ROM lua5.1 tests/save_file_codec_test.lua` and `env -u POKEPORT_ROM lua5.1 tests/save_load_roundtrip_test.lua`.
- Full: `env -u POKEPORT_ROM bash scripts/test_all.sh`; run repository checks too if the parallel CI package has landed.
- Exact allowed-path audit, literal source anchors, serialized u32 witnesses, old-code regression failure and independent review.
- No ROM/replay required for this pure synthetic arithmetic/slot-selection correction; there is no imported-data or presentation change. Public no-ROM CI must remain green after publication.

## Stop / escalate when

The retail special case is ambiguous, required behavior needs a format/caller
change, an invalid-input/suffix/mixed-generation policy decision is needed, or
the positive boundary fixture cannot be satisfied within the literal scope.
Record the finding rather than broadening acceptance or editing user saves.

## Completion and handoff

Worker commits only these seven paths with exact evidence and reports the
revision. Parent coordinates publication and independent Reviewer returns
PASS / NEEDS_FIX / BLOCK. Orchestrator closes only this defect and re-evaluates
the parent gate. Suffix preservation and live-write safety remain separate
design leaves; clean-clone/CI evidence can proceed independently.

## Worker result — 2026-09-21

Implemented the literal u32 increment and maximum-u32/zero selection correction.
`encode` now returns the modulo-2^32 generation it writes in the footer;
both-valid-slot decoding special-cases only `{0xFFFFFFFF, 0}` in either order.
All other comparisons, equal-counter slot-0 selection, checksum/validation,
single-slot fallback and EMPTY/ERROR behavior retain their existing branches.
Directly related comments now describe the rollover exception and the actual
last-valid-sector counter source. No caller, format, migration, suffix or
filesystem behavior was changed.

Source correspondence was checked at pinned retail revision
`c75f352304d529f6ba92d4f74b9cf8b5c3810788`: u32 declaration at `src/save.c:85`,
increment at 149, slot parity at 176, written footer counter at 188, and exact
two-value ordering exception at 534–550. Reverse-slot fixtures are explicitly
project-decoder predicate controls; retail physical I/O still uses parity.

Evidence with Lua 5.1 and `POKEPORT_ROM` unset:

- Baseline at dispatch `eac7d69`: codec **63/0**, roundtrip **13/0**; full suite
  **150 files PASS** in the shared working tree, including the parallel CI
  Worker's new repository-check test (149 previously tracked test files).
- Added regression fixtures before changing the codec: codec **88 passed,
  5 failed**, roundtrip **14 passed, 2 failed**, both exit 1. Failures directly
  exposed returned 4294967296/4294967297, stale maximum-generation selection,
  both maximum/zero ordering predicates, and stale load/resave continuity.
- After the correction: `lua5.1 tests/save_file_codec_test.lua` **93/0** and
  `lua5.1 tests/save_load_roundtrip_test.lua` **16/0**; full
  `env -u POKEPORT_ROM bash scripts/test_all.sh` **150 files PASS**.
- After CI package `3478822` landed, `lua5.1 scripts/check_repository.lua`
  passed: **275 tracked Lua, 144 tracked Markdown, 168 local targets**.
  `git diff --check` and the exact seven-path audit passed.
- Boundary fixtures use literal `0xFFFFFFFE`, `0xFFFFFFFF`, zero and one,
  inspecting all fourteen four-byte footer counters against independently
  specified byte strings. Distinct money/location values prove content selection;
  complete previous-slot comparisons prove canonical preservation.
- Eleven literal slot-pair controls include both max/zero orders, ordinary
  values, non-special distant values that must retain unsigned ordering, and
  zero/ordinary/maximum ties. Corrupting the wrapped slot falls back to the
  valid pre-wrap state; single-valid, both-blank and corrupt-plus-blank cases
  preserve existing statuses. Earlier compatibility/PC corruption fixtures pass.

Only the seven authorized paths belong to this change. Parallel CI paths and
Orchestrator coordination remain outside Worker staging. Documentation updates
only counter behavior/evidence and removes the reproduced rollover limitation;
suffix preservation, mixed-generation acceptance, partial-field and filesystem
limits remain documented. No ROM, real save, binary fixture or phase-status
change is included. Independent exact-revision review and later public-CI
evidence remain required before the defect is closed.
