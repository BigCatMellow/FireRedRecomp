# Task: document and verify the existing save-version contract

- Task ID: `P0-02-CONTRACT`
- Status: `IMPLEMENTED — PENDING INDEPENDENT REVIEW`
- Type: `DOCUMENTATION / COMPATIBILITY FIXTURES`
- Parent capability gate: Phase 0 save-version contract, MAPSL `P0-02`.
- Assigned role: `WORKER`; independent reviewer: separate `REVIEWER` helper.
- Prerequisites: independent PASS for discovery `b53c387`; unchanged current codec behavior.
- Risk: `LOW` — documentation and synthetic tests only; no saved data or runtime changes.

## Goal and source of truth

Replace stale no-version claims with the implemented version-2/refusal contract
and establish focused fixtures for both historical and current formats.
Use the independently accepted discovery
[`../reports/phase0-save-version-contract.md`](../reports/phase0-save-version-contract.md),
codec revisions `a01040e` (version 1) and `103c5e1` (version 2), current codec
and roundtrip tests, and the completed save-file handoff's migration-or-refusal
policy. This contract preserves the current explicit version-1 refusal; it does
not introduce migration or recover absent PC data.

## MAY CHANGE

1. `docs/save-format.md` — concise explicit compatibility/limitation matrix and evidence.
2. `PARITY_CONTRACT.md` — save-version section only; link the detailed contract.
3. `docs/handoffs/firered-recomp-checklist.md` — stale save-version prose and relevant save evidence only; do not self-mark a gate complete.
4. `docs/behavior-ledger.md` — saving/loading row and evidence only.
5. `tests/save_file_codec_test.lua` — targeted synthetic compatibility/corruption fixtures.
6. `tests/save_load_roundtrip_test.lua` — correct full previous-slot preservation evidence.
7. This task — exact Worker results.

## MUST NOT CHANGE

Runtime/codec/save layout, version numbers, decoder tolerance, migration support,
real user saves, supported ROM policy, other tests, workflow/bridge, phase status,
or inventory artifacts. Do not encode known rollover/suffix bugs as desired
production-test behavior. Do not bundle their fixes, filesystem atomicity,
UI diagnostics, overwrite policy, stricter reader validation, retail import,
or mod compatibility. No binary save/ROM fixtures or extracted assets in git.

## Acceptance criteria

1. State canonical writes precisely: `FRSV`, version 2, eight-byte header, two 14-sector slots, total 114,696 bytes. Distinguish canonical output from current decoder tolerance, and project containers from retail saves.
2. Document the two historical schemas and explicit version-1/unknown/unwrapped refusal. No automatic migrations are currently supported. Future layout changes must explicitly specify migrations or refusals, with deterministic evidence for any supported migration; never best-effort field patching.
3. Add independent synthetic fixtures proving real version-1 shape refusal (40,968 bytes with two five-sector slots), literal current header/version/length, truncation rejection, and newest-slot PC-sector corruption fallback. Construct bytes in memory from known schema definitions; no git-history or external-file dependency in normal tests.
4. Replace the misleading first-five-header-byte assertion with verification of the entire preserved prior slot in the normal supported save sequence. Check the decoded chosen generation/content as relevant.
5. Separate codec checksum/slot fallback from unproven filesystem atomicity. Record rollover and suffix-preservation limitations as pending separate leaves, without implying every tolerated or unchecked field is safe or permanently guaranteed.
6. Correct stale charter/checklist claims without changing current refusal policy or declaring a phase complete. Link exact fixtures/evidence so another agent can verify the compatibility claim.
7. Focused codec/roundtrip tests and the full no-ROM suite pass. Independent review checks exact diff and meaningful fixture coverage before any save-contract gate closure.

## Required evidence

- Baseline: existing 45/0 codec and 13/0 roundtrip checks at unchanged runtime; rerun focused baseline before changing tests as needed.
- Focused: `lua5.1 tests/save_file_codec_test.lua` and `lua5.1 tests/save_load_roundtrip_test.lua`, no ROM.
- Full: `env -u POKEPORT_ROM bash scripts/test_all.sh`; no ROM/replay required because no runtime or imported-data behavior changes.
- Exact changed-path audit, no binary/user save content, and independent review.

## Stop / escalate when

A required positive fixture cannot pass without runtime change, a historical
format fact cannot be justified, or compatibility/policy changes are needed.
Record the finding and route the smallest separate correction; do not weaken
fixtures, repair user saves, or silently broaden scope.

## Completion and handoff

Worker reports exact diff/tests and commits only allowed paths. Reviewer returns
PASS / NEEDS_FIX / BLOCK. Orchestrator may then reconcile only the explicit
save-contract gate and select a separate source-locked rollover correction or
other evidenced remaining gate. Phase 0 and broader save safety remain open.

## Dispatch

Discovery `b53c387` independently passed
[`review`](../reviews/2026-09-20-save-version-discovery-review.md), including
45/0 codec, 13/0 roundtrip and 24/24 synthetic characterization checks. Worker
may execute this exact documentation/fixture package. The existing refusal
policy requires no new human migration decision. Counter-rollover, suffix and
live-file safety changes remain separate future tasks.

## Worker result — 2026-09-21

Implemented only the seven listed documentation/test paths, based on dispatch
`2686e44`. The intervening CI research/relay commits through `3a6443f` do not
change the codec, runtime, layout, storage, or focused-test baseline. Their
disjoint work was preserved.

[`docs/save-format.md`](../../docs/save-format.md) now records canonical
version-2 output, both historical shapes, existing refusal policy, decoder
tolerance and separate corruption/filesystem limits. The charter's save section,
relevant checklist save prose and ledger row link that contract without changing
phase/checklist completion states. Counter rollover, suffix preservation,
filesystem failure safety and migration remain separate work.

The codec test independently builds two valid five-sector version-1 slots in
memory, with literal historical footer/layout definitions and zero payload
checksums. It verifies explicit version refusal, literal current header/length,
unwrapped refusal, truncation at 4/7/8/114695 bytes, and complete older-generation
fallback after payload corruption in each PC sector 5–13. The roundtrip test
compares all 57,344 bytes of the preserved previous slot, replacing the former
five-header-byte comparison; existing newer-generation/location checks remain.

Evidence, using the isolated Lua 5.1 toolchain with `POKEPORT_ROM` unset:

- Before edits: codec **45 passed, 0 failed**; roundtrip **13 passed, 0 failed**;
  full no-ROM suite **149 files PASS**.
- After edits: `lua5.1 tests/save_file_codec_test.lua` **63/0**;
  `lua5.1 tests/save_load_roundtrip_test.lua` **13/0**;
  `env -u POKEPORT_ROM bash scripts/test_all.sh` **149 files PASS**.
- One-off historical witness: the exact new legacy-fixture constructor,
  extracted from the test, is accepted by codec `a01040e` as generation 2,
  slot 0, with no PokemonStorage. This confirms a valid historical shape;
  normal tests have no git-history, ROM or external-fixture dependency.
- One-off in-memory mutation: an encoder wrapper that discards prior bytes
  triggers exactly the strengthened full-slot assertion, while the other
  twelve roundtrip checks remain satisfied. No runtime file was edited.
- `git diff --check` passed; only the seven allowed text/Lua paths are included
  in the implementation commit. No binary/user-save/ROM content was added.

The existing synthetic scratch-file fixture ran under a fresh temporary
directory for final checks; generated compatibility/corruption buffers remain
in memory. No ROM/replay or filesystem failure-injection claim is made.
Independent exact-revision review remains required before any gate closure;
Orchestrator owns coordination and publication.
