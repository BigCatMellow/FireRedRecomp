# P0-SAVE-ROLLOVER independent implementation review

- Disposition: **PASS** — only the bounded u32 generation/selection correction.
- Exact implementation: `aec377a07e73fb5e5edab5163c0be51c7881bb65`.
- Parent: `2ac79495300f2e83a34f2ab0f91c8c69666749b0`.
- Implementation tree: `79f498265960f96718606b101290881392c60346`.
- Contract: [P0-SAVE-ROLLOVER](../tasks/phase0-save-counter-rollover.md).
- Review date: 2026-09-23, after the user resumed the paused review queue.
- Independent live recovery initially found main at
  `dbb916be2bf9334f52f51dcbb39a30a35d0c48d4`; resumed coordination identifies
  the exact implementation above as `READY_FOR_REVIEWER`.

## Scope and source correspondence

The exact parent-to-implementation diff contains only the seven authorized
text paths: `src/core/SaveFileCodec.lua`, the two specified save tests,
`docs/save-format.md`, the saving/loading row in `docs/behavior-ledger.md`,
the existing save/load row in `docs/handoffs/firered-recomp-checklist.md`,
and the task. `git diff HEAD^ HEAD --check` passes. No ROM, user save, binary
fixture, extracted asset, generated cache, workflow or unrelated runtime
change entered this commit.

The only behavioral edits are `(previousCounter + 1) % 4294967296` and the
two explicit both-valid-slot maximum-u32/zero cases. For supported integer
u32 inputs, the Lua arithmetic exactly represents this increment and modulus.
Every other unequal pair retains unsigned larger-value selection; ties retain
slot 0. Header/schema, layout, checksums, slot validation, accepted/refused
inputs, previous-buffer handling, single-valid fallback, EMPTY/ERROR branches,
callers and filesystem behavior are unchanged. The corrected last-valid-sector
comment describes existing behavior; it does not add counter-consistency
validation.

The local reference checkout was independently confirmed at
`c75f352304d529f6ba92d4f74b9cf8b5c3810788`. Its
[u32 declaration and increment](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/save.c#L85)
are at `src/save.c:85` and `:149`; slot parity and written footer counter are
at `:176` and `:188`. The two slot counters are u32 at `:471–472`.
The [literal selection exception](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/save.c#L534)
at `:534–550` selects zero over maximum-u32 in either ordering, otherwise the
larger unsigned counter. The implementation matches that predicate; it does
not substitute general modular/half-range serial-number ordering.

This is source correspondence for a project save container, not evidence of
retail save import, physical flash rotation, ROM execution or durable writes.
Reverse physical ordering remains an intentional synthetic project-decoder
control; it does not claim retail I/O disregards counter parity.

## Independently verified public CI

[Run 35665565029](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/35665565029)
at exact `aec377a07e73fb5e5edab5163c0be51c7881bb65`, created
`2026-09-21T23:01:10Z`, completed successfully.
[Job 106550408501](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/35665565029/job/106550408501)
(`test`, `23:01:15Z–23:01:41Z`) reports every step successful, including the
named repository check and unchanged no-ROM suite.

Actual job logs, not just run metadata, independently show:

- Empty repository initialization and checkout of the exact implementation SHA.
- `23:01:37.6362001Z`: repository checks PASS — 275 tracked Lua, 144 tracked
  Markdown, 168 local targets.
- `23:01:39.6829778Z`: **150 test files PASS in no-ROM mode**, with explicit
  clean ROM-dependent skips earlier in the log.

Receipts were recovered with `gh run view 35665565029 --json
databaseId,headSha,createdAt,conclusion,url,jobs` (repository specified) and
`gh api repos/BigCatMellow/FireRedRecomp/actions/jobs/106550408501/logs`.
No workflow dispatch or rerun was performed. No-ROM file counts do not imply
non-skipped retail-ROM or replay assertions. The separate CI-checker
implementation review remains owned by another Reviewer.

## Independent local verification

A separate local clone at `/tmp/firered-rollover-review.j4Vryv` was detached
at the exact implementation SHA and remained clean throughout this review.
No shared-checkout or later coordination edits were included. Commands used
the provisioned Lua 5.1 toolchain and no supplied ROM:

| Command / witness | Independent result |
| --- | --- |
| `env -u POKEPORT_ROM lua5.1 tests/save_file_codec_test.lua` | **93 passed, 0 failed** |
| `env -u POKEPORT_ROM lua5.1 tests/save_load_roundtrip_test.lua` | **16 passed, 0 failed** |
| `lua5.1 scripts/check_repository.lua` | **275 Lua / 144 Markdown / 168 local targets PASS** |
| `env -u POKEPORT_ROM -u POKEPORT_RUNTIME_REPLAY bash scripts/test_all.sh` | **150 test files PASS, no-ROM mode** |
| Exact new codec tests with only the parent codec loaded | Exit 1; **88 passed, 5 failed** |
| Exact new roundtrip tests with only the parent codec loaded | Exit 1; **14 passed, 2 failed** |
| Separate Reviewer boundary/selection harness | **120 assertions PASS**, including 56 serialized u32 footer inspections and 49 slot-counter pairs |

For the old-code witnesses, a read-only `git show
aec377a07e73fb5e5edab5163c0be51c7881bb65^:src/core/SaveFileCodec.lua` supplied
the module source to `loadstring`; its returned module replaced only
`package.loaded['src.core.SaveFileCodec']` before `dofile` ran each exact new
test in a separate Lua process. No repository file was overwritten. Failures
were the reported unwrapped returned counters 4294967296/4294967297, stale
maximum-generation content, both maximum/zero ordering cases, and wrapped
session load/resave continuity. Thus the regressions detect the old defect,
rather than merely accepting the new code's own arithmetic.

The separate Reviewer harness used synthetic new-game state, literal expected
generations/parities/content, and direct little-endian decoding of all fourteen
footer counters at each of `0xFFFFFFFE`, `0xFFFFFFFF`, zero and one. It also
checked unchanged schema-2 header/114696-byte size and all 57344 bytes of each
preserved prior slot. A literal 7×7 expected-slot table covered counters zero,
one, two, `0x7FFFFFFF`, `0x80000000`, `0xFFFFFFFE` and `0xFFFFFFFF`; distinct
slot money values verified selected content as well as slot/generation.
These controls cover ordinary/tied/distant values and both maximum/zero orders
without using the codec's predicate to calculate expectations.

Direct test inspection additionally confirms meaningful wrapped-slot
corruption fallback, a single valid wrapped slot, two blank slots and
corrupt-plus-blank status controls. Existing independent legacy-version
refusal, unknown/unwrapped/truncated input, all nine PC-sector corruption
fallbacks, low-counter roundtrips and full prior-slot fixtures remain present
and pass. No invalid-input domain or corruption acceptance rule was widened.

## Documentation and remaining limits

Documentation accurately removes only the demonstrated rollover defect and
adds its source/test evidence. The checklist still marks the broader save/load
capability partial and notes independent-review gating at the implementation
revision. Suffix/prior-buffer preservation limits, mixed-generation acceptance,
partial fields, physical rotation and filesystem failure/atomicity remain
separate limitations. No whole Phase 0, general save safety, retail parity or
ROM-backed claim is supported by this PASS.

## Exact next allowance

Orchestrator may accept `aec377a07e73fb5e5edab5163c0be51c7881bb65` and close
only `P0-SAVE-ROLLOVER`, recording this review and the exact public receipt.
Continue the separately scoped CI/clean-clone/ledger gates or compile an
explicitly bounded save-safety successor; this review does not authorize
suffix, migration, overwrite, filesystem or general counter-policy changes.
Phase 0 and broader save reliability remain open. The private-ROM runner is
not a prerequisite for this synthetic arithmetic correction and its inventory
blocker is not cleared by this result.

Reviewer wrote only this review. No implementation, coordination, commit,
push, user-save access or private-ROM action was performed.
